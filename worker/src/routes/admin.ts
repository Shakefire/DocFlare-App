import { Hono } from 'hono';
import type { Env } from '../types/env';
import { requireAuth, resolveOrgMembership, type AuthVariables } from '../middleware/auth';
import { requireCapability } from '../lib/permissions';
import { Errors } from '../lib/errors';
import { parsePagination } from '../lib/validation';
import { writeAuditLog } from '../lib/audit';

const adminRoutes = new Hono<{ Bindings: Env; Variables: AuthVariables }>();

// GET /api/v1/organizations/:organizationId/trash
// List documents in trash
adminRoutes.get('/organizations/:organizationId/trash', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'document.read');

  const url = new URL(c.req.url);
  const { page, perPage, offset } = parsePagination(url);

  const totalRow = await c.env.DB
    .prepare('SELECT COUNT(*) as count FROM documents WHERE organization_id = ? AND deleted_at IS NOT NULL')
    .bind(organizationId)
    .first<{ count: number }>();

  const total = totalRow?.count ?? 0;

  const docs = await c.env.DB
    .prepare(
      `SELECT id, organization_id, folder_id, owner_id, uploaded_by, display_name,
              content_type, file_size_bytes, description, deleted_at, created_at, updated_at
       FROM documents
       WHERE organization_id = ? AND deleted_at IS NOT NULL
       ORDER BY deleted_at DESC
       LIMIT ? OFFSET ?`
    )
    .bind(organizationId, perPage, offset)
    .all();

  return c.json({
    data: docs.results,
    meta: {
      total,
      page,
      per_page: perPage,
      has_more: offset + perPage < total,
    },
  });
});

// DELETE /api/v1/organizations/:organizationId/trash/:documentId
// Permanent deletion of a soft-deleted document
adminRoutes.delete('/organizations/:organizationId/trash/:documentId', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId, documentId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'organization.manage');

  const doc = await c.env.DB
    .prepare(
      `SELECT id, organization_id, object_key, file_size_bytes, display_name, deleted_at
       FROM documents WHERE id = ? AND organization_id = ? LIMIT 1`
    )
    .bind(documentId, organizationId)
    .first<{
      id: string;
      organization_id: string;
      object_key: string;
      file_size_bytes: number;
      display_name: string;
      deleted_at: string | null;
    }>();

  if (!doc) throw Errors.notFound('Document in trash');
  if (!doc.deleted_at) {
    throw Errors.badRequest('Document must be moved to trash before it can be permanently deleted.');
  }

  // Delete from R2 object store
  await c.env.BUCKET.delete(doc.object_key);

  const now = new Date().toISOString();
  await c.env.DB.batch([
    c.env.DB.prepare('DELETE FROM documents WHERE id = ?').bind(documentId),
    c.env.DB.prepare(
      `UPDATE organizations
       SET storage_used_bytes = MAX(0, storage_used_bytes - ?), updated_at = ?
       WHERE id = ?`
    ).bind(doc.file_size_bytes, now, organizationId),
  ]);

  await writeAuditLog(c.env.DB, {
    organizationId,
    actorUserId: auth.userId,
    action: 'document.permanently_deleted',
    resourceType: 'document',
    resourceId: documentId,
    metadata: { display_name: doc.display_name, file_size_bytes: doc.file_size_bytes },
  });

  return c.json({ data: { message: 'Document permanently deleted.' } });
});

// GET /api/v1/organizations/:organizationId/audit-logs
// Audit logs for authorized administrators
adminRoutes.get('/organizations/:organizationId/audit-logs', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'audit.read');

  const url = new URL(c.req.url);
  const { page, perPage, offset } = parsePagination(url);
  const actionFilter = url.searchParams.get('action');
  const resourceType = url.searchParams.get('resource_type');

  let where = 'WHERE al.organization_id = ?';
  const params: unknown[] = [organizationId];

  if (actionFilter) {
    where += ' AND al.action = ?';
    params.push(actionFilter);
  }

  if (resourceType) {
    where += ' AND al.resource_type = ?';
    params.push(resourceType);
  }

  const totalRow = await c.env.DB
    .prepare(`SELECT COUNT(*) as count FROM audit_logs al ${where}`)
    .bind(...params)
    .first<{ count: number }>();

  const total = totalRow?.count ?? 0;

  const logs = await c.env.DB
    .prepare(
      `SELECT al.id, al.organization_id, al.actor_user_id, al.action, al.resource_type,
              al.resource_id, al.metadata_json, al.created_at, u.email as actor_email
       FROM audit_logs al
       LEFT JOIN users u ON u.id = al.actor_user_id
       ${where}
       ORDER BY al.created_at DESC
       LIMIT ? OFFSET ?`
    )
    .bind(...params, perPage, offset)
    .all();

  return c.json({
    data: logs.results,
    meta: {
      total,
      page,
      per_page: perPage,
      has_more: offset + perPage < total,
    },
  });
});

// GET /api/v1/organizations/:organizationId/storage-usage
// Detailed storage usage breakdown
adminRoutes.get('/organizations/:organizationId/storage-usage', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'document.read');

  const org = await c.env.DB
    .prepare('SELECT storage_quota_bytes, storage_used_bytes FROM organizations WHERE id = ? LIMIT 1')
    .bind(organizationId)
    .first<{ storage_quota_bytes: number; storage_used_bytes: number }>();

  if (!org) throw Errors.notFound('Organization');

  const breakdown = await c.env.DB
    .prepare(
      `SELECT
        CASE
          WHEN content_type LIKE 'image/%' THEN 'image'
          WHEN content_type = 'application/pdf' THEN 'pdf'
          WHEN content_type LIKE 'video/%' THEN 'video'
          WHEN content_type LIKE '%word%' OR content_type LIKE '%officedocument%' THEN 'office'
          ELSE 'other'
        END AS category,
        COUNT(*) as count,
        SUM(file_size_bytes) as total_bytes
       FROM documents
       WHERE organization_id = ? AND deleted_at IS NULL AND upload_status = 'completed'
       GROUP BY category`
    )
    .bind(organizationId)
    .all<{ category: string; count: number; total_bytes: number }>();

  const trashStats = await c.env.DB
    .prepare(
      `SELECT COUNT(*) as trash_count, SUM(file_size_bytes) as trash_bytes
       FROM documents
       WHERE organization_id = ? AND deleted_at IS NOT NULL`
    )
    .bind(organizationId)
    .first<{ trash_count: number; trash_bytes: number }>();

  const usedBytes = org.storage_used_bytes || 0;
  const quotaBytes = org.storage_quota_bytes || 1;
  const percentage = Math.min(100, Math.round((usedBytes / quotaBytes) * 10000) / 100);

  return c.json({
    data: {
      storage_used_bytes: usedBytes,
      storage_quota_bytes: quotaBytes,
      usage_percentage: percentage,
      by_category: breakdown.results,
      trash: {
        count: trashStats?.trash_count ?? 0,
        bytes: trashStats?.trash_bytes ?? 0,
      },
    },
  });
});

export { adminRoutes };

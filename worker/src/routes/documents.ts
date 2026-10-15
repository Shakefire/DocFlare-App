import { Hono } from 'hono';
import type { Env } from '../types/env';
import { requireAuth, resolveOrgMembership, type AuthVariables } from '../middleware/auth';
import { requireCapability } from '../lib/permissions';
import { Errors } from '../lib/errors';
import { parsePagination, isPreviewable } from '../lib/validation';
import { writeAuditLog } from '../lib/audit';

const documentRoutes = new Hono<{ Bindings: Env; Variables: AuthVariables }>();

// Helper to resolve document with org authorization
async function resolveDocument(db: D1Database, userId: string, documentId: string, allowDeleted = false) {
  const doc = await db
    .prepare(
      `SELECT d.id, d.organization_id, d.folder_id, d.owner_id, d.uploaded_by, d.display_name,
              d.object_key, d.content_type, d.file_size_bytes, d.checksum, d.description,
              d.upload_status, d.created_at, d.updated_at, d.deleted_at
       FROM documents d
       WHERE d.id = ? LIMIT 1`
    )
    .bind(documentId)
    .first<{
      id: string;
      organization_id: string;
      folder_id: string | null;
      owner_id: string;
      uploaded_by: string;
      display_name: string;
      object_key: string;
      content_type: string;
      file_size_bytes: number;
      checksum: string | null;
      description: string | null;
      upload_status: string;
      created_at: string;
      updated_at: string;
      deleted_at: string | null;
    }>();

  if (!doc) throw Errors.notFound('Document');
  if (!allowDeleted && doc.deleted_at) throw Errors.notFound('Document');

  const member = await resolveOrgMembership(db, userId, doc.organization_id);
  if (!member) throw Errors.notFound('Document');

  return { doc, member };
}

// GET /api/v1/organizations/:organizationId/documents
documentRoutes.get('/organizations/:organizationId/documents', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'document.read');

  const url = new URL(c.req.url);
  const { page, perPage, offset } = parsePagination(url);
  const folderId = url.searchParams.get('folder_id');
  const typeFilter = url.searchParams.get('type');
  const sortBy = url.searchParams.get('sort_by') || 'created_at';
  const sortOrder = url.searchParams.get('order')?.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

  let where = `WHERE organization_id = ? AND deleted_at IS NULL AND upload_status = 'completed'`;
  const params: unknown[] = [organizationId];

  if (folderId !== null) {
    if (folderId === 'null' || folderId === '') {
      where += ' AND folder_id IS NULL';
    } else {
      where += ' AND folder_id = ?';
      params.push(folderId);
    }
  }

  if (typeFilter) {
    where += ' AND content_type LIKE ?';
    params.push(`%${typeFilter}%`);
  }

  // Validate sort field
  const validSorts: Record<string, string> = {
    created_at: 'created_at',
    display_name: 'display_name',
    file_size_bytes: 'file_size_bytes',
    updated_at: 'updated_at',
  };
  const sortCol = validSorts[sortBy] || 'created_at';

  const totalRow = await c.env.DB
    .prepare(`SELECT COUNT(*) as count FROM documents ${where}`)
    .bind(...params)
    .first<{ count: number }>();

  const total = totalRow?.count ?? 0;

  const docs = await c.env.DB
    .prepare(
      `SELECT id, organization_id, folder_id, owner_id, uploaded_by, display_name,
              content_type, file_size_bytes, description, upload_status, created_at, updated_at
       FROM documents
       ${where}
       ORDER BY ${sortCol} ${sortOrder}
       LIMIT ? OFFSET ?`
    )
    .bind(...params, perPage, offset)
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

// GET /api/v1/documents/:documentId
documentRoutes.get('/documents/:documentId', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { documentId } = c.req.param();
  const { doc, member } = await resolveDocument(c.env.DB, auth.userId, documentId);
  requireCapability(member.role, 'active', 'document.read');

  // Strip internal object key from normal metadata
  const { object_key, ...safeDoc } = doc;
  return c.json({ data: safeDoc });
});

// GET /api/v1/documents/:documentId/download
documentRoutes.get('/documents/:documentId/download', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { documentId } = c.req.param();
  const { doc, member } = await resolveDocument(c.env.DB, auth.userId, documentId);
  requireCapability(member.role, 'active', 'document.download');

  const object = await c.env.BUCKET.get(doc.object_key);
  if (!object) {
    throw Errors.notFound('Stored file object');
  }

  await writeAuditLog(c.env.DB, {
    organizationId: doc.organization_id,
    actorUserId: auth.userId,
    action: 'document.downloaded',
    resourceType: 'document',
    resourceId: doc.id,
    metadata: { display_name: doc.display_name, file_size: doc.file_size_bytes },
  });

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);
  headers.set('Content-Type', doc.content_type || 'application/octet-stream');
  headers.set('Content-Disposition', `attachment; filename="${encodeURIComponent(doc.display_name)}"`);
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Cache-Control', 'private, no-cache, no-store, must-revalidate');

  return new Response(object.body, { headers });
});

// GET /api/v1/documents/:documentId/preview
documentRoutes.get('/documents/:documentId/preview', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { documentId } = c.req.param();
  const { doc, member } = await resolveDocument(c.env.DB, auth.userId, documentId);
  requireCapability(member.role, 'active', 'document.read');

  if (!isPreviewable(doc.content_type)) {
    throw Errors.badRequest('This file type cannot be previewed directly. Please download the file instead.');
  }

  const object = await c.env.BUCKET.get(doc.object_key);
  if (!object) {
    throw Errors.notFound('Stored file object');
  }

  await writeAuditLog(c.env.DB, {
    organizationId: doc.organization_id,
    actorUserId: auth.userId,
    action: 'document.previewed',
    resourceType: 'document',
    resourceId: doc.id,
    metadata: { display_name: doc.display_name },
  });

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);
  headers.set('Content-Type', doc.content_type);
  headers.set('Content-Disposition', `inline; filename="${encodeURIComponent(doc.display_name)}"`);
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Cache-Control', 'private, max-age=3600');

  return new Response(object.body, { headers });
});

// PATCH /api/v1/documents/:documentId
documentRoutes.patch('/documents/:documentId', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { documentId } = c.req.param();
  const { doc, member } = await resolveDocument(c.env.DB, auth.userId, documentId);
  requireCapability(member.role, 'active', 'document.update');

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { display_name, description, folder_id } = body as {
    display_name?: string;
    description?: string;
    folder_id?: string | null;
  };

  const updates: string[] = [];
  const params: unknown[] = [];
  const now = new Date().toISOString();

  if (display_name !== undefined) {
    if (!display_name.trim() || display_name.trim().length > 255) {
      throw Errors.unprocessable('Display name must be between 1 and 255 characters.');
    }
    updates.push('display_name = ?');
    params.push(display_name.trim());
  }

  if (description !== undefined) {
    updates.push('description = ?');
    params.push(description ? description.trim() : null);
  }

  if (folder_id !== undefined) {
    const targetFolderId = folder_id || null;
    if (targetFolderId) {
      const folder = await c.env.DB
        .prepare('SELECT id, organization_id FROM folders WHERE id = ? AND deleted_at IS NULL LIMIT 1')
        .bind(targetFolderId)
        .first<{ id: string; organization_id: string }>();

      if (!folder || folder.organization_id !== doc.organization_id) {
        throw Errors.badRequest('Destination folder not found in this organization.');
      }
    }
    updates.push('folder_id = ?');
    params.push(targetFolderId);
  }

  if (updates.length === 0) {
    const { object_key, ...safeDoc } = doc;
    return c.json({ data: safeDoc });
  }

  updates.push('updated_at = ?');
  params.push(now);
  params.push(documentId);

  await c.env.DB
    .prepare(`UPDATE documents SET ${updates.join(', ')} WHERE id = ?`)
    .bind(...params)
    .run();

  await writeAuditLog(c.env.DB, {
    organizationId: doc.organization_id,
    actorUserId: auth.userId,
    action: 'document.updated',
    resourceType: 'document',
    resourceId: documentId,
    metadata: { display_name, description, folder_id },
  });

  const updated = await c.env.DB
    .prepare(
      `SELECT id, organization_id, folder_id, owner_id, uploaded_by, display_name,
              content_type, file_size_bytes, description, upload_status, created_at, updated_at
       FROM documents WHERE id = ? LIMIT 1`
    )
    .bind(documentId)
    .first();

  return c.json({ data: updated });
});

// DELETE /api/v1/documents/:documentId (Soft Delete)
documentRoutes.delete('/documents/:documentId', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { documentId } = c.req.param();
  const { doc, member } = await resolveDocument(c.env.DB, auth.userId, documentId);
  requireCapability(member.role, 'active', 'document.delete');

  const now = new Date().toISOString();
  await c.env.DB
    .prepare('UPDATE documents SET deleted_at = ?, updated_at = ? WHERE id = ?')
    .bind(now, now, documentId)
    .run();

  await writeAuditLog(c.env.DB, {
    organizationId: doc.organization_id,
    actorUserId: auth.userId,
    action: 'document.deleted',
    resourceType: 'document',
    resourceId: documentId,
    metadata: { display_name: doc.display_name },
  });

  return c.json({ data: { message: 'Document moved to trash successfully.' } });
});

// POST /api/v1/documents/:documentId/restore
documentRoutes.post('/documents/:documentId/restore', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { documentId } = c.req.param();
  const { doc, member } = await resolveDocument(c.env.DB, auth.userId, documentId, true);
  requireCapability(member.role, 'active', 'document.restore');

  if (!doc.deleted_at) {
    return c.json({ data: { message: 'Document is not in trash.' } });
  }

  // Verify that the underlying R2 storage object still exists
  const head = await c.env.BUCKET.head(doc.object_key);
  if (!head) {
    throw Errors.conflict('Cannot restore document because the storage object is no longer available in R2.');
  }

  const now = new Date().toISOString();
  await c.env.DB
    .prepare('UPDATE documents SET deleted_at = NULL, updated_at = ? WHERE id = ?')
    .bind(now, documentId)
    .run();

  await writeAuditLog(c.env.DB, {
    organizationId: doc.organization_id,
    actorUserId: auth.userId,
    action: 'document.restored',
    resourceType: 'document',
    resourceId: documentId,
    metadata: { display_name: doc.display_name },
  });

  return c.json({ data: { message: 'Document restored successfully.' } });
});

export { documentRoutes };

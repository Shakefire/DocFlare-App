import { Hono } from 'hono';
import type { Env } from '../types/env';
import { requireAuth, resolveOrgMembership, type AuthVariables } from '../middleware/auth';
import { requireCapability } from '../lib/permissions';
import { Errors } from '../lib/errors';
import { parsePagination } from '../lib/validation';

const searchRoutes = new Hono<{ Bindings: Env; Variables: AuthVariables }>();

// GET /api/v1/organizations/:organizationId/search
searchRoutes.get('/organizations/:organizationId/search', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'document.read');

  const url = new URL(c.req.url);
  const { page, perPage, offset } = parsePagination(url);

  const query = url.searchParams.get('q') || url.searchParams.get('query') || '';
  const folderId = url.searchParams.get('folder_id');
  const typeFilter = url.searchParams.get('type');
  const ownerId = url.searchParams.get('owner_id');
  const sortBy = url.searchParams.get('sort_by') || 'created_at';
  const sortOrder = url.searchParams.get('order')?.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

  let where = `WHERE organization_id = ? AND deleted_at IS NULL AND upload_status = 'completed'`;
  const params: unknown[] = [organizationId];

  if (query.trim()) {
    where += ' AND display_name LIKE ?';
    params.push(`%${query.trim()}%`);
  }

  if (folderId) {
    if (folderId === 'root') {
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

  if (ownerId) {
    where += ' AND owner_id = ?';
    params.push(ownerId);
  }

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

export { searchRoutes };

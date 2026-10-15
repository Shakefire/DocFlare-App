import { Hono } from 'hono';
import type { Env } from '../types/env';
import { requireAuth, resolveOrgMembership, type AuthVariables } from '../middleware/auth';
import { requireCapability } from '../lib/permissions';
import { generateId } from '../lib/id';
import { Errors } from '../lib/errors';
import { writeAuditLog } from '../lib/audit';

const folderRoutes = new Hono<{ Bindings: Env; Variables: AuthVariables }>();

// Helper to resolve folder with org authorization
async function resolveFolder(db: D1Database, userId: string, folderId: string) {
  const folder = await db
    .prepare('SELECT id, organization_id, parent_folder_id, name, created_by, created_at, updated_at, deleted_at FROM folders WHERE id = ? LIMIT 1')
    .bind(folderId)
    .first<{ id: string; organization_id: string; parent_folder_id: string | null; name: string; created_by: string; created_at: string; updated_at: string; deleted_at: string | null }>();

  if (!folder || folder.deleted_at) {
    throw Errors.notFound('Folder');
  }

  const member = await resolveOrgMembership(db, userId, folder.organization_id);
  if (!member) {
    throw Errors.notFound('Folder');
  }

  return { folder, member };
}

// Check circular hierarchy
async function isDescendantOf(db: D1Database, potentialAncestorId: string, targetFolderId: string | null): Promise<boolean> {
  let currentId = targetFolderId;
  const visited = new Set<string>();

  while (currentId) {
    if (currentId === potentialAncestorId) return true;
    if (visited.has(currentId)) break;
    visited.add(currentId);

    const parent = await db
      .prepare('SELECT parent_folder_id FROM folders WHERE id = ? LIMIT 1')
      .bind(currentId)
      .first<{ parent_folder_id: string | null }>();

    currentId = parent?.parent_folder_id ?? null;
  }
  return false;
}

// GET /api/v1/organizations/:organizationId/folders
folderRoutes.get('/organizations/:organizationId/folders', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'document.read');

  const parentId = c.req.query('parent_folder_id');

  let query = 'SELECT id, organization_id, parent_folder_id, name, created_by, created_at, updated_at FROM folders WHERE organization_id = ? AND deleted_at IS NULL';
  const params: unknown[] = [organizationId];

  if (parentId !== undefined) {
    if (parentId === 'null' || parentId === '') {
      query += ' AND parent_folder_id IS NULL';
    } else {
      query += ' AND parent_folder_id = ?';
      params.push(parentId);
    }
  }

  query += ' ORDER BY name ASC';
  const folders = await c.env.DB.prepare(query).bind(...params).all();

  return c.json({ data: folders.results });
});

// POST /api/v1/organizations/:organizationId/folders
folderRoutes.post('/organizations/:organizationId/folders', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'folder.create');

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { name, parent_folder_id } = body as { name?: string; parent_folder_id?: string | null };

  if (!name || name.trim().length === 0) {
    throw Errors.unprocessable('Folder name is required.');
  }
  if (name.trim().length > 120) {
    throw Errors.unprocessable('Folder name must be at most 120 characters.');
  }

  const parentFolderId = parent_folder_id || null;
  if (parentFolderId) {
    const parent = await c.env.DB
      .prepare('SELECT id, organization_id FROM folders WHERE id = ? AND deleted_at IS NULL LIMIT 1')
      .bind(parentFolderId)
      .first<{ id: string; organization_id: string }>();

    if (!parent || parent.organization_id !== organizationId) {
      throw Errors.badRequest('Parent folder not found in this organization.');
    }
  }

  // Prevent duplicate names under same parent
  let dupQuery = 'SELECT id FROM folders WHERE organization_id = ? AND name = ? AND deleted_at IS NULL';
  const dupParams: unknown[] = [organizationId, name.trim()];
  if (parentFolderId) {
    dupQuery += ' AND parent_folder_id = ?';
    dupParams.push(parentFolderId);
  } else {
    dupQuery += ' AND parent_folder_id IS NULL';
  }
  const duplicate = await c.env.DB.prepare(dupQuery).bind(...dupParams).first();
  if (duplicate) {
    throw Errors.conflict('A folder with that name already exists in this location.');
  }

  const folderId = generateId();
  const now = new Date().toISOString();

  await c.env.DB
    .prepare(
      `INSERT INTO folders (id, organization_id, parent_folder_id, name, created_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(folderId, organizationId, parentFolderId, name.trim(), auth.userId, now, now)
    .run();

  await writeAuditLog(c.env.DB, {
    organizationId,
    actorUserId: auth.userId,
    action: 'folder.created',
    resourceType: 'folder',
    resourceId: folderId,
    metadata: { name: name.trim(), parent_folder_id: parentFolderId },
  });

  return c.json(
    {
      data: {
        id: folderId,
        organization_id: organizationId,
        parent_folder_id: parentFolderId,
        name: name.trim(),
        created_at: now,
        updated_at: now,
      },
    },
    201
  );
});

// GET /api/v1/folders/:folderId
folderRoutes.get('/folders/:folderId', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { folderId } = c.req.param();
  const { folder, member } = await resolveFolder(c.env.DB, auth.userId, folderId);
  requireCapability(member.role, 'active', 'document.read');

  return c.json({ data: folder });
});

// PATCH /api/v1/folders/:folderId
folderRoutes.patch('/folders/:folderId', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { folderId } = c.req.param();
  const { folder, member } = await resolveFolder(c.env.DB, auth.userId, folderId);
  requireCapability(member.role, 'active', 'folder.update');

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { name, parent_folder_id } = body as { name?: string; parent_folder_id?: string | null };

  const updates: string[] = [];
  const params: unknown[] = [];
  const now = new Date().toISOString();

  if (name !== undefined) {
    if (!name.trim() || name.trim().length > 120) {
      throw Errors.unprocessable('Folder name must be between 1 and 120 characters.');
    }
    updates.push('name = ?');
    params.push(name.trim());
  }

  if (parent_folder_id !== undefined) {
    const newParentId = parent_folder_id || null;
    if (newParentId === folderId) {
      throw Errors.badRequest('A folder cannot be its own parent.');
    }

    if (newParentId) {
      const parent = await c.env.DB
        .prepare('SELECT id, organization_id FROM folders WHERE id = ? AND deleted_at IS NULL LIMIT 1')
        .bind(newParentId)
        .first<{ id: string; organization_id: string }>();

      if (!parent || parent.organization_id !== folder.organization_id) {
        throw Errors.badRequest('Target parent folder does not exist in this organization.');
      }

      // Check circular hierarchy
      const isCircular = await isDescendantOf(c.env.DB, folderId, newParentId);
      if (isCircular) {
        throw Errors.badRequest('Moving folder here would create a circular hierarchy.');
      }
    }
    updates.push('parent_folder_id = ?');
    params.push(newParentId);
  }

  if (updates.length === 0) {
    return c.json({ data: folder });
  }

  updates.push('updated_at = ?');
  params.push(now);
  params.push(folderId);

  await c.env.DB
    .prepare(`UPDATE folders SET ${updates.join(', ')} WHERE id = ?`)
    .bind(...params)
    .run();

  await writeAuditLog(c.env.DB, {
    organizationId: folder.organization_id,
    actorUserId: auth.userId,
    action: 'folder.updated',
    resourceType: 'folder',
    resourceId: folderId,
    metadata: { name, parent_folder_id },
  });

  const updatedFolder = await c.env.DB
    .prepare('SELECT id, organization_id, parent_folder_id, name, created_by, created_at, updated_at FROM folders WHERE id = ? LIMIT 1')
    .bind(folderId)
    .first();

  return c.json({ data: updatedFolder });
});

// DELETE /api/v1/folders/:folderId
folderRoutes.delete('/folders/:folderId', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { folderId } = c.req.param();
  const { folder, member } = await resolveFolder(c.env.DB, auth.userId, folderId);
  requireCapability(member.role, 'active', 'folder.delete');

  const recursive = c.req.query('recursive') === 'true';

  if (!recursive) {
    // Check if folder contains active subfolders or documents
    const childFolders = await c.env.DB
      .prepare('SELECT COUNT(*) as count FROM folders WHERE parent_folder_id = ? AND deleted_at IS NULL')
      .bind(folderId)
      .first<{ count: number }>();

    const childDocs = await c.env.DB
      .prepare('SELECT COUNT(*) as count FROM documents WHERE folder_id = ? AND deleted_at IS NULL')
      .bind(folderId)
      .first<{ count: number }>();

    if ((childFolders?.count ?? 0) > 0 || (childDocs?.count ?? 0) > 0) {
      throw Errors.conflict('Folder is not empty. Supply ?recursive=true to delete folder and all contents.');
    }
  }

  const now = new Date().toISOString();

  if (recursive) {
    // Mark folder and child documents as soft-deleted
    await c.env.DB.batch([
      c.env.DB.prepare('UPDATE folders SET deleted_at = ?, updated_at = ? WHERE id = ?').bind(now, now, folderId),
      c.env.DB.prepare('UPDATE folders SET deleted_at = ?, updated_at = ? WHERE parent_folder_id = ? AND deleted_at IS NULL').bind(now, now, folderId),
      c.env.DB.prepare('UPDATE documents SET deleted_at = ?, updated_at = ? WHERE folder_id = ? AND deleted_at IS NULL').bind(now, now, folderId),
    ]);
  } else {
    await c.env.DB
      .prepare('UPDATE folders SET deleted_at = ?, updated_at = ? WHERE id = ?')
      .bind(now, now, folderId)
      .run();
  }

  await writeAuditLog(c.env.DB, {
    organizationId: folder.organization_id,
    actorUserId: auth.userId,
    action: 'folder.deleted',
    resourceType: 'folder',
    resourceId: folderId,
    metadata: { recursive },
  });

  return c.json({ data: { message: 'Folder deleted successfully.' } });
});

export { folderRoutes };

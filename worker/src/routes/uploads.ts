import { Hono } from 'hono';
import type { Env } from '../types/env';
import { requireAuth, resolveOrgMembership, type AuthVariables } from '../middleware/auth';
import { requireCapability } from '../lib/permissions';
import { generateId, generateObjectKey } from '../lib/id';
import { Errors } from '../lib/errors';
import { validateMimeType, getExtension } from '../lib/validation';
import { writeAuditLog } from '../lib/audit';

const uploadRoutes = new Hono<{ Bindings: Env; Variables: AuthVariables }>();

// POST /api/v1/organizations/:organizationId/uploads
// Step 1: Initiate upload session
uploadRoutes.post('/organizations/:organizationId/uploads', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'document.upload');

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { display_name, file_size_bytes, content_type, folder_id, description } = body as {
    display_name?: string;
    file_size_bytes?: number;
    content_type?: string;
    folder_id?: string | null;
    description?: string;
  };

  if (!display_name || !display_name.trim()) {
    throw Errors.unprocessable('File display name is required.');
  }
  if (!file_size_bytes || typeof file_size_bytes !== 'number' || file_size_bytes <= 0) {
    throw Errors.unprocessable('Valid file size in bytes is required.');
  }
  if (!content_type || !validateMimeType(content_type)) {
    throw Errors.unprocessable(`Unsupported or invalid file content type: ${content_type}`);
  }

  const maxFileSize = parseInt(c.env.MAX_FILE_SIZE_BYTES || '524288000', 10); // 500 MB
  if (file_size_bytes > maxFileSize) {
    throw Errors.payloadTooLarge(`File size (${Math.round(file_size_bytes / 1024 / 1024)}MB) exceeds maximum limit (${Math.round(maxFileSize / 1024 / 1024)}MB).`);
  }

  // Validate folder
  const targetFolderId = folder_id || null;
  if (targetFolderId) {
    const folder = await c.env.DB
      .prepare('SELECT id, organization_id FROM folders WHERE id = ? AND deleted_at IS NULL LIMIT 1')
      .bind(targetFolderId)
      .first<{ id: string; organization_id: string }>();

    if (!folder || folder.organization_id !== organizationId) {
      throw Errors.badRequest('Target folder does not exist in this organization.');
    }
  }

  // Check storage quota
  const org = await c.env.DB
    .prepare('SELECT storage_quota_bytes, storage_used_bytes FROM organizations WHERE id = ? LIMIT 1')
    .bind(organizationId)
    .first<{ storage_quota_bytes: number; storage_used_bytes: number }>();

  if (!org) throw Errors.notFound('Organization');
  if (org.storage_used_bytes + file_size_bytes > org.storage_quota_bytes) {
    throw Errors.forbidden('Organization storage quota exceeded.');
  }

  const ext = getExtension(display_name);
  const objectKey = generateObjectKey(organizationId, ext);
  const documentId = generateId();
  const sessionId = generateId();
  const now = new Date().toISOString();
  const ttl = parseInt(c.env.UPLOAD_SESSION_TTL_SECONDS || '3600', 10);
  const expiresAt = new Date(Date.now() + ttl * 1000).toISOString();

  // Mode: single for <= 100 MB, multipart for > 100 MB
  const uploadMode = file_size_bytes > 100 * 1024 * 1024 ? 'multipart' : 'single';
  let multipartUploadId: string | null = null;

  if (uploadMode === 'multipart') {
    const multipart = await c.env.BUCKET.createMultipartUpload(objectKey, {
      httpMetadata: { contentType: content_type },
    });
    multipartUploadId = multipart.uploadId;
  }

  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO documents (
        id, organization_id, folder_id, owner_id, uploaded_by, display_name,
        object_key, content_type, file_size_bytes, description, upload_status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)`
    ).bind(
      documentId,
      organizationId,
      targetFolderId,
      auth.userId,
      auth.userId,
      display_name.trim(),
      objectKey,
      content_type,
      file_size_bytes,
      description?.trim() || null,
      now,
      now
    ),
    c.env.DB.prepare(
      `INSERT INTO upload_sessions (
        id, organization_id, document_id, initiated_by, object_key,
        upload_mode, status, expected_size_bytes, multipart_upload_id, expires_at, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)`
    ).bind(
      sessionId,
      organizationId,
      documentId,
      auth.userId,
      objectKey,
      uploadMode,
      file_size_bytes,
      multipartUploadId,
      expiresAt,
      now
    ),
  ]);

  await writeAuditLog(c.env.DB, {
    organizationId,
    actorUserId: auth.userId,
    action: 'upload.initiated',
    resourceType: 'upload_session',
    resourceId: sessionId,
    metadata: { document_id: documentId, display_name, file_size_bytes, upload_mode: uploadMode },
  });

  return c.json(
    {
      data: {
        upload_session_id: sessionId,
        document_id: documentId,
        upload_mode: uploadMode,
        expected_size_bytes: file_size_bytes,
        expires_at: expiresAt,
        upload_url: `/api/v1/uploads/${sessionId}/file`,
      },
    },
    201
  );
});

// PUT /api/v1/uploads/:uploadId/file
// Direct streaming upload for single-file mode
uploadRoutes.put('/uploads/:uploadId/file', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { uploadId } = c.req.param();

  const session = await c.env.DB
    .prepare(
      `SELECT id, organization_id, document_id, initiated_by, object_key, upload_mode, status, expected_size_bytes, expires_at
       FROM upload_sessions WHERE id = ? LIMIT 1`
    )
    .bind(uploadId)
    .first<{
      id: string;
      organization_id: string;
      document_id: string;
      initiated_by: string;
      object_key: string;
      upload_mode: string;
      status: string;
      expected_size_bytes: number;
      expires_at: string;
    }>();

  if (!session) throw Errors.notFound('Upload session');
  if (session.initiated_by !== auth.userId) throw Errors.forbidden('You do not own this upload session.');
  if (session.status !== 'pending' && session.status !== 'uploading') {
    throw Errors.badRequest(`Cannot upload to session with status: ${session.status}`);
  }
  if (new Date(session.expires_at) < new Date()) throw Errors.badRequest('Upload session has expired.');

  const body = c.req.raw.body;
  if (!body) throw Errors.badRequest('Upload payload body is missing.');

  const doc = await c.env.DB
    .prepare('SELECT content_type FROM documents WHERE id = ? LIMIT 1')
    .bind(session.document_id)
    .first<{ content_type: string }>();

  // Stream directly to R2
  await c.env.BUCKET.put(session.object_key, body, {
    httpMetadata: { contentType: doc?.content_type || 'application/octet-stream' },
  });

  await c.env.DB
    .prepare('UPDATE upload_sessions SET status = \'uploading\' WHERE id = ?')
    .bind(uploadId)
    .run();

  return c.json({ data: { message: 'File stream received. Proceed to complete upload session.' } });
});

// POST /api/v1/uploads/:uploadId/parts/:partNumber
// Upload part for multipart mode
uploadRoutes.post('/uploads/:uploadId/parts/:partNumber', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { uploadId, partNumber } = c.req.param();
  const partNum = parseInt(partNumber, 10);

  if (isNaN(partNum) || partNum < 1 || partNum > 10000) {
    throw Errors.badRequest('Invalid part number.');
  }

  const session = await c.env.DB
    .prepare(
      `SELECT id, organization_id, document_id, initiated_by, object_key, upload_mode, status, multipart_upload_id, expires_at
       FROM upload_sessions WHERE id = ? LIMIT 1`
    )
    .bind(uploadId)
    .first<{
      id: string;
      organization_id: string;
      document_id: string;
      initiated_by: string;
      object_key: string;
      upload_mode: string;
      status: string;
      multipart_upload_id: string | null;
      expires_at: string;
    }>();

  if (!session) throw Errors.notFound('Upload session');
  if (session.initiated_by !== auth.userId) throw Errors.forbidden('You do not own this upload session.');
  if (session.upload_mode !== 'multipart' || !session.multipart_upload_id) {
    throw Errors.badRequest('Session is not in multipart upload mode.');
  }
  if (session.status !== 'pending' && session.status !== 'uploading') {
    throw Errors.badRequest(`Invalid session status: ${session.status}`);
  }
  if (new Date(session.expires_at) < new Date()) throw Errors.badRequest('Upload session has expired.');

  const body = await c.req.arrayBuffer();
  if (!body || body.byteLength === 0) {
    throw Errors.badRequest('Part data body is empty.');
  }

  const multipart = c.env.BUCKET.resumeMultipartUpload(session.object_key, session.multipart_upload_id);
  const uploadedPart = await multipart.uploadPart(partNum, body);

  return c.json({
    data: {
      partNumber: partNum,
      etag: uploadedPart.etag,
    },
  });
});

// POST /api/v1/uploads/:uploadId/complete
uploadRoutes.post('/uploads/:uploadId/complete', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { uploadId } = c.req.param();

  const session = await c.env.DB
    .prepare(
      `SELECT id, organization_id, document_id, initiated_by, object_key, upload_mode, status,
              expected_size_bytes, multipart_upload_id, expires_at
       FROM upload_sessions WHERE id = ? LIMIT 1`
    )
    .bind(uploadId)
    .first<{
      id: string;
      organization_id: string;
      document_id: string;
      initiated_by: string;
      object_key: string;
      upload_mode: string;
      status: string;
      expected_size_bytes: number;
      multipart_upload_id: string | null;
      expires_at: string;
    }>();

  if (!session) throw Errors.notFound('Upload session');
  if (session.initiated_by !== auth.userId) throw Errors.forbidden('You do not own this upload session.');

  // Idempotency: if already completed, return existing document
  if (session.status === 'completed') {
    const existingDoc = await c.env.DB
      .prepare('SELECT id, organization_id, folder_id, display_name, content_type, file_size_bytes, upload_status FROM documents WHERE id = ? LIMIT 1')
      .bind(session.document_id)
      .first();
    return c.json({ data: existingDoc });
  }

  if (session.status !== 'pending' && session.status !== 'uploading') {
    throw Errors.badRequest(`Cannot complete session with status: ${session.status}`);
  }

  const body = await c.req.json().catch(() => ({}));
  const { parts } = body as { parts?: Array<{ partNumber: number; etag: string }> };

  if (session.upload_mode === 'multipart') {
    if (!parts || !Array.isArray(parts) || parts.length === 0) {
      throw Errors.badRequest('Multipart completion requires an array of uploaded parts with partNumber and etag.');
    }
    if (!session.multipart_upload_id) {
      throw Errors.internal('Missing multipart upload identifier.');
    }
    const multipart = c.env.BUCKET.resumeMultipartUpload(session.object_key, session.multipart_upload_id);
    await multipart.complete(parts);
  }

  // Authoritatively inspect resulting R2 object
  const r2Object = await c.env.BUCKET.head(session.object_key);
  if (!r2Object) {
    throw Errors.conflict('Uploaded object was not found in storage. Ensure data was uploaded before completing.');
  }

  const actualSize = r2Object.size;
  const checksum = r2Object.checksums?.md5
    ? Array.from(new Uint8Array(r2Object.checksums.md5)).map((b) => b.toString(16).padStart(2, '0')).join('')
    : null;

  const now = new Date().toISOString();

  // Atomically update document, org storage_used_bytes, and upload session
  await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE documents
       SET upload_status = 'completed', file_size_bytes = ?, checksum = ?, updated_at = ?
       WHERE id = ?`
    ).bind(actualSize, checksum, now, session.document_id),
    c.env.DB.prepare(
      `UPDATE organizations
       SET storage_used_bytes = storage_used_bytes + ?, updated_at = ?
       WHERE id = ?`
    ).bind(actualSize, now, session.organization_id),
    c.env.DB.prepare(
      `UPDATE upload_sessions
       SET status = 'completed', completed_at = ?
       WHERE id = ?`
    ).bind(now, session.id),
  ]);

  await writeAuditLog(c.env.DB, {
    organizationId: session.organization_id,
    actorUserId: auth.userId,
    action: 'upload.completed',
    resourceType: 'document',
    resourceId: session.document_id,
    metadata: { file_size_bytes: actualSize, checksum },
  });

  const doc = await c.env.DB
    .prepare('SELECT id, organization_id, folder_id, display_name, content_type, file_size_bytes, upload_status, created_at FROM documents WHERE id = ? LIMIT 1')
    .bind(session.document_id)
    .first();

  return c.json({ data: doc });
});

// POST /api/v1/uploads/:uploadId/cancel
uploadRoutes.post('/uploads/:uploadId/cancel', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { uploadId } = c.req.param();

  const session = await c.env.DB
    .prepare(
      `SELECT id, organization_id, document_id, initiated_by, object_key, upload_mode, status, multipart_upload_id
       FROM upload_sessions WHERE id = ? LIMIT 1`
    )
    .bind(uploadId)
    .first<{
      id: string;
      organization_id: string;
      document_id: string;
      initiated_by: string;
      object_key: string;
      upload_mode: string;
      status: string;
      multipart_upload_id: string | null;
    }>();

  if (!session) throw Errors.notFound('Upload session');
  if (session.initiated_by !== auth.userId) throw Errors.forbidden('You do not own this upload session.');

  if (session.status === 'completed') {
    throw Errors.badRequest('Cannot cancel an already completed upload session.');
  }

  // If multipart, abort in R2
  if (session.upload_mode === 'multipart' && session.multipart_upload_id) {
    try {
      const multipart = c.env.BUCKET.resumeMultipartUpload(session.object_key, session.multipart_upload_id);
      await multipart.abort();
    } catch {
      // Ignore abort failure if already aborted
    }
  } else {
    // Delete single object if uploaded
    await c.env.BUCKET.delete(session.object_key);
  }

  const now = new Date().toISOString();
  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE upload_sessions SET status = \'cancelled\' WHERE id = ?').bind(session.id),
    c.env.DB.prepare('UPDATE documents SET upload_status = \'cancelled\', deleted_at = ?, updated_at = ? WHERE id = ?').bind(now, now, session.document_id),
  ]);

  await writeAuditLog(c.env.DB, {
    organizationId: session.organization_id,
    actorUserId: auth.userId,
    action: 'upload.cancelled',
    resourceType: 'upload_session',
    resourceId: session.id,
    metadata: { document_id: session.document_id },
  });

  return c.json({ data: { message: 'Upload session cancelled.' } });
});

export { uploadRoutes };

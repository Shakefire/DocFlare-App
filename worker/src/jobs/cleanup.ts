import type { Env } from '../types/env';

export async function scheduledCleanup(env: Env): Promise<{
  expiredSessionsCleaned: number;
  expiredTrashCleaned: number;
  expiredTokensCleaned: number;
}> {
  console.log('[CLEANUP JOB] Starting scheduled cleanup...');
  const now = new Date().toISOString();

  // 1. Clean up expired upload sessions
  const expiredSessions = await env.DB
    .prepare(
      `SELECT id, organization_id, document_id, object_key, upload_mode, multipart_upload_id
       FROM upload_sessions
       WHERE status IN ('pending', 'uploading') AND expires_at < ?
       LIMIT 50`
    )
    .bind(now)
    .all<{
      id: string;
      organization_id: string;
      document_id: string;
      object_key: string;
      upload_mode: string;
      multipart_upload_id: string | null;
    }>();

  let sessionsCleaned = 0;
  for (const session of expiredSessions.results) {
    try {
      if (session.upload_mode === 'multipart' && session.multipart_upload_id) {
        try {
          const multipart = env.BUCKET.resumeMultipartUpload(session.object_key, session.multipart_upload_id);
          await multipart.abort();
        } catch {
          // Ignore if already aborted
        }
      } else {
        await env.BUCKET.delete(session.object_key);
      }

      await env.DB.batch([
        env.DB.prepare('UPDATE upload_sessions SET status = \'cancelled\' WHERE id = ?').bind(session.id),
        env.DB.prepare('DELETE FROM documents WHERE id = ? AND upload_status = \'pending\'').bind(session.document_id),
      ]);
      sessionsCleaned++;
    } catch (err) {
      console.error(`[CLEANUP JOB] Failed to clean upload session ${session.id}:`, err);
    }
  }

  // 2. Clean up expired trash records
  const retentionDays = parseInt(env.TRASH_RETENTION_DAYS || '30', 10);
  const cutoffDate = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000).toISOString();

  const expiredTrash = await env.DB
    .prepare(
      `SELECT id, organization_id, object_key, file_size_bytes
       FROM documents
       WHERE deleted_at IS NOT NULL AND deleted_at < ?
       LIMIT 50`
    )
    .bind(cutoffDate)
    .all<{ id: string; organization_id: string; object_key: string; file_size_bytes: number }>();

  let trashCleaned = 0;
  for (const doc of expiredTrash.results) {
    try {
      await env.BUCKET.delete(doc.object_key);
      const updateTime = new Date().toISOString();

      await env.DB.batch([
        env.DB.prepare('DELETE FROM documents WHERE id = ?').bind(doc.id),
        env.DB.prepare(
          `UPDATE organizations
           SET storage_used_bytes = MAX(0, storage_used_bytes - ?), updated_at = ?
           WHERE id = ?`
        ).bind(doc.file_size_bytes, updateTime, doc.organization_id),
      ]);
      trashCleaned++;
    } catch (err) {
      console.error(`[CLEANUP JOB] Failed to purge expired trash document ${doc.id}:`, err);
    }
  }

  // 3. Purge expired security tokens
  const tokenResult = await env.DB.batch([
    env.DB.prepare('DELETE FROM revoked_tokens WHERE expires_at < ?').bind(now),
    env.DB.prepare('DELETE FROM email_verifications WHERE expires_at < ?').bind(now),
    env.DB.prepare('DELETE FROM password_resets WHERE expires_at < ?').bind(now),
  ]);

  let tokensCleaned = 0;
  for (const res of tokenResult) {
    tokensCleaned += res.meta.changes ?? 0;
  }

  console.log(`[CLEANUP JOB] Finished. Sessions: ${sessionsCleaned}, Trash: ${trashCleaned}, Tokens: ${tokensCleaned}`);

  return {
    expiredSessionsCleaned: sessionsCleaned,
    expiredTrashCleaned: trashCleaned,
    expiredTokensCleaned: tokensCleaned,
  };
}

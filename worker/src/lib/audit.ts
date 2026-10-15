import { generateId } from './id';

export type AuditAction =
  | 'user.registered'
  | 'user.email_verified'
  | 'user.login'
  | 'user.logout'
  | 'user.password_reset'
  | 'organization.created'
  | 'organization.updated'
  | 'member.invited'
  | 'member.invitation_accepted'
  | 'member.role_changed'
  | 'member.removed'
  | 'folder.created'
  | 'folder.updated'
  | 'folder.deleted'
  | 'document.uploaded'
  | 'document.updated'
  | 'document.downloaded'
  | 'document.previewed'
  | 'document.deleted'
  | 'document.restored'
  | 'document.permanently_deleted'
  | 'upload.initiated'
  | 'upload.completed'
  | 'upload.failed'
  | 'upload.cancelled';

export async function writeAuditLog(
  db: D1Database,
  params: {
    organizationId: string;
    actorUserId: string;
    action: AuditAction;
    resourceType: string;
    resourceId: string;
    metadata?: Record<string, unknown>;
  }
): Promise<void> {
  const id = generateId();
  const now = new Date().toISOString();
  const metadataJson = params.metadata ? JSON.stringify(params.metadata) : null;
  await db
    .prepare(
      `INSERT INTO audit_logs (id, organization_id, actor_user_id, action, resource_type, resource_id, metadata_json, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(
      id,
      params.organizationId,
      params.actorUserId,
      params.action,
      params.resourceType,
      params.resourceId,
      metadataJson,
      now
    )
    .run();
}

export type Role = 'admin' | 'manager' | 'viewer';
export type MemberStatus = 'active' | 'suspended';
export type OrgStatus = 'active' | 'suspended';
export type UploadStatus = 'pending' | 'uploading' | 'completed' | 'failed' | 'cancelled';
export type UploadMode = 'single' | 'multipart';

export interface User {
  id: string;
  email: string;
  email_normalized: string;
  email_verified_at: string | null;
  created_at: string;
  updated_at: string;
  disabled_at: string | null;
}

export interface Organization {
  id: string;
  name: string;
  slug: string;
  created_by: string;
  created_at: string;
  updated_at: string;
  storage_quota_bytes: number;
  status: OrgStatus;
}

export interface OrganizationMember {
  id: string;
  organization_id: string;
  user_id: string;
  role: Role;
  status: MemberStatus;
  created_at: string;
  updated_at: string;
}

export interface OrganizationInvitation {
  id: string;
  organization_id: string;
  email_normalized: string;
  role: Role;
  token_hash: string;
  invited_by: string;
  expires_at: string;
  accepted_at: string | null;
  revoked_at: string | null;
  created_at: string;
}

export interface Folder {
  id: string;
  organization_id: string;
  parent_folder_id: string | null;
  name: string;
  created_by: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface Document {
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
  upload_status: UploadStatus;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface DocumentAccessGrant {
  id: string;
  document_id: string;
  organization_id: string;
  grantee_user_id: string;
  granted_by: string;
  capabilities: string; // JSON array of capabilities
  created_at: string;
  revoked_at: string | null;
}

export interface UploadSession {
  id: string;
  organization_id: string;
  document_id: string;
  initiated_by: string;
  object_key: string;
  upload_mode: UploadMode;
  status: UploadStatus;
  expected_size_bytes: number;
  multipart_upload_id: string | null;
  expires_at: string;
  created_at: string;
  completed_at: string | null;
}

export interface AuditLog {
  id: string;
  organization_id: string;
  actor_user_id: string;
  action: string;
  resource_type: string;
  resource_id: string;
  metadata_json: string | null;
  created_at: string;
}

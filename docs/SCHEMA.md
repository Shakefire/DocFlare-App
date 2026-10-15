# Cloudflare D1 Relational Database Schema

Docflare uses Cloudflare D1 (SQLite-compatible SQL) as the authoritative source of truth for users, organizations, memberships, folders, document metadata, upload sessions, and audit events.

---

## Entity Relationship Overview

```
[users] ──< [organization_members] >── [organizations]
   │                 │                        │
   │                 ├──< [folders]           ├──< [documents]
   │                 │         │                   │
   │                 │         └──< [documents]    ├──< [upload_sessions]
   │                 │                             ├──< [document_access_grants]
   │                 └──< [audit_logs]             └──< [audit_logs]
   ├──< [email_verifications]
   ├──< [password_resets]
   └──< [revoked_tokens]
```

---

## Tables Definition

### `users`
Authoritative user identity records.
- `id` (TEXT PRIMARY KEY) - CUID2 unique identifier.
- `email` (TEXT NOT NULL) - Original email input.
- `email_normalized` (TEXT NOT NULL UNIQUE) - Lowercased, trimmed email.
- `password_hash` (TEXT NOT NULL) - PBKDF2-SHA256 (310,000 iterations, 32-byte salt).
- `email_verified_at` (TEXT) - ISO timestamp when email verification succeeded.
- `created_at` (TEXT NOT NULL) - Creation timestamp.
- `updated_at` (TEXT NOT NULL) - Last modified timestamp.
- `disabled_at` (TEXT) - Suspension timestamp.

### `organizations`
Independent tenant organizations.
- `id` (TEXT PRIMARY KEY) - CUID2 unique identifier.
- `name` (TEXT NOT NULL) - Display name.
- `slug` (TEXT NOT NULL UNIQUE) - URL-safe unique slug.
- `created_by` (TEXT NOT NULL REFERENCES users(id)) - Initial admin user.
- `storage_quota_bytes` (INTEGER NOT NULL DEFAULT 10737418240) - Quota limit (default 10 GB).
- `storage_used_bytes` (INTEGER NOT NULL DEFAULT 0) - Authoritative active byte count.
- `status` (TEXT NOT NULL CHECK in 'active', 'suspended').

### `organization_members`
Organization memberships and assigned roles.
- `id` (TEXT PRIMARY KEY).
- `organization_id` (TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE).
- `user_id` (TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE).
- `role` (TEXT NOT NULL CHECK in 'admin', 'manager', 'viewer').
- `status` (TEXT NOT NULL CHECK in 'active', 'suspended').
- `UNIQUE(organization_id, user_id)` - Prevents duplicate memberships.

### `organization_invitations`
Single-use email invitation tokens.
- `id` (TEXT PRIMARY KEY).
- `organization_id` (TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE).
- `email_normalized` (TEXT NOT NULL).
- `role` (TEXT NOT NULL CHECK in 'manager', 'viewer').
- `token_hash` (TEXT NOT NULL UNIQUE) - SHA-256 hash of single-use invitation token.
- `invited_by` (TEXT NOT NULL REFERENCES users(id)).
- `expires_at` (TEXT NOT NULL) - 7-day expiration timestamp.
- `accepted_at` (TEXT) - Timestamp when redeemed.
- `revoked_at` (TEXT) - Revocation timestamp.

### `folders`
Hierarchical document organization.
- `id` (TEXT PRIMARY KEY).
- `organization_id` (TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE).
- `parent_folder_id` (TEXT REFERENCES folders(id) ON DELETE CASCADE) - Nullable for root folders.
- `name` (TEXT NOT NULL).
- `created_by` (TEXT NOT NULL REFERENCES users(id)).
- `deleted_at` (TEXT) - Soft-deletion timestamp.
- `CHECK (id != parent_folder_id)` - Disallows self-referencing hierarchy.

### `documents`
Authoritative document metadata.
- `id` (TEXT PRIMARY KEY).
- `organization_id` (TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE).
- `folder_id` (TEXT REFERENCES folders(id) ON DELETE SET NULL).
- `owner_id` (TEXT NOT NULL REFERENCES users(id)).
- `uploaded_by` (TEXT NOT NULL REFERENCES users(id)).
- `display_name` (TEXT NOT NULL) - Untrusted user filename.
- `object_key` (TEXT NOT NULL UNIQUE) - Server-generated R2 object path (`orgs/{orgId}/{ts}-{id}.ext`).
- `content_type` (TEXT NOT NULL) - Validated MIME type.
- `file_size_bytes` (INTEGER NOT NULL DEFAULT 0).
- `checksum` (TEXT) - MD5 / SHA-256 checksum from R2 verification.
- `description` (TEXT).
- `upload_status` (TEXT NOT NULL CHECK in 'pending', 'uploading', 'completed', 'failed', 'cancelled').
- `deleted_at` (TEXT) - Soft-deletion timestamp (Trash).

### `upload_sessions`
Upload lifecycle tracking for direct-to-R2 transfers.
- `id` (TEXT PRIMARY KEY).
- `organization_id` (TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE).
- `document_id` (TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE).
- `initiated_by` (TEXT NOT NULL REFERENCES users(id)).
- `object_key` (TEXT NOT NULL).
- `upload_mode` (TEXT NOT NULL CHECK in 'single', 'multipart').
- `status` (TEXT NOT NULL CHECK in 'pending', 'uploading', 'completed', 'failed', 'cancelled').
- `expected_size_bytes` (INTEGER NOT NULL).
- `multipart_upload_id` (TEXT).
- `expires_at` (TEXT NOT NULL) - 1-hour session TTL.
- `completed_at` (TEXT).

### `audit_logs`
Immutable compliance and security audit logs.
- `id` (TEXT PRIMARY KEY).
- `organization_id` (TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE).
- `actor_user_id` (TEXT NOT NULL REFERENCES users(id)).
- `action` (TEXT NOT NULL).
- `resource_type` (TEXT NOT NULL).
- `resource_id` (TEXT NOT NULL).
- `metadata_json` (TEXT) - Structured non-sensitive event metadata.
- `created_at` (TEXT NOT NULL).

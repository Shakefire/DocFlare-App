INSERT OR REPLACE INTO users (id, email, email_normalized, password_hash, email_verified_at, created_at, updated_at)
VALUES (
  'usr_admin_001',
  'admin@docflare.com',
  'admin@docflare.com',
  'pbkdf2_sha256:100000:be0d8a623231dc37672bd79f13414a92609605e6e17c119c90bb78b696808da3:e296caf631a27b1244c0126a2c79689b51f5cae729d3b84ca8caa214d485352e',
  '2026-10-15T12:00:00.000Z',
  '2026-10-15T12:00:00.000Z',
  '2026-10-15T12:00:00.000Z'
);

INSERT OR REPLACE INTO organizations (id, name, slug, created_by, created_at, updated_at, storage_quota_bytes, storage_used_bytes, status)
VALUES (
  'org_demo_001',
  'Docflare HQ',
  'docflare-hq',
  'usr_admin_001',
  '2026-10-15T12:00:00.000Z',
  '2026-10-15T12:00:00.000Z',
  10737418240,
  0,
  'active'
);

INSERT OR REPLACE INTO organization_members (id, organization_id, user_id, role, status, created_at, updated_at)
VALUES (
  'mem_admin_001',
  'org_demo_001',
  'usr_admin_001',
  'admin',
  'active',
  '2026-10-15T12:00:00.000Z',
  '2026-10-15T12:00:00.000Z'
);

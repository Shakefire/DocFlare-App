# Security Architecture & Data Isolation

Docflare implements enterprise-grade multi-tenant data isolation and defense-in-depth across the mobile application and Cloudflare Workers runtime.

---

## 1. Multi-Tenant Organization Isolation

- **Authoritative Database Validation**: Organization isolation is enforced at the database query layer. Every document, folder, upload session, and member operation validates `organization_id` against the authenticated user's active membership in `organization_members`.
- **Anti-IDOR (Insecure Direct Object Reference)**: Guessing or substituting another organization's document ID or folder ID results in `404 Not Found`. Resource existence is concealed from unauthorized tenants.
- **Cross-Organization Shielding**: Storage quota, audit logs, and scheduled cleanup operations are strictly compartmentalized per organization.

---

## 2. Authentication & Cryptography

- **Password Hashing**: NIST-compliant PBKDF2 with SHA-256 (310,000 iterations, 32-byte cryptographically secure random salt). Plaintext passwords and fast general-purpose hashes (MD5, SHA1) are strictly prohibited.
- **Session Tokens**: Cryptographically signed JWT tokens (HMAC-SHA256) with 7-day expiration.
- **Server-Side Token Revocation**: Logout stores the SHA-256 hash of the revoked session token in D1 (`revoked_tokens`). The authentication middleware checks revoked token hashes on every protected request.
- **Mobile Credential Protection**: On Android, credentials are stored in `EncryptedSharedPreferences` backed by Android KeyStore. On iOS, credentials are saved in the iOS Keychain (`kSecAttrAccessibleAfterFirstUnlock`). Credentials are never saved in plain SharedPreferences or logs.
- **Email Verification Mandatory**: Users must verify their email address before accessing organization documents or accepting invitations.

---

## 3. Storage Security & File Safety

- **Private R2 Bucket**: Original file contents are stored in a private R2 bucket with zero public bucket access.
- **Streaming Authorization**: All downloads and previews require valid authentication and organization membership. Files are streamed with:
  - `X-Content-Type-Options: nosniff`
  - `Content-Disposition: attachment; filename="..."` (or `inline` for safe previews)
  - `Cache-Control: private, no-cache, no-store, must-revalidate`
- **MIME Allowlisting**: Strict allowlisting of acceptable file types. Dangerous executables (`.exe`, `.sh`, `.bat`, `.html`, `.js`) are rejected on upload initialization.

---

## 4. Rate Limiting & Protection

- Edge-based rate limiting on sensitive routes:
  - `auth:register`: 10 requests / minute / IP
  - `auth:login`: 10 requests / minute / IP
  - `auth:forgot`: 5 requests / minute / IP
  - `upload:initiate`: 30 requests / minute / IP

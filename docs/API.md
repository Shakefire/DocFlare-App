# Docflare REST API Specification (v1)

All endpoints are versioned under `/api/v1`.

## Global Conventions

- **Content-Type**: `application/json` (except file upload streams which use `application/octet-stream`).
- **Authorization**: `Authorization: Bearer <session_jwt>`.
- **Response Format**:
  - Success: `{ "data": ... , "meta": { ... } }`
  - Error: `{ "error": { "code": "STRING", "message": "Human readable message", "details": { ... } } }`

## HTTP Status Codes

- `200 OK`: Successful retrieval or mutation.
- `201 Created`: Resource successfully created.
- `400 Bad Request`: Invalid payload or malformed request parameters.
- `401 Unauthorized`: Unauthenticated request or expired token.
- `403 Forbidden`: Authenticated, but lacking permission or unverified email.
- `404 Not Found`: Target resource does not exist or access is concealed.
- `409 Conflict`: Conflict (e.g. duplicate email, slug collision, last admin demotion).
- `413 Payload Too Large`: Upload file exceeds maximum size limit (500 MB).
- `422 Unprocessable Entity`: Validation failure (short password, invalid email).
- `429 Too Many Requests`: Rate limit exceeded.
- `500 Internal Error`: Unexpected server exception.

---

## 1. Authentication Endpoints

### `POST /api/v1/auth/register`
Creates a new user account and dispatches an email verification token.
- **Request**: `{ "email": "user@org.com", "password": "SecurePassword123" }`
- **Response (201)**: `{ "data": { "userId": "...", "email": "...", "message": "..." } }`

### `POST /api/v1/auth/verify-email`
Verifies user email address.
- **Request**: `{ "token": "64_char_hex_token" }`
- **Response (200)**: `{ "data": { "message": "Email address verified successfully." } }`

### `POST /api/v1/auth/resend-verification`
Re-sends verification email token.
- **Request**: `{ "email": "user@org.com" }`
- **Response (200)**: `{ "data": { "message": "..." } }`

### `POST /api/v1/auth/login`
Authenticates user and returns a cryptographically signed session token.
- **Request**: `{ "email": "user@org.com", "password": "SecurePassword123" }`
- **Response (200)**: `{ "data": { "token": "jwt...", "user": { "id": "...", "email": "...", "email_verified": true } } }`

### `POST /api/v1/auth/logout`
Revokes active session token by storing its hash in `revoked_tokens`.
- **Response (200)**: `{ "data": { "message": "Successfully logged out." } }`

### `GET /api/v1/auth/me`
Retrieves authenticated user profile and organizations.
- **Response (200)**: `{ "data": { "id": "...", "email": "...", "email_verified": true, "organizations": [...] } }`

### `POST /api/v1/auth/forgot-password`
Generates a 1-hour single-use password reset token.
- **Request**: `{ "email": "user@org.com" }`
- **Response (200)**: `{ "data": { "message": "..." } }`

### `POST /api/v1/auth/reset-password`
Resets password using valid token.
- **Request**: `{ "token": "...", "new_password": "NewSecurePassword123" }`
- **Response (200)**: `{ "data": { "message": "Password has been updated..." } }`

---

## 2. Organization Endpoints

### `POST /api/v1/organizations`
Creates a new organization. Creator is assigned `admin` role.
- **Request**: `{ "name": "Acme Global" }`
- **Response (201)**: `{ "data": { "id": "...", "name": "Acme Global", "slug": "acme-global", "role": "admin" } }`

### `GET /api/v1/organizations`
Lists organizations the authenticated user belongs to.
- **Response (200)**: `{ "data": [ { "id": "...", "name": "...", "slug": "...", "role": "admin" } ] }`

### `GET /api/v1/organizations/:organizationId`
Retrieves single organization details.

### `GET /api/v1/organizations/:organizationId/members`
Lists all members in the organization.

### `POST /api/v1/organizations/:organizationId/invitations`
Dispatches a secure email invitation with single-use token.
- **Request**: `{ "email": "colleague@org.com", "role": "manager" }`

### `POST /api/v1/invitations/accept`
Accepts invitation and creates active membership.
- **Request**: `{ "token": "..." }`

### `PATCH /api/v1/organizations/:organizationId/members/:memberId`
Updates member role (`admin`, `manager`, `viewer`). Protected against demoting last administrator.

### `DELETE /api/v1/organizations/:organizationId/members/:memberId`
Suspends member from organization. Protected against removing last administrator.

---

## 3. Folders Endpoints

### `GET /api/v1/organizations/:organizationId/folders`
Lists active folders. Supports query `?parent_folder_id=<id|null>`.

### `POST /api/v1/organizations/:organizationId/folders`
Creates a folder within the organization.
- **Request**: `{ "name": "Q3 Reports", "parent_folder_id": null }`

### `PATCH /api/v1/folders/:folderId`
Renames or moves folder. Enforces circular hierarchy prevention.

### `DELETE /api/v1/folders/:folderId`
Soft-deletes folder. Requires `?recursive=true` if folder contains subfolders or documents.

---

## 4. Documents & Uploads Endpoints

### `GET /api/v1/organizations/:organizationId/documents`
Lists active documents with sorting and pagination.
- **Query params**: `folder_id`, `type`, `page`, `per_page`, `sort_by`, `order`.

### `GET /api/v1/documents/:documentId`
Retrieves document metadata.

### `POST /api/v1/organizations/:organizationId/uploads`
Initiates an upload session. Validates size, quota, MIME type.
- **Request**: `{ "display_name": "report.pdf", "file_size_bytes": 1048576, "content_type": "application/pdf", "folder_id": null }`
- **Response (201)**: `{ "data": { "upload_session_id": "...", "document_id": "...", "upload_mode": "single", "upload_url": "/api/v1/uploads/.../file" } }`

### `PUT /api/v1/uploads/:uploadId/file`
Streams binary data directly to Cloudflare R2 object store.

### `POST /api/v1/uploads/:uploadId/parts/:partNumber`
Uploads part for multipart transfer (> 100 MB).

### `POST /api/v1/uploads/:uploadId/complete`
Authoritatively verifies R2 object size and checksum, updates D1 record, updates quota, and marks completed.

### `POST /api/v1/uploads/:uploadId/cancel`
Aborts upload and removes temporary storage object.

### `GET /api/v1/documents/:documentId/download`
Streams authorized file with `Content-Disposition: attachment`.

### `GET /api/v1/documents/:documentId/preview`
Streams previewable file inline (`image/*`, `application/pdf`, `video/*`, `text/plain`).

### `DELETE /api/v1/documents/:documentId`
Moves document to trash (soft deletion).

### `POST /api/v1/documents/:documentId/restore`
Restores soft-deleted document after verifying underlying R2 object still exists.

---

## 5. Administration & Audit Endpoints

### `GET /api/v1/organizations/:organizationId/search`
Filename search with type filtering and pagination.

### `GET /api/v1/organizations/:organizationId/trash`
Lists soft-deleted documents within 30-day retention window.

### `DELETE /api/v1/organizations/:organizationId/trash/:documentId`
Permanently deletes document and frees R2 storage (Admin only).

### `GET /api/v1/organizations/:organizationId/audit-logs`
Detailed chronological audit history with actor and resource metadata (Admin only).

### `GET /api/v1/organizations/:organizationId/storage-usage`
Detailed quota utilization and breakdown by category.

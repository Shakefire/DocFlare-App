# Large-File & Multipart Upload Architecture

Docflare supports transferring large files (including files exceeding 100 MB up to 500 MB) without buffering complete payloads in Worker memory.

---

## 1. Upload Lifecycle

```
[Flutter Client]              [Cloudflare Worker]                [Cloudflare R2]
       │                               │                                │
       │  1. Initiate Upload           │                                │
       ├──────────────────────────────>│                                │
       │  (size, name, mime, folder)   │─── Validate quota & MIME       │
       │                               │─── Reserve unique object_key   │
       │                               │─── Create D1 Pending Document  │
       │                               │─── Create D1 Upload Session    │
       │  2. Return Session & URL      │                                │
       │<──────────────────────────────┤                                │
       │                               │                                │
       │  3. Stream Data               │                                │
       ├──────────────────────────────>│─── Stream directly to R2 ─────>│
       │                               │    (no in-memory buffering)    │
       │                               │                                │
       │  4. Complete Session          │                                │
       ├──────────────────────────────>│─── Verify R2 Object Exists ────>│
       │                               │<── Size & MD5 Checksum ────────┤
       │                               │─── D1: Status = completed      │
       │                               │─── D1: Increment Org Quota     │
       │  5. Confirmed Document        │                                │
       │<──────────────────────────────┤                                │
```

---

## 2. Transfer Modes

### Single Stream Transfer (<= 100 MB)
1. **Initiation**: Client calls `POST /api/v1/organizations/:orgId/uploads`.
2. **Transfer**: Client streams chunked byte body directly to `PUT /api/v1/uploads/:uploadId/file`. The Worker pipes the stream directly into `env.BUCKET.put()`.
3. **Completion**: Client calls `POST /api/v1/uploads/:uploadId/complete`.

### Multipart Upload Transfer (> 100 MB)
For files exceeding 100 MB:
1. **Initiation**: The Worker calls `env.BUCKET.createMultipartUpload()` and returns a `multipart_upload_id`.
2. **Parts Transfer**: Client splits file into 5 MB - 50 MB chunks and uploads each via `POST /api/v1/uploads/:uploadId/parts/:partNumber`. The Worker executes `uploadPart()` and returns the part `etag`.
3. **Completion**: Client sends the list of parts and etags to `POST /api/v1/uploads/:uploadId/complete`. The Worker resumes and completes the multipart upload via `complete()`.

---

## 3. Quota and Security Verification

- **Never Trust Client Assertion**: The backend never accepts client assertions that an upload succeeded. It verifies the object's presence, size, and checksum against authoritative R2 metadata before marking the document `completed`.
- **Idempotent Completion**: If completion is retried by network resilience logic, it returns the existing document without double-incrementing storage quotas.
- **Server-Controlled Object Keys**: Object keys follow the strict pattern `orgs/{orgId}/{timestamp}-{cuid2}.{extension}`. Clients never specify R2 object keys.
- **Automatic Session Expiration**: Uncompleted upload sessions expire after 1 hour (`UPLOAD_SESSION_TTL_SECONDS = 3600`). Abandoned multipart uploads and uncompleted R2 objects are purged daily by the scheduled cleanup Worker cron.

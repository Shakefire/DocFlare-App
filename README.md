# Docflare — Cloudflare Connections, Credentials & Setup Guide

This document contains all the connection strings, database IDs, credentials, and step-by-step instructions for the **Docflare** application. It also provides a comprehensive, reproducible tutorial on how to build and connect a similar Flutter application to Cloudflare Workers, D1 (SQL Database), R2 (Object Storage), and KV.

---

## Table of Contents
1. [Cloudflare Account & Resource Connections](#1-cloudflare-account--resource-connections)
2. [Default Seed Credentials & Test Accounts](#2-default-seed-credentials--test-accounts)
3. [Architecture Overview](#3-architecture-overview)
4. [Step-by-Step Setup: Building a Similar Flutter + Cloudflare App](#4-step-by-step-setup-building-a-similar-flutter--cloudflare-app)
   - [Phase 1: Cloudflare Infrastructure Provisioning](#phase-1-cloudflare-infrastructure-provisioning)
   - [Phase 2: Worker Backend Development & Deployment](#phase-2-worker-backend-development--deployment)
   - [Phase 3: Database Migrations & Seeding](#phase-3-database-migrations--seeding)
   - [Phase 4: Flutter Mobile & Web Client Setup](#phase-4-flutter-mobile--web-client-setup)
   - [Phase 5: Building & Packaging (Web & Android APK)](#phase-5-building--packaging-web--android-apk)
5. [Key Production Gotchas & Fixes](#5-key-production-gotchas--fixes)
6. [API Route Reference](#6-api-route-reference)

---

## 1. Cloudflare Account & Resource Connections

### Cloudflare Account Details
| Property | Value |
| :--- | :--- |
| **Account Name** | `Muhammadkabirhassan.infinity@gmail.com's Account` |
| **Account Email** | `muhammadkabirhassan.infinity@gmail.com` |
| **Account ID** | `c1c242c15972c98b84e9d48c43d1127f` |

---

### Cloudflare Resources & Bindings

#### 1. Worker (Compute & API Gateway)
- **Worker Script Name**: `docflare-worker`
- **Live Production URL**: `https://docflare-worker.muhammadkabirhassan-infinity.workers.dev`
- **Base API Endpoint**: `https://docflare-worker.muhammadkabirhassan-infinity.workers.dev/api/v1`
- **Health Check Endpoint**: `https://docflare-worker.muhammadkabirhassan-infinity.workers.dev/health`
- **Compatibility Date**: `2024-11-01`
- **Compatibility Flags**: `nodejs_compat`

#### 2. Cloudflare D1 (Serverless SQLite Relational Database)
- **Binding Name**: `DB`
- **Database Name**: `docflare-db`
- **Database ID**: `aedddebb-a8e9-4753-9f85-e75fdb8e380a`
- **Region**: `WEUR` (Western Europe)
- **Migrations Directory**: `worker/migrations`

#### 3. Cloudflare R2 (S3-Compatible Object Storage)
- **Binding Name**: `BUCKET`
- **Bucket Name**: `docflare-documents`
- **Storage Scope**: Document files, binary assets, and encrypted uploads.

#### 4. Cloudflare Workers KV (Key-Value Store)
- **Binding Name**: `KV`
- **Namespace ID**: `75a4ab6a19704a6db30cee7516ca04f5`
- **Usage**: Rate limiting counters, token blacklists, and fast session lookups.

#### 5. Configured Worker Secrets (`wrangler secret put <NAME>`)
| Secret Name | Purpose | Value / Format |
| :--- | :--- | :--- |
| `JWT_SECRET` | HS256 cryptographic signing key for user session tokens | 64+ char random hexadecimal string |
| `EMAIL_API_KEY` | Transactional email provider key (e.g., [Resend](https://resend.com)) | `re_...` |
| `EMAIL_FROM` | Transactional outbound email address | `Docflare <onboarding@resend.dev>` or custom domain |

---

## 2. Default Seed Credentials & Test Accounts

The remote database has been pre-seeded with the primary administrator account and a default organization:

### Administrator Account
- **Email**: `admin@docflare.com`
- **Password**: `Docflare123!`
- **User ID**: `usr_admin_001`
- **Role**: `admin`
- **Email Verified**: Yes (`email_verified_at` set)

### Default Organization
- **Organization Name**: `Docflare HQ`
- **Organization ID**: `org_demo_001`
- **Slug**: `docflare-hq`
- **Storage Quota**: 10 GB (`10737418240` bytes)

---

## 3. Architecture Overview

```
 ┌─────────────────────────────────────────────────────────────┐
 │                      FLUTTER CLIENT                         │
 │     Web (Chrome / Safari)   │   Mobile (Android / iOS)      │
 └──────────────────────────────┬──────────────────────────────┘
                                │ HTTPS / REST / JSON
                                ▼
 ┌─────────────────────────────────────────────────────────────┐
 │                CLOUDFLARE WORKER (Hono.js)                  │
 │  - Dynamic CORS Reflection  │ - Secure Headers / CORP       │
 │  - PBKDF2 Password Hashing  │ - HS256 JWT Authentication    │
 │  - RBAC Capability Engine   │ - Direct Binary File Stream   │
 └──────┬───────────────────────┼───────────────────────┬──────┘
        │                       │                       │
        ▼                       ▼                       ▼
 ┌───────────────┐       ┌───────────────┐       ┌───────────────┐
 │ Cloudflare D1 │       │ Cloudflare R2 │       │ Cloudflare KV │
 │  (SQLite DB)  │       │(Object Storage│       │  (Key-Value)  │
 │ Users, Orgs,  │       │ Binary blobs, │       │  Rate limits, │
 │ Folders, Docs │       │   PDFs, imgs  │       │  revocations  │
 └───────────────┘       └───────────────┘       └───────────────┘
```

### File Upload Flow (Zero-Lag Direct Streaming)
1. **Initiate**: Flutter sends `POST /api/v1/organizations/:orgId/uploads` with metadata (`display_name`, `file_size_bytes`, `content_type`, `folder_id`).
2. **Session Allocation**: Worker creates an `upload_sessions` row in D1 and assigns an R2 object key: `orgs/<orgId>/<timestamp>-<cuid>.<ext>`.
3. **Payload Stream**: Flutter streams binary bytes via `PUT /api/v1/uploads/:uploadSessionId/file` with raw bytes (`Uint8List`).
4. **Direct R2 Put**: The Worker streams the incoming HTTP request body directly into Cloudflare R2 via `env.BUCKET.put(key, c.req.raw.body)`.
5. **Finalize**: Flutter calls `POST /api/v1/uploads/:uploadSessionId/complete`, marking the document as active in D1.

---

## 4. Step-by-Step Setup: Building a Similar Flutter + Cloudflare App

Follow this exact walkthrough to set up a new project with your own Cloudflare account.

### Prerequisites
- [Node.js](https://nodejs.org) (v18.0.0 or higher)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.22.0 or higher)
- Java 17+ & Android SDK Command-line Tools (for Android builds)
- Git

---

### Phase 1: Cloudflare Infrastructure Provisioning

1. **Login to Cloudflare via Wrangler**:
   ```powershell
   npx wrangler login
   ```
   A browser window will open. Click **Allow** to grant permissions.

2. **Verify your account**:
   ```powershell
   npx wrangler whoami
   ```
   Note your `Account ID`.

3. **Create the D1 SQL Database**:
   ```powershell
   npx wrangler d1 create my-app-db
   ```
   Output gives you the database ID:
   ```toml
   [[d1_databases]]
   binding = "DB"
   database_name = "my-app-db"
   database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```

4. **Create the R2 Storage Bucket**:
   ```powershell
   npx wrangler r2 bucket create my-app-storage
   ```

5. **Create the KV Namespace**:
   ```powershell
   npx wrangler kv:namespace create my-app-kv
   ```
   Note the `id` printed in the console.

---

### Phase 2: Worker Backend Development & Deployment

1. **Initialize the Worker**:
   ```powershell
   mkdir worker
   cd worker
   npm init -y
   npm install hono @paralleldrive/cuid2
   npm install --save-dev typescript @cloudflare/workers-types wrangler
   ```

2. **Configure `worker/wrangler.toml`**:
   ```toml
   name = "my-app-worker"
   main = "src/index.ts"
   compatibility_date = "2024-11-01"
   compatibility_flags = ["nodejs_compat"]

   [vars]
   ENVIRONMENT = "production"
   APP_NAME = "MyApp"
   CORS_ORIGIN = "*"
   MAX_FILE_SIZE_BYTES = 524288000       # 500 MB
   DEFAULT_ORG_QUOTA_BYTES = 10737418240 # 10 GB

   [[d1_databases]]
   binding = "DB"
   database_name = "my-app-db"
   database_id = "PASTE_YOUR_D1_DATABASE_ID_HERE"
   migrations_dir = "migrations"

   [[r2_buckets]]
   binding = "BUCKET"
   bucket_name = "my-app-storage"

   [[kv_namespaces]]
   binding = "KV"
   id = "PASTE_YOUR_KV_NAMESPACE_ID_HERE"
   ```

3. **Configure Worker Secrets**:
   ```powershell
   # Generate a random 64-char key for JWT:
   npx wrangler secret put JWT_SECRET
   # (Enter a secure random string when prompted)

   # Optional email secrets:
   npx wrangler secret put EMAIL_API_KEY
   npx wrangler secret put EMAIL_FROM
   ```

4. **Implement CORS & Cross-Origin-Resource-Policy in Hono (`worker/src/index.ts`)**:
   > **CRITICAL FOR FLUTTER WEB**:
   > Browsers will block POST/PUT requests with `net::ERR_CONNECTION_CLOSED` unless `crossOriginResourcePolicy` is explicitly set to `cross-origin` and CORS origin is reflected for credentials mode.

   ```typescript
   import { Hono } from 'hono';
   import { cors } from 'hono/cors';
   import { secureHeaders } from 'hono/secure-headers';

   const app = new Hono<{ Bindings: Env }>();

   // Global Security Headers with cross-origin CORP
   app.use('*', secureHeaders({
     crossOriginResourcePolicy: 'cross-origin',
     crossOriginOpenerPolicy: 'same-origin-allow-popups',
   }));

   // Dynamic Origin Reflection for CORS
   app.use('/api/*', async (c, next) => {
     const reqOrigin = c.req.header('Origin') || '*';
     const corsHandler = cors({
       origin: reqOrigin,
       allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
       allowHeaders: ['Content-Type', 'Authorization', 'X-Request-Id'],
       exposeHeaders: ['Content-Length', 'X-Request-Id'],
       credentials: true,
       maxAge: 86400,
     });
     return corsHandler(c, next);
   });

   // Preflight OPTIONS handler
   app.options('*', (c) => c.text('', 204));
   ```

5. **Deploy the Worker**:
   ```powershell
   npx wrangler deploy
   ```
   Take note of your assigned URL: `https://my-app-worker.<your-subdomain>.workers.dev`.

---

### Phase 3: Database Migrations & Seeding

1. **Create the Migration (`worker/migrations/0001_initial_schema.sql`)**:
   Add the SQL tables for `users`, `organizations`, `organization_members`, `folders`, `documents`, and `upload_sessions`.

2. **Apply Migrations to Remote Cloudflare D1**:
   ```powershell
   npx wrangler d1 migrations apply my-app-db --remote
   ```

3. **Seed Initial Data**:
   Create a `seed.sql` file and execute it against remote D1:
   ```powershell
   npx wrangler d1 execute my-app-db --file=./seed.sql --remote
   ```

---

### Phase 4: Flutter Mobile & Web Client Setup

1. **Create the Flutter Project**:
   ```powershell
   flutter create mobile
   cd mobile
   ```

2. **Add Required Dependencies (`mobile/pubspec.yaml`)**:
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     http: ^1.2.2
     provider: ^6.1.2
     flutter_secure_storage: ^11.2.0
     file_picker: ^13.1.0
     intl: ^0.19.0
     mime: ^2.0.0
     open_filex: ^4.5.0
     path_provider: ^2.1.4
   ```

3. **Configure API Base URL (`lib/core/constants/api_constants.dart`)**:
   ```dart
   class ApiConstants {
     static const String baseUrl = String.fromEnvironment(
       'API_BASE_URL',
       defaultValue: 'https://docflare-worker.muhammadkabirhassan-infinity.workers.dev/api/v1',
     );
   }
   ```

4. **Implement Universal Byte Uploading (`lib/core/network/api_client.dart`)**:
   > **IMPORTANT**: On Flutter Web, `PlatformFile.path` is `null` because browsers lack filesystem access. Always upload bytes using `readAsBytes()`.

   ```dart
   Future<dynamic> uploadBytes(
     String path,
     List<int> bytes, {
     required String contentType,
     void Function(int sent, int total)? onProgress,
   }) async {
     final uri = _buildUri(path);
     final request = http.StreamedRequest('PUT', uri);
     request.headers['Content-Type'] = contentType;
     request.headers['Content-Length'] = bytes.length.toString();

     final token = await _storage.getToken();
     if (token != null) {
       request.headers['Authorization'] = 'Bearer $token';
     }

     // Stream the bytes
     request.sink.add(bytes);
     request.sink.close();

     final streamedResponse = await request.send();
     final response = await http.Response.fromStream(streamedResponse);
     return jsonDecode(response.body);
   }
   ```

5. **Configure Android Permissions (`android/app/src/main/AndroidManifest.xml`)**:
   Inside `<manifest>`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
   <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
   <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
   ```
   Inside `<application>`:
   ```xml
   android:usesCleartextTraffic="true"
   ```

---

### Phase 5: Building & Packaging (Web & Android APK)

#### Running on Web (Local Chrome)
```powershell
cd mobile
flutter run -d chrome --web-port 8080
```

#### Building Release Android APK
```powershell
cd mobile
flutter build apk --release
```
- **Output Location**: `mobile/build/app/outputs/flutter-apk/app-release.apk`
- To specify a custom Cloudflare backend at build time:
  ```powershell
  flutter build apk --release --dart-define=API_BASE_URL=https://my-custom-worker.workers.dev/api/v1
  ```

---

## 5. Key Production Gotchas & Fixes

### 1. Cloudflare WebCrypto PBKDF2 Iteration Cap
- **Issue**: Standard NIST guidelines recommend 310,000 PBKDF2 iterations for passwords. However, Cloudflare Workers' `workerd` runtime enforces a hard limit of **100,000 iterations**. Exceeding this throws `OperationError: The operation failed for an operation-specific reason`.
- **Solution**: Set iterations to `100000` in your password hashing function:
  ```typescript
  const derivedBits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations: 100000 },
    keyMaterial,
    256
  );
  ```

### 2. Cross-Origin-Resource-Policy (`net::ERR_CONNECTION_CLOSED`)
- **Issue**: Hono's `secureHeaders()` defaults to `Cross-Origin-Resource-Policy: same-origin`. When Flutter Web (`http://localhost:8080`) sends POST requests to your Cloudflare domain, Chromium abruptly terminates the connection.
- **Solution**: Configure `secureHeaders({ crossOriginResourcePolicy: 'cross-origin' })`.

### 3. File Picker in Flutter Web
- **Issue**: Calling `File(platformFile.path!)` in Flutter Web crashes with `Unsupported operation: Platform._operatingSystem` or `Null check operator used on a null value`.
- **Solution**: Use `await platformFile.readAsBytes()` which works uniformly on Web, Android, iOS, Windows, macOS, and Linux.

### 4. Duplicate Base URL Prefixes
- **Issue**: When Worker routes return relative upload endpoints such as `upload_url: '/api/v1/uploads/:id/file'`, calling `_api.uploadBytes(session.uploadUrl)` prepends another `/api/v1`, creating an invalid path `https://worker.../api/v1/api/v1/uploads/...`.
- **Solution**: Implement a URL normalizer in your API client:
  ```dart
  Uri _buildUri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    var cleanPath = path.startsWith('/') ? path : '/$path';
    if (cleanBase.endsWith('/api/v1') && cleanPath.startsWith('/api/v1/')) {
      cleanPath = cleanPath.substring(7);
    }
    return Uri.parse('$cleanBase$cleanPath');
  }
  ```

---

## 6. API Route Reference

All routes are mounted under `/api/v1`.

### Authentication
- `POST /auth/register` — Create a new user account.
- `POST /auth/login` — Sign in and obtain a JWT bearer token.
- `GET /auth/me` — Retrieve current user profile and organization memberships.
- `POST /auth/logout` — Revoke active session token.
- `POST /auth/forgot-password` — Request password reset token.
- `POST /auth/reset-password` — Complete password reset.

### Organizations & Team Members
- `GET /organizations` — List user's active organizations.
- `POST /organizations` — Create a new organization (user becomes `admin`).
- `GET /organizations/:id` — Get organization details and storage quota.
- `GET /organizations/:id/members` — List members in an organization.
- `POST /organizations/:id/members` — Directly add an existing registered user by email.
- `GET /organizations/:id/invitations` — List pending invitations.
- `POST /organizations/:id/invitations` — Invite a new member via email and return invite token.
- `POST /invitations/accept` — Accept an invitation token.
- `PATCH /organizations/:id/members/:memberId` — Update member role (`admin`, `manager`, `viewer`).
- `DELETE /organizations/:id/members/:memberId` — Remove/suspend a member.

### Document & Folder Management
- `GET /organizations/:id/folders` — List folders (supports `parent_id` parameter).
- `POST /organizations/:id/folders` — Create a folder.
- `PATCH /folders/:folderId` — Rename a folder.
- `DELETE /folders/:folderId` — Delete a folder (supports `?recursive=true`).
- `GET /organizations/:id/documents` — List active documents in organization or folder.
- `GET /documents/:id` — Get document metadata and download URL.
- `PATCH /documents/:id` — Rename document or update folder placement.
- `DELETE /documents/:id` — Move document to trash.
- `GET /organizations/:id/trash` — List documents in trash.
- `POST /documents/:id/restore` — Restore document from trash.
- `DELETE /documents/:id/permanent` — Permanently delete document and purge R2 object.

### File Uploads & Binary Streaming
- `POST /organizations/:id/uploads` — Initiate an upload session.
- `PUT /uploads/:id/file` — Stream raw binary payload into R2.
- `POST /uploads/:id/complete` — Finalize upload session and verify object checksum.
- `POST /uploads/:id/cancel` — Abort upload and clean up session.

### Search & Audit
- `GET /organizations/:id/search?q=...` — Search documents by display name, description, and type.
- `GET /organizations/:id/audit-logs` — Retrieve compliance audit trails (Admin only).

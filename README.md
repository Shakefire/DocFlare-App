# Full-Stack Flutter + Cloudflare Serverless Blueprint

A comprehensive, production-tested boilerplate and setup guide for connecting **any Flutter application** (Mobile, Web, Desktop) to **Cloudflare Serverless Infrastructure** (Workers, D1 SQL Database, R2 Object Storage, and Workers KV).

This file also acts as your centralized credential vault containing your active Cloudflare account identifiers and service bindings.

---

## 1. Your Cloudflare Account Credentials & Active Services

The following identifiers and connections are active on your Cloudflare account and can be referenced directly in this or any future project:

### Account Information
| Property | Value |
| :--- | :--- |
| **Account Name** | `Muhammadkabirhassan.infinity@gmail.com's Account` |
| **Account Email** | `muhammadkabirhassan.infinity@gmail.com` |
| **Account ID** | `c1c242c15972c98b84e9d48c43d1127f` |

---

### Active Cloudflare Services & Bindings
| Service | Name / ID | Binding Name | Role / Purpose |
| :--- | :--- | :--- | :--- |
| **Worker (Compute)** | `docflare-worker` | — | Hono REST API Gateway & Backend Compute |
| **D1 Database (SQL)** | `docflare-db`<br>`aedddebb-a8e9-4753-9f85-e75fdb8e380a` | `DB` | Serverless SQLite relational database (WEUR region) |
| **R2 Storage (Blobs)** | `docflare-documents` | `BUCKET` | S3-compatible zero-egress bucket for files, images, PDFs |
| **Workers KV (Cache)** | `75a4ab6a19704a6db30cee7516ca04f5` | `KV` | High-read, low-latency key-value store for sessions & caching |

---

### Live Endpoints
- **Production API Base**: `https://docflare-worker.muhammadkabirhassan-infinity.workers.dev/api/v1`
- **Health Check**: `https://docflare-worker.muhammadkabirhassan-infinity.workers.dev/health`

---

### Worker Secrets Configured on Cloudflare
| Secret Key | Description | Status |
| :--- | :--- | :--- |
| `JWT_SECRET` | 64+ character random string for signing/verifying session JWTs | Configured via `wrangler secret put JWT_SECRET` |
| `EMAIL_API_KEY` | Transactional email provider key (e.g., [Resend](https://resend.com)) | Configured via `wrangler secret put EMAIL_API_KEY` |
| `EMAIL_FROM` | Outbound sender address (e.g., `noreply@yourdomain.com`) | Configured via `wrangler secret put EMAIL_FROM` |

---

### Pre-Seeded Default Test Account
| Field | Value |
| :--- | :--- |
| **Email** | `admin@docflare.com` |
| **Password** | `Docflare123!` |
| **User ID** | `usr_admin_001` |
| **Organization** | `Docflare HQ` (`org_demo_001`) |
| **Role** | `admin` |

---

## 2. Generic Architecture: How Flutter + Cloudflare Works

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                      FLUTTER CLIENT APPLICATION                       │
 │  Platforms: Android APK  │  iOS  │  Web (Chrome / Safari)  │  Desktop  │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │ HTTPS JSON / Binary Streams
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │                   CLOUDFLARE WORKER (API GATEWAY)                      │
 │                 Built with Hono.js (TypeScript)                        │
 │                                                                        │
 │  • Dynamic CORS Reflection (supports credentials & localhost)          │
 │  • CORP (Cross-Origin-Resource-Policy) for browser client support      │
 │  • PBKDF2 Password Hashing (100,000 iterations via WebCrypto)          │
 │  • HS256 JWT Authentication & Route Guards                             │
 │  • Direct Streaming to R2 (Zero intermediate disk buffering)           │
 └──────────────┬────────────────────┬────────────────────┬───────────────┘
                │                    │                    │
                ▼                    ▼                    ▼
        ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
        │ Cloudflare D1 │    │ Cloudflare R2 │    │ Cloudflare KV │
        │ (SQLite DB)   │    │(Object Storage│    │ (Fast Key-Val)│
        │ Structured    │    │ Images, PDFs, │    │ Sessions,     │
        │ relational    │    │ media, user   │    │ rate limits,  │
        │ tables & data │    │ uploads       │    │ auth cache    │
        └───────────────┘    └───────────────┘    └───────────────┘
```

---

## 3. Generic Worker Configuration (`wrangler.toml`)

Create a `worker/wrangler.toml` file to declare all bindings between your Worker and Cloudflare products:

```toml
name = "my-app-worker"
main = "src/index.ts"
compatibility_date = "2024-11-01"
compatibility_flags = ["nodejs_compat"]

[vars]
ENVIRONMENT = "production"
APP_NAME = "MyFlutterApp"
CORS_ORIGIN = "*"
MAX_FILE_SIZE_BYTES = 524288000 # 500 MB

# D1 Relational Database Binding
[[d1_databases]]
binding = "DB"
database_name = "docflare-db"
database_id = "aedddebb-a8e9-4753-9f85-e75fdb8e380a"
migrations_dir = "migrations"

# R2 Object Storage Bucket Binding
[[r2_buckets]]
binding = "BUCKET"
bucket_name = "docflare-documents"

# KV Cache / Session Binding
[[kv_namespaces]]
binding = "KV"
id = "75a4ab6a19704a6db30cee7516ca04f5"

# Optional Cron Trigger (e.g. daily cleanup at 02:00 UTC)
[triggers]
crons = ["0 2 * * *"]
```

---

## 4. Generic Worker Backend Template (`src/index.ts`)

Here is a clean, modular Hono-based Worker backend template providing CORS, Authentication, D1 CRUD, and R2 Binary Uploading:

```typescript
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { secureHeaders } from 'hono/secure-headers';

// Environment Bindings Interface
export interface Env {
  DB: D1Database;
  BUCKET: R2Bucket;
  KV: KVNamespace;
  JWT_SECRET: string;
  ENVIRONMENT: string;
}

const app = new Hono<{ Bindings: Env }>();

// 1. Cross-Origin Security Headers (Essential for Flutter Web)
app.use('*', secureHeaders({
  crossOriginResourcePolicy: 'cross-origin',
  crossOriginOpenerPolicy: 'same-origin-allow-popups',
}));

// 2. Dynamic CORS Reflection (Supports Bearer auth & localhost dev)
app.use('/api/*', async (c, next) => {
  const origin = c.req.header('Origin') || '*';
  const corsMiddleware = cors({
    origin,
    allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Content-Type', 'Authorization', 'X-Request-Id'],
    exposeHeaders: ['Content-Length', 'X-Request-Id'],
    credentials: true,
    maxAge: 86400,
  });
  return corsMiddleware(c, next);
});

// Explicit OPTIONS preflight handler
app.options('*', (c) => c.text('', 204));

// Health check
app.get('/health', (c) => c.json({ status: 'ok', timestamp: new Date().toISOString() }));

const api = app.basePath('/api/v1');

// 3. Generic D1 Database Query Endpoint
api.get('/items', async (c) => {
  const result = await c.env.DB
    .prepare('SELECT * FROM items ORDER BY created_at DESC LIMIT 50')
    .all();
  return c.json({ data: result.results });
});

api.post('/items', async (c) => {
  const body = await c.req.json();
  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  await c.env.DB
    .prepare('INSERT INTO items (id, name, created_at) VALUES (?, ?, ?)')
    .bind(id, body.name, now)
    .run();

  return c.json({ data: { id, name: body.name } }, 201);
});

// 4. Generic R2 Direct Binary Streaming Upload
api.put('/upload/:key', async (c) => {
  const key = c.req.param('key');
  const contentType = c.req.header('Content-Type') || 'application/octet-stream';

  // Stream raw request body directly into Cloudflare R2
  const object = await c.env.BUCKET.put(key, c.req.raw.body, {
    httpMetadata: { contentType },
  });

  return c.json({ data: { key, size: object?.size, uploaded_at: new Date().toISOString() } });
});

// 5. Generic R2 File Download / Serve
api.get('/files/:key', async (c) => {
  const key = c.req.param('key');
  const object = await c.env.BUCKET.get(key);
  if (!object) return c.json({ error: 'File not found' }, 404);

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);

  return new Response(object.body, { headers });
});

// 6. Generic KV Cache Read / Write
api.get('/cache/:key', async (c) => {
  const val = await c.env.KV.get(c.req.param('key'));
  return c.json({ key: c.req.param('key'), value: val });
});

api.put('/cache/:key', async (c) => {
  const body = await c.req.json();
  await c.env.KV.put(c.req.param('key'), JSON.stringify(body), { expirationTtl: 3600 });
  return c.json({ message: 'Cached successfully' });
});

export default app;
```

---

## 5. Generic Flutter Client Setup

### A. Dependencies (`mobile/pubspec.yaml`)
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.2                  # REST & binary streaming
  provider: ^6.1.2              # State management
  flutter_secure_storage: ^11.2.0 # Encrypted token storage
  file_picker: ^13.1.0          # Universal file picking
  intl: ^0.19.0                 # Date & number formatting
  mime: ^2.0.0                  # Mime-type detection
```

### B. Environment-Aware Configuration (`api_constants.dart`)
Allows switching between local development, staging, and Cloudflare production using compile-time flags:
```dart
class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://docflare-worker.muhammadkabirhassan-infinity.workers.dev/api/v1',
  );

  static const Duration timeout = Duration(seconds: 30);
}
```

### C. Universal API Client (`api_client.dart`)
Handles JWT authentication, duplicate `/api/v1` URL normalisation, and streaming file uploads:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final String baseUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final http.Client _client = http.Client();

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? 'https://docflare-worker.muhammadkabirhassan-infinity.workers.dev/api/v1';

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

  Future<Map<String, String>> _headers({bool isJson = true}) async {
    final headers = <String, String>{};
    if (isJson) headers['Content-Type'] = 'application/json';
    final token = await _storage.read(key: 'auth_token');
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // GET
  Future<dynamic> get(String path) async {
    final res = await _client.get(_buildUri(path), headers: await _headers());
    return _handleResponse(res);
  }

  // POST
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final res = await _client.post(
      _buildUri(path),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(res);
  }

  // Direct Binary Byte Upload (Works identically on Web and Native)
  Future<dynamic> uploadBytes(
    String path,
    List<int> bytes, {
    required String contentType,
  }) async {
    final uri = _buildUri(path);
    final request = http.StreamedRequest('PUT', uri);
    request.headers['Content-Type'] = contentType;
    request.headers['Content-Length'] = bytes.length.toString();

    final token = await _storage.read(key: 'auth_token');
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.sink.add(bytes);
    request.sink.close();

    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);
    return _handleResponse(res);
  }

  dynamic _handleResponse(http.Response res) {
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw Exception(data['error']?['message'] ?? 'Request failed (${res.statusCode})');
  }
}
```

### D. Universal File Upload Pattern (Web & Mobile Compatible)
> **Crucial Rule**: On Flutter Web, `PlatformFile.path` is `null` by design. Do not pass `File(platformFile.path!)`. Instead, use `platformFile.readAsBytes()`:

```dart
Future<void> pickAndUploadFile(BuildContext context, ApiClient api) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'png', 'jpg', 'docx', 'xlsx'],
  );

  if (result != null && result.files.isNotEmpty) {
    final platformFile = result.files.first;

    // 1. Read bytes asynchronously (Cross-platform)
    final bytes = await platformFile.readAsBytes();
    final fileName = platformFile.name;

    // 2. Stream directly to Cloudflare Worker R2 endpoint
    await api.uploadBytes(
      '/upload/$fileName',
      bytes,
      contentType: 'application/octet-stream',
    );
  }
}
```

### E. Android Manifest Configuration (`android/app/src/main/AndroidManifest.xml`)
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Internet permission for Cloudflare API calls -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>

    <application
        android:label="MyApp"
        android:name="${applicationName}"
        android:usesCleartextTraffic="true">
        <!-- ... -->
    </application>
</manifest>
```

---

## 6. CLI Command Cheat Sheet

### Cloudflare & Wrangler Commands
```powershell
# 1. Sign in & inspect account
npx wrangler login
npx wrangler whoami

# 2. Manage D1 Database
npx wrangler d1 create <db-name>
npx wrangler d1 migrations apply <db-name> --remote
npx wrangler d1 execute <db-name> --command="SELECT * FROM users" --remote
npx wrangler d1 execute <db-name> --file=./seed.sql --remote

# 3. Manage R2 Storage
npx wrangler r2 bucket create <bucket-name>
npx wrangler r2 bucket list

# 4. Manage KV
npx wrangler kv:namespace create <kv-name>
npx wrangler kv:key list --binding=KV

# 5. Set Production Secrets
npx wrangler secret put JWT_SECRET
npx wrangler secret put EMAIL_API_KEY

# 6. Deploy Worker to Cloudflare Edge
npx wrangler deploy
```

### Flutter Commands
```powershell
# 1. Run on Chrome (Web) with custom port
flutter run -d chrome --web-port 8080

# 2. Build Release APK (Android)
flutter build apk --release

# 3. Build Release APK pointing to another custom Cloudflare Worker
flutter build apk --release --dart-define=API_BASE_URL=https://my-worker.workers.dev/api/v1

# 4. Install APK directly to connected Android device
adb install build/app/outputs/flutter-apk/app-release.apk

# 5. Clean stale caches & build artifacts
flutter clean
flutter pub get
```

---

## 7. Crucial Production Lessons Learned

### 1. Cloudflare WebCrypto PBKDF2 Iteration Limit
Cloudflare Workers `workerd` runtime enforces a strict ceiling of **100,000 iterations** on PBKDF2 hashing. Attempting to use 310,000 iterations throws an unhandled `OperationError`.
- **Fix**: Always configure PBKDF2 iterations to `100000`:
  ```typescript
  const derivedBits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations: 100000 },
    keyMaterial,
    256
  );
  ```

### 2. Browser CORS & Cross-Origin-Resource-Policy (`CORP`)
If Hono's `secureHeaders()` middleware runs with default settings, it injects `Cross-Origin-Resource-Policy: same-origin`. This causes Chrome to abort cross-origin POST requests from localhost with `net::ERR_CONNECTION_CLOSED`.
- **Fix**: Explicitly set `crossOriginResourcePolicy: 'cross-origin'` and dynamic origin reflection in `secureHeaders()`.

### 3. Flutter Web File Paths Are Null
On Web, browser security sandboxes prevent access to local filesystem paths (`file.path` is `null`).
- **Fix**: Use `platformFile.readAsBytes()` which resolves bytes uniformly across Web and mobile.

### 4. Disk Space During Android APK Native Builds
Flutter release builds compile native assets and R8 shrinking, which can require up to 2-3 GB of free disk space during compilation. If disk space runs low, the Dart compiler will exit with `errno = 112 (No space left on disk)`.
- **Fix**: Keep at least 4-5 GB of free space on your system drive before triggering `flutter build apk --release`.

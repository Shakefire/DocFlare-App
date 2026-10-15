# Docflare Setup & Deployment Guide

This guide details the step-by-step instructions to set up, develop, test, and deploy both the **Cloudflare Workers backend** and the **Flutter mobile application**.

---

## 1. Prerequisites

Ensure the following tools are installed:

- **Node.js**: v18.0.0 or higher (v24.x tested)
- **npm**: v9.0.0 or higher
- **Wrangler**: Cloudflare CLI (`npm install -g wrangler`)
- **Flutter SDK**: 3.x with Dart 3.x
- **Cloudflare Account**: with access to Workers, D1 Database, R2 Storage, and KV

---

## 2. Cloudflare Infrastructure Provisioning

Run these commands with Wrangler to provision the backing Cloudflare resources:

### Step 2.1: Log in to Cloudflare
```bash
npx wrangler login
```

### Step 2.2: Create the D1 Database
```bash
npx wrangler d1 create docflare-db
```
*Note the returned `database_id` and update it in `worker/wrangler.toml` under `[[d1_databases]]`.*

### Step 2.3: Create the R2 Storage Bucket
```bash
npx wrangler r2 bucket create docflare-documents
```

### Step 2.4: Create the KV Namespace
```bash
npx wrangler kv namespace create docflare-kv
npx wrangler kv namespace create docflare-kv --preview
```
*Note the returned IDs and update `id` and `preview_id` in `worker/wrangler.toml` under `[[kv_namespaces]]`.*

### Step 2.5: Configure Secrets
Set the production secrets via Wrangler:
```bash
cd worker
npx wrangler secret put JWT_SECRET          # 32+ character random hex secret
npx wrangler secret put EMAIL_API_KEY       # API key from Resend (https://resend.com)
npx wrangler secret put EMAIL_FROM          # e.g. Docflare <noreply@docflare.app>
```

---

## 3. Database Migrations

### Apply Migrations Locally (for dev/test):
```bash
cd worker
npx wrangler d1 migrations apply docflare-db --local
```

### Apply Migrations to Remote / Production D1:
```bash
cd worker
npx wrangler d1 migrations apply docflare-db --remote
```

---

## 4. Running the Worker Backend Locally

```bash
cd worker
npm install
npm run dev
```
The local Worker starts at `http://127.0.0.1:8787` with local D1, local R2 emulator, and local KV storage.

---

## 5. Running the Flutter Mobile Application

### Step 5.1: Install Dependencies
```bash
cd mobile
flutter pub get
```

### Step 5.2: Run on Android / iOS Simulator or Device
For local development against the local worker:
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787/api/v1   # Android Emulator
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8787/api/v1  # iOS Simulator / Desktop
```

For production deployment:
```bash
flutter run --dart-define=API_BASE_URL=https://docflare-worker.YOUR_SUBDOMAIN.workers.dev/api/v1
```

---

## 6. Running Automated Tests

### Run Backend Unit & Integration Tests:
```bash
cd worker
npm test
```

### Run Flutter Unit & Widget Tests:
```bash
cd mobile
flutter test
```

---

## 7. Deploying Worker Backend to Production

```bash
cd worker
npx wrangler deploy
```

---

## 8. Building Mobile Production Releases

### Android APK / App Bundle:
```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://docflare-worker.YOUR_SUBDOMAIN.workers.dev/api/v1
flutter build appbundle --release --dart-define=API_BASE_URL=https://docflare-worker.YOUR_SUBDOMAIN.workers.dev/api/v1
```

### iOS Release:
```bash
cd mobile
flutter build ipa --release --dart-define=API_BASE_URL=https://docflare-worker.YOUR_SUBDOMAIN.workers.dev/api/v1
```

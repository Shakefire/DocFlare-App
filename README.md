# Docflare — Secure Document Management System

A production-grade mobile document management system built with **Flutter** (mobile) and **Cloudflare Workers** (backend).

## Architecture

```
Docflare App/
├── worker/          # Cloudflare Workers TypeScript backend
│   ├── src/         # Worker source code
│   ├── migrations/  # D1 SQL migrations
│   └── wrangler.toml
├── mobile/          # Flutter mobile application
│   ├── lib/         # Dart source code
│   ├── test/        # Flutter tests
│   └── pubspec.yaml
└── docs/            # Architecture and API documentation
```

## Technology Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.x / Dart 3.x |
| Backend API | Cloudflare Workers (TypeScript) |
| Relational DB | Cloudflare D1 (SQLite) |
| Object Storage | Cloudflare R2 (private) |
| KV Store | Cloudflare KV (config/flags only) |
| Deployment | Wrangler CLI |

## Quick Start

See [docs/SETUP.md](docs/SETUP.md) for full setup instructions.

### Prerequisites

- Node.js 18+
- npm 9+
- Flutter 3.x SDK
- Cloudflare account with Workers, D1, R2, KV access
- Wrangler CLI (`npm install -g wrangler`)

### Backend (Worker)

```bash
cd worker
npm install
npx wrangler dev          # local development
npx wrangler deploy       # production deploy
```

### Mobile (Flutter)

```bash
cd mobile
flutter pub get
flutter run               # requires connected device or emulator
```

## Documentation

- [Setup Guide](docs/SETUP.md)
- [API Reference](docs/API.md)
- [Database Schema](docs/SCHEMA.md)
- [Role-Permission Matrix](docs/ROLES.md)
- [Upload Architecture](docs/UPLOADS.md)
- [Security Model](docs/SECURITY.md)
- [Operational Runbook](docs/OPERATIONS.md)

export interface Env {
  // Cloudflare bindings
  DB: D1Database;
  BUCKET: R2Bucket;
  KV: KVNamespace;

  // Environment variables
  ENVIRONMENT: string;
  APP_NAME: string;
  CORS_ORIGIN: string;
  MAX_FILE_SIZE_BYTES: string;
  DEFAULT_ORG_QUOTA_BYTES: string;
  TRASH_RETENTION_DAYS: string;
  UPLOAD_SESSION_TTL_SECONDS: string;
  INVITATION_TTL_SECONDS: string;

  // Secrets
  JWT_SECRET: string;
  EMAIL_API_KEY: string;
  EMAIL_FROM: string;
}

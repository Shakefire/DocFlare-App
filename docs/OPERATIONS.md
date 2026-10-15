# Operational Reliability & Disaster Recovery Runbook

This runbook documents production maintenance, scheduled cleanup, partial failure handling, and backup/restore procedures for Docflare.

---

## 1. Scheduled Background Worker (Cron)

A Cloudflare Scheduled Worker runs daily at `02:00 UTC` (`0 2 * * *` configured in `wrangler.toml`):

```typescript
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(scheduledCleanup(env));
  },
};
```

### Automated Maintenance Tasks:
1. **Purge Abandoned Uploads**: Aborts uncompleted multipart uploads in R2 and deletes uncompleted pending documents older than 1 hour.
2. **Expired Trash Purge**: Permanently deletes documents soft-deleted more than 30 days ago (`TRASH_RETENTION_DAYS`), removes their R2 storage objects, and deducts bytes from organization storage.
3. **Expired Token Cleanup**: Purges expired tokens from `revoked_tokens`, `email_verifications`, and `password_resets`.

---

## 2. Handling Partial Failures (D1 vs R2)

Because cross-service distributed transactions do not exist across D1 and R2, Docflare uses two-phase state transitions and reconciliation:

1. **Uploads**: Document is created with `upload_status = 'pending'`. Only after R2 verifies that bytes have arrived does D1 update `upload_status = 'completed'`. If the upload fails halfway or network drops, the scheduled cleanup job reconciles and purges the pending record.
2. **Restorations**: When restoring a document from trash, the backend executes `env.BUCKET.head(object_key)`. If the storage object is missing, restoration is aborted with a `409 Conflict`, preventing corrupted metadata records.

---

## 3. Database Backup & Disaster Recovery

### D1 Database Backup:
Cloudflare D1 automatically retains point-in-time snapshots. To take a manual export:
```bash
# Export remote database to SQL file
npx wrangler d1 export docflare-db --remote --output=./backups/d1-backup-$(date +%Y%m%d).sql
```

### D1 Database Restoration:
```bash
# Execute SQL backup into target database
npx wrangler d1 execute docflare-db --remote --file=./backups/d1-backup-20261015.sql
```

### R2 Bucket Disaster Recovery:
Enable R2 Object Versioning or Cloudflare R2 Cross-Region Replication for high availability.

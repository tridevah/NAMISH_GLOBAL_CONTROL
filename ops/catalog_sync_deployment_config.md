# GC Catalog Sync Configuration

## Production Environment Variables Required

### ERP (.env)
- GC_WEBHOOK_SECRET: Secure cryptographic token generated natively on the VPS for webhook authentication. (Currently PROVISIONED on production).

### GC Database Roles and Endpoints
- gc_worker_login: Mapped to gc_dispatcher_worker (PROVISIONED).
- integration.webhook_endpoints: Bound to ERP production webhook url.
- integration.topic_subscriptions: Configured for 'catalog.release.published', currently set to PAUSED.

> WARNING: Never commit actual database passwords or webhook secrets into version control.

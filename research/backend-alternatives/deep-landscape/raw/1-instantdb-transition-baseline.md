Source URLs:
- https://www.instantdb.com/essays/instant_team_joins_openai
- https://www.instantdb.com/docs/self-hosting/migrate
- https://www.instantdb.com/docs/backups
- https://www.instantdb.com/docs/self-hosting
- https://www.instantdb.com/docs/backend

# The Instant team joins OpenAI

We have a big announcement to make today: the Instant team is joining OpenAI.

If you are a user of Instant Cloud:
1. New signups are closed. Existing users should migrate off Instant Cloud within the next 12 months. Subscriptions started after July 31st, 2026 will be fully refunded.
2. On August 31st, 2027, all cloud apps will shut down. Backups stay available for 12 more months, until August 31st, 2028.
3. Instant is open source and has a self-hosting and migration guide.

# Migrate from Instant Cloud

Migration has two phases: rehearse by setting up self-hosted Instant and restoring a test backup; then cut over by pausing writes, restoring a fresh backup, and pointing the app at self-hosted Instant.

Self-hosted prerequisites/checks include email provider configuration for magic codes, restricting dashboard signups, disabling temporary apps, webhook configuration, and recreating OAuth providers/callbacks. A restored app should be checked for schema/permissions, application data, files, auth providers/templates. Prepare a client PR with a new UUID app ID and update app ID, API URL, WebSocket URL; Admin SDK users also update app ID, admin token, and apiURI.

For cutover, enable read-only mode and wait 30 seconds for in-flight mutations. Reads/live queries/presence continue, but new writes including queued offline writes are rejected. Create and restore a final on-demand backup; check /health/system returns {"wal":"ok"}; turn read-only off on self-hosted; deploy and verify queries, writes, auth, and uploads. Users may need to sign in again.

# Backups

Instant creates nightly backups and exposes the last 7 days through dashboard or CLI. Commands include `npx instant-cli@latest backup list` and `npx instant-cli@latest backup download --latest`. A backup ZIP contains config.json (schema, rules, magic-code template, counts), NDJSON entity files per table, and raw file blobs. It includes user data such as email addresses and must be stored securely. Restore requires the deployment superuser and the self-hosted dashboard restore page. OAuth client secrets do not carry over and must be updated.

# Self hosting

Instant is fully open source. The docs estimate at least ~$30/month for a side-project VPS and at least ~$600/month for a serious AWS deployment. Operators must configure an email provider; the backend logs email bodies/login codes until configured. Set `INSTANT_SUPERUSER_EMAIL`, restrict dashboard signups, disable unauthenticated temporary app creation, and configure CLI API/dashboard URIs. Health monitoring uses `curl -fsS https://api.myinstant.com/health/system` and expects `{"wal":"ok"}`. Multi-server deployments require shared configuration, server discovery, and Hazelcast/gRPC communication. JVM heap must be bounded separately from OS/container memory.

# Instant on the Backend

`@instantdb/admin` is for non-browser JavaScript contexts and supports async query/transact, subscriptions, schema typing, impersonation, auth, and custom endpoints. An admin token bypasses permission checks and must not be exposed; accidental leakage requires token regeneration. Without an admin token, a client-environment process must use `asUser({token})` or guest mode. Admin SDK server calls are not an offline browser database and are distinct from the browser client SDK.

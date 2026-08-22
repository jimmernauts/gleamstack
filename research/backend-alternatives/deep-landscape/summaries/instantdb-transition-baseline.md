---
cycle: 1
purpose: "Establish the migration baseline: InstantDB shutdown announcement, any official migration/self-hosting/export guidance, and implications for Mealstack's current browser core plus worker/admin usage."
quality: high
tags: [InstantDB, migration, self-hosting]
sources:
  - url: https://www.instantdb.com/essays/instant_team_joins_openai
    title: "The Instant team joins OpenAI"
  - url: https://www.instantdb.com/docs/self-hosting/migrate
    title: "Migrate from Instant Cloud"
  - url: https://www.instantdb.com/docs/backups
    title: "Backups"
  - url: https://www.instantdb.com/docs/self-hosting
    title: "Self hosting"
  - url: https://www.instantdb.com/docs/backend
    title: "Instant on the Backend"
---

## Key Claims
- Instant announced that new signups are closed; existing users should migrate within 12 months, cloud apps shut down on August 31, 2027, and backups remain available until August 31, 2028 (announcement).
- The official migration is a two-phase rehearsal/cutover process: restore a test backup, then pause writes, restore a fresh backup, and repoint clients (migration guide).
- Backups are downloadable ZIPs containing schema/rules/template configuration, per-table JSONL entities, and file blobs; the CLI supports listing and downloading backups (backups guide).
- Instant is open source, but self-hosting transfers operations to the app owner: email, dashboard access, temporary-app controls, health monitoring, scaling, and resource sizing are explicitly documented (self-hosting guide).
- `@instantdb/admin` supports privileged worker/server queries and writes, but admin tokens bypass permission checks and must remain secret; it is not a substitute for browser-local durability (backend guide).

## Technical Detail
The migration guide requires recreating OAuth providers and callback URLs, checking schema, permissions, data, files, auth, and templates after rehearsal, then preparing a client change with a new UUID app ID and updated API/WebSocket URLs. During final cutover, Instant Cloud read-only mode continues reads/live queries/presence but rejects new writes, including queued offline writes. The guide asks operators to wait 30 seconds for in-flight mutations, restore a final backup, verify `/health/system` returns `{"wal":"ok"}`, turn read-only off on the new instance, and deploy. Users may need to authenticate again.

Nightly backups are available for seven days through the dashboard/CLI. The ZIP includes user records (including email addresses), JSONL entities, and raw `$files` blobs, so it is sensitive and needs secure handling. Restores require a deployment superuser; OAuth client secrets do not carry over. This is useful export/restore evidence, but it is a migration artifact rather than a portable browser sync protocol or a user-controlled per-user cloud backup format.

Self-hosting ranges from the documented ~$30/month VPS starting point to at least ~$600/month for a serious AWS setup. The operator must configure an email provider (otherwise codes are logged), restrict dashboard signups, disable unauthenticated temporary apps, configure CLI endpoints, monitor the WAL health endpoint, and provide service discovery and Hazelcast/gRPC communication for multi-server deployments. Worker/admin use remains possible through the JavaScript Admin SDK or HTTP API, but privileged credentials must stay in a protected environment.

## Relevance
This is a viable short-term continuity bridge if preserving Instant semantics matters: self-host and migrate the existing database. It does not satisfy the brief's desired reduction of operational/vendor dependence, user-controlled backup/bootstrap, or browser-local authority by itself. Mealstack's browser core can continue using the client SDK while worker/admin paths are repointed, but the migration's write pause explicitly means offline queued writes must be drained or accepted as rejected during cutover. Multi-user conflict semantics remain inherited from Instant and are not explained by the migration materials.

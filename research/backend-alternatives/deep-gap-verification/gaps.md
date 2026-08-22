---
topic: Mealstack local-first backend gap verification
cycle: 1
date: 2026-08-22
---

# Next-Cycle Brief: Mealstack local-first backend gap verification

## Priority Gaps (focus here next run)

1. **Triplit, Dexie Cloud/plain Dexie, and Replicache decision status** — these named finalists received no evidence, so their current licenses, commercial/hosted boundaries, release health, full-local-data behavior, conflict/delete authority, export, and continuity cannot be compared with the provisional shortlist.
   - Suggested queries: "site:triplit.dev OR site:github.com/aspen-cloud/triplit self host license sync conflict delete export release 2026", "site:dexie.org/cloud pricing limits conflict delete export self host 2026", "site:replicache.dev OR site:rocicorp.dev Replicache supported license pricing BYOB push pull IndexedDB 2026"
   - Source types most likely to help: web / github

2. **iOS installed-PWA durability and execution limits** — every browser candidate depends on local persistence, but the run found no primary platform evidence for IndexedDB/OPFS eviction, persistent-storage grants, service-worker/background limits, multi-tab behavior, or recovery after long suspension.
   - Suggested queries: "site:webkit.org iOS installed web app IndexedDB OPFS storage eviction persistent storage 2026", "site:developer.mozilla.org StorageManager persist eviction IndexedDB OPFS Safari", "site:web.dev OR site:caniuse.com background sync periodic background sync iOS Safari 2026"
   - Source types most likely to help: web

3. **Object-store and Google Drive bespoke-sync feasibility** — no evidence established whether immutable operation segments on R2/Tigris can safely coordinate writes or remain economical, nor whether Google Drive OAuth, changes, revisions, and quotas make low-frequency sync practical. These are intentionally small architecture alternatives and need platform facts separated from application merge logic.
   - Suggested queries: "site:developers.cloudflare.com/r2 consistency conditional put ETag checksum versioning lifecycle pricing operations", "site:tigrisdata.com/docs object storage consistency If-Match ETag versioning lifecycle pricing", "site:developers.google.com/drive/api appDataFolder drive.file changes revisions quota", "site:developers.google.com/identity/oauth2/web token expiration renewal user gesture"
   - Source types most likely to help: web

4. **Backup/restore, licensing, and continuity proofs for the provisional shortlist** — RxDB, PowerSync, Evolu, Fireproof, TinyBase, and Automerge Repo have enough architecture evidence for POCs, but not complete first-party license/commercial continuity records or demonstrated independent export/restore runbooks.
   - Suggested queries: "site:rxdb.info backup export import license replication recovery", "site:docs.powersync.com backup restore export Open Edition license", "site:evolu.dev export backup restore license", "site:use-fireproof.com export backup restore gateway license", "site:tinybase.org save load export merge license", "site:automerge.org save load export backup license repo"
   - Source types most likely to help: web / github

## Do Not Re-Fetch
Topics already well-covered. The next worker should skip these even if results look relevant.
- RxDB's checkpointed pull, assumed-master push, idempotent retry, tombstone, and default conflict-handler semantics.
- CouchDB's divergent revision leaves, deterministic winner, application-managed merge, and compaction behavior.
- PowerSync Web's local SQLite/upload-queue architecture, source-database requirement, VFS choices, hosted pricing, and Docker self-hosting boundary.
- Jazz's OPFS/tab-leader persistence, query-subscription sync, last-writer-wins behavior, and basic self-hosted server modes.
- LiveStore's central event ordering and documented beta status plus missing conflict handling, compaction, and encryption.
- Evolu's stateless Cloudflare-compatible relay and recommendation for a geographically separate secondary relay.
- Fireproof's encrypted immutable content-addressed ledger, CRDT merge, and pluggable gateway architecture.
- TinyBase's IndexedDB and Durable Object SQLite persisters and its role as a toolkit rather than complete sync authority.
- Automerge Repo's IndexedDB/BroadcastChannel/WebSocket adapters, experimental public server warning, WASM requirement, and 2026 reliability-fix release activity.
- CR-SQLite's browser WASM capabilities and the separate persistence/VFS, worker, schema, and sync-server integration burden.

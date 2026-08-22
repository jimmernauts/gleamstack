# Mealstack offline-first InstantDB replacement landscape

## Overview
InstantDB remains usable as a migration bridge, but its cloud closes on August 31, 2027, and self-hosting transfers a substantial operational burden to Mealstack. For the target end state, the evidence supports six distinct architectures: Dexie Cloud, self-hosted Triplit, RxDB with a small coordinator, PouchDB/CouchDB, a CRDT framework with a secured relay, or bespoke SQLite-Wasm plus an operation log; all still need explicit browser-eviction recovery and a separate user-controlled backup/bootstrap path.

## InstantDB transition baseline
InstantDB has closed new signups, asks existing users to migrate within 12 months, will close cloud apps on August 31, 2027, and will retain downloadable backups until August 31, 2028. Its official cutover procedure is to rehearse a restore, pause writes, wait for in-flight mutations, restore a fresh backup, verify WAL health, repoint API/WebSocket endpoints, and resume writes; queued offline writes are rejected during read-only cutover, so Mealstack must deliberately drain or account for them ([announcement](https://www.instantdb.com/essays/instant_team_joins_openai), [migration guide](https://www.instantdb.com/docs/self-hosting/migrate)).

Backups are ZIP archives containing schema, permissions/templates, per-table JSONL, user records, and file blobs. They are useful for migration and archival export, but do not constitute a browser replication protocol or per-user backup format. OAuth secrets do not transfer ([backups](https://www.instantdb.com/docs/backups), [migration guide](https://www.instantdb.com/docs/self-hosting/migrate)).

Self-hosting preserves current client semantics and lets existing `@instantdb/admin` worker paths be repointed, but shifts email, dashboard security, health monitoring, sizing, scaling, service discovery, and multi-node communication to Mealstack. Instant documents roughly $30/month as a small VPS starting point and at least roughly $600/month for a serious AWS setup; admin tokens bypass permissions and must remain server-side ([self-hosting](https://www.instantdb.com/docs/self-hosting), [backend SDK](https://www.instantdb.com/docs/backend)). This makes self-hosted Instant a continuity option rather than a reduction in operational dependence.

Sources: [Instant announcement](https://www.instantdb.com/essays/instant_team_joins_openai), [migration guide](https://www.instantdb.com/docs/self-hosting/migrate), [backups](https://www.instantdb.com/docs/backups), [self-hosting](https://www.instantdb.com/docs/self-hosting), [backend SDK](https://www.instantdb.com/docs/backend)

## IndexedDB-first document databases
**Dexie Cloud** combines IndexedDB-local data with a server-authoritative coordinator, atomic transactions, access realms, conditional operations, and optional Y.js integration. Concurrent updates to different properties can merge; same-property updates use latest operation time. Flat Mealstack records fit this policy if arrays are normalized and field updates use `update()` rather than whole-record replacement. The tradeoff is that hosted Dexie Cloud—not user-controlled object storage—is the normal deployment, while on-prem is a separate commercial offering ([consistency](https://dexie.org/docs/cloud/consistency), [pricing](https://dexie.org/pricing)).

**PouchDB/CouchDB** is self-hostable and retains explicit revision trees: immediate conflicts return 409, while disconnected conflicts preserve competing revisions and expose a deterministic winner until the application resolves them. Deletes remain tombstone revisions. It offers transparent, established document replication but leaves Mealstack responsible for authorization, conflict UX, compaction, and backup/restore operations ([conflicts](https://pouchdb.com/guides/conflicts.html)).

**RxDB** is local-first and can replicate IndexedDB/OPFS data through a custom HTTP or GraphQL backend. Its protocol guidance explicitly requires deterministic checkpoints, retained tombstones, duplicate-safe push handling, retry, and a live stream or periodic resync. Its default conflict handler favors server state, but custom handlers can implement field-level policy. This creates a clean boundary for a small Mealstack coordinator without making cloud storage the browser's authority ([replication](https://rxdb.info/replication.html)).

**Fireproof** claims an embedded browser database, encrypted live sync, CRDT collaboration, content-addressed encrypted blobs, and causal/hash-history integrity. The repository advertises Apache-2.0, but package-level licensing, gateway behavior, and operational continuity were not verified sufficiently for the shortlist ([repository](https://github.com/fireproof-storage/fireproof)).

Sources: [Dexie consistency](https://dexie.org/docs/cloud/consistency), [Dexie pricing](https://dexie.org/pricing), [PouchDB conflicts](https://pouchdb.com/guides/conflicts.html), [RxDB replication](https://rxdb.info/replication.html), [Fireproof repository](https://github.com/fireproof-storage/fireproof)

## CRDT and local-first frameworks
**Automerge Repo** persists documents through an IndexedDB adapter and synchronizes through pluggable network adapters. Production use requires a secured, durable relay because its public sync endpoint is explicitly experimental. CRDT convergence handles concurrent document changes, but Mealstack must still define record indexing, authorization, logical deletion, retention, and export ([storage](https://automerge.org/docs/reference/repositories/storage/), [network sync](https://automerge.org/docs/tutorial/network-sync/)).

**Yjs** persists CRDT updates through `y-indexeddb`, but networking, server retention, room naming, authorization, indexing, garbage collection, and replicated deletion remain application concerns. It is technically more natural for collaborative documents or rich fields than for ordinary flat CRUD records; clearing one local Yjs database is not a replicated delete ([IndexedDB provider](https://docs.yjs.dev/ecosystem/database-provider/y-indexeddb)).

**TinyBase** offers mergeable structured stores, IndexedDB/server persisters, BroadcastChannel and WebSocket synchronizers, custom synchronization, and a Cloudflare Durable Object server pattern. Its example servers do not automatically authenticate or authorize channels, so a Mealstack deployment must secure upgrades and channel access ([synchronizers](https://tinybase.org/guides/synchronization/using-a-synchronizer/)). **Evolu** advertises local SQLite, CRDT history, E2E-encrypted sync/backup, MIT licensing, and a self-hostable relay, but the fetched landing page did not establish browser persistence or object-storage integration in enough detail ([Evolu](https://www.evolu.dev/)).

Jazz, LiveStore, and vlcn/cr-sqlite appeared active in primary repositories, but the evidence gathered did not establish their exact browser persistence, sharing, licensing, sync hosting, and continuity characteristics ([Jazz](https://github.com/garden-co/jazz), [LiveStore](https://www.github.com/livestorejs/livestore), [cr-sqlite](https://github.com/vlcn-io/cr-sqlite)).

Sources: [Automerge storage](https://automerge.org/docs/reference/repositories/storage/), [Automerge network sync](https://automerge.org/docs/tutorial/network-sync/), [Yjs IndexedDB](https://docs.yjs.dev/ecosystem/database-provider/y-indexeddb), [TinyBase synchronizers](https://tinybase.org/guides/synchronization/using-a-synchronizer/), [Evolu](https://www.evolu.dev/), [Jazz](https://github.com/garden-co/jazz), [LiveStore](https://www.github.com/livestorejs/livestore), [cr-sqlite](https://github.com/vlcn-io/cr-sqlite)

## Managed and server-coordinated products
**Triplit** advertises IndexedDB-local operation, offline reconnection, property-level conflict resolution, rollback/retry, server authorization, CRDT collaboration, and Node/Cloudflare server packages. It is close to a complete replacement and appears self-hostable, but AGPL implications, delete/tombstone behavior, backup/export, hosted pricing, and long-term continuity still need direct verification ([repository](https://github.com/aspen-cloud/triplit)).

**PowerSync** provides local SQLite plus queued uploads and remote synchronization, with field-level LWW by default: distinct fields merge and same-field writes use arrival order. Its upload callback leaves authentication, authorization, idempotency, validation, conflict policy, and durable canonical storage in Mealstack's backend, so it is a coordinator component rather than a user-controlled backup solution ([custom conflict resolution](https://docs.powersync.com/handling-writes/custom-conflict-resolution)).

**Electric/PGlite** and **Zero** do not currently meet the required offline-write model. PGlite's Electric sync plugin is alpha and one-way, with no local-write upload or conflict resolution; Zero is generally available as of March 2026 but explicitly rejects offline writes and describes itself as authoritative client-server ([PGlite sync](https://pglite.dev/docs/sync), [Zero status](https://zero.rocicorp.dev/docs/status), [Zero suitability](https://zero.rocicorp.dev/docs/when-to-use)). Replicache's current support and hosting status was not established.

Sources: [Triplit repository](https://github.com/aspen-cloud/triplit), [PGlite sync](https://pglite.dev/docs/sync), [PowerSync conflict resolution](https://docs.powersync.com/handling-writes/custom-conflict-resolution), [Zero status](https://zero.rocicorp.dev/docs/status), [Zero suitability](https://zero.rocicorp.dev/docs/when-to-use)

## Mainstream comparison baselines
Firestore Web can persist a cache in IndexedDB, coordinate multiple tabs, serve cached reads, apply latency-compensated local writes/deletes, and queue persisted batches. Persistence can fail in unsupported browser/tab configurations, and write completion still means remote acknowledgement. This is an offline-capable cloud cache with separately billed operations, backup, PITR, and restore—not a portable local authority or user-selected storage substrate ([JavaScript API](https://firebase.google.com/docs/reference/js/firestore_), [IndexedDB implementation](https://github.com/firebase/firebase-js-sdk/blob/main/packages/firestore/src/local/indexeddb_persistence.ts), [pricing](https://cloud.google.com/firestore/pricing)).

Supabase supplies hosted Postgres, auth, storage, realtime, and plan-based backups, but `supabase-js` does not itself provide browser-local authority and conflict replication. Paid plans retain daily backups for 7, 14, or 30 days; free projects are directed to `supabase db dump`, and restores incur downtime. It can be a canonical backend beneath RxDB, PowerSync, or bespoke sync, not the complete offline-first layer ([pricing](https://supabase.com/pricing), [backups](https://supabase.com/docs/guides/platform/backups)).

Sources: [Firestore API](https://firebase.google.com/docs/reference/js/firestore_), [Firestore IndexedDB source](https://github.com/firebase/firebase-js-sdk/blob/main/packages/firestore/src/local/indexeddb_persistence.ts), [Firestore pricing](https://cloud.google.com/firestore/pricing), [Supabase pricing](https://supabase.com/pricing), [Supabase backups](https://supabase.com/docs/guides/platform/backups)

## Bespoke local database and operation log
SQLite-Wasm can make a Worker-owned OPFS database the local SQL authority, but standard OPFS needs appropriate browser support and headers, is Worker-only, can encounter cross-tab locks, and is still subject to quota and eviction. Safari versions below 17 cannot use the standard VFS. A single database-owning Worker with tab communication reduces lock contention, but export/import and remote recovery remain mandatory ([SQLite-Wasm](https://github.com/sqlite/sqlite-wasm), [persistence options](https://sqlite.org/wasm/doc/trunk/persistence.md)).

A proportionate bespoke design is current-state tables plus an atomically written operation table, rather than full event sourcing. Operations need unique IDs, device and entity IDs, schema version, field patch/intent, ordering timestamp, and integrity hash; deletes need retained tombstones. The coordinator must deduplicate retries, return authoritative operations, and compact only after replica watermarks permit it. Snapshots speed replay but do not replace an immutable log, while schema evolution, idempotency, privacy deletion, archival, and repair add real complexity ([AWS event sourcing](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/event-sourcing-pattern.html), [Azure event sourcing](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing)). The detailed Mealstack record format and compaction protocol are design inferences from these constraints, not prescriptions in those sources.

For flat records, per-field LWW can preserve independent edits; sets/sequences need explicit operations or a CRDT, and cross-record invariants need coordinator validation. Full event sourcing has weak proportionality unless audit/time travel is itself a requirement, because Microsoft explicitly cautions against its complexity for straightforward CRUD ([Azure event sourcing](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing)).

Sources: [SQLite-Wasm](https://github.com/sqlite/sqlite-wasm), [SQLite persistence](https://sqlite.org/wasm/doc/trunk/persistence.md), [AWS event sourcing](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/event-sourcing-pattern.html), [Azure event sourcing](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing)

## User-controlled cloud backup and bootstrap
Google Drive's hidden `appDataFolder` can hold an app-private encrypted snapshot/oplog bundle under the `drive.appdata` OAuth scope. Its change feed offers page-token-based chronological detection and watch notifications, but notifications merely indicate that changes exist. App uninstall or manual deletion can remove the folder, and its files cannot be shared, moved, or trashed, so it should not be the only recovery path ([app data](https://developers.google.com/workspace/drive/api/guides/appdata), [changes](https://developers.google.com/workspace/drive/api/guides/manage-changes)).

S3, R2, and Tigris can store immutable snapshot/log generations uploaded through short-lived presigned URLs without exposing signing credentials. These URLs are bearer tokens; CORS and object keys must be narrowly scoped. S3 Versioning retains complete object versions and delete markers, while lifecycle rules are needed to control noncurrent-version cost. R2 supports 1-second to 7-day presigned URLs and Tigris documents up to 90 days ([S3 presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html), [S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html), [R2](https://developers.cloudflare.com/r2/api/s3/presigned-urls/), [Tigris](https://www.tigrisdata.com/docs/objects/presigned/)).

None of these stores supplies record-level ordering, conflict resolution, identity, authorization, tombstone retention, or convergence. A coordinator must serialize or conditionally update a latest-generation manifest and issue scoped upload/download access. This is why object storage fits backup/bootstrap—or durable log storage behind a coordinator—but not standalone cross-device sync.

Sources: [Drive app data](https://developers.google.com/workspace/drive/api/guides/appdata), [Drive changes](https://developers.google.com/workspace/drive/api/guides/manage-changes), [S3 presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html), [S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html), [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/), [Tigris presigned URLs](https://www.tigrisdata.com/docs/objects/presigned/)

## Cloudflare coordinator and web-platform constraints
A Durable Object is a globally named, single-threaded actor with transactional, strongly consistent private storage, making a per-user or per-dataset object a natural operation-ordering and WebSocket fanout point. Hibernation preserves connections but discards in-memory state, so identity and synchronization state must be recoverable from durable storage or serialized attachments. SQLite-backed objects have a 10 GB per-object limit and soft 1,000 requests/second/object limit, among other message and CPU constraints ([concepts](https://developers.cloudflare.com/durable-objects/concepts/what-are-durable-objects/), [WebSockets](https://developers.cloudflare.com/durable-objects/best-practices/websockets/), [limits](https://developers.cloudflare.com/durable-objects/platform/limits/)). A Worker-authenticated Durable Object plus R2/Tigris snapshot publication is an architectural inference from those capabilities, not a packaged sync product.

All browser-local choices share a durability caveat: IndexedDB and OPFS are best-effort by default. `navigator.storage.persist()` can request stronger protection, but browser approval varies; Safari may proactively remove inactive script-created data after seven days. Background Sync is also not universally supported, so Mealstack must retry its outbox when launched, made visible, or brought online, and must provide encrypted export/bootstrap and quota-failure recovery ([storage quotas](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria), [`persist()`](https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist), [Background Sync](https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API)). Thus “durable local data” cannot be an absolute browser guarantee.

Sources: [Durable Objects WebSockets](https://developers.cloudflare.com/durable-objects/best-practices/websockets/), [Durable Objects concepts](https://developers.cloudflare.com/durable-objects/concepts/what-are-durable-objects/), [Durable Objects limits](https://developers.cloudflare.com/durable-objects/platform/limits/), [MDN quotas and eviction](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria), [MDN `persist()`](https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist), [MDN Background Sync](https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API)

## Decision shortlist: six viable architectures

| Architecture | Local authority and convergence | Operations / dependence | User-controlled backup fit | Principal caveat |
|---|---|---|---|---|
| **Dexie + Dexie Cloud** | IndexedDB-first; conditional operations; field merge and same-field latest-operation policy | Low custom sync work; hosted service or commercial on-prem | Add encrypted Drive/S3-compatible exports separately | Storage/control is not user-controlled by default |
| **Triplit self-hosted** | IndexedDB client; advertised property-level conflicts and CRDT collaboration | Integrated server/auth model; Cloudflare/Node packages | Add snapshot/export path after verifying APIs | AGPL, delete/export semantics, pricing, and continuity need verification |
| **RxDB + Worker/Durable Object + R2/Drive** | IndexedDB/OPFS authority; custom checkpoints, tombstones, and field policy | Moderate custom protocol; serverless coordinator dependence | Direct fit for encrypted immutable bundles | Mealstack owns auth, conflict policy, compaction, and repair tooling |
| **PouchDB + CouchDB** | Local document authority; explicit revision conflicts and tombstones | Self-hosted database operations and conflict UX | Standard server backups plus per-user encrypted export | Revision-tree conflict and compaction complexity |
| **Automerge Repo or TinyBase + secured relay** | CRDT/mergeable local state and deterministic convergence | Custom relay, authz, indexing, lifecycle, and retention | Snapshot/update bundles can be exported | More collaboration machinery and modeling than flat CRUD may need |
| **SQLite-Wasm + bespoke oplog + Durable Object** | Full local SQL authority; explicitly selected field-LWW/operation semantics | Highest engineering ownership; low database-product dependence | Natural manifest/snapshot/log generations in Drive/R2/Tigris | Browser OPFS caveats and sync/security/repair become product code |

These are architectural options rather than interchangeable libraries. Dexie Cloud and Triplit reduce custom synchronization; RxDB and PouchDB expose more protocol or conflict control; CRDT frameworks emphasize concurrent convergence; SQLite-Wasm plus an oplog maximizes control at the cost of engineering surface. PowerSync remains a credible variant when a separate canonical backend is already desired, while self-hosted Instant is a time-bounded migration bridge rather than the intended end state.

For every option, multi-user sharing requires explicit authorization and membership semantics. CRDT convergence does not authorize edits, object storage does not order them, and field-level LWW can silently choose a same-field winner; Mealstack should expose conflicts where semantic loss matters and use coordinator validation for cross-record invariants.

Sources: [Dexie consistency](https://dexie.org/docs/cloud/consistency), [Triplit](https://github.com/aspen-cloud/triplit), [RxDB replication](https://rxdb.info/replication.html), [PouchDB conflicts](https://pouchdb.com/guides/conflicts.html), [Automerge sync](https://automerge.org/docs/tutorial/network-sync/), [TinyBase synchronization](https://tinybase.org/guides/synchronization/using-a-synchronizer/), [SQLite persistence](https://sqlite.org/wasm/doc/trunk/persistence.md), [Durable Objects](https://developers.cloudflare.com/durable-objects/concepts/what-are-durable-objects/)

## NOT FOUND
- Current Replicache product availability, support, pricing, and self-hosting position; it was queried but no adequate current primary source was captured.
- Package-level Fireproof licensing, exact gateway/storage adapters, hosted-service continuity, and production operational model.
- Definitive browser storage, relay hosting, sharing, licensing, and maintenance evidence for Jazz, LiveStore, and vlcn/cr-sqlite; only repository-level signals were captured.
- Detailed browser persistence and object-storage integration for Evolu.
- Directly verified Triplit hosted pricing, license obligations, delete/tombstone semantics, backup/export format, and multi-user sharing behavior.
- InstantDB's detailed concurrent-write and delete convergence semantics; migration materials cover cutover, not conflict behavior.
- A primary-source, installed-iOS-PWA compatibility matrix covering IndexedDB/OPFS persistence, eviction, private mode, quota, and Background Sync across current Safari versions.

## All Sources
- [The Instant team joins OpenAI](https://www.instantdb.com/essays/instant_team_joins_openai)
- [InstantDB: Migrate from Instant Cloud](https://www.instantdb.com/docs/self-hosting/migrate)
- [InstantDB Backups](https://www.instantdb.com/docs/backups)
- [InstantDB Self hosting](https://www.instantdb.com/docs/self-hosting)
- [Instant on the Backend](https://www.instantdb.com/docs/backend)
- [Consistency in Dexie Cloud](https://dexie.org/docs/cloud/consistency)
- [Dexie Cloud Pricing](https://dexie.org/pricing)
- [PouchDB Conflicts](https://pouchdb.com/guides/conflicts.html)
- [RxDB realtime Sync Engine](https://rxdb.info/replication.html)
- [Fireproof repository](https://github.com/fireproof-storage/fireproof)
- [Automerge Repo Storage](https://automerge.org/docs/reference/repositories/storage/)
- [Automerge Network Sync](https://automerge.org/docs/tutorial/network-sync/)
- [Yjs IndexedDB provider](https://docs.yjs.dev/ecosystem/database-provider/y-indexeddb)
- [TinyBase Synchronizers](https://tinybase.org/guides/synchronization/using-a-synchronizer/)
- [Evolu](https://www.evolu.dev/)
- [Jazz repository](https://github.com/garden-co/jazz)
- [LiveStore repository](https://www.github.com/livestorejs/livestore)
- [cr-sqlite repository](https://github.com/vlcn-io/cr-sqlite)
- [Triplit repository](https://github.com/aspen-cloud/triplit)
- [Sync using Electric/PGlite](https://pglite.dev/docs/sync)
- [PowerSync Custom Conflict Resolution](https://docs.powersync.com/handling-writes/custom-conflict-resolution)
- [Zero Project Status](https://zero.rocicorp.dev/docs/status)
- [When To Use Zero](https://zero.rocicorp.dev/docs/when-to-use)
- [Firestore JavaScript API](https://firebase.google.com/docs/reference/js/firestore_)
- [Firestore IndexedDB persistence source](https://github.com/firebase/firebase-js-sdk/blob/main/packages/firestore/src/local/indexeddb_persistence.ts)
- [Firestore pricing](https://cloud.google.com/firestore/pricing)
- [Supabase pricing](https://supabase.com/pricing)
- [Supabase database backups](https://supabase.com/docs/guides/platform/backups)
- [SQLite Wasm](https://github.com/sqlite/sqlite-wasm)
- [SQLite Wasm Persistent Storage Options](https://sqlite.org/wasm/doc/trunk/persistence.md)
- [AWS Event sourcing pattern](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/event-sourcing-pattern.html)
- [Azure Event Sourcing Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing)
- [Google Drive application data folder](https://developers.google.com/workspace/drive/api/guides/appdata)
- [Google Drive retrieve changes](https://developers.google.com/workspace/drive/api/guides/manage-changes)
- [Amazon S3 presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html)
- [Amazon S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [Cloudflare R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)
- [Tigris presigned URLs](https://www.tigrisdata.com/docs/objects/presigned/)
- [Durable Objects WebSockets](https://developers.cloudflare.com/durable-objects/best-practices/websockets/)
- [What are Durable Objects?](https://developers.cloudflare.com/durable-objects/concepts/what-are-durable-objects/)
- [Durable Objects limits](https://developers.cloudflare.com/durable-objects/platform/limits/)
- [MDN storage quotas and eviction](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria)
- [MDN StorageManager.persist](https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist)
- [MDN Background Synchronization API](https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API)

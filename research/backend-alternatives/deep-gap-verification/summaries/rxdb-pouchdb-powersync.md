---
cycle: 2
purpose: "Verify RxDB, PouchDB/CouchDB, and PowerSync Web against the required offline/full-dataset model, free versus paid or hosted boundaries, persistence and replication semantics, Cloudflare feasibility, operational health, and backup/export."
quality: high
tags: [rxdb, pouchdb, couchdb, powersync, offline, replication]
sources:
  - url: https://rxdb.info/premium/
    title: "RxDB for Professionals"
  - url: https://rxdb.info/rx-storage-indexeddb.html
    title: "Instant Performance with IndexedDB RxStorage"
  - url: https://rxdb.info/replication.html
    title: "RxDB realtime Sync Engine"
  - url: https://docs.couchdb.org/en/latest/replication/conflicts.html
    title: "CouchDB replication and conflict model"
  - url: https://docs.powersync.com/client-sdks/reference/javascript-web
    title: "PowerSync JavaScript Web SDK"
  - url: https://powersync.com/pricing
    title: "PowerSync Pricing"
  - url: https://docs.powersync.com/intro/self-hosting
    title: "PowerSync Self-Hosting"
---

## Key Claims
- RxDB's free open-source core includes replication/realtime sync and default Dexie, Memory, and LokiJS storage, but its IndexedDB, OPFS, SQLite, filesystem, encryption, and performance plugins are Premium; Premium access requires an annual signed license and has no free trial or monthly plan ([RxDB for Professionals](https://rxdb.info/premium/)).
- RxDB supports arbitrary HTTP/GraphQL/custom backends. Its protocol requires checkpointed pull, optimistic push with assumed-master state, optional streaming, idempotent retries, and tombstones rather than physical deletes ([RxDB Sync Engine](https://rxdb.info/replication.html)).
- RxDB's default conflict handler discards the fork in favor of the master; custom handlers are available. This is a documented policy choice, not a field-level merge guarantee ([RxDB Sync Engine](https://rxdb.info/replication.html)).
- CouchDB/PouchDB-style replication preserves divergent revisions and selects a deterministic winner for ordinary reads. Applications must inspect conflicts, merge application data, and delete losing leaves; compaction removes old bodies but retains revision metadata ([CouchDB conflict model](https://docs.couchdb.org/en/latest/replication/conflicts.html)).
- PowerSync Web gives local SQLite reads/writes and an upload queue, but requires a source database, sync service configuration, auth credential callback, and application-defined uploadData backend. It is not a standalone browser-to-object-store sync layer ([PowerSync Web SDK](https://docs.powersync.com/client-sdks/reference/javascript-web)).
- PowerSync Web offers IndexedDB and OPFS VFS choices, with OPFSCoopSyncVFS documented for Safari/iOS multi-tab support. Its free hosted tier has soft limits and deactivates inactive projects; production Pro starts at $49/month. Self-hosting is Docker/Open Edition, with dashboard/support boundaries ([PowerSync Web SDK](https://docs.powersync.com/client-sdks/reference/javascript-web); [pricing](https://powersync.com/pricing); [self-hosting](https://docs.powersync.com/intro/self-hosting)).

## Technical Detail
RxDB is the most directly adaptable of the three when the team is willing to implement a small backend. The sync contract is explicit: pull returns documents after a deterministic checkpoint; push receives assumed master and fork states and returns conflicts; deleted documents remain represented as tombstones. The backend can be a Worker endpoint backed by another store, but it must supply ordering, conditional authority, durable tombstones, idempotency, and a recovery/export path. RxDB's browser default is based on Dexie; the separately licensed IndexedDB plugin is presented as optimized for browser use, with OPFS recommended for larger datasets.

CouchDB's semantics are robust but expose application work rather than hiding it. Two offline edits to one JSON document become divergent revision leaves. A deterministic winner can make one edit appear absent until the application merges the revisions. A full-data PWA therefore needs explicit conflict inspection and a merge policy, plus tombstone retention and compaction/revision-history policy. HTTP replication and CORS/auth are feasible on Cloudflare only with a separately operated Couch-compatible service; the sources do not establish a native R2/Worker CouchDB deployment.

PowerSync is a stronger integrated SQLite/offline option than a bespoke protocol, but it is architecturally heavier and partial-sync oriented. Its browser path is local SQLite in a worker, and writes go to an upload queue whose server-side application must apply mutations to the source database. The hosted free tier is not a continuity guarantee because inactive projects deactivate. Self-hosting avoids that hosted boundary but adds Docker operations and removes the dashboard. The sources do not establish a simple full-dataset Cloudflare/R2-only deployment.

## Relevance
RxDB is a plausible finalist for a custom Worker sync endpoint if the POC proves tombstones, conditional push, retries, and export/restore. PouchDB/CouchDB is technically complete but conflict-visible and operationally larger. PowerSync is feasible if accepting a database/source-service architecture and paid/operational boundaries; it should not be treated as a minimal R2 transport. Backup/export details for all three still require a targeted POC or additional source verification.

# Mealstack local-first backend gap verification

## Overview
The useful evidence covers RxDB/PouchDB/PowerSync, four newer CRDT/event frameworks, and TinyBase/Automerge Repo/CR-SQLite; five of eight cycles produced no evidence because all configured search providers failed before returning URLs. The strongest provisional architecture shapes are an RxDB custom backend, PowerSync with a real source database, Evolu, Fireproof, TinyBase with a Durable Object, and Automerge Repo, but none is decision-ready because browser/iOS durability and backup/restore were not verified. Triplit, Dexie Cloud/plain Dexie, Replicache, object-store-only sync, and Google Drive transport remain unassessed rather than excluded.

## Integrated and minimally bespoke options: Triplit and Dexie
No useful findings were produced. Searches intended to verify Triplit self-hosting/AGPL/release health and Dexie Cloud/plain Dexie licensing, pricing, sync, conflict/delete authority, Cloudflare/auth, export, and continuity all failed before any source URL was returned. These options therefore cannot be shortlisted or excluded from this run.

Sources: none.

## RxDB, PouchDB/CouchDB, and PowerSync
RxDB's open-source core includes replication and default Dexie, Memory, and LokiJS storage, while optimized IndexedDB, OPFS, SQLite, filesystem, encryption, and performance plugins are Premium under an annual signed license with no monthly plan or free trial ([RxDB for Professionals](https://rxdb.info/premium/)). Its backend-neutral protocol is explicit: checkpointed deterministic pulls, optimistic pushes carrying assumed-master state, idempotent retries, optional streaming, and tombstones instead of physical deletion. Its default conflict handler accepts the master over the fork; field-level merge requires application logic ([RxDB Sync Engine](https://rxdb.info/replication.html)). This makes RxDB plus a Worker/backend plausible, but the backend must still provide ordering, conditional authority, durable tombstones, recovery, and export.

PouchDB/CouchDB replication retains divergent revision leaves and chooses a deterministic winner for normal reads. Applications must inspect and merge conflicts, delete losing leaves, and manage compaction/tombstone policy; compaction removes old bodies but retains revision metadata ([CouchDB conflict model](https://docs.couchdb.org/en/latest/replication/conflicts.html)). It is technically capable but operationally larger, and the evidence does not establish a native Worker/R2 CouchDB deployment.

PowerSync Web supplies local SQLite reads/writes plus an upload queue, but it requires a source database, sync service, authentication callback, and an application-defined `uploadData` backend; it is not browser-to-object-store sync ([PowerSync JavaScript Web SDK](https://docs.powersync.com/client-sdks/reference/javascript-web)). It supports IndexedDB and OPFS VFS choices, including an OPFSCoopSyncVFS documented for Safari/iOS multi-tab use ([PowerSync JavaScript Web SDK](https://docs.powersync.com/client-sdks/reference/javascript-web)). Hosted production Pro starts at $49/month, while free hosted projects have soft limits and inactivity deactivation; Docker/Open Edition self-hosting removes the hosted dependency but adds operations and lacks some hosted dashboard/support boundaries ([PowerSync pricing](https://powersync.com/pricing); [PowerSync self-hosting](https://docs.powersync.com/intro/self-hosting)).

Sources: [RxDB premium](https://rxdb.info/premium/), [RxDB IndexedDB storage](https://rxdb.info/rx-storage-indexeddb.html), [RxDB replication](https://rxdb.info/replication.html), [CouchDB conflicts](https://docs.couchdb.org/en/latest/replication/conflicts.html), [PowerSync Web SDK](https://docs.powersync.com/client-sdks/reference/javascript-web), [PowerSync pricing](https://powersync.com/pricing), [PowerSync self-hosting](https://docs.powersync.com/intro/self-hosting).

## Jazz, LiveStore, Evolu, and Fireproof
Jazz persists browser data through an OPFS worker with tab leadership, continues reads/writes offline, and syncs query subscriptions rather than necessarily maintaining a complete local database. Concurrent writes to the same field use last-writer-wins while losing row versions remain in history ([Jazz sync](https://jazz.tools/docs/concepts/how-sync-works)). Its self-hosted server supports persistent files, authentication modes, and upstream edge mode; its in-memory mode loses data on exit, and unclaimed generated hosted apps are deleted after 14 days ([Jazz server setup](https://jazz.tools/docs/getting-started/server-setup)). Jazz is conditional on proving that subscriptions can maintain and restore Mealstack's complete dataset.

LiveStore uses event sourcing and a central backend as the authority for total event order. That backend must expose ordered cursor reads plus notifications or polling, but conflict handling, compaction, and encryption are explicitly not implemented ([LiveStore syncing](https://docs.livestore.dev/reference/syncing/)). The project labels itself beta, says it is not ready for every production scenario, and may change client/backend storage formats in minor releases ([LiveStore state of the project](https://docs.livestore.dev/misc/state-of-the-project/)). Those are direct production exclusions unless a tightly constrained proof shows the missing behavior is irrelevant.

Evolu offers a stateless, self-hostable relay that can run on Cloudflare Workers and recommends a geographically separate secondary relay; the free relay is for testing, not a hosting commitment ([Evolu Relay](https://www.evolu.dev/docs/relay)). This is promising for encrypted, redundant sync, but the available evidence does not prove browser persistence durability or independent export/restore.

Fireproof uses encrypted immutable content-addressed ledger files, offline queues, CRDT merging, and pluggable gateways. Fireproof Cloud combines Cloudflare data storage with Supabase metadata, while custom gateways can target other servers or serverless functions ([Fireproof sync](https://use-fireproof.com/docs/architecture/sync)). Its metadata/gateway protocol adds components, and no complete independent backup/restore runbook was found.

Search evidence identifies `cojson` as MIT licensed and LiveStore as Apache-2.0 licensed, but the fetched technical pages do not establish full commercial support or continuity terms ([cojson package](https://www.npmjs.com/package/cojson); [LiveStore repository](https://github.com/livestorejs/livestore)).

Sources: [Jazz sync](https://jazz.tools/docs/concepts/how-sync-works), [Jazz server setup](https://jazz.tools/docs/getting-started/server-setup), [LiveStore syncing](https://docs.livestore.dev/reference/syncing/), [LiveStore project state](https://docs.livestore.dev/misc/state-of-the-project/), [Evolu Relay](https://www.evolu.dev/docs/relay), [Fireproof sync](https://use-fireproof.com/docs/architecture/sync), [cojson package](https://www.npmjs.com/package/cojson), [LiveStore repository](https://github.com/livestorejs/livestore).

## TinyBase, Automerge Repo, and CR-SQLite
TinyBase provides browser IndexedDB persistence plus adapters for SQLite, Cloudflare Durable Objects, WebSockets, remote storage, PartyKit, PowerSync, and CR-SQLite WASM ([TinyBase IndexedDB persister](https://tinybase.org/api/persister-indexed-db/); [TinyBase persisters](https://tinybase.org/api/persisters/)). It can persist directly to Durable Object SQLite, with the required `new_sqlite_classes` migration configuration ([TinyBase Durable Object SQLite](https://tinybase.org/api/persister-durable-object-sql-storage/)). It is a composable toolkit, not a complete sync authority: Mealstack would own transport selection, authentication, merge/conflict rules, and backup.

Automerge Repo provides document CRDTs, IndexedDB storage, BroadcastChannel and WebSocket adapters, and self-hosted sync servers; its public sync server is explicitly experimental with no reliability or data-safety guarantee ([Automerge network sync](https://automerge.org/docs/tutorial/network-sync/)). Browser deployment requires WebAssembly setup ([Automerge initialization](https://automerge.org/docs/reference/library-initialization/)). Its 2026 release stream includes alpha versions and fixes for IndexedDB transaction failures, shutdown/flush, sync state, and network errors, showing active work but also a changing reliability surface ([Automerge Repo releases](https://github.com/automerge/automerge-repo/releases)).

CR-SQLite provides mergeable SQLite in WASM on browser main threads and workers, with transactions and update hooks. Its starter includes a SPA, schema, and sync server, but persistence/VFS, deployment, worker coordination, and schema management remain separate integration choices ([CR-SQLite WASM](https://vlcn.io/docs/cr-sqlite/js/wasm); [CR-SQLite first app](https://vlcn.io/docs/cr-sqlite/js/first-app)). This may be disproportionate for a small single-household dataset unless relational querying and multi-device merging justify the complexity. Search evidence identifies Automerge Repo and CR-SQLite as MIT licensed, but the fetched pages do not prove built-in E2EE, managed backup, or continuity guarantees.

Sources: [TinyBase IndexedDB persister](https://tinybase.org/api/persister-indexed-db/), [TinyBase persisters](https://tinybase.org/api/persisters/), [TinyBase Durable Object SQLite](https://tinybase.org/api/persister-durable-object-sql-storage/), [Automerge initialization](https://automerge.org/docs/reference/library-initialization/), [Automerge network sync](https://automerge.org/docs/tutorial/network-sync/), [Automerge Repo releases](https://github.com/automerge/automerge-repo/releases), [CR-SQLite WASM](https://vlcn.io/docs/cr-sqlite/js/wasm), [CR-SQLite first app](https://vlcn.io/docs/cr-sqlite/js/first-app).

## Replicache status
No useful findings were produced. Current availability after Zero GA, support, licensing, pricing, IndexedDB persistence, offline mutation behavior, and BYOB push/pull endpoint status all remain unverified. Replicache must not be excluded or selected based on this run.

Sources: none.

## Plain Dexie with immutable operations on R2 or Tigris
No useful findings were produced. The cycle did not establish R2/Tigris consistency, conditional writes, checksums, versioning, lifecycle rules, request pricing, or whether a transactional outbox plus immutable operation segments can be correct without a conventional database. This design remains an open architecture and POC, not a verified low-cost finalist.

Sources: none.

## Google Drive as sync and backup transport
No useful findings were produced. The distinctions among `appDataFolder`, user-visible `drive.file` storage, browser OAuth renewal/user-gesture constraints, Changes API behavior, revisions, quotas, and application-managed merge/tombstone semantics remain open. Google Drive's platform APIs must not be assumed to provide application sync semantics.

Sources: none.

## Browser and iOS PWA storage risks
No primary WebKit/MDN/standards evidence was obtained for installed-PWA IndexedDB/OPFS durability, eviction, persistent-storage grants, background/service-worker limits, cross-tab coordination, foreground recovery, or SQLite-WASM proportionality. Framework-specific claims—such as Jazz's OPFS worker and PowerSync's Safari/iOS multi-tab VFS—describe their implementations but do not resolve platform-level durability or eviction risk ([Jazz sync](https://jazz.tools/docs/concepts/how-sync-works); [PowerSync JavaScript Web SDK](https://docs.powersync.com/client-sdks/reference/javascript-web)). Device testing remains mandatory.

Sources: [Jazz sync](https://jazz.tools/docs/concepts/how-sync-works), [PowerSync Web SDK](https://docs.powersync.com/client-sdks/reference/javascript-web).

## Provisional architecture shortlist and exclusions
This is a POC shortlist, not a universal recommendation:

1. **RxDB with a small authoritative backend** — explicit checkpoint/push/tombstone protocol and default Dexie storage; prove conditional authority, retries, export/restore, and whether free storage performance is adequate ([RxDB replication](https://rxdb.info/replication.html); [RxDB premium](https://rxdb.info/premium/)).
2. **PowerSync with a source database** — integrated local SQLite and upload queue; accept a heavier database/sync-service architecture and test full-dataset behavior, operating cost, and self-hosting ([PowerSync Web SDK](https://docs.powersync.com/client-sdks/reference/javascript-web); [PowerSync pricing](https://powersync.com/pricing)).
3. **Evolu with primary and secondary relays** — stateless Worker-compatible relay and explicit relay redundancy; prove persistence and independent export/restore ([Evolu Relay](https://www.evolu.dev/docs/relay)).
4. **Fireproof with a controlled gateway** — encrypted immutable ledger and CRDT merge fit the data shape; prove metadata independence and full backup/restore ([Fireproof sync](https://use-fireproof.com/docs/architecture/sync)).
5. **TinyBase plus Durable Object SQLite** — direct Cloudflare fit and low-level control; application must implement sync authority, auth, merge, and backup ([TinyBase Durable Object SQLite](https://tinybase.org/api/persister-durable-object-sql-storage/)).
6. **Automerge Repo with a self-hosted server** — complete document CRDT path with IndexedDB; avoid the experimental public server and prove WASM/iOS reliability and export ([Automerge network sync](https://automerge.org/docs/tutorial/network-sync/); [Automerge Repo releases](https://github.com/automerge/automerge-repo/releases)).

Conditional/excluded from this shortlist:
- **Jazz** is conditional because query-subscription sync does not itself prove a complete local replica ([Jazz sync](https://jazz.tools/docs/concepts/how-sync-works)).
- **LiveStore** is excluded for now because it is beta and lacks implemented conflict handling, compaction, and encryption ([LiveStore syncing](https://docs.livestore.dev/reference/syncing/); [project state](https://docs.livestore.dev/misc/state-of-the-project/)).
- **PouchDB/CouchDB** is excluded from the small shortlist due to application-visible revision conflicts and the need to operate a Couch-compatible service, though it remains technically viable ([CouchDB conflicts](https://docs.couchdb.org/en/latest/replication/conflicts.html)).
- **CR-SQLite** is excluded provisionally as higher integration complexity than the dataset appears to require; this is an inference, not a documented limitation ([CR-SQLite WASM](https://vlcn.io/docs/cr-sqlite/js/wasm)).
- **Triplit, Dexie Cloud/plain Dexie, Replicache, R2/Tigris bespoke sync, and Google Drive sync** are unassessed, not evidence-based exclusions, because their cycles returned no sources.

## Cross-cutting risk register and falsifiable POCs
- **Complete local data:** after a fresh install and full sync, disconnect and verify every household record/query is available. This is especially important for Jazz's subscription model ([Jazz sync](https://jazz.tools/docs/concepts/how-sync-works)).
- **Conflict/delete correctness:** make concurrent same-record edits and deletes on two offline devices, reconnect in both orders, and assert a documented deterministic result plus durable tombstones/history. RxDB and CouchDB expose materially different conflict models ([RxDB replication](https://rxdb.info/replication.html); [CouchDB conflicts](https://docs.couchdb.org/en/latest/replication/conflicts.html)).
- **Crash/idempotency:** interrupt upload after server commit but before acknowledgement, retry, and prove no duplicate operation or lost mutation. RxDB explicitly requires idempotent retries ([RxDB replication](https://rxdb.info/replication.html)).
- **Continuity/export:** destroy the hosted relay/server and restore a new deployment solely from an independently stored export; verify byte-level or logical data equivalence. No candidate has a verified end-to-end runbook in this evidence set.
- **iOS durability:** test installed-PWA cold starts, storage pressure, device reboot, multi-tab operation, long suspension, and foreground resumption on real iOS hardware. The platform-level evidence cycle failed, so implementation-specific storage claims are insufficient.
- **Operational loss:** for multi-relay/gateway candidates, remove the primary service and verify continued writes and later convergence. Evolu explicitly recommends a separate secondary relay ([Evolu Relay](https://www.evolu.dev/docs/relay)).

## NOT FOUND
- **Triplit:** current releases, AGPL/commercial boundaries, self-hosting, full-data behavior, auth, conflicts/deletes, export, Cloudflare deployment, and continuity.
- **Dexie Cloud/plain Dexie:** pricing, sync limits and authority, conflicts/deletes, export, self-hosting/commercial boundaries, and suitability as the basis of bespoke sync.
- **Replicache:** post-Zero availability/support, current license/pricing, persistence, offline mutations, and BYOB push/pull status.
- **R2/Tigris bespoke sync:** consistency, conditional writes, checksums, versioning, lifecycle, request costs, and correctness/economics of immutable operation segments.
- **Google Drive transport:** `appDataFolder` versus visible files, GIS OAuth renewal, Changes API, revisions, quotas, and merge/tombstone responsibilities.
- **Browser/iOS:** IndexedDB/OPFS eviction and durability, persistent-storage behavior, background limits, cross-tab semantics, foreground recovery, and SQLite-WASM proportionality.
- **Across otherwise covered candidates:** complete first-party license/commercial continuity evidence and demonstrated backup/export/restore procedures remain incomplete.

For each failed cycle, planned Exa searches returned HTTP 429 rate-limit errors; Gemini retries lacked an API key/browser login, and Perplexity retries lacked an API key. Because no search result URL was obtained, no pages were fetched.

## All Sources
- [RxDB for Professionals](https://rxdb.info/premium/)
- [RxDB IndexedDB RxStorage](https://rxdb.info/rx-storage-indexeddb.html)
- [RxDB realtime Sync Engine](https://rxdb.info/replication.html)
- [CouchDB replication and conflict model](https://docs.couchdb.org/en/latest/replication/conflicts.html)
- [PowerSync JavaScript Web SDK](https://docs.powersync.com/client-sdks/reference/javascript-web)
- [PowerSync pricing](https://powersync.com/pricing)
- [PowerSync self-hosting](https://docs.powersync.com/intro/self-hosting)
- [Jazz: How sync works](https://jazz.tools/docs/concepts/how-sync-works)
- [Jazz server setup](https://jazz.tools/docs/getting-started/server-setup)
- [LiveStore syncing](https://docs.livestore.dev/reference/syncing/)
- [LiveStore state of the project](https://docs.livestore.dev/misc/state-of-the-project/)
- [Evolu Relay](https://www.evolu.dev/docs/relay)
- [Fireproof sync architecture](https://use-fireproof.com/docs/architecture/sync)
- [cojson package](https://www.npmjs.com/package/cojson)
- [LiveStore GitHub repository](https://github.com/livestorejs/livestore)
- [TinyBase IndexedDB persister](https://tinybase.org/api/persister-indexed-db/)
- [TinyBase persisters](https://tinybase.org/api/persisters/)
- [TinyBase Durable Object SQLite persister](https://tinybase.org/api/persister-durable-object-sql-storage/)
- [Automerge library initialization](https://automerge.org/docs/reference/library-initialization/)
- [Automerge network sync](https://automerge.org/docs/tutorial/network-sync/)
- [Automerge Repo releases](https://github.com/automerge/automerge-repo/releases)
- [CR-SQLite WASM and browser APIs](https://vlcn.io/docs/cr-sqlite/js/wasm)
- [CR-SQLite first app](https://vlcn.io/docs/cr-sqlite/js/first-app)

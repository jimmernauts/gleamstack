https://rxdb.info/premium/

Fetched source excerpt:
RxDB core is open source and free. Free includes schemas, queries, hooks, replication/realtime sync, default RxStorage (Dexie, Memory, LokiJS), schema validation/migration, and up to 13 open collections in parallel. Premium plugins add IndexedDB/OPFS/SQLite/filesystem storage, performance plugins, and encryption. Premium licenses are annual and require a signed agreement; no free trial or monthly subscription is offered.

https://rxdb.info/rx-storage-indexeddb.html

Fetched source excerpt:
RxDB's IndexedDB storage is based on plain IndexedDB and is intended for browsers. It uses batching and write-ahead logging-like behavior for consistency. The page states it is a Premium plugin, not part of the default module; it is recommended for browser compatibility and smaller datasets, while OPFS is better for datasets over 10k documents.

https://rxdb.info/replication.html

Fetched source excerpt:
The RxDB sync engine works with arbitrary backends. Clients read/write offline and resume replication after reconnect. The backend implements pullHandler, pushHandler, and optionally pullStream. Documents must be deterministically sortable by a checkpoint and deletions must remain as tombstones. Conflicts are returned by the server and resolved on the client; the default handler drops the fork in favor of the master, while custom conflict handlers are possible. Retries must be idempotent because a failed response can follow a successful server write.

https://docs.couchdb.org/en/latest/replication/conflicts.html

Fetched source excerpt:
CouchDB replication is HTTP push/pull. Concurrent revisions are retained on both peers; a deterministic winner is selected for ordinary reads, while losing revisions remain available through conflict APIs. Applications must inspect, merge, and delete conflicting leaf revisions. Local concurrent updates can receive 409 Conflict. Deleted revisions remain as deleted leaves; compaction discards old bodies while retaining revision metadata.

https://docs.powersync.com/client-sdks/reference/javascript-web

Fetched source excerpt:
PowerSync Web stores data in a local SQLite database and queues client writes for uploadData() to an application backend. It supports IndexedDB-backed IDBBatchAtomicVFS and OPFS alternatives. The page describes OPFSCoopSyncVFS as the Safari/iOS multi-tab option, while OPFSWriteAheadVFS is Chromium-only. The backend connector must provide credentials and upload behavior; source database and sync configuration are required.

https://powersync.com/pricing

Fetched source excerpt:
PowerSync Cloud Free is $0 but has 2 GB/month synced, 500 MB hosted, 50 peak connections, two instances, and deactivates projects after one week of inactivity. Pro starts at $49/month and removes deactivation. Team starts at $599/month and adds SLAs, version locking, and customer-provided bucket storage.

https://docs.powersync.com/intro/self-hosting

Fetched source excerpt:
PowerSync Service can be self-hosted with Docker as Open Edition. The dashboard is not available when self-hosting; an Enterprise Self-Hosted Edition with support and advanced functionality is separately priced.

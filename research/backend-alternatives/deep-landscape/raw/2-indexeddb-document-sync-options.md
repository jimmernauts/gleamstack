Source URLs:
- https://dexie.org/docs/cloud/consistency
- https://dexie.org/pricing
- https://pouchdb.com/guides/conflicts.html
- https://rxdb.info/replication.html
- https://github.com/fireproof-storage/fireproof

# Dexie Cloud consistency
Dexie Cloud uses server-authoritative consistency by default: operations run locally then the server re-executes operations with where clauses. It also supports Y.js CRDTs for collaborative documents. Atomic transactions roll back as a unit; globally unique IDs avoid insert collisions; update operations merge different properties but same-property writes use latest operation time. Declarative modify/delete operations preserve intent across offline peers. Relational modeling is recommended over frequently edited arrays. Realm membership controls sharing, with tied realm IDs for deterministic offline sharing/deletion.

# Dexie Cloud pricing
The pricing page says the service is an optional cloud add-on with free development/demo usage, 3 production seats free, 100 MB storage on the free tier, and paid tiers; on-prem is a separate Gold offering. The page lists full source code/on-prem access under Gold rather than as the default cloud service.

# PouchDB conflicts
PouchDB implements CouchDB replication. Immediate conflicts surface as HTTP/API 409 and must be handled. Eventual conflicts from offline peers are represented as revision trees; a deterministic but arbitrary winner is selected, losing revisions remain inspectable, and the app must resolve conflicts. Tombstone/revision history is part of replication. An append-only delta-document design can avoid same-document conflicts but shifts materialization and compaction into application design.

# RxDB Sync Engine
RxDB is local-first: browser storage remains usable offline and replication resumes online. The engine can use arbitrary HTTP/GraphQL/Postgres/MongoDB backends. Pull uses checkpoints and push sends assumed-master/new-fork states; conflicts are resolved client-side with a default handler that drops the fork in favor of master, or a custom handler. Deleted documents must remain as `_deleted` tombstones so they replicate. Backends need deterministic sorting/checkpoints, idempotent retry handling, and a resync after reconnect if events were missed. IndexedDB is a browser storage option; OPFS is better for larger datasets. RxDB has a paid commercial/enterprise licensing model for some plugins/features.

# Fireproof repository
Fireproof describes itself as an embedded browser/JavaScript document database with encrypted live sync, CRDT-based collaboration, cryptographic causal consistency, hash-history/ledger integrity, and content-addressed encrypted blobs. It advertises pluggable gateways and commodity object storage. The GitHub repository shown is Apache-2.0, while package metadata in search identified @fireproof/core as AFL-2.0; licensing should therefore be checked for the exact package/version and commercial distribution. The README documents browser and standalone APIs and file attachments, but the fetched repository page did not establish a fully documented self-hosted S3 adapter or operational contract.

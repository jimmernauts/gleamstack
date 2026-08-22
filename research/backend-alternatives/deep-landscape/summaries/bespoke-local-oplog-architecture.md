---
cycle: 6
purpose: "Research a deliberately small bespoke local database plus immutable operation-log/snapshot design, including LWW versus field merge versus CRDT/event logs, bootstrap, deletes/compaction, integrity, encryption, device identity, schema evolution, and safe sync retry/idempotency patterns."
quality: high
tags: [oplog, SQLite-Wasm, event-sourcing]
sources:
  - url: https://github.com/sqlite/sqlite-wasm
    title: "SQLite Wasm"
  - url: https://sqlite.org/wasm/doc/trunk/persistence.md
    title: "SQLite Wasm Persistent Storage Options"
  - url: https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/event-sourcing-pattern.html
    title: "AWS Event sourcing pattern"
  - url: https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing
    title: "Azure Event Sourcing Pattern"
---

## Key Claims
- SQLite Wasm can provide a browser-local SQL authority through OPFS in a Worker, but requires browser-specific headers/versions and has locking, quota, eviction/disappearance, and incognito caveats (SQLite docs).
- Event sourcing gives an immutable audit/history source, replay and point-in-time reconstruction, but requires optimistic concurrency, snapshots, schema evolution, idempotent processing, archival, and deletion/privacy design (AWS/Azure guidance).
- Snapshots accelerate replay but do not replace the append-only event stream; events remain the source of truth (AWS/Azure guidance).
- For straightforward CRUD, Azure explicitly cautions that event sourcing's complexity often outweighs its benefits; this is a material caveat for Mealstack's flat records (Azure guidance).

## Technical Detail
A small bespoke architecture can use a local SQLite-Wasm database in a dedicated Worker, with OPFS as the primary local file and IndexedDB or an in-memory fallback where OPFS is unavailable. The official package is Apache-2.0. Standard OPFS requires COOP/COEP headers, is Worker-only, and has browser-dependent behavior: Safari below 17 cannot use the standard VFS, OPFS handles lock the file, concurrent tabs can produce `SQLITE_BUSY` or generic I/O errors, and long transactions worsen contention. SQLite documents that quotas vary and that browser/environment cleanup can make databases disappear; the application must expose export/import and sync a durable remote copy rather than claiming device persistence is absolute. A single foreground Worker owning the database plus BroadcastChannel messages to tabs reduces the concurrency surface.

For Mealstack, the durable local model can be ordinary current-state tables plus a small `operations` table: globally unique `op_id`, device ID, entity ID, operation kind, field patch or intent, schema version, logical/HLC timestamp, and payload hash. Every local mutation commits the materialized row and operation atomically. Deletes are explicit tombstones with a deletion timestamp/version; they are retained until every relevant replica has acknowledged a watermark, then compacted into snapshots/log segments. A bootstrap bundle should contain schema version, snapshot, operation segments, manifest hashes/sizes, and an encryption/version key identifier. Verify hashes before install, write to a temporary generation, fsync/close where supported, then atomically advance the manifest; keep the previous generation for rollback. This is an engineering design inference, not a direct prescription from the cited sources.

Conflict policy should match the data: per-field LWW with server-assigned ordering/HLC is enough for independent recipe fields; set/sequence changes need explicit add/remove operations or a CRDT; cross-record invariants need server validation or an append-only intent/event model. A canonical coordinator must deduplicate `op_id`, accept retries safely, reject/record stale base versions where required, and return authoritative operations/tombstones. Device identity should be a random stable device key, not a trusted clock; server timestamps/order and authenticated user scope should govern. Event schema versions should be retained with tolerant decoding/upcasters; never rewrite immutable history. Encrypt local sensitive data and remote bundles with keys kept outside public object URLs; use crypto-shredding or separate PII if hard deletion is required.

## Relevance
This architecture best satisfies local authority, self-hostable/user-controlled backup, and low vendor dependence, but it is not “just SQLite”: sync, ordering, bootstrap, tombstones, compaction, security, and repair tooling are the product. A simpler current-state-plus-oplog design is preferable to full event sourcing for Mealstack unless audit/time travel is a goal. The cited web-platform constraints mean the design must include explicit export/import and foreground retry rather than rely on Background Sync or guaranteed OPFS durability. Multi-user concurrent edits should default to field-level merge and visible conflict records, not silently claim CRDT-level convergence.

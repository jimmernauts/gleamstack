Source URLs:
- https://github.com/sqlite/sqlite-wasm
- https://sqlite.org/wasm/doc/trunk/persistence.md
- https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/event-sourcing-pattern.html
- https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing

# SQLite Wasm and OPFS
Official SQLite Wasm wraps SQLite as an ES module. Worker deployments can use OPFS; the worker version requires COOP/COEP headers for the standard OPFS VFS. Main-thread fallback is transient unless another VFS is used. OPFS is unavailable to the main UI thread. Safari <17 is incompatible with the standard OPFS VFS; alternatives exist for Safari 16.4+. OPFS has locking/concurrency limits, can return SQLITE_BUSY/I/O errors, and storage may disappear due to browser/OS/environment decisions. SQLite docs say browser storage limits differ by environment and exceedance produces generic I/O errors. Incognito/guest modes can reduce or eliminate persistence. The official wrapper is Apache-2.0.

# Event sourcing guidance
AWS and Azure describe immutable append-only event stores, replay/materialized views, optimistic concurrency, snapshots, event versioning, idempotent consumers, archival, and point-in-time recovery. Event streams are per entity; snapshots speed rehydration but do not replace the event stream. Event delivery is commonly at least once, so consumers need idempotency. Azure warns event sourcing is complex and often unjustified for straightforward CRUD; event schema must be versioned/upcasted and personal-data deletion needs an external-data or crypto-shredding strategy.

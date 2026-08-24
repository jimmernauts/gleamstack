## Summary

The "cloud owns schema; client resets and re-pulls on mismatch" model is **supported** by the Turso Sync / sync-wasm machinery, with a few nuances. A fresh `connect()` bootstraps schema and data from the cloud automatically. Incremental DDL propagation via `pull()` is architecturally plausible (WAL pages include all frames) but is **not explicitly documented** for the user-facing sync API—making schema-version tracking via a normal table plus a full reset the safer and better-documented path. No Turso API detects schema-version mismatches; that is application code. OPFS file deletion for a clean re-bootstrap requires standard Web APIs plus care to remove all five sync-state files.

The proposed architecture is simpler than running `migrate:up` in the browser because the browser never needs migration logic: it only reads the current schema version from a synced row and either proceeds or discards + reconnects. The risk is data loss for unsynced local writes, which the question already acknowledges.

## Key Findings

### Q1 — Does a fresh local sync-wasm DB bootstrap schema + data from the cloud on first connect?

**YES — documented behavior.**

`docs.turso.tech/sync/usage` shows the minimal connect call:
```js
const db = await connect({ path, url, authToken });
await db.pull();
```
In source, `connect()` in [`promise-default.ts`](https://github.com/tursodatabase/turso/blob/main/bindings/javascript/sync/packages/wasm/promise-default.ts) constructs a `SyncEngine` with `bootstrapIfEmpty: true` (the default when `url` is a plain string), then calls `db.connect()` → `engine.connect()`. This bootstrap pull fetches the remote's current WAL pages into the local OPFS file before the first query executes. Functions involved: `connect()` (public API), `Database.connect()`, `SyncEngine.connect()` (Rust, via WASM), `pull()` for subsequent incremental pulls.

### Q2 — Is incremental DDL sync documented?

**Partially documented, partially inference.**

The sync engine uses two protocols (from [`DatabaseOpts.logicalMvccPull`](https://github.com/tursodatabase/turso/blob/main/bindings/javascript/sync/packages/common/types.ts) JSDoc): *WAL page streams* (default for non-MVCC remotes) and *MVCC logical-log streams*. WAL page streams replicate every 4 KB page frame written by the server, which physically includes DDL frames — this is documented in the Embedded Replicas page ("One frame equals 4kB of data, one on disk page frame"). PR [#7811](https://github.com/tursodatabase/turso/pull/7811) confirms DDL (captured as `sqlite_schema` inserts) travels in the CDC/push path from client to server. **Inference**: the same mechanism applies on pull for DDL generated server-side. However, the user-facing sync docs make **no explicit statement** that running ALTER TABLE on the cloud will replicate DDL to connected browser clients via `pull()`. Treat as undocumented until tested. The clean-reset path avoids this ambiguity entirely.

### Q3 — Built-in schema-version mismatch detection?

**No built-in feature. Application code only.**

Neither `docs.turso.tech/sync/usage`, `types.ts`, nor the `Database` class exposes any `onSchemaMismatch` callback or version guard. Mismatch detection (read version row, compare to build constant, decide to reset) is application code.

### Q4 — How to reset the local DB for a clean re-bootstrap?

**`close()` is documented in source; OPFS deletion is inference.**

The `Database.close()` method ([`promise-default.ts`](https://github.com/tursodatabase/turso/blob/main/bindings/javascript/sync/packages/wasm/promise-default.ts)) is the documented shutdown path. It calls `engine.close()` and `unregisterFileAtWorker` for all five files: `{path}`, `{path}-wal`, `{path}-wal-revert`, `{path}-info`, `{path}-changes`. There is no `reset()` or `deleteDatabase()` API in Turso Sync. **Inference**: after `close()`, deleting those five OPFS entries via `(await navigator.storage.getDirectory()).removeEntry(name)` and the two `localStorage` entries used by `BrowserIO` (`{path}-info`, `{path}-changes`) should produce a clean slate. `connect()` will then re-bootstrap. This OPFS/localStorage removal sequence is application code using Web APIs, not a Turso API.

### Q5 — `PRAGMA user_version` read-only; metadata table recommended; `schema_migrations` syncs normally?

**Confirmed — all three parts documented.**

From [`docs.turso.tech/cloud/limitations`](https://docs.turso.tech/cloud/limitations): "`user_version` — Read-only on Turso Cloud. Use a `_schema_version` table instead to track schema migrations." A `schema_migrations` table (or any normal table) is a standard SQLite table; its rows are included in WAL frames and will sync to the browser client on `pull()` like any other data. The client reads the highest applied migration version from that table to determine schema state.

### Conclusion

The model is sound and better-supported than in-browser migrations:

- **Bootstrap**: fully documented (`connect()` + `bootstrapIfEmpty`).
- **Version detection**: fully supported (read `schema_migrations` row after `pull()`).
- **Reset path**: `close()` documented; OPFS file deletion is inference but straightforward Web API usage.
- **What a short integration test must confirm**: (a) a fresh `connect()` to a pre-migrated Turso Cloud DB produces the correct schema locally without any explicit DDL; (b) `schema_migrations` (or equivalent) is readable after `pull()`; (c) `close()` + OPFS `removeEntry()` for all five files + re-`connect()` successfully re-bootstraps to the latest server state.

## Sources

- [Usage — Turso Sync](https://docs.turso.tech/sync/usage) — official connect/pull/push usage docs
- [promise-default.ts (sync-wasm)](https://github.com/tursodatabase/turso/blob/main/bindings/javascript/sync/packages/wasm/promise-default.ts) — `connect()`, `Database.connect()`, `pull()`, `push()`, `close()` source; `bootstrapIfEmpty` constructor arg
- [types.ts (sync-common)](https://github.com/tursodatabase/turso/blob/main/bindings/javascript/sync/packages/common/types.ts) — `DatabaseOpts` type; `logicalMvccPull` doc comment (WAL page streams vs MVCC logical-log streams)
- [Turso Cloud Limitations](https://docs.turso.tech/cloud/limitations) — `user_version` read-only; metadata table recommendation
- [Embedded Replicas Introduction](https://docs.turso.tech/features/embedded-replicas/introduction) — WAL frame sync mechanics; "removing/invalidating local files causes re-sync from scratch"
- [PR #7811 — fix/sync: Replay pushed CREATE DDL with IF NOT EXISTS](https://github.com/tursodatabase/turso/pull/7811) — DDL captured from `sqlite_schema` inserts in CDC push path
- [Issue #5640 — column order mismatch after DROP COLUMN + ADD COLUMN](https://github.com/tursodatabase/turso/issues/5640) — CDC records are positional; ABA problem warning
- [Discussion #6539 — serverless vs sync-wasm](https://github.com/tursodatabase/turso/discussions/6539) — partial sync strategies; `db.sync()` behaviour

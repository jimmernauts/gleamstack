Source URLs:
- https://github.com/aspen-cloud/triplit
- https://pglite.dev/docs/sync
- https://docs.powersync.com/handling-writes/custom-conflict-resolution
- https://zero.rocicorp.dev/docs/status
- https://zero.rocicorp.dev/docs/when-to-use

# Triplit
Triplit is open source and syncs server/browser in real time. Its README advertises a full client-side DB with IndexedDB and other storage providers, offline mode with automatic reconnection, property-level conflict resolution, rollback/retry, schemas, server-enforced authorization, CRDT collaboration, and pluggable server/client packages. It documents a Node server and Cloudflare Worker server package in the monorepo. Search-result metadata identified AGPL-3.0 licensing; verify exact distribution terms.

# Electric/PGlite
PGlite embeds Postgres in WASM for browser/Node/Bun/Deno. The current `@electric-sql/pglite-sync` documentation describes an alpha one-way shape sync from Electric into local PGlite tables. It does not yet support syncing local writes out or conflict resolution. Multi-table shapes can preserve Postgres transaction consistency; shape checkpoints can persist for resume. This is not currently a full bidirectional offline-write solution.

# PowerSync
PowerSync writes instantly to local SQLite, queues operations, uploads through an application `uploadData` function to Postgres/MySQL/MongoDB/etc., and downloads server changes through sync streams/rules. Default conflict behavior is last-write-wins per field: different fields merge, same field uses last operation received. It documents custom strategies: timestamp/version detection, field-level LWW, business rules, recording both versions for human resolution, change logs, cumulative/delta operations, and CRDTs. It explicitly recommends idempotency because operations can be delivered more than once.

# Zero
Zero's March 2026 status says it is generally available and fully supported, with Cloud Zero planned for broader availability in 2026. Zero is open source/self-hostable but requires zero-cache, Postgres, frontend, and API server. Its own guidance says it is authoritative client-server, not local-first, and does not support offline writes; disconnected clients can continue reading cached synced data but writes are rejected. It is therefore a poor fit for Mealstack's durable offline-write requirement despite good query-driven partial sync and authorization.

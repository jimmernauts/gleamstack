---
cycle: 4
purpose: "Evaluate managed or server-coordinated sync products: Triplit, ElectricSQL/PGlite, PowerSync, Rocicorp Zero, and Replicache, including current availability, browser data authority, offline support, concurrent-write model, self-hosting/hosted boundaries, and continuity risk."
quality: high
tags: [sync-coordinator, offline-writes, hosted]
sources:
  - url: https://github.com/aspen-cloud/triplit
    title: "Triplit repository"
  - url: https://pglite.dev/docs/sync
    title: "Sync using Electric/PGlite"
  - url: https://docs.powersync.com/handling-writes/custom-conflict-resolution
    title: "PowerSync Custom Conflict Resolution"
  - url: https://zero.rocicorp.dev/docs/status
    title: "Zero Project Status"
  - url: https://zero.rocicorp.dev/docs/when-to-use
    title: "When To Use Zero"
---

## Key Claims
- Triplit advertises an open-source full-stack database with IndexedDB client storage, offline reconnection, property-level conflict resolution, rollback/retry, server authorization, CRDT collaboration, and Node/Cloudflare server packages (Triplit README).
- PGlite embeds Postgres in WASM, but the documented Electric sync plugin is alpha and currently one-way: local writes and conflict resolution are not supported (PGlite sync docs).
- PowerSync's default is field-level LWW: distinct fields merge, while same-field writes use arrival order; its upload callback and documented custom strategies leave the domain backend in charge (PowerSync docs).
- Zero is generally available and supported as of March 2026, but its own guide says it is authoritative client-server and rejects offline writes; it is not a local-first fit for Mealstack (Zero status/usage docs).
- Triplit's search metadata identifies AGPL-3.0; hosted pricing/continuity and exact package terms need direct verification before adoption.

## Technical Detail
Triplit is the closest product-like fit in this group. Its client package lists IndexedDB, SQLite, LevelDB, memory, and other storage providers; the README claims optimistic local interaction, automatic reconnection, property-level conflict resolution, rollback/retry, schemas, and server-enforced authorization. The repository includes a sync server and Cloudflare Worker server packages, which suggests a self-hostable coordinator. It also combines ordinary relational queries with CRDT-powered collaboration. The practical risks are AGPL obligations, project continuity, and verifying exact delete/tombstone, backup/export, object-storage, and multi-user sharing behavior rather than relying on README claims.

PGlite is useful as a local SQL engine and perhaps a future Electric substrate, but the primary sync docs explicitly label the plugin alpha and state that local writes are not synced out and conflict resolution is absent. It cannot currently satisfy the bidirectional offline-write requirement without additional application sync logic. PowerSync is more mature as a coordinator around local SQLite and a source database: local writes queue through `uploadData`, and downloaded changes merge into local state. It offers a credible field-LWW baseline for flat records, but the backend must implement authentication, authorization, idempotency, business rules, and any user-controlled backup. A user-controlled object store is not itself a coordinator.

Zero is valuable as a contrast case. It offers partial query-driven sync, expressive read permissions and mutators, PostgreSQL compatibility, open-source self-hosting, and a managed path, but explicitly rejects offline writes and is not local-first. Its March 2026 GA/support statement improves continuity evidence, yet not the core data-authority mismatch. Replicache was named in the query but the fetched current primary sources did not establish a current supported product/hosting position, so it should not be shortlisted without another verification pass.

## Relevance
Triplit and PowerSync are viable managed/coordinated architectures to prototype, with Triplit more integrated and PowerSync more explicit about backend conflict policy. A bespoke RxDB/TinyBase/SQLite coordinator retains more storage control. Electric/PGlite and Zero should be treated as non-fitting for the required offline writes in their documented current forms. All coordinated products still require a durable canonical store and a user-controlled export/backup path separate from sync.

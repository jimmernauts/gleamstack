---
topic: Mealstack offline-first InstantDB replacement landscape
cycle: 1
date: 2026-03-13
---

# Next-Cycle Brief: Mealstack offline-first InstantDB replacement landscape

## Priority Gaps (focus here next run)

1. **Verify the finalists' legal, operational, and continuity boundaries** — Triplit, Fireproof, Evolu, Jazz, and LiveStore still lack decision-grade evidence on licensing, hosted/self-hosted boundaries, release health, export, and production support.
   - Suggested queries: "Triplit AGPL commercial license hosted pricing export backup tombstone docs 2026", "Fireproof npm package license storage gateway self host production 2026", "Evolu Jazz LiveStore browser persistence self host relay license backup 2026"
   - Source types most likely to help: github / web

2. **Establish current iOS PWA durability empirically and from primary compatibility data** — every architecture depends on IndexedDB or OPFS, but current installed-PWA behavior for eviction, quotas, private mode, multi-tab locking, and foreground/background synchronization is not yet sufficiently specific.
   - Suggested queries: "Safari iOS 18 installed PWA IndexedDB OPFS eviction storage persist primary source 2026", "WebKit Background Sync API status iOS PWA 2026", "WebKit storage policy seven day eviction installed web app IndexedDB OPFS"
   - Source types most likely to help: web / github

3. **Obtain exact delete, conflict, and sharing semantics for the leading integrated options** — property-level merge claims are not enough to judge concurrent recipe edits, delete-versus-update, membership revocation, tombstone retention, or conflict visibility.
   - Suggested queries: "Triplit delete update conflict tombstone property merge authorization sharing docs", "Dexie Cloud delete update conflict tied realm offline revoke access docs", "PowerSync delete conflict tombstone multi user authorization docs"
   - Source types most likely to help: web / github

4. **Resolve migration and prototype-level compatibility details** — the next decision needs an explicit mapping from Instant JSONL/schema/auth exports and worker/admin calls into two or three finalists, plus measured Gleam-to-JavaScript FFI and bundle/runtime constraints.
   - Suggested queries: "InstantDB backup JSONL schema restore format migrate custom database", "RxDB Gleam JavaScript FFI IndexedDB example", "Triplit vanilla JavaScript client bundle IndexedDB Cloudflare Worker example", "SQLite wasm OPFS Gleam JavaScript Worker FFI"
   - Source types most likely to help: web / github

## Do Not Re-Fetch
Topics already well-covered. The next worker should skip these even if results look relevant.
- InstantDB shutdown dates, backup contents, official rehearsal/cutover sequence, and broad self-hosting responsibilities
- General Dexie Cloud consistency behavior, PouchDB revision conflicts, and RxDB checkpoint/tombstone replication requirements
- The fact that PGlite/Electric is currently one-way and Zero rejects offline writes
- Generic Firestore offline cache and Supabase backup behavior
- General event-sourcing advantages/costs and the current-state-plus-oplog architectural outline
- Google Drive `appDataFolder`, changes-feed basics, and S3/R2/Tigris presigned URL/versioning basics
- Durable Object actor/WebSocket capabilities and broad browser storage-eviction/Background Sync limitations

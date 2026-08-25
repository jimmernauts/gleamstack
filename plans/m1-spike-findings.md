# M1 Spike Findings — Turso sync-wasm on Cloudflare Workers

**Date:** 2026-08-25  
**Status:** ✅ Proven — all requirements met

## Pinned Version

- `@tursodatabase/sync-wasm`: **0.7.2**
- Vite build target: `esnext` (required for top-level await / wasm)
- WASM file: ~12.8 MB uncompressed, ~4.2 MB gzipped

## What Works

| Requirement | Result |
|---|---|
| `crossOriginIsolated` | ✅ via `_headers` file (COOP + COEP) |
| `SharedArrayBuffer` | ✅ available |
| OPFS connect + bootstrap | ✅ `connect()` + initial `pull()` |
| Write + Read (local) | ✅ `prepare().run()` / `prepare().all()` |
| Persistence across reconnects | ✅ OPFS data survives close + reopen |
| Push to Turso Cloud | ✅ `push()` sends local mutations |
| Pull from Turso Cloud | ✅ `pull()` returns `changed=true` |
| Conflict resolution | ✅ last-push-wins (INSERT OR REPLACE) |
| Token delivery without rebuild | ✅ Worker secrets via `/api/` route at request time |

## API Surface (sync-wasm 0.7.2)

The `connect()` return is **not** the libsql `Client` — it's a different object:

```
db.pull()          → Promise<boolean>     (true if changes pulled)
db.push()          → Promise<void>
db.exec(sql)       → Promise<void>        (DDL, fire-and-forget)
db.prepare(sql)    → Promise<Statement>
  stmt.all(...args)  → Promise<Row[]>     (rows as objects keyed by column)
  stmt.get(...args)  → Promise<Row>
  stmt.run(...args)  → Promise<{changes, lastInsertRowid}>
db.close()         → Promise<void>
```

No `execute()` method — M2's repository layer should use `prepare()` directly.

## One-Tab Behaviour

OPFS in exclusive mode allows only **one tab** to hold the database open.
Opening a second tab with the same `path` will fail or block. The app must
either:
- Use a `BroadcastChannel` to coordinate (leader election), or
- Accept single-tab usage and show a "already open" message in other tabs

## Gaps / Risks for M2+

1. **No `execute()` convenience** — need a thin repository wrapper around `prepare()`
2. **WASM size** — 12.8 MB uncompressed is large for cold-start; gzip helps (4.2 MB)
3. **One-tab lock** — needs UX handling (BroadcastChannel leader or user message)
4. **Token expiry** — spike used 7-day token; production needs rotation strategy
   (Worker secret update via API, or use Turso's `authToken: () => string` callback)
5. **`_headers` file** — CF applies these to all static assets; must stay in `app/public/`
6. **Push returns void** — no confirmation payload; errors are thrown exceptions

## Files Retained for M2

- `app/public/_headers` — COOP/COEP (required for SharedArrayBuffer)
- `app/package.json` — `@tursodatabase/sync-wasm` dependency
- `wrangler.jsonc` — `main` pointing to `worker/src/index.mjs` (stable, not gitignored)
- `plans/m1-spike-plan.md` — reference

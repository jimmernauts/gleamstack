# M1: Prove Turso works in the real deployment — Implementation plan

## Goal

Deploy a throwaway spike page on the same `workers.dev` hostname, behind the existing Workers Access policy, with COOP/COEP headers, and confirm that `@tursodatabase/sync-wasm` works end-to-end in this real environment. Record what works, what doesn't, and what the main app conversion needs.

## What the spike must prove

From the architecture doc:

1. A named OPFS database persists across reload and browser restart, with COOP/COEP set.
2. A fresh local database bootstraps its schema and data from a dbmate-migrated Turso Cloud database.
3. Discarding the local OPFS database triggers a clean re-bootstrap from the cloud.
4. Offline edits stay local, then `push()` sends them and `pull()` brings remote changes down (`true` when something changed, `false` when not).
5. The Turso token is delivered from `/api/db-config` behind Access, is absent from the built assets, and rotates by changing the Worker secret without a rebuild.
6. One deliberate two-profile conflicting edit shows the last-push-wins result.

## Current deployment structure

```
wrangler.jsonc
├── main: worker/build/dev/javascript/mealstack_worker/index.mjs
├── assets.directory: ./app/dist (SPA fallback)
├── workers_dev: true
└── no COOP/COEP headers currently set

Worker routes: /api/scrape_url, /api/parse_recipe_text, /api/parse_recipe_image
Static: everything else from app/dist via Cloudflare asset serving
Access: all-traffic policy already active on the workers.dev hostname
```

## Implementation plan

### Phase 1: Infrastructure setup (outside sandbox)

These require CLI access with credentials — they can't run in this sandbox.

1. **Create a spike Turso database**
   ```bash
   turso db create gleamstack-spike
   turso db tokens create gleamstack-spike --expiration 7d
   ```

2. **Apply a minimal schema** (via turso db shell or dbmate)
   ```sql
   CREATE TABLE IF NOT EXISTS spike_items (
     id TEXT PRIMARY KEY,
     title TEXT NOT NULL,
     value TEXT,
     updated_at TEXT DEFAULT (datetime('now'))
   );
   CREATE TABLE IF NOT EXISTS schema_migrations (
     version TEXT PRIMARY KEY
   );
   INSERT OR IGNORE INTO schema_migrations (version) VALUES ('001_spike_items');
   ```

3. **Add Worker secrets**
   ```bash
   wrangler secret put TURSO_SPIKE_URL    # https://gleamstack-spike-<org>.turso.io
   wrangler secret put TURSO_SPIKE_TOKEN  # the token from step 1
   ```

### Phase 2: Code changes (this sandbox can do this)

#### 2a. Add the spike page

Create a standalone HTML+JS page at `app/public/spike.html` that:
- Imports `@tursodatabase/sync-wasm` from a CDN or bundled entry
- Fetches config from `/api/db-config`
- Opens a named OPFS database
- Runs a set of manual test buttons:
  - **Persist test**: write a row, reload, read it back
  - **Bootstrap test**: show schema_migrations table content
  - **Reset test**: delete OPFS database, re-bootstrap from cloud
  - **Push test**: write locally, push, show result
  - **Pull test**: pull, show changed/unchanged result
  - **Offline test**: disconnect, write, reconnect, push
- Displays results in a log panel on the page

#### 2b. Add `/api/db-config` endpoint to the Worker

Modify `worker/src/index.mjs` (the fetch entry point) to intercept `/api/db-config` before the Gleam handler:

```javascript
if (new URL(request.url).pathname === '/api/db-config') {
  return new Response(JSON.stringify({
    url: env.TURSO_SPIKE_URL,
    // Token absent if secrets not set — proves it's not in assets
  }), {
    headers: { 'Content-Type': 'application/json' }
  });
}
```

This endpoint:
- Only works behind Access (Access gates all traffic)
- Returns the Turso URL and token from Worker secrets
- Proves the token is not embedded in static assets

#### 2c. Add COOP/COEP headers

Add response headers middleware in `worker/src/index.mjs` for all responses:

```javascript
res.headers.set('Cross-Origin-Opener-Policy', 'same-origin');
res.headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
```

These are required for `SharedArrayBuffer` which `sync-wasm` uses.

#### 2d. Add `@tursodatabase/sync-wasm` to app dependencies

```bash
cd app && npm install @tursodatabase/sync-wasm
```

Pin the exact version in package.json.

#### 2e. Create a Vite entry for the spike

Add `app/src/spike-entry.ts` as a separate entry that:
- Fetches `/api/db-config`
- Creates the Turso WASM connection with OPFS path
- Exposes test functions to the spike page buttons

Update `app/vite.config.ts` to build this as an additional entry (or use a simple `<script type="module">` from the public spike.html).

### Phase 3: Deploy and test manually

1. Build: `cd app && npx vite build`
2. Deploy: `npx wrangler deploy`
3. Open `https://<app>.workers.dev/spike.html`
4. Run through each test button and record results
5. Test with two browser profiles for the conflict scenario
6. Test offline by toggling network in DevTools

### Phase 4: Record findings

Create `plans/m1-spike-results.md` documenting:
- Pinned `sync-wasm` version
- OPFS persistence: pass/fail
- Bootstrap from cloud: pass/fail
- Reset and re-bootstrap: pass/fail
- Push/pull behaviour: pass/fail, return values
- Token delivery: pass/fail, confirm absent from assets
- Last-push-wins conflict: recorded result
- One-tab behaviour: what happens with two tabs
- Any Vite config changes needed (e.g. WASM plugin, worker config)
- Any gaps or fallbacks required

## File layout

```
app/
  public/spike.html           ← throwaway test page (UI + manual test buttons)
  src/spike-entry.ts          ← Turso WASM connection and test logic
  vite.config.ts              ← possibly add spike entry

worker/
  src/index.mjs               ← add /api/db-config route + COOP/COEP headers

plans/
  m1-spike-plan.md            ← this plan
  m1-spike-results.md         ← findings after testing
```

## What this sandbox can deliver

- The spike page HTML and TypeScript
- The Worker modifications (db-config endpoint, COOP/COEP headers)
- The npm dependency addition
- The plan and results template

## What requires the host environment

- `turso db create` and token generation
- `wrangler secret put` for TURSO_SPIKE_URL and TURSO_SPIKE_TOKEN
- `wrangler deploy`
- Manual browser testing on the deployed page
- Recording the actual results

## Risks

| Risk | Mitigation |
|---|---|
| sync-wasm OPFS doesn't work with Cloudflare's asset serving | COOP/COEP headers should fix this; if not, try a custom service worker |
| SharedArrayBuffer unavailable despite headers | Verify headers are applied to the spike.html response specifically |
| Package is pre-release / unstable | Pin version, test basic operations, document issues |
| Access blocks the spike page | It shouldn't — Access admits the owner to all routes |
| COOP/COEP breaks existing app features (iframes, cross-origin loads) | Spike is isolated; measure impact before applying to whole app |

## Acceptance criteria

1. Spike page loads on `workers.dev` behind Access with COOP/COEP active
2. OPFS database persists across reload
3. Fresh database bootstraps schema from Turso Cloud
4. OPFS reset triggers clean re-bootstrap
5. Push sends local changes, pull receives remote changes with correct return values
6. `/api/db-config` returns token only behind Access, absent from static assets
7. Two-profile conflict demonstrates last-push-wins
8. Pinned version, one-tab behaviour, and any gaps documented

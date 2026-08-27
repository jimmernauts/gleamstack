---
description: End-to-end verification sequence for the Gleamstack app using agent-browser and wrangler dev.
---

# E2E Verification

Run the full app locally and verify it works from within the sandbox using `agent-browser`.

## Prerequisites

- `wrangler` available via npx
- `.dev.vars` in project root with `TURSO_URL` and `TURSO_AUTH_TOKEN`
- Turso Cloud database has the schema applied (`db/migrations/001_initial_schema.sql`)
- `agent-browser` CLI installed globally

## Start the dev server

Kill any leftover wrangler/workerd processes first — orphan workerd processes survive their parent and hold the port:

```bash
# Kill by searching ALL wrangler/workerd processes, not just by name
ps -eo pid,args | grep -E "wrangler|workerd" | grep -v grep | awk '{print $1}' | xargs kill -9 2>/dev/null
sleep 3
```

Build and start:

```bash
cd app && rm -rf dist && npx vite build
cd ..
npx wrangler dev --port 8787 --ip 0.0.0.0 > /dev/null 2>&1 &
```

Wait for ready (wrangler takes ~8 seconds):

```bash
for i in $(seq 1 15); do
  curl --noproxy '*' -s --max-time 2 http://0.0.0.0:8787/ > /dev/null 2>&1 && echo "ready" && break
  sleep 1
done
```

## Verify with agent-browser

Close any stale browser sessions first:

```bash
agent-browser close 2>/dev/null; sleep 1
```

### 1. Page loads and shows recipes

```bash
agent-browser navigate http://localhost:8787/recipes
sleep 6
agent-browser eval '
  Array.from(document.querySelectorAll("a[href*=\"/recipes/\"]"))
    .map(a => a.textContent.trim().slice(0,30))
'
```

Expected: array of recipe titles (may be empty if cloud DB has no data).

### 2. SPA routing works

```bash
agent-browser navigate http://localhost:8787/recipes/new
sleep 2
agent-browser eval 'document.querySelector("h1")?.textContent'
```

Expected: page title like "New Recipe" (SPA fallback serves index.html for all routes).

### 3. Save persists after page refresh

```bash
# Save a recipe via the form
agent-browser navigate http://localhost:8787/recipes/new
sleep 2
agent-browser eval '
  const inputSet = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
  inputSet.call(document.getElementById("serves"), "4");
  document.getElementById("serves").dispatchEvent(new Event("input", {bubbles: true}));
  document.querySelector("button[type=submit]").click();
  "saved"
'
sleep 5

# Reload the page
agent-browser eval 'location.reload()'
sleep 6

# Check recipes are still there
agent-browser eval '
  Array.from(document.querySelectorAll("a[href*=\"/recipes/\"]"))
    .map(a => a.textContent.trim().slice(0,30))
'
```

Expected: the recipe list includes the saved recipe after reload.

### 4. Save persists after browser close and reopen

```bash
agent-browser close
sleep 3
agent-browser navigate http://localhost:8787/recipes
sleep 6
agent-browser eval '
  Array.from(document.querySelectorAll("a[href*=\"/recipes/\"]"))
    .map(a => a.textContent.trim().slice(0,30))
'
```

Expected: same recipes as before close. Data round-trips through Turso Cloud.

### 5. Server stays responsive

After any browser interaction, confirm workerd hasn't become unresponsive:

```bash
curl --noproxy '*' -s --max-time 3 http://0.0.0.0:8787/api/db-config | head -1
```

Expected: JSON response with `url` and `authToken`.

### 6. Screenshot for evidence

```bash
agent-browser screenshot /tmp/gleamstack-e2e.png
```

## Verify cloud data directly

Query Turso Cloud via HTTP to confirm push() worked:

```bash
# Derive endpoint and token from .dev.vars (region/URL can change — never hardcode)
TOKEN=$(grep TURSO_AUTH_TOKEN .dev.vars | cut -d= -f2)
TURSO_HTTP=$(grep TURSO_URL .dev.vars | cut -d= -f2 | sed -E 's,^(turso|libsql)://,https://,')
curl --noproxy '*' -s --max-time 10 \
  "$TURSO_HTTP/v3/pipeline" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"requests":[{"type":"execute","stmt":{"sql":"SELECT slug, title FROM recipes"}},{"type":"close"}]}'
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Address already in use` | Orphan workerd from previous wrangler | Kill all: `ps -eo pid,args \| grep workerd \| awk '{print $1}' \| xargs kill -9` |
| workerd accepts TCP but never responds | Old wrangler parent respawning stale workerd children | Find and kill the wrangler parent node process (check `PPid` in `/proc/<pid>/status`) |
| curl returns empty but wrangler says "Ready" | Sandbox proxy interfering; use `--noproxy '*'` with curl | Always use `curl --noproxy '*'` inside the sandbox |
| Recipes don't show despite data in DB | Gleam decoder type mismatch (e.g. bool vs int) | Check `codecs.gleam` — SQLite returns integers for booleans |
| Page loads but OPFS files are 0 bytes | Turso Cloud schema not applied | `turso db shell <dbname> < db/migrations/001_initial_schema.sql` from the host, or from the sandbox POST the migration statements to `$TURSO_HTTP/v3/pipeline` (same auth as "Verify cloud data directly") |
| COOP/COEP headers ignored in host browser | Accessing via IP instead of localhost | Use `http://localhost:<port>` — browsers require trustworthy origin for COOP/COEP |

## Notes on agent-browser form interaction

Lustre (the Gleam UI framework) uses virtual DOM diffing. Setting input values via native property setters + `dispatchEvent(new Event("input"))` works for most inputs but may not update the Lustre model for textarea fields. For reliable form testing, prefer clicking existing UI elements over programmatic value setting.

#!/usr/bin/env bash
# M1 Spike Deployment — run on host with turso + wrangler authenticated
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== M1: Deploy Turso Spike ==="
echo ""

# 1. Create Turso database
echo "Step 1: Creating Turso database..."
if turso db show gleamstack-spike &>/dev/null; then
  echo "  Database 'gleamstack-spike' already exists."
else
  turso db create gleamstack-spike
  echo "  Created 'gleamstack-spike'."
fi

# 2. Apply schema
echo ""
echo "Step 2: Applying spike schema..."
turso db shell gleamstack-spike <<'SQL'
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
SQL
echo "  Schema applied."

# 3. Generate token (7-day expiry)
echo ""
echo "Step 3: Generating Turso token..."
SPIKE_TOKEN=$(turso db tokens create gleamstack-spike --expiration 7d)
echo "  Token generated (7-day expiry)."

# 4. Get database URL
SPIKE_URL=$(turso db show gleamstack-spike --url)
echo "  URL: $SPIKE_URL"

# 5. Set Worker secrets
echo ""
echo "Step 4: Setting Wrangler secrets..."
echo "$SPIKE_URL" | npx wrangler secret put TURSO_SPIKE_URL
echo "$SPIKE_TOKEN" | npx wrangler secret put TURSO_SPIKE_TOKEN
echo "  Secrets set."

# 6. Build app
echo ""
echo "Step 5: Building app..."
cd app && npm run build && cd ..
echo "  Build complete."

# 7. Deploy
echo ""
echo "Step 6: Deploying to workers.dev..."
npx wrangler deploy
echo ""
echo "=== Done! ==="
echo "Open your workers.dev URL /spike.html to test."
echo "e.g. https://mealstack.<account>.workers.dev/spike.html"

import * as glen from '../glen/glen.mjs';
import * as mealstack_worker from './mealstack_worker.mjs';

// COOP/COEP headers required for SharedArrayBuffer (Turso sync-wasm OPFS)
function addCrossOriginHeaders(response) {
  const res = new Response(response.body, response);
  res.headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  res.headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
  return res;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Spike: deliver Turso config from Worker secrets (behind Access)
    if (url.pathname === '/api/db-config') {
      const config = {
        url: env.TURSO_SPIKE_URL || null,
        token: env.TURSO_SPIKE_TOKEN || null,
      };
      return addCrossOriginHeaders(new Response(JSON.stringify(config), {
        headers: { 'Content-Type': 'application/json' },
      }));
    }

    // Spike: apply schema to Turso Cloud DB (worker can reach the DB, sandbox cannot)
    if (url.pathname === '/api/db-setup') {
      if (!env.TURSO_SPIKE_URL || !env.TURSO_SPIKE_TOKEN) {
        return addCrossOriginHeaders(new Response(JSON.stringify({ error: 'Missing secrets' }), {
          status: 500, headers: { 'Content-Type': 'application/json' },
        }));
      }
      try {
        const dbHost = env.TURSO_SPIKE_URL.replace(/^https?:\/\//, '');
        const res = await fetch(`https://${dbHost}/v2/pipeline`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${env.TURSO_SPIKE_TOKEN}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            requests: [
              { type: 'execute', stmt: { sql: "CREATE TABLE IF NOT EXISTS spike_items (id TEXT PRIMARY KEY, title TEXT NOT NULL, value TEXT, updated_at TEXT DEFAULT (datetime('now')))" } },
              { type: 'execute', stmt: { sql: 'CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY)' } },
              { type: 'execute', stmt: { sql: "INSERT OR IGNORE INTO schema_migrations (version) VALUES ('001_spike_items')" } },
              { type: 'close' },
            ],
          }),
        });
        const result = await res.json();
        return addCrossOriginHeaders(new Response(JSON.stringify({ ok: true, result }), {
          headers: { 'Content-Type': 'application/json' },
        }));
      } catch (e) {
        return addCrossOriginHeaders(new Response(JSON.stringify({ error: e.message }), {
          status: 500, headers: { 'Content-Type': 'application/json' },
        }));
      }
    }

    // Existing Gleam worker routes
    console.log(request);
    const req = glen.convert_request(request);
    const response = await mealstack_worker.handle_req(req);
    const res = glen.convert_response(response);

    return addCrossOriginHeaders(res);
  },
};
import * as glen from '../glen/glen.mjs';
import * as mealstack_worker from './mealstack_worker.mjs';

// COOP/COEP headers required for SharedArrayBuffer (Turso sync-wasm OPFS)
// For worker-created responses (JSON etc), simple wrap is fine.
function addCrossOriginHeaders(response) {
  const headers = new Headers(response.headers);
  headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
  // Strip encoding metadata — when we pass response.body through,
  // the runtime may have already decoded it, causing a mismatch.
  headers.delete('Content-Encoding');
  headers.delete('Content-Length');
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
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

    // Existing Gleam worker API routes
    if (url.pathname.startsWith('/api/')) {
      console.log(request);
      const req = glen.convert_request(request);
      const response = await mealstack_worker.handle_req(req);
      const res = glen.convert_response(response);
      return addCrossOriginHeaders(res);
    }

    // Serve static assets via the ASSETS binding (so COOP/COEP headers apply to all responses)
    // Request identity encoding to avoid compressed-body-passthrough corruption
    const assetReq = new Request(request.url, request);
    assetReq.headers.set('Accept-Encoding', 'identity');
    const assetResponse = await env.ASSETS.fetch(assetReq);
    return addCrossOriginHeaders(assetResponse);
  },
};
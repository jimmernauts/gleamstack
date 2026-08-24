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

    // Existing Gleam worker routes
    console.log(request);
    const req = glen.convert_request(request);
    const response = await mealstack_worker.handle_req(req);
    const res = glen.convert_response(response);

    return addCrossOriginHeaders(res);
  },
};
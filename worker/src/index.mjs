import * as glen from '../build/dev/javascript/glen/glen.mjs';
import * as mealstack_worker from '../build/dev/javascript/mealstack_worker/mealstack_worker.mjs';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Serve Turso database config to authenticated clients
    if (url.pathname === '/api/db-config') {
      if (!env.TURSO_URL || !env.TURSO_AUTH_TOKEN) {
        return new Response(JSON.stringify({ error: 'Database not configured' }), {
          status: 503,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      return new Response(JSON.stringify({
        url: env.TURSO_URL,
        authToken: env.TURSO_AUTH_TOKEN,
      }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // API routes handled by Gleam worker
    if (url.pathname.startsWith('/api/')) {
      console.log(request);
      const req = glen.convert_request(request);
      const response = await mealstack_worker.handle_req(req);
      return glen.convert_response(response);
    }

    // All other routes: serve from static assets (SPA fallback)
    // The assets binding respects not_found_handling: single-page-application
    return env.ASSETS.fetch(request);
  },
};

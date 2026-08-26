// Lazy-import the Gleam worker to avoid module-level side effects
// (parse_recipe.ts initialises InstantDB admin at import time)
let glen, mealstack_worker;
async function getGleamWorker() {
  if (!glen) {
    glen = await import('../build/dev/javascript/glen/glen.mjs');
    mealstack_worker = await import('../build/dev/javascript/mealstack_worker/mealstack_worker.mjs');
  }
  return { glen, mealstack_worker };
}

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

    // API routes handled by Gleam worker (lazy-loaded)
    if (url.pathname.startsWith('/api/')) {
      const { glen, mealstack_worker } = await getGleamWorker();
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

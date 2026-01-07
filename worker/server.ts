// this is a basic bun server for the worker
// it is used for development only to debug when something is not working using wrangler dev
// it is not used for production

import fetch from "./build/dev/javascript/mealstack_worker/index.mjs";

Bun.serve(fetch);
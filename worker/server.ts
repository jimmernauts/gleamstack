// this is a basic bun server for the worker
// it is used for development only to debug when something is not working using wrangler dev
// it is not used for production

import { config } from "dotenv";

config({ path: ".dev.vars" });

const { default: fetch } = await import(
    "./build/dev/javascript/mealstack_worker/index.mjs",
);

Bun.serve(fetch);
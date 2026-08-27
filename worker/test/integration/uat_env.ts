const PRODUCTION_WORKER_HOST = "mealstack.jimmernauts.workers.dev";

export function requireUatEnvironment(): URL {
    if (!process.env.TURSO_URL) {
        throw new Error(
            "UAT tests require TURSO_URL (set in worker/.dev.vars)",
        );
    }

    if (!process.env.TURSO_AUTH_TOKEN) {
        throw new Error(
            "UAT tests require TURSO_AUTH_TOKEN (set in worker/.dev.vars)",
        );
    }

    if (!process.env.GEMINI_API_KEY) {
        throw new Error(
            "UAT tests require GEMINI_API_KEY (set in worker/.dev.vars)",
        );
    }

    // Expose env for parse_recipe.ts (mirrors what index.mjs does at runtime)
    globalThis.__workerEnv = {
        TURSO_URL: process.env.TURSO_URL,
        TURSO_AUTH_TOKEN: process.env.TURSO_AUTH_TOKEN,
        GEMINI_API_KEY: process.env.GEMINI_API_KEY,
    };

    const workerUrl = new URL(
        process.env.MEALSTACK_WORKER_URL ?? "http://127.0.0.1:3000",
    );
    if (workerUrl.hostname === PRODUCTION_WORKER_HOST) {
        throw new Error(
            "UAT tests must not target the production Mealstack worker",
        );
    }

    return workerUrl;
}

const MEALSTACK_DEV_APP_ID = "4304e120-9a5c-45e4-ba7a-4aaa0b7f282a";
const PRODUCTION_WORKER_HOST = "mealstack.jimmernauts.workers.dev";

export function requireUatEnvironment(): URL {
    if (process.env.INSTANT_APP_ID !== MEALSTACK_DEV_APP_ID) {
        throw new Error(
            "UAT tests require INSTANT_APP_ID for the mealstack-dev InstantDB app",
        );
    }

    if (!process.env.INSTANT_ADMIN_TOKEN) {
        throw new Error(
            "UAT tests require INSTANT_ADMIN_TOKEN from worker/.dev.vars",
        );
    }

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

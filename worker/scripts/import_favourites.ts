import { init } from "@instantdb/admin";
import { createHash } from "node:crypto";
import { appendFile, mkdir, readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import schema from "../../app/src/instant.schema.ts";
import {
    toRecipePersistenceFields,
    type RecipePersistenceFields,
} from "../../common/recipe_persistence.ts";
import type { Recipe } from "../../common/types.ts";
import type { ScrapeRecipe, ScrapeResult } from "../src/scrape_url.ts";

type Bookmark = {
    index: number;
    title: string;
    url: string;
};

type Options = {
    bookmarkFile: string;
    workerUrl: string;
    offset: number;
    limit: number;
    concurrency: number;
    timeoutMs: number;
    retries: number;
    retryDelayMs: number;
    checkpoint: string;
    write: boolean;
    appId?: string;
};

type ParseSuccess = {
    ok: true;
    httpStatus: number;
    attempts: number;
    payload: ScrapeResult;
};

type ParseFailure = {
    ok: false;
    httpStatus?: number;
    attempts: number;
    error: string;
};

type ParseResult = ParseSuccess | ParseFailure;

type RecipeWriteResult = {
    recipe_key: string;
    entity_id: string;
    status: "success" | "skipped" | "failure";
    tx_id?: string;
    error?: string;
};

type CheckpointRecord = {
    version: 1;
    kind: "url_result";
    index: number;
    bookmark_title: string;
    url: string;
    normalized_url: string;
    worker_url: string;
    generated_at_utc: string;
    parse_status: "success" | "failure";
    http_status?: number;
    attempts: number;
    recipes?: ScrapeRecipe[];
    warnings?: string[];
    error?: string;
    validation_errors?: string[];
    write_status?: "not_requested" | "success" | "partial" | "failure";
    write_app_id?: string;
    writes?: RecipeWriteResult[];
};

type AdminDb = any;

export function formatAdminError(error: unknown): string {
    if (error && typeof error === "object") {
        const value = error as {
            status?: unknown;
            message?: unknown;
            body?: unknown;
        };
        const details = {
            ...(value.status !== undefined ? { status: value.status } : {}),
            ...(value.message !== undefined ? { message: value.message } : {}),
            ...(value.body !== undefined ? { body: value.body } : {}),
        };
        if (Object.keys(details).length > 0) {
            try {
                return JSON.stringify(details);
            } catch {
                // Fall through to the safe string conversion below.
            }
        }
    }
    return error instanceof Error ? error.message : String(error);
}

const REPO_ROOT = resolve(import.meta.dir, "../..");
const DEFAULT_BOOKMARK_FILE = resolve(
    REPO_ROOT,
    "plans/favourites_17_08_2026.html",
);
const DEFAULT_CHECKPOINT = resolve(
    REPO_ROOT,
    "plans/favourites_import_results.jsonl",
);
const DEFAULT_WORKER_URL =
    process.env.MEALSTACK_WORKER_URL ??
    "https://mealstack.jimmernauts.workers.dev";

export function extractRecipeBookmarks(html: string): Bookmark[] {
    const heading = /<H3[^>]*>\s*recipe\s*<\/H3>/i.exec(html);
    if (!heading) throw new Error("Could not find the recipe bookmark folder");

    const folderStart = heading.index + heading[0].length;
    const folderEnd = html.indexOf("</DL><p>", folderStart);
    if (folderEnd < 0) {
        throw new Error("Could not find the end of the recipe bookmark folder");
    }

    const folderHtml = html.slice(folderStart, folderEnd);
    const seen = new Set<string>();
    const bookmarks: Bookmark[] = [];
    const linkPattern = /<A\s+HREF="([^"]+)"[^>]*>(.*?)<\/A>/gi;

    for (const match of folderHtml.matchAll(linkPattern)) {
        const url = normalizeBookmarkUrl(decodeHtml(match[1]));
        if (!url || seen.has(url)) continue;
        seen.add(url);
        bookmarks.push({
            index: bookmarks.length,
            title: decodeHtml(match[2].replace(/<[^>]+>/g, "")).trim() || url,
            url,
        });
    }

    return bookmarks;
}

function normalizeBookmarkUrl(value: string): string | null {
    try {
        const url = new URL(value);
        if (url.protocol !== "http:" && url.protocol !== "https:") return null;
        url.hash = "";
        return url.toString();
    } catch {
        return null;
    }
}

function decodeHtml(value: string): string {
    return value
        .replace(/&#x([0-9a-f]+);/gi, (_, hex) =>
            String.fromCodePoint(Number.parseInt(hex, 16)),
        )
        .replace(/&#(\d+);/g, (_, decimal) =>
            String.fromCodePoint(Number.parseInt(decimal, 10)),
        )
        .replace(/&amp;/g, "&")
        .replace(/&quot;/g, '"')
        .replace(/&apos;/g, "'")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">");
}

export function stableRecipeId(sourceUrl: string, slug: string): string {
    const hex = createHash("sha256")
        .update(`${sourceUrl}\n${slug}`)
        .digest("hex")
        .slice(0, 32);
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-5${hex.slice(13, 16)}-${(8 | Number.parseInt(hex[16], 16) % 4).toString(16)}${hex.slice(17, 20)}-${hex.slice(20)}`;
}

export function scrapeRecipeToFrontendRecipe(
    scrapeRecipe: ScrapeRecipe,
    sourceUrl: string,
): Recipe {
    if (!scrapeRecipe.title || !scrapeRecipe.slug) {
        throw new Error("Scraped recipe is missing title or slug");
    }

    const ingredients = Object.fromEntries(
        scrapeRecipe.ingredients.map((ingredient, index) => [
            String(index),
            normalizeIngredient(ingredient),
        ]),
    );
    const methodSteps = Object.fromEntries(
        scrapeRecipe.method_steps.map((step, index) => [
            String(index),
            { step_text: readString(step) ?? "" },
        ]),
    );

    return {
        title: scrapeRecipe.title,
        slug: scrapeRecipe.slug,
        cook_time: scrapeRecipe.cook_time,
        prep_time: scrapeRecipe.prep_time,
        serves: scrapeRecipe.serves,
        ...(scrapeRecipe.author ? { author: scrapeRecipe.author } : {}),
        source: scrapeRecipe.source || sourceUrl,
        ingredients: JSON.stringify(ingredients),
        method_steps: JSON.stringify(methodSteps),
    };
}

function normalizeIngredient(value: unknown): Record<string, unknown> {
    if (typeof value === "string") {
        return {
            name: value,
            quantity: "",
            units: "",
            ismain: "false",
            category: { name: "" },
        };
    }

    if (!value || typeof value !== "object") {
        return {
            name: String(value ?? ""),
            quantity: "",
            units: "",
            ismain: "false",
            category: { name: "" },
        };
    }

    const ingredient = value as Record<string, unknown>;
    const main = ingredient.ismain ?? ingredient.isMain;
    const category = ingredient.category;
    return {
        name: readString(ingredient.name) ?? readString(ingredient.text) ?? "",
        quantity: readString(ingredient.quantity) ?? "",
        units: readString(ingredient.units) ?? "",
        ismain:
            typeof main === "boolean"
                ? String(main)
                : readString(main) ?? "false",
        category:
            category && typeof category === "object"
                ? { name: readString((category as Record<string, unknown>).name) ?? "" }
                : { name: readString(category) ?? "" },
    };
}

function readString(value: unknown): string | undefined {
    if (typeof value === "string") return value;
    if (typeof value === "number" || typeof value === "boolean") {
        return String(value);
    }
    if (value && typeof value === "object") {
        const object = value as Record<string, unknown>;
        return (
            readString(object.step_text) ??
            readString(object.text) ??
            readString(object.name)
        );
    }
    return undefined;
}

async function scrapeWithRetries(
    bookmark: Bookmark,
    options: Options,
): Promise<ParseResult> {
    const endpoint = new URL("/api/scrape_url", options.workerUrl);
    endpoint.searchParams.set("target", bookmark.url);
    endpoint.searchParams.set("all", "true");

    let lastError = "Unknown scrape failure";
    let lastStatus: number | undefined;

    for (let attempt = 1; attempt <= options.retries + 1; attempt += 1) {
        try {
            const response = await fetch(endpoint, {
                headers: {
                    Accept: "application/json",
                    "User-Agent": "mealstack-favourites-import/1.0",
                },
                signal: AbortSignal.timeout(options.timeoutMs),
            });
            const body = await response.text();
            lastStatus = response.status;

            if (!response.ok) {
                lastError = `worker HTTP ${response.status}: ${body.slice(0, 2000)}`;
                if (!isRetryableStatus(response.status) || attempt > options.retries) {
                    return {
                        ok: false,
                        httpStatus: response.status,
                        attempts: attempt,
                        error: lastError,
                    };
                }
                await sleep(retryDelay(response, attempt, options));
                continue;
            }

            let payload: unknown;
            try {
                payload = JSON.parse(body);
            } catch {
                lastError = `worker returned non-JSON: ${body.slice(0, 2000)}`;
                if (attempt > options.retries) {
                    return { ok: false, httpStatus: response.status, attempts: attempt, error: lastError };
                }
                await sleep(retryDelay(response, attempt, options));
                continue;
            }

            if (!isScrapeResult(payload)) {
                return {
                    ok: false,
                    httpStatus: response.status,
                    attempts: attempt,
                    error: "worker returned JSON without a recipes array",
                };
            }
            if (payload.recipes.length === 0) {
                return {
                    ok: false,
                    httpStatus: response.status,
                    attempts: attempt,
                    error: `worker reported ${payload.status}: no recipes returned`,
                };
            }

            return { ok: true, httpStatus: response.status, attempts: attempt, payload };
        } catch (error) {
            lastError = error instanceof Error ? error.message : String(error);
            if (attempt > options.retries) {
                return { ok: false, httpStatus: lastStatus, attempts: attempt, error: lastError };
            }
            await sleep(options.retryDelayMs * 2 ** (attempt - 1));
        }
    }

    return { ok: false, httpStatus: lastStatus, attempts: options.retries + 1, error: lastError };
}

function isScrapeResult(value: unknown): value is ScrapeResult {
    if (!value || typeof value !== "object") return false;
    const object = value as Record<string, unknown>;
    return Array.isArray(object.recipes) && typeof object.status === "string";
}

function isRetryableStatus(status: number): boolean {
    return status === 408 || status === 429 || status >= 500;
}

function retryDelay(response: Response, attempt: number, options: Options): number {
    const retryAfter = response.headers.get("retry-after");
    if (retryAfter) {
        const seconds = Number(retryAfter);
        if (Number.isFinite(seconds)) return Math.max(0, seconds * 1000);
        const date = Date.parse(retryAfter);
        if (Number.isFinite(date)) return Math.max(0, date - Date.now());
    }
    return options.retryDelayMs * 2 ** (attempt - 1);
}

async function writeRecipes(
    db: AdminDb,
    record: CheckpointRecord,
    previousWrites: RecipeWriteResult[],
    writeAppId: string,
 ): Promise<CheckpointRecord> {
    const writes = new Map(previousWrites.map((write) => [write.recipe_key, write]));

    for (const scrapeRecipe of record.recipes ?? []) {
        let recipe: Recipe;
        try {
            recipe = scrapeRecipeToFrontendRecipe(scrapeRecipe, record.url);
        } catch (error) {
            const recipeKey = `${record.url}#${scrapeRecipe.slug || scrapeRecipe.title}`;
            writes.set(recipeKey, {
                recipe_key: recipeKey,
                entity_id: "",
                status: "failure",
                error: formatAdminError(error),
            });
            continue;
        }

        const recipeKey = `${record.url}#${recipe.slug}`;
        const entityId = stableRecipeId(record.url, recipe.slug);
        const previous = writes.get(recipeKey);
        if (previous?.status === "success") continue;

        try {
            const fields: RecipePersistenceFields = toRecipePersistenceFields(recipe);
            const transaction = await db.transact([
                db.tx.recipes[entityId].update(fields),
            ]);
            writes.set(recipeKey, {
                recipe_key: recipeKey,
                entity_id: entityId,
                status: "success",
                tx_id: transaction?.["tx-id"],
            });
        } catch (error) {
            writes.set(recipeKey, {
                recipe_key: recipeKey,
                entity_id: entityId,
                status: "failure",
                error: formatAdminError(error),
            });
        }
    }

    const writeResults = [...writes.values()];
    const failures = writeResults.filter((write) => write.status === "failure");
    return {
        ...record,
        write_app_id: writeAppId,
        write_status:
            failures.length === 0
                ? "success"
                : failures.length === writeResults.length
                  ? "failure"
                  : "partial",
        writes: writeResults,
    };
}

async function verifyAdminAccess(db: AdminDb, appId: string): Promise<void> {
    try {
        const result = await db.query({
            recipes: {
                $: {
                    fields: ["id"],
                    limit: 1,
                },
            },
        });
        console.log(
            JSON.stringify({
                event: "admin_preflight",
                app_id: appId,
                recipe_count: result.recipes?.length ?? 0,
            }),
        );
    } catch (error) {
        throw new Error(
            `InstantDB admin preflight failed for app ${appId}: ${formatAdminError(error)}`,
        );
    }
}

function validateRecipes(recipes: ScrapeRecipe[], sourceUrl: string): string[] {
    const errors: string[] = [];
    for (const recipe of recipes) {
        try {
            scrapeRecipeToFrontendRecipe(recipe, sourceUrl);
        } catch (error) {
            errors.push(error instanceof Error ? error.message : String(error));
        }
    }
    return errors;
}

class CheckpointWriter {
    private chain = Promise.resolve();

    constructor(private readonly path: string) {}

    append(record: CheckpointRecord): Promise<void> {
        this.chain = this.chain.then(() =>
            appendFile(this.path, `${JSON.stringify(record)}\n`, "utf8"),
        );
        return this.chain;
    }

    flush(): Promise<void> {
        return this.chain;
    }
}

async function loadCheckpoint(path: string): Promise<Map<string, CheckpointRecord>> {
    const latest = new Map<string, CheckpointRecord>();
    try {
        const content = await readFile(path, "utf8");
        for (const line of content.split("\n")) {
            if (!line.trim()) continue;
            try {
                const record = JSON.parse(line) as CheckpointRecord;
                if (record.kind === "url_result") {
                    latest.set(record.normalized_url, record);
                }
            } catch {
                console.warn("Ignoring malformed checkpoint line");
            }
        }
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
    return latest;
}

async function processBookmark(
    bookmark: Bookmark,
    options: Options,
    checkpoint: Map<string, CheckpointRecord>,
    writer: CheckpointWriter,
    db?: AdminDb,
): Promise<void> {
    const normalizedUrl = bookmark.url;
    const previous = checkpoint.get(normalizedUrl);

    if (
        options.write &&
        previous?.write_status === "success" &&
        previous.write_app_id === options.appId
    ) {
        console.log(`[skip] ${bookmark.index + 1}: already written ${bookmark.url}`);
        return;
    }
    if (!options.write && previous?.parse_status === "success") {
        console.log(`[skip] ${bookmark.index + 1}: already parsed ${bookmark.url}`);
        return;
    }

    let record: CheckpointRecord;
    if (previous?.parse_status === "success" && previous.recipes) {
        record = previous;
        console.log(`[reuse] ${bookmark.index + 1}: using checkpoint ${bookmark.url}`);
    } else {
        console.log(`[fetch] ${bookmark.index + 1}: ${bookmark.url}`);
        const parsed = await scrapeWithRetries(bookmark, options);
        record = {
            version: 1,
            kind: "url_result",
            index: bookmark.index,
            bookmark_title: bookmark.title,
            url: bookmark.url,
            normalized_url: normalizedUrl,
            worker_url: options.workerUrl,
            generated_at_utc: new Date().toISOString(),
            parse_status: parsed.ok ? "success" : "failure",
            http_status: parsed.httpStatus,
            attempts: parsed.attempts,
            ...(parsed.ok
                ? {
                      recipes: parsed.payload.recipes,
                      warnings: parsed.payload.warnings,
                      validation_errors: validateRecipes(parsed.payload.recipes, bookmark.url),
                  }
                : { error: parsed.error }),
        };
    }

    if (record.parse_status === "failure") {
        await writer.append(record);
        checkpoint.set(normalizedUrl, record);
        console.log(`[parse-failed] ${bookmark.url}: ${record.error}`);
        return;
    }

    if (!options.write) {
        const parseOnlyRecord = {
            ...record,
            write_status: "not_requested" as const,
        };
        await writer.append(parseOnlyRecord);
        checkpoint.set(normalizedUrl, parseOnlyRecord);
        console.log(`[parsed] ${bookmark.url}: ${record.recipes?.length ?? 0} recipe(s)`);
        return;
    }

    if (!db) throw new Error("Admin DB is required in --write mode");
    const previousWrites =
        previous?.write_app_id === options.appId ? previous.writes ?? [] : [];
    const written = await writeRecipes(
        db,
        record,
        previousWrites,
        options.appId!,
    );
    await writer.append(written);
    checkpoint.set(normalizedUrl, written);
    const failedWrites = (written.writes ?? []).filter(
        (write) => write.status === "failure",
    );
    if (failedWrites.length > 0) {
        console.error(
            JSON.stringify({
                event: "write_failures",
                app_id: options.appId,
                url: bookmark.url,
                failures: failedWrites,
            }),
        );
    }
    console.log(
        `[${written.write_status}] ${bookmark.url}: ${written.writes?.length ?? 0} recipe transaction(s)`,
    );
}

async function mapWithConcurrency<T>(
    values: T[],
    concurrency: number,
    callback: (value: T) => Promise<void>,
): Promise<void> {
    let next = 0;
    const worker = async () => {
        while (true) {
            const index = next++;
            if (index >= values.length) return;
            await callback(values[index]);
        }
    };
    await Promise.all(
        Array.from({ length: Math.min(concurrency, values.length) }, worker),
    );
}

function parseOptions(argv: string[]): Options {
    const options: Options = {
        bookmarkFile: DEFAULT_BOOKMARK_FILE,
        workerUrl: DEFAULT_WORKER_URL,
        offset: 0,
        limit: 10,
        concurrency: 2,
        timeoutMs: 240_000,
        retries: 2,
        retryDelayMs: 1_000,
        checkpoint: DEFAULT_CHECKPOINT,
        write: false,
    };

    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];
        switch (argument) {
            case "--help":
                printHelp();
                process.exit(0);
            case "--write":
            case "--commit":
                options.write = true;
                break;
            case "--bookmarks":
                options.bookmarkFile = resolve(requireValue(argv, ++index, argument));
                break;
            case "--worker-url":
                options.workerUrl = requireValue(argv, ++index, argument);
                break;
            case "--offset":
                options.offset = parseIntOption(argv, ++index, argument, 0);
                break;
            case "--limit":
                options.limit = parseIntOption(argv, ++index, argument, 1);
                break;
            case "--concurrency":
                options.concurrency = parseIntOption(argv, ++index, argument, 1);
                break;
            case "--timeout-ms":
                options.timeoutMs = parseIntOption(argv, ++index, argument, 1_000);
                break;
            case "--retries":
                options.retries = parseIntOption(argv, ++index, argument, 0);
                break;
            case "--retry-delay-ms":
                options.retryDelayMs = parseIntOption(argv, ++index, argument, 0);
                break;
            case "--checkpoint":
            case "--resume":
                options.checkpoint = resolve(requireValue(argv, ++index, argument));
                break;
            case "--app-id":
                options.appId = requireValue(argv, ++index, argument);
                break;
            default:
                throw new Error(`Unknown argument: ${argument}`);
        }
    }

    return options;
}

function requireValue(argv: string[], index: number, flag: string): string {
    const value = argv[index];
    if (!value || value.startsWith("--")) throw new Error(`${flag} requires a value`);
    return value;
}

function parseIntOption(
    argv: string[],
    index: number,
    flag: string,
    minimum: number,
): number {
    const value = Number.parseInt(requireValue(argv, index, flag), 10);
    if (!Number.isInteger(value) || value < minimum) {
        throw new Error(`${flag} must be an integer >= ${minimum}`);
    }
    return value;
}

function printHelp(): void {
    console.log(`One-off favourites importer

Default mode parses only and appends JSONL checkpoints. Add --write to transact recipes.

Options:
  --bookmarks PATH       Netscape export (default: plans/favourites_17_08_2026.html)
  --offset N             Zero-based recipe-folder offset (default: 0)
  --limit N              Number of URLs in this batch (default: 10)
  --checkpoint PATH      JSONL checkpoint/result path
  --resume PATH          Alias for --checkpoint
  --worker-url URL       Existing worker endpoint
  --write                Write successful recipes with InstantDB Admin SDK
  --app-id ID            InstantDB app ID for --write (or INSTANT_APP_ID)
  --concurrency N        Bounded URL concurrency (default: 2)
  --retries N            Retries for 408/429/5xx/transient failures (default: 2)
  --timeout-ms N         Per-request timeout (default: 240000)
`);
}

async function main(): Promise<void> {
    const options = parseOptions(process.argv.slice(2));
    const html = await readFile(options.bookmarkFile, "utf8");
    const allBookmarks = extractRecipeBookmarks(html);
    const bookmarks = allBookmarks.slice(options.offset, options.offset + options.limit);

    if (bookmarks.length === 0) {
        throw new Error("No recipe bookmarks selected for this batch");
    }

    const checkpoint = await loadCheckpoint(options.checkpoint);
    await mkdir(dirname(options.checkpoint), { recursive: true });
    const writer = new CheckpointWriter(options.checkpoint);
    let db: AdminDb | undefined;

    if (options.write) {
        const appId = options.appId ?? process.env.INSTANT_APP_ID;
        const adminToken = process.env.INSTANT_ADMIN_TOKEN;
        if (!appId) throw new Error("--write requires --app-id or INSTANT_APP_ID");
        if (!adminToken) throw new Error("--write requires INSTANT_ADMIN_TOKEN");
        options.appId = appId;
        const adminDb = init({ appId, adminToken, schema });
        db = adminDb;
        console.log(`Write mode enabled for InstantDB app ${appId}`);
        await verifyAdminAccess(adminDb, appId);
    }

    console.log(
        JSON.stringify({
            event: "batch_started",
            selected: bookmarks.length,
            total_recipe_folder_urls: allBookmarks.length,
            offset: options.offset,
            limit: options.limit,
            write: options.write,
            worker_url: options.workerUrl,
            checkpoint: options.checkpoint,
        }),
    );

    await mapWithConcurrency(bookmarks, options.concurrency, async (bookmark) => {
        await processBookmark(bookmark, options, checkpoint, writer, db);
    });
    await writer.flush();
    console.log(JSON.stringify({ event: "batch_finished", selected: bookmarks.length }));
}

function sleep(milliseconds: number): Promise<void> {
    return new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds));
}

if (import.meta.main) {
    await main().catch((error) => {
        console.error(formatAdminError(error));
        process.exitCode = 1;
    });
}

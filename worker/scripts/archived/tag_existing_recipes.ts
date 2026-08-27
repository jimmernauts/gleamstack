import { init } from "@instantdb/admin";
import { GoogleGenAI, ThinkingLevel } from "@google/genai";
import { appendFile, mkdir, readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import schema from "../../app/src/instant.schema.ts";
import {
    buildTagInstructions,
    normalizeTags,
    tagSuggestionsSchema,
    type AllowedTagOptions,
} from "../src/parse_recipe.ts";

type AdminDb = any;
type TagName = "Cuisine" | "Style" | "Label";
type Tag = { name: string; value: string };
type Tags = Record<string, Tag>;

type RecipeEntity = {
    id: string;
    title?: string;
    slug?: string;
    source?: string;
    ingredients?: unknown;
    method_steps?: unknown;
    tags?: unknown;
};

type BackfillRecord = {
    version: 1;
    prompt_version: number;
    kind: "tag_backfill";
    recipe_id: string;
    title: string;
    slug: string;
    source: string;
    existing_tags: Tags;
    missing_categories: TagName[];
    suggested_tags: Tags;
    status: "planned" | "written" | "skipped" | "failure";
    tx_id?: string;
    error?: string;
};

type Options = {
    appId?: string;
    offset: number;
    limit: number;
    concurrency: number;
    delayMs: number;
    maxRetries: number;
    report: string;
    write: boolean;
};

const REPO_ROOT = resolve(import.meta.dir, "../..");
const DEFAULT_REPORT = resolve(
    REPO_ROOT,
    "plans/favourites_tag_backfill.jsonl",
);
const TAG_NAMES: TagName[] = ["Cuisine", "Style", "Label"];
const PAGE_SIZE = 100;
const PROMPT_VERSION = 2;
const DEFAULT_REQUEST_DELAY_MS = 13_000;
const DEFAULT_MAX_RETRIES = 4;
const MAX_RETRY_DELAY_MS = 5 * 60_000;

function formatError(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
}

function serializedError(error: unknown): string {
    const formatted = formatError(error);
    try {
        return `${formatted} ${JSON.stringify(error)}`;
    } catch {
        return formatted;
    }
}

export function isRateLimitError(error: unknown): boolean {
    return /\b429\b|RESOURCE_EXHAUSTED|rate.?limit|quota exceeded/i.test(
        serializedError(error),
    );
}

export function isDailyQuotaExceeded(error: unknown): boolean {
    return /GenerateRequestsPerDay|RequestsPerDay|PerDayPerProject|daily (?:quota|limit)/i.test(
        serializedError(error),
    );
}

class DailyQuotaExceededError extends Error {
    constructor(public readonly cause: unknown) {
        super(`Gemini daily quota exhausted: ${formatError(cause)}`);
        this.name = "DailyQuotaExceededError";
    }
}

export function retryDelayMs(error: unknown, attempt: number): number {
    const match = serializedError(error).match(
        /retryDelay["']?\s*[:=]\s*["']?([\d.]+)\s*s/i,
    );
    const requestedDelay = match ? Math.ceil(Number(match[1]) * 1_000) : 0;
    if (requestedDelay > 0) {
        return Math.min(requestedDelay, MAX_RETRY_DELAY_MS);
    }
    return Math.min(5_000 * 2 ** attempt, MAX_RETRY_DELAY_MS);
}

function sleep(milliseconds: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

class RequestLimiter {
    private nextRequestAt = 0;
    private queue = Promise.resolve();

    constructor(private readonly minDelayMs: number) {}

    async wait(): Promise<void> {
        let release!: () => void;
        const previous = this.queue;
        this.queue = new Promise<void>((resolve) => {
            release = resolve;
        });
        await previous;
        try {
            const delay = this.nextRequestAt - Date.now();
            if (delay > 0) await sleep(delay);
            this.nextRequestAt = Date.now() + this.minDelayMs;
        } finally {
            release();
        }
    }
}

function parseJsonValue(value: unknown): unknown {
    if (typeof value !== "string") return value;
    try {
        return JSON.parse(value);
    } catch {
        return value;
    }
}

function readStoredTags(value: unknown): Tags {
    const parsed = parseJsonValue(value);
    const candidates = Array.isArray(parsed)
        ? parsed
        : parsed && typeof parsed === "object"
          ? Object.values(parsed)
          : [];
    const tags: Tags = {};
    for (const candidate of candidates) {
        if (!candidate || typeof candidate !== "object") continue;
        const tag = candidate as { name?: unknown; value?: unknown };
        if (typeof tag.name !== "string" || typeof tag.value !== "string") continue;
        tags[String(Object.keys(tags).length)] = {
            name: tag.name,
            value: tag.value,
        };
    }
    return tags;
}

function missingCategories(tags: Tags): TagName[] {
    const present = new Set(
        Object.values(tags).map((tag) => tag.name.trim().toLowerCase()),
    );
    return TAG_NAMES.filter((name) => !present.has(name.toLowerCase()));
}

function mergeTags(existing: Tags, suggested: Tags): Tags {
    const merged: Tags = {};
    const present = new Set<string>();
    for (const tag of [...Object.values(existing), ...Object.values(suggested)]) {
        const name = tag.name.trim();
        const key = name.toLowerCase();
        if (!name || present.has(key)) continue;
        merged[String(Object.keys(merged).length)] = { name, value: tag.value };
        present.add(key);
    }
    return merged;
}

function recipeText(recipe: RecipeEntity, existing: Tags, missing: TagName[]): string {
    const format = (value: unknown): string => {
        const parsed = parseJsonValue(value);
        return typeof parsed === "string" ? parsed : JSON.stringify(parsed ?? []);
    };
    return [
        `Title: ${recipe.title ?? ""}`,
        `Slug: ${recipe.slug ?? ""}`,
        `Source: ${recipe.source ?? ""}`,
        `Existing tags (preserve exactly): ${JSON.stringify(existing)}`,
        `Only fill these missing categories: ${missing.join(", ")}`,
        `Ingredients: ${format(recipe.ingredients)}`,
        `Method: ${format(recipe.method_steps)}`,
    ]
        .join("\n")
        .slice(0, 60_000);
}

function parseTagOptions(value: unknown): string[] {
    const parsed = parseJsonValue(value);
    return Array.isArray(parsed)
        ? parsed.filter((item): item is string => typeof item === "string")
        : [];
}

async function loadTagOptions(
    db: AdminDb,
    log: (message: string) => void,
): Promise<AllowedTagOptions> {
    const options: AllowedTagOptions = { Cuisine: [], Style: [], Label: [] };
    log("Loading existing tag options...");
    const result = await db.query({ tag_options: {} });
    for (const row of result.tag_options ?? []) {
        const rawName = typeof row.name === "string" ? row.name.trim() : "";
        const name = TAG_NAMES.find(
            (candidate) => candidate.toLowerCase() === rawName.toLowerCase(),
        );
        if (!name) continue;
        options[name] = [
            ...new Set(
                parseTagOptions(row.options)
                    .map((value) => value.trim())
                    .filter(Boolean),
            ),
        ];
    }
    return options;
}

async function loadGeminiClient(
    db: AdminDb,
    log: (message: string) => void,
): Promise<GoogleGenAI> {
    log("Loading Gemini settings...");
    const result = await db.query({ settings: { $: { limit: 1 } } });
    const apiKey = result.settings?.[0]?.api_key;
    if (!apiKey) throw new Error("No valid Gemini API key available");
    return new GoogleGenAI({ apiKey });
}

async function suggestTags(
    ai: GoogleGenAI,
    recipe: RecipeEntity,
    existing: Tags,
    missing: TagName[],
    options: AllowedTagOptions,
    limiter: RequestLimiter,
    maxRetries: number,
): Promise<Tags> {
    const prompt = [
        "Suggest metadata tags for this existing recipe.",
        "Preserve every existing tag exactly and return suggestions only for the missing categories.",
        "Be conservative: if a category is not clearly supported by the recipe, leave it blank. An empty result is better than a guess.",
        "Label is especially subjective; only assign it when the recipe itself makes that use unmistakable, not based on personal preference or a possible use case.",
        "Use only exact values from the existing options. Never invent, paraphrase, or normalize a value.",
        `Missing categories: ${missing.join(", ")}`,
        buildTagInstructions(options),
        recipeText(recipe, existing, missing),
    ].join("\n\n");
    let response: Awaited<ReturnType<typeof ai.models.generateContent>> | undefined;
    for (let attempt = 0; attempt <= maxRetries; attempt += 1) {
        await limiter.wait();
        try {
            response = await ai.models.generateContent({
                model: "gemini-3-flash-preview",
                contents: prompt,
                config: {
                    thinkingConfig: { thinkingLevel: ThinkingLevel.LOW },
                    responseMimeType: "application/json",
                    responseSchema: tagSuggestionsSchema,
                },
            });
            break;
        } catch (error) {
            if (isDailyQuotaExceeded(error)) {
                throw new DailyQuotaExceededError(error);
            }
            if (!isRateLimitError(error) || attempt === maxRetries) throw error;
            const delay = retryDelayMs(error, attempt);
            console.warn(
                `[rate-limit] ${recipe.id}: retry ${attempt + 1}/${maxRetries} in ${Math.ceil(delay / 1_000)}s`,
            );
            await sleep(delay);
        }
    }
    if (!response?.text) throw new Error("No tag response received");
    const normalized = normalizeTags(JSON.parse(response.text), options);
    const allowedMissing = new Set(missing);
    return Object.fromEntries(
        Object.entries(normalized).filter(([_, tag]) => allowedMissing.has(tag.name)),
    );
}

async function loadRecipes(db: AdminDb): Promise<RecipeEntity[]> {
    const recipes: RecipeEntity[] = [];
    for (let offset = 0; ; offset += PAGE_SIZE) {
        const result = await db.query({
            recipes: {
                $: {
                    fields: [
                        "id",
                        "title",
                        "slug",
                        "source",
                        "ingredients",
                        "method_steps",
                        "tags",
                    ],
                    limit: PAGE_SIZE,
                    offset,
                },
            },
        });
        const page = (result.recipes ?? []) as RecipeEntity[];
        recipes.push(...page);
        if (page.length < PAGE_SIZE) return recipes;
    }
}

class ReportWriter {
    private chain = Promise.resolve();

    constructor(private readonly path: string) {}

    append(record: BackfillRecord): Promise<void> {
        this.chain = this.chain.then(() =>
            appendFile(this.path, `${JSON.stringify(record)}\n`, "utf8"),
        );
        return this.chain;
    }

    flush(): Promise<void> {
        return this.chain;
    }
}

async function loadReport(path: string): Promise<Map<string, BackfillRecord>> {
    const latest = new Map<string, BackfillRecord>();
    try {
        const content = await readFile(path, "utf8");
        for (const line of content.split("\n")) {
            if (!line.trim()) continue;
            try {
                const record = JSON.parse(line) as BackfillRecord;
                if (record.kind === "tag_backfill") latest.set(record.recipe_id, record);
            } catch {
                console.warn("Ignoring malformed tag backfill report line");
            }
        }
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
    return latest;
}

async function processRecipe(
    recipe: RecipeEntity,
    options: Options,
    tagOptions: AllowedTagOptions,
    ai: GoogleGenAI,
    db: AdminDb,
    limiter: RequestLimiter,
    previous: BackfillRecord | undefined,
    writer: ReportWriter,
 ): Promise<void> {
    if (previous?.status === "written" || previous?.status === "skipped") {
        console.log(`[skip] ${recipe.id}: already ${previous.status}`);
        return;
    }

    const existingTags = readStoredTags(recipe.tags);
    const missing = missingCategories(existingTags);
    const base: BackfillRecord = {
        version: 1,
        prompt_version: PROMPT_VERSION,
        kind: "tag_backfill",
        recipe_id: recipe.id,
        title: recipe.title ?? "",
        slug: recipe.slug ?? "",
        source: recipe.source ?? "",
        existing_tags: existingTags,
        missing_categories: missing,
        suggested_tags: {},
        status: "skipped",
    };

    if (missing.length === 0) {
        await writer.append(base);
        console.log(`[skip] ${recipe.id}: all tag categories already present`);
        return;
    }

    try {
        const previousSuggestions =
            previous?.prompt_version === PROMPT_VERSION && previous.status === "planned"
                ? previous.suggested_tags
                : undefined;
        const suggested = previousSuggestions ??
            await suggestTags(
                ai,
                recipe,
                existingTags,
                missing,
                tagOptions,
                limiter,
                options.maxRetries,
            );
        const merged = mergeTags(existingTags, suggested);
        const record: BackfillRecord = {
            ...base,
            suggested_tags: suggested,
            status: options.write && Object.keys(suggested).length > 0 ? "written" : "planned",
        };

        if (options.write && Object.keys(suggested).length > 0) {
            const transaction = await db.transact(
                db.tx.recipes[recipe.id].update({ tags: JSON.stringify(merged) }),
            );
            record.tx_id = transaction?.["tx-id"];
        }
        await writer.append(record);
        console.log(
            `[${record.status}] ${recipe.id}: ${Object.keys(suggested).length} tag(s)`,
        );
    } catch (error) {
        const record: BackfillRecord = { ...base, status: "failure", error: formatError(error) };
        await writer.append(record);
        if (error instanceof DailyQuotaExceededError) {
            console.error(`[quota-exhausted] ${recipe.id}: stopping the batch`);
            throw error;
        }
        console.error(`[failure] ${recipe.id}: ${record.error}`);
    }
}

function parseOptions(argv: string[]): Options {
    const options: Options = {
        offset: 0,
        limit: 100_000,
        concurrency: 1,
        delayMs: DEFAULT_REQUEST_DELAY_MS,
        maxRetries: DEFAULT_MAX_RETRIES,
        report: DEFAULT_REPORT,
        write: false,
    };
    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];
        switch (argument) {
            case "--help":
                console.log(`Existing recipe tag backfill

Default mode suggests tags and writes a JSONL report. Add --write to update tags.

Options:
  --app-id ID          InstantDB app ID (or INSTANT_APP_ID)
  --offset N           Zero-based recipe offset (default: 0)
  --limit N            Number of recipes (default: all)
  --concurrency N      Gemini concurrency (default: 1)
  --delay-ms N         Minimum delay between requests (default: 13000)
  --max-retries N      Rate-limit retries per recipe (default: 4)
  --report PATH        JSONL report path
  --write              Update only the tags field`);
                process.exit(0);
            case "--app-id":
                options.appId = requireValue(argv, ++index, argument);
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
            case "--delay-ms":
                options.delayMs = parseIntOption(argv, ++index, argument, 0);
                break;
            case "--max-retries":
                options.maxRetries = parseIntOption(argv, ++index, argument, 0);
                break;
            case "--report":
                options.report = resolve(requireValue(argv, ++index, argument));
                break;
            case "--write":
                options.write = true;
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

async function mapWithConcurrency<T>(
    values: T[],
    concurrency: number,
    callback: (value: T) => Promise<void>,
): Promise<void> {
    let next = 0;
    let stopped = false;
    const worker = async () => {
        while (!stopped) {
            const index = next++;
            if (index >= values.length) return;
            try {
                await callback(values[index]);
            } catch (error) {
                stopped = true;
                throw error;
            }
        }
    };
    await Promise.all(
        Array.from({ length: Math.min(concurrency, values.length) }, worker),
    );
}

async function main(): Promise<void> {
    const options = parseOptions(process.argv.slice(2));
    const appId = options.appId ?? process.env.INSTANT_APP_ID;
    const adminToken = process.env.INSTANT_ADMIN_TOKEN;
    if (!appId) throw new Error("Requires --app-id or INSTANT_APP_ID");
    if (!adminToken) throw new Error("Requires INSTANT_ADMIN_TOKEN");

    const db = init({ appId, adminToken, schema });
    const allRecipes = await loadRecipes(db);
    const recipes = allRecipes.slice(options.offset, options.offset + options.limit);
    const tagOptions = await loadTagOptions(db, console.log);
    const ai = await loadGeminiClient(db, console.log);
    const previous = await loadReport(options.report);
    await mkdir(dirname(options.report), { recursive: true });
    const writer = new ReportWriter(options.report);
    const requestLimiter = new RequestLimiter(options.delayMs);

    console.log(
        JSON.stringify({
            event: "tag_backfill_started",
            app_id: appId,
            total_recipes: allRecipes.length,
            selected: recipes.length,
            offset: options.offset,
            limit: options.limit,
            write: options.write,
            request_delay_ms: options.delayMs,
            max_retries: options.maxRetries,
            report: options.report,
            tag_options: tagOptions,
        }),
    );

    try {
        await mapWithConcurrency(recipes, options.concurrency, (recipe) =>
            processRecipe(
                recipe,
                options,
                tagOptions,
                ai,
                db,
                requestLimiter,
                previous.get(recipe.id),
                writer,
            ),
        );
    } finally {
        await writer.flush();
    }
    console.log(JSON.stringify({ event: "tag_backfill_finished", selected: recipes.length }));
}

if (import.meta.main) {
    await main().catch((error) => {
        console.error(formatError(error));
        process.exitCode = 1;
    });
}

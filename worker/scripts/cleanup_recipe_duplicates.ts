import { init } from "@instantdb/admin";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import schema from "../../app/src/instant.schema.ts";
import {
    recipeIdentity,
    stableRecipeId,
    type RecipeIdentity,
} from "../../common/recipe_dedupe.ts";

type AdminDb = any;

type RecipeEntity = {
    id: string;
    slug?: string;
    title?: string;
    source?: string;
    ingredients?: unknown;
    method_steps?: unknown;
};

type DuplicateRecord = {
    id: string;
    slug: string;
    title: string;
    source: string;
    has_ingredients: boolean;
    has_method_steps: boolean;
};

type DeletionResult = {
    id: string;
    status: "deleted" | "failure" | "skipped";
    error?: string;
};

type DuplicateGroup = {
    key: string;
    confidence: RecipeIdentity["confidence"];
    slug: string;
    title: string;
    source: string;
    keep_id: string;
    delete_ids: string[];
    records: DuplicateRecord[];
    deletions?: DeletionResult[];
};

type DuplicateReport = {
    version: 1;
    generated_at_utc: string;
    app_id: string;
    total_recipes: number;
    duplicate_groups: number;
    duplicate_entities: number;
    safe_duplicate_entities: number;
    groups: DuplicateGroup[];
};

type Options = {
    appId?: string;
    reportPath: string;
    delete: boolean;
    confirm?: string;
    includeLowConfidence: boolean;
};

const REPO_ROOT = resolve(import.meta.dir, "../..");
const DEFAULT_REPORT = resolve(
    REPO_ROOT,
    "plans/favourites_duplicate_report.json",
);
const DELETE_CONFIRMATION = "DELETE_DUPLICATES";
const PAGE_SIZE = 100;

function formatError(error: unknown): string {
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

function hasContent(value: unknown): boolean {
    if (value === undefined || value === null) return false;
    if (typeof value === "string") {
        return value !== "" && value !== "null" && value !== "{}";
    }
    if (Array.isArray(value)) return value.length > 0;
    if (typeof value === "object") return Object.keys(value).length > 0;
    return true;
}

function toDuplicateRecord(recipe: RecipeEntity): DuplicateRecord {
    return {
        id: recipe.id,
        slug: String(recipe.slug ?? ""),
        title: String(recipe.title ?? ""),
        source: String(recipe.source ?? ""),
        has_ingredients: hasContent(recipe.ingredients),
        has_method_steps: hasContent(recipe.method_steps),
    };
}

function keepScore(recipe: DuplicateRecord): number {
    let score = 0;
    if (recipe.source && recipe.slug) {
        if (stableRecipeId(recipe.source, recipe.slug) === recipe.id) score += 100;
    }
    if (recipe.has_ingredients) score += 2;
    if (recipe.has_method_steps) score += 2;
    if (recipe.source) score += 1;
    return score;
}

function chooseKeeper(records: DuplicateRecord[]): DuplicateRecord {
    return [...records].sort(
        (left, right) =>
            keepScore(right) - keepScore(left) || left.id.localeCompare(right.id),
    )[0];
}

export function findDuplicateGroups(recipes: RecipeEntity[]): DuplicateGroup[] {
    const groups = new Map<
        string,
        { identity: RecipeIdentity; records: DuplicateRecord[] }
    >();

    for (const recipe of recipes) {
        if (!recipe.id) continue;
        const identity = recipeIdentity(recipe);
        if (!identity) continue;
        const existing = groups.get(identity.key);
        const record = toDuplicateRecord(recipe);
        if (existing) {
            existing.records.push(record);
        } else {
            groups.set(identity.key, { identity, records: [record] });
        }
    }

    return [...groups.values()]
        .filter(({ records }) => records.length > 1)
        .map(({ identity, records }) => {
            const keeper = chooseKeeper(records);
            return {
                key: identity.key,
                confidence: identity.confidence,
                slug: identity.slug,
                title: identity.title,
                source: identity.source,
                keep_id: keeper.id,
                delete_ids: records
                    .filter((record) => record.id !== keeper.id)
                    .map((record) => record.id),
                records,
            };
        });
}

async function loadRecipes(db: AdminDb): Promise<RecipeEntity[]> {
    const recipes: RecipeEntity[] = [];
    for (let offset = 0; ; offset += PAGE_SIZE) {
        const result = await db.query({
            recipes: {
                $: {
                    fields: [
                        "id",
                        "slug",
                        "title",
                        "source",
                        "ingredients",
                        "method_steps",
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

async function deleteDuplicates(
    db: AdminDb,
    report: DuplicateReport,
    includeLowConfidence: boolean,
 ): Promise<number> {
    let failures = 0;
    for (const group of report.groups) {
        if (group.confidence !== "source" && !includeLowConfidence) {
            group.deletions = group.delete_ids.map((id) => ({
                id,
                status: "skipped",
                error: "Non-source duplicate; pass --include-low-confidence to delete",
            }));
            continue;
        }

        group.deletions = [];
        for (const id of group.delete_ids) {
            try {
                await db.transact(db.tx.recipes[id].delete());
                group.deletions.push({ id, status: "deleted" });
            } catch (error) {
                failures += 1;
                group.deletions.push({
                    id,
                    status: "failure",
                    error: formatError(error),
                });
            }
        }
    }
    return failures;
}

function parseOptions(argv: string[]): Options {
    const options: Options = {
        reportPath: DEFAULT_REPORT,
        delete: false,
        includeLowConfidence: false,
    };

    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];
        switch (argument) {
            case "--help":
                printHelp();
                process.exit(0);
            case "--app-id":
                options.appId = requireValue(argv, ++index, argument);
                break;
            case "--report":
                options.reportPath = resolve(requireValue(argv, ++index, argument));
                break;
            case "--delete":
                options.delete = true;
                break;
            case "--confirm":
                options.confirm = requireValue(argv, ++index, argument);
                break;
            case "--include-low-confidence":
                options.includeLowConfidence = true;
                break;
            default:
                throw new Error(`Unknown argument: ${argument}`);
        }
    }

    if (options.delete && options.confirm !== DELETE_CONFIRMATION) {
        throw new Error(
            `--delete requires --confirm ${DELETE_CONFIRMATION}; run a report first`,
        );
    }
    return options;
}

function requireValue(argv: string[], index: number, flag: string): string {
    const value = argv[index];
    if (!value || value.startsWith("--")) throw new Error(`${flag} requires a value`);
    return value;
}

function printHelp(): void {
    console.log(`Recipe duplicate report and cleanup

Default mode is read-only and writes a JSON report.

Options:
  --app-id ID                  InstantDB app ID (or INSTANT_APP_ID)
  --report PATH                Report path (default: plans/favourites_duplicate_report.json)
  --delete                     Delete selected duplicate entities
  --confirm DELETE_DUPLICATES  Required with --delete
  --include-low-confidence     Also delete title/slug-only duplicate groups
`);
}

async function main(): Promise<void> {
    const options = parseOptions(process.argv.slice(2));
    const appId = options.appId ?? process.env.INSTANT_APP_ID;
    const adminToken = process.env.INSTANT_ADMIN_TOKEN;
    if (!appId) throw new Error("Requires --app-id or INSTANT_APP_ID");
    if (!adminToken) throw new Error("Requires INSTANT_ADMIN_TOKEN");

    const db = init({ appId, adminToken, schema });
    const recipes = await loadRecipes(db);
    const groups = findDuplicateGroups(recipes);
    const report: DuplicateReport = {
        version: 1,
        generated_at_utc: new Date().toISOString(),
        app_id: appId,
        total_recipes: recipes.length,
        duplicate_groups: groups.length,
        duplicate_entities: groups.reduce(
            (total, group) => total + group.delete_ids.length,
            0,
        ),
        safe_duplicate_entities: groups.reduce(
            (total, group) =>
                total +
                (group.confidence === "source" ? group.delete_ids.length : 0),
            0,
        ),
        groups,
    };

    await mkdir(dirname(options.reportPath), { recursive: true });
    await writeFile(options.reportPath, `${JSON.stringify(report, null, 2)}\n`);
    console.log(
        JSON.stringify({
            event: "duplicate_report",
            app_id: appId,
            total_recipes: report.total_recipes,
            duplicate_groups: report.duplicate_groups,
            duplicate_entities: report.duplicate_entities,
            safe_duplicate_entities: report.safe_duplicate_entities,
            report: options.reportPath,
            delete: options.delete,
        }),
    );

    if (options.delete) {
        const deletionFailures = await deleteDuplicates(
            db,
            report,
            options.includeLowConfidence,
        );
        await writeFile(options.reportPath, `${JSON.stringify(report, null, 2)}\n`);
        if (deletionFailures > 0) {
            throw new Error(`${deletionFailures} duplicate deletion(s) failed; see ${options.reportPath}`);
        }
        console.log(
            JSON.stringify({
                event: "duplicate_cleanup_finished",
                report: options.reportPath,
                deleted: report.groups.reduce(
                    (total, group) =>
                        total +
                        (group.deletions ?? []).filter(
                            (deletion) => deletion.status === "deleted",
                        ).length,
                    0,
                ),
            }),
        );
    }
}

if (import.meta.main) {
    await main().catch((error) => {
        console.error(formatError(error));
        process.exitCode = 1;
    });
}

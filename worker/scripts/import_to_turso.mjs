/**
 * Import InstantDB export JSON files into a Turso Cloud database.
 *
 * Cloud counterpart of db/scripts/import_instantdb_export.mjs (which targets
 * a local SQLite file). Same field mappings, same idempotency (INSERT OR
 * REPLACE with stable IDs), same deliberate omission of the settings
 * collection (Gemini key lives as a Worker secret).
 *
 * Usage:
 *   set -a && source .dev.vars && set +a   # TURSO_URL + TURSO_AUTH_TOKEN
 *   bun worker/scripts/import_to_turso.mjs [export-dir]
 *
 * Defaults:
 *   export-dir: plans/archive/export/
 *
 * Each collection is imported as one atomic batch. After importing, the
 * script re-queries live table counts and exits non-zero on any mismatch.
 */

import { connect } from "@tursodatabase/serverless";
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, "../..");

const url = process.env.TURSO_URL;
const authToken = process.env.TURSO_AUTH_TOKEN;
const exportDir = process.argv[2] || resolve(PROJECT_ROOT, "plans/archive/export");

if (!url || !authToken) {
  console.error("TURSO_URL and TURSO_AUTH_TOKEN must be set (set -a && source .dev.vars && set +a)");
  process.exit(1);
}
if (!existsSync(exportDir)) {
  console.error(`Export directory not found: ${exportDir}`);
  process.exit(1);
}
if (authToken.startsWith("sbx-")) {
  console.error("TURSO_AUTH_TOKEN looks like a sandbox placeholder (sbx-…) — source .dev.vars with set -a first.");
  process.exit(1);
}

function readRecords(name) {
  const filePath = resolve(exportDir, `${name}.json`);
  if (!existsSync(filePath)) return null;
  return JSON.parse(readFileSync(filePath, "utf8")).records;
}

/** Collection → batch of parameterized INSERT OR REPLACE statements. */
const COLLECTIONS = [
  {
    file: "recipes",
    table: "recipes",
    toStatement: (r) => ({
      sql: `INSERT OR REPLACE INTO recipes
              (id, slug, title, cook_time, prep_time, serves, author, source,
               ingredients, method_steps, tags, shortlisted, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))`,
      args: [
        r.id, r.slug, r.title,
        r.cook_time ?? null, r.prep_time ?? null, r.serves ?? null,
        r.author ?? null, r.source ?? null,
        r.ingredients ?? null, r.method_steps ?? null, r.tags ?? null,
        r.shortlisted ? 1 : 0,
      ],
    }),
  },
  {
    file: "tag_options",
    table: "tag_options",
    toStatement: (r) => ({
      sql: "INSERT OR REPLACE INTO tag_options (id, name, options) VALUES (?, ?, ?)",
      args: [r.id, r.name, r.options ?? null],
    }),
  },
  {
    file: "plan",
    table: "plan_days",
    toStatement: (r) => ({
      sql: "INSERT OR REPLACE INTO plan_days (id, date, lunch, dinner) VALUES (?, ?, ?, ?)",
      args: [r.id, r.date, r.lunch ?? null, r.dinner ?? null],
    }),
  },
  {
    file: "shopping_lists",
    table: "shopping_lists",
    toStatement: (r) => ({
      sql: `INSERT OR REPLACE INTO shopping_lists
              (id, date, status, items, linked_recipes, linked_plan_start, linked_plan_end)
            VALUES (?, ?, ?, ?, ?, ?, ?)`,
      args: [
        r.id, r.date, r.status,
        r.items ?? null, r.linked_recipes ?? null,
        r.linked_plan_start ?? null, r.linked_plan_end ?? null,
      ],
    }),
  },
];

console.log(`Importing from: ${exportDir}`);
console.log(`Into database:  ${url}`);
console.log("");

const conn = connect({ url, authToken });
let failed = false;

for (const { file, table, toStatement } of COLLECTIONS) {
  const records = readRecords(file);
  if (records === null) {
    console.log(`  ${table}: skipped (${file}.json not found)`);
    continue;
  }

  await conn.batch(records.map(toStatement), "write");

  const [{ n }] = await conn.all(`SELECT count(*) AS n FROM ${table}`);
  const ok = Number(n) >= records.length;
  if (!ok) failed = true;
  console.log(`  ${table}: imported ${records.length}, live count ${n} ${ok ? "✓" : "✗ MISMATCH"}`);
}

console.log("");
console.log(failed ? "Import completed WITH MISMATCHES." : "Import complete. All live counts cover the export.");
process.exit(failed ? 1 : 0);

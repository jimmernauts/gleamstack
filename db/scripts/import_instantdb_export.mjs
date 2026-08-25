/**
 * Import InstantDB export JSON files into a SQLite/Turso database.
 *
 * Usage:
 *   node --experimental-sqlite db/scripts/import_instantdb_export.mjs [db-path] [export-dir]
 *
 * Defaults:
 *   db-path:    db/local.db
 *   export-dir: plans/archive/export/
 *
 * Idempotent: uses INSERT OR REPLACE with stable IDs from the export.
 * Skips the settings collection (Gemini key moved to Worker secret).
 */

import { DatabaseSync } from "node:sqlite";
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, "../..");

/**
 * Import all collections from an export directory into the given database.
 */
export function importExport(dbPath, exportDir) {
  const db = new DatabaseSync(dbPath);
  db.exec("PRAGMA journal_mode = WAL");

  const results = {};

  // Recipes
  results.recipes = importRecipes(db, exportDir);

  // Tag options
  results.tag_options = importTagOptions(db, exportDir);

  // Plan days
  results.plan_days = importPlanDays(db, exportDir);

  // Shopping lists
  results.shopping_lists = importShoppingLists(db, exportDir);

  db.close();
  return results;
}

function importRecipes(db, exportDir) {
  const filePath = resolve(exportDir, "recipes.json");
  if (!existsSync(filePath)) return { imported: 0, skipped: true };

  const data = JSON.parse(readFileSync(filePath, "utf8"));
  const stmt = db.prepare(`
    INSERT OR REPLACE INTO recipes
      (id, slug, title, cook_time, prep_time, serves, author, source, ingredients, method_steps, tags, shortlisted, created_at, updated_at)
    VALUES
      (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
  `);

  let count = 0;
  for (const r of data.records) {
    stmt.run(
      r.id,
      r.slug,
      r.title,
      r.cook_time ?? null,
      r.prep_time ?? null,
      r.serves ?? null,
      r.author ?? null,
      r.source ?? null,
      r.ingredients ?? null,
      r.method_steps ?? null,
      r.tags ?? null,
      r.shortlisted ? 1 : 0
    );
    count++;
  }

  return { imported: count };
}

function importTagOptions(db, exportDir) {
  const filePath = resolve(exportDir, "tag_options.json");
  if (!existsSync(filePath)) return { imported: 0, skipped: true };

  const data = JSON.parse(readFileSync(filePath, "utf8"));
  const stmt = db.prepare(`
    INSERT OR REPLACE INTO tag_options (id, name, options)
    VALUES (?, ?, ?)
  `);

  let count = 0;
  for (const r of data.records) {
    stmt.run(r.id, r.name, r.options ?? null);
    count++;
  }

  return { imported: count };
}

function importPlanDays(db, exportDir) {
  const filePath = resolve(exportDir, "plan.json");
  if (!existsSync(filePath)) return { imported: 0, skipped: true };

  const data = JSON.parse(readFileSync(filePath, "utf8"));
  const stmt = db.prepare(`
    INSERT OR REPLACE INTO plan_days (id, date, lunch, dinner)
    VALUES (?, ?, ?, ?)
  `);

  let count = 0;
  for (const r of data.records) {
    stmt.run(
      r.id,
      r.date,
      r.lunch ?? null,
      r.dinner ?? null
    );
    count++;
  }

  return { imported: count };
}

function importShoppingLists(db, exportDir) {
  const filePath = resolve(exportDir, "shopping_lists.json");
  if (!existsSync(filePath)) return { imported: 0, skipped: true };

  const data = JSON.parse(readFileSync(filePath, "utf8"));
  const stmt = db.prepare(`
    INSERT OR REPLACE INTO shopping_lists
      (id, date, status, items, linked_recipes, linked_plan_start, linked_plan_end)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);

  let count = 0;
  for (const r of data.records) {
    stmt.run(
      r.id,
      r.date,
      r.status,
      r.items ?? null,
      r.linked_recipes ?? null,
      r.linked_plan_start ?? null,
      r.linked_plan_end ?? null
    );
    count++;
  }

  return { imported: count };
}

// CLI entry point
const isMain = process.argv[1] && (
  process.argv[1].endsWith("import_instantdb_export.mjs") ||
  process.argv[1] === fileURLToPath(import.meta.url)
);

if (isMain) {
  const dbPath = process.argv[2] || resolve(PROJECT_ROOT, "db/local.db");
  const exportDir = process.argv[3] || resolve(PROJECT_ROOT, "plans/archive/export");

  if (!existsSync(exportDir)) {
    console.error(`Export directory not found: ${exportDir}`);
    process.exit(1);
  }

  console.log(`Importing from: ${exportDir}`);
  console.log(`Into database:  ${dbPath}`);
  console.log("");

  const results = importExport(dbPath, exportDir);

  for (const [table, result] of Object.entries(results)) {
    if (result.skipped) {
      console.log(`  ${table}: skipped (file not found)`);
    } else {
      console.log(`  ${table}: ${result.imported} records`);
    }
  }

  console.log("\nDone.");
}

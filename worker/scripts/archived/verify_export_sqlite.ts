/**
 * Verify the InstantDB export by restoring into a disposable SQLite database.
 *
 * Usage:
 *   npx tsx worker/scripts/verify_export_sqlite.ts
 *
 * Reads from plans/archive/export/*.json, creates a temporary SQLite database,
 * inserts all records, validates constraints, and reports results.
 *
 * Requires: better-sqlite3 (npm install -D better-sqlite3 @types/better-sqlite3)
 */

import Database from "better-sqlite3";
import { createHash } from "node:crypto";
import { readFile, unlink } from "node:fs/promises";
import { resolve } from "node:path";

const EXPORT_DIR = resolve(new URL(".", import.meta.url).pathname, "../../plans/archive/export");
const TEMP_DB = resolve(EXPORT_DIR, ".verify-temp.sqlite");

// --- Schema matching architecture doc ---

const CREATE_TABLES = `
  CREATE TABLE recipes (
    id TEXT PRIMARY KEY,
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    cook_time INTEGER,
    prep_time INTEGER,
    serves INTEGER,
    author TEXT,
    source TEXT,
    ingredients TEXT,
    method_steps TEXT,
    tags TEXT,
    shortlisted INTEGER DEFAULT 0,
    created_at TEXT,
    updated_at TEXT
  );

  CREATE TABLE tag_options (
    id TEXT PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    options TEXT
  );

  CREATE TABLE plan_days (
    id TEXT PRIMARY KEY,
    date INTEGER UNIQUE NOT NULL,
    lunch TEXT,
    dinner TEXT
  );

  CREATE TABLE shopping_lists (
    id TEXT PRIMARY KEY,
    date INTEGER UNIQUE NOT NULL,
    status TEXT NOT NULL,
    items TEXT,
    linked_recipes TEXT,
    linked_plan_start INTEGER,
    linked_plan_end INTEGER
  );
`;

// --- Helpers ---

async function loadExport(collection: string) {
  const filePath = resolve(EXPORT_DIR, `${collection}.json`);
  const raw = await readFile(filePath, "utf8");
  const data = JSON.parse(raw);
  return data.records as Record<string, unknown>[];
}

async function loadManifest() {
  const raw = await readFile(resolve(EXPORT_DIR, "manifest.json"), "utf8");
  return JSON.parse(raw);
}

function jsonOrNull(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "string") return value;
  return JSON.stringify(value);
}

// --- Main ---

async function main() {
  console.log("=== Export Verification (SQLite restore) ===\n");

  // Load manifest
  const manifest = await loadManifest();
  console.log(`Manifest exported at: ${manifest.exported_at}`);
  console.log(`Expected total records: ${manifest.total_records}\n`);

  // Create disposable database
  const db = new Database(TEMP_DB);
  db.exec("PRAGMA journal_mode = WAL");
  db.exec(CREATE_TABLES);
  console.log("✓ Created temporary SQLite database with schema\n");

  const results: { collection: string; expected: number; inserted: number; status: string }[] = [];
  let totalInserted = 0;

  // --- Insert recipes ---
  {
    const records = await loadExport("recipes");
    const stmt = db.prepare(`
      INSERT INTO recipes (id, slug, title, cook_time, prep_time, serves, author, source, ingredients, method_steps, tags, shortlisted)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    let inserted = 0;
    for (const r of records) {
      stmt.run(
        r.id as string,
        r.slug as string,
        r.title as string,
        (r.cook_time as number) ?? null,
        (r.prep_time as number) ?? null,
        (r.serves as number) ?? null,
        (r.author as string) ?? null,
        (r.source as string) ?? null,
        jsonOrNull(r.ingredients),
        jsonOrNull(r.method_steps),
        jsonOrNull(r.tags),
        r.shortlisted ? 1 : 0
      );
      inserted++;
    }

    const expected = manifest.collections.recipes.count;
    results.push({
      collection: "recipes",
      expected,
      inserted,
      status: inserted === expected ? "PASS" : "FAIL",
    });
    totalInserted += inserted;
  }

  // --- Insert tag_options ---
  {
    const records = await loadExport("tag_options");
    const stmt = db.prepare(`
      INSERT INTO tag_options (id, name, options)
      VALUES (?, ?, ?)
    `);

    let inserted = 0;
    for (const r of records) {
      stmt.run(r.id as string, r.name as string, jsonOrNull(r.options));
      inserted++;
    }

    const expected = manifest.collections.tag_options.count;
    results.push({
      collection: "tag_options",
      expected,
      inserted,
      status: inserted === expected ? "PASS" : "FAIL",
    });
    totalInserted += inserted;
  }

  // --- Insert plan (as plan_days) ---
  {
    const records = await loadExport("plan");
    const stmt = db.prepare(`
      INSERT INTO plan_days (id, date, lunch, dinner)
      VALUES (?, ?, ?, ?)
    `);

    let inserted = 0;
    for (const r of records) {
      stmt.run(
        r.id as string,
        r.date as number,
        (r.lunch as string) ?? null,
        (r.dinner as string) ?? null
      );
      inserted++;
    }

    const expected = manifest.collections.plan.count;
    results.push({
      collection: "plan → plan_days",
      expected,
      inserted,
      status: inserted === expected ? "PASS" : "FAIL",
    });
    totalInserted += inserted;
  }

  // --- Insert shopping_lists ---
  {
    const records = await loadExport("shopping_lists");
    const stmt = db.prepare(`
      INSERT INTO shopping_lists (id, date, status, items, linked_recipes, linked_plan_start, linked_plan_end)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    let inserted = 0;
    for (const r of records) {
      stmt.run(
        r.id as string,
        r.date as number,
        r.status as string,
        jsonOrNull(r.items),
        jsonOrNull(r.linked_recipes),
        (r.linked_plan_start as number) ?? null,
        (r.linked_plan_end as number) ?? null
      );
      inserted++;
    }

    const expected = manifest.collections.shopping_lists.count;
    results.push({
      collection: "shopping_lists",
      expected,
      inserted,
      status: inserted === expected ? "PASS" : "FAIL",
    });
    totalInserted += inserted;
  }

  // --- Settings (excluded from SQLite — sensitive) ---
  console.log("⊘ settings: skipped (contains Gemini key, excluded from restore)\n");

  // --- Verify round-trip of a JSON field ---
  const sampleRecipe = db
    .prepare("SELECT id, slug, ingredients FROM recipes LIMIT 1")
    .get() as { id: string; slug: string; ingredients: string | null } | undefined;

  let jsonRoundTrip = "SKIP";
  if (sampleRecipe?.ingredients) {
    try {
      JSON.parse(sampleRecipe.ingredients);
      jsonRoundTrip = "PASS";
    } catch {
      jsonRoundTrip = "FAIL";
    }
  }

  // --- Hash verification ---
  let hashChecks = 0;
  let hashPassed = 0;
  for (const collection of ["recipes", "tag_options", "plan", "shopping_lists"] as const) {
    const filePath = resolve(EXPORT_DIR, `${collection}.json`);
    const raw = await readFile(filePath, "utf8");
    const hash = createHash("sha256").update(raw, "utf8").digest("hex");
    hashChecks++;
    if (hash === manifest.collections[collection].sha256) {
      hashPassed++;
    } else {
      console.log(`⚠️  Hash mismatch for ${collection}.json`);
    }
  }

  // --- Print results ---
  console.log("=== Results ===\n");
  console.log("Collection          | Expected | Inserted | Status");
  console.log("--------------------|----------|----------|-------");
  for (const r of results) {
    const col = r.collection.padEnd(20);
    const exp = String(r.expected).padEnd(9);
    const ins = String(r.inserted).padEnd(9);
    console.log(`${col}| ${exp}| ${ins}| ${r.status}`);
  }

  const settingsExpected = manifest.collections.settings?.count ?? 0;
  console.log(
    `${"settings (excluded)".padEnd(20)}| ${String(settingsExpected).padEnd(9)}| ${"—".padEnd(9)}| SKIP`
  );

  console.log("");
  console.log(`Total inserted: ${totalInserted} (expected ${manifest.total_records - settingsExpected} excl. settings)`);
  console.log(`JSON round-trip: ${jsonRoundTrip}`);
  console.log(`Hash checks: ${hashPassed}/${hashChecks} passed`);

  const allPassed =
    results.every((r) => r.status === "PASS") &&
    jsonRoundTrip !== "FAIL" &&
    hashPassed === hashChecks;

  console.log(`\n${allPassed ? "✓ VERIFICATION PASSED" : "✗ VERIFICATION FAILED"}`);

  // Cleanup
  db.close();
  try {
    await unlink(TEMP_DB);
    await unlink(TEMP_DB + "-wal").catch(() => {});
    await unlink(TEMP_DB + "-shm").catch(() => {});
    console.log("\n✓ Temporary database deleted.");
  } catch {
    console.log(`\n⚠️  Could not delete ${TEMP_DB} — remove manually.`);
  }

  process.exit(allPassed ? 0 : 1);
}

main().catch((err) => {
  console.error("Verification failed:", err);
  process.exit(1);
});

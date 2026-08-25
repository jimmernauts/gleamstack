/**
 * Apply pending SQL migrations to a local SQLite database.
 *
 * Usage:
 *   node --experimental-sqlite db/scripts/apply_migrations.mjs [db-path]
 *
 * Defaults to db/local.db. Reads db/migrations/*.sql (excluding *.down.sql),
 * checks schema_migrations for already-applied versions, and applies new ones in order.
 *
 * Uses Node 22's built-in node:sqlite — no external dependencies.
 */

import { DatabaseSync } from "node:sqlite";
import { readdirSync, readFileSync } from "node:fs";
import { resolve, basename, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = resolve(__dirname, "../migrations");

export function applyMigrations(dbPath) {
  const db = new DatabaseSync(dbPath);
  db.exec("PRAGMA journal_mode = WAL");

  // Ensure schema_migrations exists (needed for first-ever run)
  db.exec("CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY)");

  // Get already-applied versions
  const stmt = db.prepare("SELECT version FROM schema_migrations");
  const appliedVersions = new Set(stmt.all().map((r) => r.version));

  // Find migration files (exclude .down.sql)
  const files = readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith(".sql") && !f.endsWith(".down.sql"))
    .sort();

  const applied = [];
  const skipped = [];

  for (const file of files) {
    const version = basename(file, ".sql");
    if (appliedVersions.has(version)) {
      skipped.push(version);
      continue;
    }

    const sql = readFileSync(resolve(MIGRATIONS_DIR, file), "utf8");
    db.exec(sql);
    applied.push(version);
  }

  db.close();
  return { applied, skipped };
}

export function rollbackMigration(dbPath, version) {
  const downFile = resolve(MIGRATIONS_DIR, `${version}.down.sql`);
  const sql = readFileSync(downFile, "utf8");
  const db = new DatabaseSync(dbPath);
  db.exec(sql);
  db.close();
}

// CLI entry point
const isMain = process.argv[1] && (
  process.argv[1].endsWith("apply_migrations.mjs") ||
  process.argv[1] === fileURLToPath(import.meta.url)
);

if (isMain) {
  const dbPath = process.argv[2] || resolve(__dirname, "../local.db");
  console.log(`Applying migrations to: ${dbPath}`);
  const result = applyMigrations(dbPath);
  if (result.applied.length) {
    console.log(`Applied: ${result.applied.join(", ")}`);
  }
  if (result.skipped.length) {
    console.log(`Already applied: ${result.skipped.join(", ")}`);
  }
  if (!result.applied.length && !result.skipped.length) {
    console.log("No migration files found.");
  }
}

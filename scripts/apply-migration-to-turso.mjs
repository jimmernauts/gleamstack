/**
 * Apply migration SQL to a Turso Cloud database via its HTTP API.
 * No turso CLI needed — just a database URL and auth token.
 *
 * Usage:
 *   node scripts/apply-migration-to-turso.mjs <db-url> <auth-token> [migration-file]
 *
 * Examples:
 *   node scripts/apply-migration-to-turso.mjs https://gleamstack-dev-XYZ.turso.io $TURSO_TOKEN
 *   node scripts/apply-migration-to-turso.mjs $TURSO_URL $TURSO_TOKEN db/migrations/001_initial_schema.sql
 *
 * The DB URL and token can also be set via environment variables:
 *   TURSO_URL=... TURSO_TOKEN=... node scripts/apply-migration-to-turso.mjs
 */

import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, "..");

const dbUrl = process.argv[2] || process.env.TURSO_URL;
const authToken = process.argv[3] || process.env.TURSO_TOKEN;
const migrationFile = process.argv[4] || resolve(PROJECT_ROOT, "db/migrations/001_initial_schema.sql");

if (!dbUrl || !authToken) {
  console.error("Usage: node scripts/apply-migration-to-turso.mjs <db-url> <auth-token> [migration-file]");
  console.error("");
  console.error("Or set environment variables:");
  console.error("  TURSO_URL=https://your-db.turso.io TURSO_TOKEN=... node scripts/apply-migration-to-turso.mjs");
  process.exit(1);
}

const sql = readFileSync(migrationFile, "utf8");

// Split into individual statements (Turso HTTP API executes one at a time)
const statements = sql
  .split(";")
  .map((s) => s.trim())
  .filter((s) => s.length > 0 && !s.startsWith("--"));

console.log(`Applying ${migrationFile} to ${dbUrl}`);
console.log(`Statements: ${statements.length}`);
console.log("");

// Turso HTTP API: POST /v2/pipeline
const pipelineUrl = `${dbUrl}/v2/pipeline`;

const requests = statements.map((stmt) => ({
  type: "execute",
  stmt: { sql: stmt },
}));

// Add a close request at the end
requests.push({ type: "close" });

const response = await fetch(pipelineUrl, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${authToken}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({ requests }),
});

if (!response.ok) {
  const text = await response.text();
  console.error(`HTTP ${response.status}: ${text}`);
  process.exit(1);
}

const result = await response.json();

// Check for errors in results
let hasError = false;
for (let i = 0; i < result.results.length; i++) {
  const r = result.results[i];
  if (r.type === "error") {
    console.error(`Statement ${i + 1} failed: ${r.error.message}`);
    console.error(`  SQL: ${statements[i]?.substring(0, 100)}...`);
    hasError = true;
  }
}

if (hasError) {
  console.error("\nMigration failed.");
  process.exit(1);
}

console.log("Migration applied successfully.");
console.log("");

// Verify schema_migrations
const verifyResponse = await fetch(pipelineUrl, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${authToken}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    requests: [
      { type: "execute", stmt: { sql: "SELECT * FROM schema_migrations" } },
      { type: "close" },
    ],
  }),
});

if (verifyResponse.ok) {
  const verifyResult = await verifyResponse.json();
  const rows = verifyResult.results[0]?.response?.result?.rows || [];
  console.log("schema_migrations:");
  for (const row of rows) {
    console.log(`  ${row[0]?.value}`);
  }
} else {
  console.log("(Could not verify schema_migrations)");
}

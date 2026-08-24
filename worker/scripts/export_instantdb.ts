/**
 * Export all InstantDB entity groups for the Gleamstack migration.
 *
 * Usage:
 *   INSTANT_APP_ID=... INSTANT_ADMIN_TOKEN=... bun run worker/scripts/export_instantdb.ts
 *
 * Or with a .env file:
 *   cd worker && bun --env-file=.dev.vars run scripts/export_instantdb.ts
 *
 * Outputs JSON files and a validation manifest to plans/archive/export/
 */

import { init } from "@instantdb/admin";
import { createHash } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import schema from "../../app/src/instant.schema.ts";

// --- Configuration ---

const APP_ID =
  process.env.INSTANT_APP_ID || "eeaf3b82-5b5d-40c4-a29a-b68988377c3c";
const ADMIN_TOKEN = process.env.INSTANT_ADMIN_TOKEN;

if (!ADMIN_TOKEN) {
  console.error("ERROR: INSTANT_ADMIN_TOKEN is required.");
  console.error(
    "Set it in the environment or use: bun --env-file=.dev.vars run scripts/export_instantdb.ts"
  );
  process.exit(1);
}

const OUTPUT_DIR = resolve(new URL(".", import.meta.url).pathname, "../../plans/archive/export");

// --- Initialize InstantDB Admin ---

const db = init({ appId: APP_ID, adminToken: ADMIN_TOKEN, schema });

// --- Collections to export ---

const COLLECTIONS = [
  "recipes",
  "tag_options",
  "plan",
  "settings",
  "shopping_lists",
] as const;

type CollectionName = (typeof COLLECTIONS)[number];

// --- Validation rules per collection ---

function validateRecord(
  collection: CollectionName,
  record: Record<string, unknown>,
  index: number
): string[] {
  const errors: string[] = [];

  if (!record.id || typeof record.id !== "string") {
    errors.push(`[${collection}][${index}] missing or invalid id`);
  }

  switch (collection) {
    case "recipes":
      if (!record.slug || typeof record.slug !== "string") {
        errors.push(`[${collection}][${index}] missing or empty slug`);
      }
      break;
    case "tag_options":
      if (!record.name || typeof record.name !== "string") {
        errors.push(`[${collection}][${index}] missing or empty name`);
      }
      break;
    case "plan":
      if (typeof record.date !== "number") {
        errors.push(`[${collection}][${index}] missing or non-numeric date`);
      }
      break;
    case "shopping_lists":
      if (typeof record.date !== "number") {
        errors.push(`[${collection}][${index}] missing or non-numeric date`);
      }
      if (!record.status || typeof record.status !== "string") {
        errors.push(`[${collection}][${index}] missing or empty status`);
      }
      break;
    case "settings":
      // No strict validation; just ensure ID exists (covered above)
      break;
  }

  return errors;
}

// --- Main export logic ---

async function exportCollection(collection: CollectionName) {
  console.log(`  Exporting ${collection}...`);

  const query = { [collection]: {} };
  const result = await db.query(query);
  const records = (result as Record<string, unknown[]>)[collection] ?? [];

  console.log(`    → ${records.length} records`);
  return records as Record<string, unknown>[];
}

function sha256(content: string): string {
  return createHash("sha256").update(content, "utf8").digest("hex");
}

async function main() {
  console.log("=== InstantDB Export ===");
  console.log(`App ID: ${APP_ID}`);
  console.log(`Output: ${OUTPUT_DIR}`);
  console.log("");

  // Test connectivity
  console.log("Testing connection...");
  try {
    await db.query({ recipes: { $: { limit: 1 } } });
    console.log("  ✓ Connection OK\n");
  } catch (err) {
    console.error("  ✗ Connection failed:", err);
    process.exit(1);
  }

  // Ensure output directory exists
  await mkdir(OUTPUT_DIR, { recursive: true });

  const exportedAt = new Date().toISOString();
  const manifest: {
    exported_at: string;
    app_id: string;
    collections: Record<
      string,
      { count: number; sha256: string; sensitive?: boolean }
    >;
    total_records: number;
    validation_errors: string[];
  } = {
    exported_at: exportedAt,
    app_id: APP_ID,
    collections: {},
    total_records: 0,
    validation_errors: [],
  };

  // Export each collection
  for (const collection of COLLECTIONS) {
    const records = await exportCollection(collection);

    // Validate records
    for (let i = 0; i < records.length; i++) {
      const errors = validateRecord(collection, records[i], i);
      manifest.validation_errors.push(...errors);
    }

    // Check for duplicate IDs
    const ids = records.map((r) => r.id as string).filter(Boolean);
    const uniqueIds = new Set(ids);
    if (uniqueIds.size !== ids.length) {
      manifest.validation_errors.push(
        `[${collection}] duplicate IDs detected (${ids.length} total, ${uniqueIds.size} unique)`
      );
    }

    // Write the export file
    const exportData = {
      exported_at: exportedAt,
      collection,
      count: records.length,
      records,
    };

    const json = JSON.stringify(exportData, null, 2);
    const filePath = resolve(OUTPUT_DIR, `${collection}.json`);
    await writeFile(filePath, json, "utf8");

    // Record in manifest
    manifest.collections[collection] = {
      count: records.length,
      sha256: sha256(json),
      ...(collection === "settings" ? { sensitive: true } : {}),
    };
    manifest.total_records += records.length;
  }

  // Write manifest
  const manifestJson = JSON.stringify(manifest, null, 2);
  const manifestPath = resolve(OUTPUT_DIR, "manifest.json");
  await writeFile(manifestPath, manifestJson, "utf8");

  // Print summary
  console.log("\n=== Export Summary ===");
  console.log(`Exported at: ${exportedAt}`);
  console.log(`Total records: ${manifest.total_records}`);
  console.log("");
  console.log("Collection counts:");
  for (const [name, info] of Object.entries(manifest.collections)) {
    const flag = info.sensitive ? " ⚠️  SENSITIVE (gitignored)" : "";
    console.log(`  ${name}: ${info.count} records${flag}`);
  }

  if (manifest.validation_errors.length > 0) {
    console.log(`\n⚠️  Validation errors (${manifest.validation_errors.length}):`);
    for (const err of manifest.validation_errors) {
      console.log(`  - ${err}`);
    }
  } else {
    console.log("\n✓ All validation checks passed.");
  }

  console.log(`\nManifest: ${manifestPath}`);
  console.log("Done.");
}

main().catch((err) => {
  console.error("Export failed:", err);
  process.exit(1);
});

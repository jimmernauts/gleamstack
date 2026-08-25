/**
 * Tests for the InstantDB export importer.
 *
 * Run: node --experimental-sqlite --test db/scripts/import.test.mjs
 */

import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { existsSync, unlinkSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { applyMigrations } from "./apply_migrations.mjs";
import { importExport } from "./import_instantdb_export.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const TEST_DB = resolve(__dirname, "../test-import.db");
const FIXTURES_DIR = resolve(__dirname, "../fixtures");

function cleanUp() {
  if (existsSync(TEST_DB)) unlinkSync(TEST_DB);
}

describe("InstantDB export importer", () => {
  before(() => {
    cleanUp();
    applyMigrations(TEST_DB);
  });
  after(cleanUp);

  it("imports all fixture collections with correct counts", () => {
    const results = importExport(TEST_DB, FIXTURES_DIR);

    assert.equal(results.recipes.imported, 2);
    assert.equal(results.tag_options.imported, 3);
    assert.equal(results.plan_days.imported, 3);
    assert.equal(results.shopping_lists.imported, 2);
  });

  it("is idempotent (re-import does not duplicate)", () => {
    // Import again
    importExport(TEST_DB, FIXTURES_DIR);

    const db = new DatabaseSync(TEST_DB);
    const recipeCount = db.prepare("SELECT COUNT(*) as n FROM recipes").get().n;
    const tagCount = db.prepare("SELECT COUNT(*) as n FROM tag_options").get().n;
    const planCount = db.prepare("SELECT COUNT(*) as n FROM plan_days").get().n;
    const shopCount = db.prepare("SELECT COUNT(*) as n FROM shopping_lists").get().n;
    db.close();

    assert.equal(recipeCount, 2);
    assert.equal(tagCount, 3);
    assert.equal(planCount, 3);
    assert.equal(shopCount, 2);
  });

  it("preserves recipe fields correctly", () => {
    const db = new DatabaseSync(TEST_DB);
    const recipe = db.prepare("SELECT * FROM recipes WHERE slug = 'simple-pasta'").get();
    db.close();

    assert.equal(recipe.id, "test-recipe-002");
    assert.equal(recipe.title, "Simple Pasta");
    assert.equal(recipe.cook_time, 8);
    assert.equal(recipe.prep_time, 10);
    assert.equal(recipe.serves, 2);
    assert.equal(recipe.author, "Test Author");
    assert.equal(recipe.source, "Test Book");
    assert.equal(recipe.shortlisted, 1);
    // JSON fields stored as strings
    assert.ok(recipe.ingredients.includes("spaghetti"));
    assert.ok(recipe.method_steps.includes("Cook pasta"));
    assert.ok(recipe.tags.includes("Weeknight"));
  });

  it("preserves tag_options fields correctly", () => {
    const db = new DatabaseSync(TEST_DB);
    const tag = db.prepare("SELECT * FROM tag_options WHERE name = 'Cuisine'").get();
    db.close();

    assert.equal(tag.id, "tag-cuisine");
    const options = JSON.parse(tag.options);
    assert.ok(options.includes("Mediterranean"));
    assert.ok(options.includes("Italian"));
  });

  it("preserves plan_days fields correctly", () => {
    const db = new DatabaseSync(TEST_DB);
    const plan = db.prepare("SELECT * FROM plan_days WHERE date = 739507").get();
    db.close();

    assert.equal(plan.id, "plan-001");
    assert.ok(plan.lunch.includes("Rice stuffed chicken"));
    assert.ok(plan.dinner.includes("Carbo"));
  });

  it("handles plan_days with missing lunch/dinner", () => {
    const db = new DatabaseSync(TEST_DB);
    const plan = db.prepare("SELECT * FROM plan_days WHERE date = 739509").get();
    db.close();

    assert.equal(plan.id, "plan-003");
    assert.equal(plan.lunch, null);
    assert.equal(plan.dinner, null);
  });

  it("preserves shopping_lists fields correctly", () => {
    const db = new DatabaseSync(TEST_DB);
    const list = db.prepare("SELECT * FROM shopping_lists WHERE date = 739625").get();
    db.close();

    assert.equal(list.id, "shop-002");
    assert.equal(list.status, "Active");
    assert.equal(list.linked_plan_start, 739620);
    assert.equal(list.linked_plan_end, 739626);
  });
});

describe("Importer against real export", () => {
  const EXPORT_DIR = resolve(__dirname, "../../plans/archive/export");
  const REAL_DB = resolve(__dirname, "../test-real-import.db");

  before(() => {
    if (existsSync(REAL_DB)) unlinkSync(REAL_DB);
    applyMigrations(REAL_DB);
  });
  after(() => {
    if (existsSync(REAL_DB)) unlinkSync(REAL_DB);
  });

  it("imports the real export with expected counts from manifest", () => {
    if (!existsSync(resolve(EXPORT_DIR, "recipes.json"))) {
      // Skip if export not available (CI)
      return;
    }

    const results = importExport(REAL_DB, EXPORT_DIR);

    // From manifest.json: recipes=65, tag_options=3, plan=196, shopping_lists=3
    assert.equal(results.recipes.imported, 65);
    assert.equal(results.tag_options.imported, 3);
    assert.equal(results.plan_days.imported, 196);
    assert.equal(results.shopping_lists.imported, 3);
  });

  it("all recipes have valid slugs after import", () => {
    if (!existsSync(resolve(EXPORT_DIR, "recipes.json"))) return;

    const db = new DatabaseSync(REAL_DB);
    const nullSlugs = db.prepare("SELECT COUNT(*) as n FROM recipes WHERE slug IS NULL OR slug = ''").get();
    db.close();

    assert.equal(nullSlugs.n, 0);
  });
});

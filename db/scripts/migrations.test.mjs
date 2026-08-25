/**
 * Tests for the initial migration and migration runner.
 *
 * Run: node --experimental-sqlite --test db/scripts/migrations.test.mjs
 *
 * Uses Node 22 built-in test runner and node:sqlite — no external dependencies.
 */

import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { existsSync, unlinkSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { applyMigrations, rollbackMigration } from "./apply_migrations.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const TEST_DB = resolve(__dirname, "../test.db");

function cleanUp() {
  if (existsSync(TEST_DB)) unlinkSync(TEST_DB);
}

describe("001_initial_schema migration", () => {
  before(cleanUp);
  after(cleanUp);

  it("applies cleanly to a fresh database", () => {
    cleanUp();
    const result = applyMigrations(TEST_DB);
    assert.ok(result.applied.includes("001_initial_schema"));
  });

  it("is idempotent (second run skips)", () => {
    cleanUp();
    applyMigrations(TEST_DB);
    const result = applyMigrations(TEST_DB);
    assert.equal(result.applied.length, 0);
    assert.ok(result.skipped.includes("001_initial_schema"));
  });

  it("creates all expected tables", () => {
    cleanUp();
    applyMigrations(TEST_DB);
    const db = new DatabaseSync(TEST_DB);
    const tables = db
      .prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
      .all()
      .map((r) => r.name);
    db.close();

    assert.ok(tables.includes("recipes"));
    assert.ok(tables.includes("tag_options"));
    assert.ok(tables.includes("plan_days"));
    assert.ok(tables.includes("shopping_lists"));
    assert.ok(tables.includes("schema_migrations"));
  });

  it("records version in schema_migrations", () => {
    cleanUp();
    applyMigrations(TEST_DB);
    const db = new DatabaseSync(TEST_DB);
    const versions = db
      .prepare("SELECT version FROM schema_migrations")
      .all()
      .map((r) => r.version);
    db.close();

    assert.deepEqual(versions, ["001_initial_schema"]);
  });

  it("enforces unique slug on recipes", () => {
    cleanUp();
    applyMigrations(TEST_DB);
    const db = new DatabaseSync(TEST_DB);

    db.prepare("INSERT INTO recipes (id, slug, title) VALUES ('r1', 'test-slug', 'Test')").run();

    assert.throws(() => {
      db.prepare("INSERT INTO recipes (id, slug, title) VALUES ('r2', 'test-slug', 'Dupe')").run();
    });

    db.close();
  });

  it("enforces unique date on plan_days", () => {
    cleanUp();
    applyMigrations(TEST_DB);
    const db = new DatabaseSync(TEST_DB);

    db.prepare("INSERT INTO plan_days (id, date) VALUES ('p1', 20260101)").run();

    assert.throws(() => {
      db.prepare("INSERT INTO plan_days (id, date) VALUES ('p2', 20260101)").run();
    });

    db.close();
  });

  it("enforces unique date on shopping_lists", () => {
    cleanUp();
    applyMigrations(TEST_DB);
    const db = new DatabaseSync(TEST_DB);

    db.prepare("INSERT INTO shopping_lists (id, date, status) VALUES ('s1', 20260101, 'Active')").run();

    assert.throws(() => {
      db.prepare("INSERT INTO shopping_lists (id, date, status) VALUES ('s2', 20260101, 'Active')").run();
    });

    db.close();
  });

  it("stores JSON text fields without corruption", () => {
    cleanUp();
    applyMigrations(TEST_DB);
    const db = new DatabaseSync(TEST_DB);

    const ingredients = JSON.stringify([{ name: "flour", quantity: "200g" }]);
    const tags = JSON.stringify(["dinner", "quick"]);

    db.prepare("INSERT INTO recipes (id, slug, title, ingredients, tags) VALUES (?, ?, ?, ?, ?)").run(
      "r1", "test", "Test Recipe", ingredients, tags
    );

    const row = db.prepare("SELECT ingredients, tags FROM recipes WHERE id = 'r1'").get();
    assert.deepEqual(JSON.parse(row.ingredients), [{ name: "flour", quantity: "200g" }]);
    assert.deepEqual(JSON.parse(row.tags), ["dinner", "quick"]);

    db.close();
  });

  it("down migration drops all tables", () => {
    cleanUp();
    applyMigrations(TEST_DB);
    rollbackMigration(TEST_DB, "001_initial_schema");

    const db = new DatabaseSync(TEST_DB);
    const tables = db
      .prepare("SELECT name FROM sqlite_master WHERE type='table'")
      .all()
      .map((r) => r.name);
    db.close();

    assert.ok(!tables.includes("recipes"));
    assert.ok(!tables.includes("tag_options"));
    assert.ok(!tables.includes("plan_days"));
    assert.ok(!tables.includes("shopping_lists"));
    assert.ok(!tables.includes("schema_migrations"));
  });
});

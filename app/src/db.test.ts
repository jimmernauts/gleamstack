/**
 * Integration tests for recipe CRUD and subscription re-query.
 *
 * Uses Node 22 built-in `node:sqlite` with a thin async wrapper to match
 * the Turso `prepare().all()/.run()/.get()` shape used in db.ts.
 *
 * Run: cd app && npx vitest run src/db.test.ts
 */

import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

// --- Turso-compatible async wrapper for node:sqlite ---

function createTestDb() {
  const raw = new DatabaseSync(":memory:");

  // Apply the migration schema
  const migrationPath = resolve(__dirname, "../../db/migrations/001_initial_schema.sql");
  const sql = readFileSync(migrationPath, "utf-8");
  raw.exec(sql);

  // Return an object matching the Turso async API shape
  return {
    prepare(query: string) {
      const stmt = raw.prepare(query);
      return {
        all(...params: any[]) {
          return stmt.all(...params);
        },
        run(...params: any[]) {
          return stmt.run(...params);
        },
        get(...params: any[]) {
          return stmt.get(...params) ?? undefined;
        },
      };
    },
    exec(query: string) {
      raw.exec(query);
    },
    close() {
      raw.close();
    },
  };
}

// --- Import the module under test ---
// We need to mock getDb before importing db.ts

let testDb: ReturnType<typeof createTestDb>;

// Dynamic import after mocking
let dbModule: typeof import("./db");

describe("recipe repository with subscriber registry", () => {
  beforeEach(async () => {
    testDb = createTestDb();

    // Mock the turso module's getDb to return our test database
    const { vi } = await import("vitest");
    vi.doMock("./turso", () => ({
      getDb: () => Promise.resolve(testDb),
      setDbForTesting: () => {},
    }));

    // Mock the Gleam option module (used by plan functions, not recipe)
    vi.doMock("../gleam_stdlib/gleam/option.mjs", () => ({
      Option$isSome: (v: any) => v != null && v?.$gleam_variant === "Some",
      Option$Some$0: (v: any) => v?.[0],
    }));

    // Fresh import each test to get clean registry state
    dbModule = await import("./db");
  });

  afterEach(async () => {
    const { vi } = await import("vitest");
    vi.doUnmock("./turso");
    vi.doUnmock("../gleam_stdlib/gleam/option.mjs");
    vi.resetModules();
    testDb?.close();
  });

  // --- Helpers ---

  function insertRecipe(overrides: Record<string, any> = {}) {
    const defaults = {
      id: crypto.randomUUID(),
      slug: "test-recipe",
      title: "Test Recipe",
      cook_time: 30,
      prep_time: 10,
      serves: 4,
      author: null,
      source: null,
      tags: null,
      ingredients: null,
      method_steps: null,
      shortlisted: 0,
    };
    const r = { ...defaults, ...overrides };
    testDb.prepare(
      `INSERT INTO recipes (id, slug, title, cook_time, prep_time, serves, author, source, tags, ingredients, method_steps, shortlisted)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(r.id, r.slug, r.title, r.cook_time, r.prep_time, r.serves, r.author, r.source, r.tags, r.ingredients, r.method_steps, r.shortlisted);
    return r;
  }

  // --- Tests ---

  describe("do_subscribe_to_recipe_summaries", () => {
    it("fires initial query with current recipes", async () => {
      insertRecipe({ slug: "pasta", title: "Pasta" });
      insertRecipe({ slug: "salad", title: "Salad" });

      const results: unknown[] = [];
      dbModule.do_subscribe_to_recipe_summaries((r) => results.push(r));

      // Wait for async initial query
      await new Promise((r) => setTimeout(r, 10));

      expect(results).toHaveLength(1);
      const data = results[0] as any;
      expect(data.data.recipes).toHaveLength(2);
      expect(data.data.recipes.map((r: any) => r.title)).toContain("Pasta");
      expect(data.data.recipes.map((r: any) => r.title)).toContain("Salad");
    });

    it("re-fires after save_recipe", async () => {
      const results: unknown[] = [];
      dbModule.do_subscribe_to_recipe_summaries((r) => results.push(r));
      await new Promise((r) => setTimeout(r, 10));

      expect(results).toHaveLength(1);
      expect((results[0] as any).data.recipes).toHaveLength(0);

      await dbModule.do_save_recipe({
        id: "r1",
        slug: "new-recipe",
        title: "New Recipe",
        cook_time: 20,
        prep_time: 5,
        serves: 2,
      });

      await new Promise((r) => setTimeout(r, 10));

      expect(results.length).toBeGreaterThanOrEqual(2);
      const last = results[results.length - 1] as any;
      expect(last.data.recipes).toHaveLength(1);
      expect(last.data.recipes[0].title).toBe("New Recipe");
    });

    it("re-fires after delete_recipe", async () => {
      const recipe = insertRecipe({ id: "r-del", slug: "to-delete", title: "Delete Me" });

      const results: unknown[] = [];
      dbModule.do_subscribe_to_recipe_summaries((r) => results.push(r));
      await new Promise((r) => setTimeout(r, 10));

      expect((results[0] as any).data.recipes).toHaveLength(1);

      await dbModule.do_delete_recipe("r-del");
      await new Promise((r) => setTimeout(r, 10));

      const last = results[results.length - 1] as any;
      expect(last.data.recipes).toHaveLength(0);
    });

    it("does not fire after unsubscribe", async () => {
      const results: unknown[] = [];
      const unsub = dbModule.do_subscribe_to_recipe_summaries((r) => results.push(r));
      await new Promise((r) => setTimeout(r, 10));

      unsub();

      await dbModule.do_save_recipe({
        id: "r2",
        slug: "ignored",
        title: "Ignored",
        cook_time: 0,
        prep_time: 0,
        serves: 1,
      });
      await new Promise((r) => setTimeout(r, 10));

      // Should only have the initial dispatch
      expect(results).toHaveLength(1);
    });
  });

  describe("do_subscribe_to_one_recipe_by_slug", () => {
    it("fires initial query for the specific slug", async () => {
      insertRecipe({ slug: "target", title: "Target Recipe" });
      insertRecipe({ slug: "other", title: "Other Recipe" });

      const results: unknown[] = [];
      dbModule.do_subscribe_to_one_recipe_by_slug("target", (r) => results.push(r));
      await new Promise((r) => setTimeout(r, 10));

      expect(results).toHaveLength(1);
      const data = results[0] as any;
      expect(data.data.recipes).toHaveLength(1);
      expect(data.data.recipes[0].title).toBe("Target Recipe");
    });

    it("re-fires when the matching slug is saved", async () => {
      insertRecipe({ id: "r-target", slug: "target", title: "Original" });

      const results: unknown[] = [];
      dbModule.do_subscribe_to_one_recipe_by_slug("target", (r) => results.push(r));
      await new Promise((r) => setTimeout(r, 10));

      await dbModule.do_save_recipe({
        id: "r-target",
        slug: "target",
        title: "Updated Title",
        cook_time: 15,
        prep_time: 5,
        serves: 2,
      });
      await new Promise((r) => setTimeout(r, 10));

      expect(results.length).toBeGreaterThanOrEqual(2);
      const last = results[results.length - 1] as any;
      expect(last.data.recipes[0].title).toBe("Updated Title");
    });

    it("does not fire for a different slug save", async () => {
      insertRecipe({ slug: "watched", title: "Watched" });

      const results: unknown[] = [];
      dbModule.do_subscribe_to_one_recipe_by_slug("watched", (r) => results.push(r));
      await new Promise((r) => setTimeout(r, 10));

      await dbModule.do_save_recipe({
        id: "r-other",
        slug: "other-slug",
        title: "Other",
        cook_time: 0,
        prep_time: 0,
        serves: 1,
      });
      await new Promise((r) => setTimeout(r, 10));

      // Only the initial dispatch
      expect(results).toHaveLength(1);
    });

    it("fires with empty result after the recipe is deleted", async () => {
      insertRecipe({ id: "r-gone", slug: "target", title: "Will Be Deleted" });

      const results: unknown[] = [];
      dbModule.do_subscribe_to_one_recipe_by_slug("target", (r) => results.push(r));
      await new Promise((r) => setTimeout(r, 10));

      await dbModule.do_delete_recipe("r-gone");
      await new Promise((r) => setTimeout(r, 10));

      const last = results[results.length - 1] as any;
      expect(last.data.recipes).toHaveLength(0);
    });

    it("does not fire after unsubscribe", async () => {
      insertRecipe({ id: "r-unsub", slug: "target", title: "Target" });

      const results: unknown[] = [];
      const unsub = dbModule.do_subscribe_to_one_recipe_by_slug("target", (r) => results.push(r));
      await new Promise((r) => setTimeout(r, 10));

      unsub();

      await dbModule.do_save_recipe({
        id: "r-unsub",
        slug: "target",
        title: "Changed",
        cook_time: 0,
        prep_time: 0,
        serves: 1,
      });
      await new Promise((r) => setTimeout(r, 10));

      expect(results).toHaveLength(1);
    });
  });

  describe("do_save_recipe", () => {
    it("returns the recipe id", async () => {
      const result = await dbModule.do_save_recipe({
        id: "r-new",
        slug: "new",
        title: "New",
        cook_time: 10,
        prep_time: 5,
        serves: 2,
      });
      expect(result).toEqual({ id: "r-new" });
    });

    it("generates an id if none provided", async () => {
      const result = await dbModule.do_save_recipe({
        slug: "auto-id",
        title: "Auto ID",
        cook_time: 0,
        prep_time: 0,
        serves: 1,
      });
      expect(result.id).toBeDefined();
      expect(result.id.length).toBeGreaterThan(0);
    });

    it("persists all fields including JSON text", async () => {
      const tags = JSON.stringify([{ name: "Cuisine", value: "Italian" }]);
      const ingredients = JSON.stringify([{ name: "flour", quantity: "200g" }]);
      const method = JSON.stringify([{ step_text: "Mix well" }]);

      await dbModule.do_save_recipe({
        id: "r-full",
        slug: "full-recipe",
        title: "Full Recipe",
        cook_time: 45,
        prep_time: 15,
        serves: 6,
        author: "Chef",
        source: "https://example.com",
        tags,
        ingredients,
        method_steps: method,
        shortlisted: true,
      });

      const rows = testDb.prepare("SELECT * FROM recipes WHERE id = ?").all("r-full");
      expect(rows).toHaveLength(1);
      const row = rows[0] as any;
      expect(row.title).toBe("Full Recipe");
      expect(row.author).toBe("Chef");
      expect(row.shortlisted).toBe(1);
      expect(JSON.parse(row.tags)).toEqual([{ name: "Cuisine", value: "Italian" }]);
      expect(JSON.parse(row.ingredients)).toEqual([{ name: "flour", quantity: "200g" }]);
    });

    it("updates existing recipe on same id", async () => {
      await dbModule.do_save_recipe({
        id: "r-upd",
        slug: "original",
        title: "Original",
        cook_time: 10,
        prep_time: 5,
        serves: 2,
      });

      await dbModule.do_save_recipe({
        id: "r-upd",
        slug: "updated",
        title: "Updated",
        cook_time: 20,
        prep_time: 10,
        serves: 4,
      });

      const rows = testDb.prepare("SELECT * FROM recipes WHERE id = ?").all("r-upd");
      expect(rows).toHaveLength(1);
      expect((rows[0] as any).title).toBe("Updated");
    });
  });

  describe("do_delete_recipe", () => {
    it("removes the recipe from the database", async () => {
      insertRecipe({ id: "r-del2", slug: "delme", title: "Delete" });

      await dbModule.do_delete_recipe("r-del2");

      const rows = testDb.prepare("SELECT * FROM recipes WHERE id = ?").all("r-del2");
      expect(rows).toHaveLength(0);
    });

    it("does not throw for non-existent id", async () => {
      await expect(dbModule.do_delete_recipe("non-existent")).resolves.not.toThrow();
    });
  });

  describe("do_get_recipes", () => {
    it("returns all recipes ordered by created_at DESC", async () => {
      testDb.prepare(
        "INSERT INTO recipes (id, slug, title, created_at) VALUES (?, ?, ?, ?)"
      ).run("r1", "first", "First", "2024-01-01T00:00:00Z");
      testDb.prepare(
        "INSERT INTO recipes (id, slug, title, created_at) VALUES (?, ?, ?, ?)"
      ).run("r2", "second", "Second", "2024-06-01T00:00:00Z");

      const rows = await dbModule.do_get_recipes();
      expect(rows).toHaveLength(2);
      expect((rows as any[])[0].title).toBe("Second");
      expect((rows as any[])[1].title).toBe("First");
    });
  });
});

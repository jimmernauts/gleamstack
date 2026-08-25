/**
 * Database repository — SQL query and write helpers.
 *
 * Replaces the InstantDB adapter. Keeps the same exported function signatures
 * so the Gleam FFI layer doesn't need changes during the migration.
 *
 * Subscriptions are stubbed as one-shot queries for M2. M3–M5 will convert
 * each feature slice to use direct re-query after writes.
 */

import { getDb } from "./turso";
import type { Recipe, ShoppingList } from "../../common/types.ts";
import { Option$isSome, Option$Some$0 } from "../gleam_stdlib/gleam/option.mjs";

// --- Helpers ---

function generateId(): string {
  return crypto.randomUUID();
}

// --- TAG OPTIONS ---

export async function do_get_tagoptions() {
  const db = await getDb();
  const stmt = await db.prepare("SELECT id, name, options FROM tag_options");
  const rows = await stmt.all();
  return rows.map((r: any) => ({
    ...r,
    options: r.options ? JSON.parse(r.options) : [],
  }));
}

// --- RECIPES ---

export async function do_get_recipes() {
  const db = await getDb();
  const stmt = await db.prepare("SELECT * FROM recipes ORDER BY created_at DESC");
  return await stmt.all();
}

export function do_subscribe_to_recipe_summaries(
  dispatch: (result: unknown) => void
): () => void {
  // M2 stub: one-shot query, no live updates (M3 converts this)
  (async () => {
    const db = await getDb();
    const stmt = await db.prepare(
      "SELECT id, slug, title, cook_time, prep_time, serves, author, source, tags, shortlisted FROM recipes ORDER BY created_at DESC"
    );
    const rows = await stmt.all();
    dispatch({ data: { recipes: rows } });
  })();
  return () => {}; // no-op unsubscribe
}

export function do_subscribe_to_one_recipe_by_slug(
  slug: string,
  dispatch: (result: unknown) => void
): () => void {
  // M2 stub: one-shot query (M3 converts this)
  (async () => {
    const db = await getDb();
    const stmt = await db.prepare("SELECT * FROM recipes WHERE slug = ?");
    const rows = await stmt.all(slug);
    dispatch({ data: { recipes: rows } });
  })();
  return () => {};
}

export async function do_get_one_recipe_by_slug(slug: string) {
  const db = await getDb();
  const stmt = await db.prepare("SELECT * FROM recipes WHERE slug = ?");
  return await stmt.all(slug);
}

export async function do_save_recipe(recipe: Recipe) {
  const db = await getDb();
  const id = recipe.id || generateId();
  const now = new Date().toISOString();

  const stmt = await db.prepare(`
    INSERT OR REPLACE INTO recipes
      (id, slug, title, cook_time, prep_time, serves, author, source, tags, ingredients, method_steps, shortlisted, created_at, updated_at)
    VALUES
      (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE((SELECT created_at FROM recipes WHERE id = ?), ?), ?)
  `);

  await stmt.run(
    id,
    recipe.slug,
    recipe.title,
    recipe.cook_time,
    recipe.prep_time,
    recipe.serves,
    recipe.author || null,
    recipe.source || null,
    recipe.tags && recipe.tags !== "null" && recipe.tags !== "{}" ? recipe.tags : null,
    recipe.ingredients && recipe.ingredients !== "null" && recipe.ingredients !== "{}" ? recipe.ingredients : null,
    recipe.method_steps && recipe.method_steps !== "null" && recipe.method_steps !== "{}" ? recipe.method_steps : null,
    recipe.shortlisted ? 1 : 0,
    id, // for COALESCE subquery
    now, // created_at fallback
    now  // updated_at
  );

  return { id };
}

export async function do_delete_recipe(id: string) {
  const db = await getDb();
  const stmt = await db.prepare("DELETE FROM recipes WHERE id = ?");
  return await stmt.run(id);
}

// --- PLAN ---

export async function do_get_plan(startDate: number, endDate: number) {
  const db = await getDb();
  const stmt = await db.prepare(
    "SELECT id, date, lunch, dinner FROM plan_days WHERE date >= ? AND date <= ? ORDER BY date"
  );
  return await stmt.all(startDate, endDate);
}

export function do_subscribe_to_plan(
  dispatch: (result: unknown) => void,
  startDate: number,
  endDate: number
): () => void {
  // M2 stub: one-shot query (M4 converts this)
  (async () => {
    const rows = await do_get_plan(startDate, endDate);
    dispatch({ data: { plan: rows } });
  })();
  return () => {};
}

export async function do_save_plan(plan: any[]): Promise<void> {
  const db = await getDb();

  for (const day of plan) {
    const lunch = Option$isSome(day.lunch) ? Option$Some$0(day.lunch) : null;
    const dinner = Option$isSome(day.dinner) ? Option$Some$0(day.dinner) : null;

    // Find existing by date, or create new
    const findStmt = await db.prepare("SELECT id FROM plan_days WHERE date = ?");
    const existing = await findStmt.get(day.date);
    const id = existing?.id || generateId();

    const stmt = await db.prepare(`
      INSERT OR REPLACE INTO plan_days (id, date, lunch, dinner)
      VALUES (?, ?, ?, ?)
    `);
    await stmt.run(id, day.date, lunch, dinner);
  }
}

// --- SETTINGS ---
// Gemini key moved to Worker secret. These stubs maintain the FFI interface
// until the settings UI is removed in M5.

export async function do_retrieve_settings() {
  console.warn("[db] Settings removed — Gemini key is now a Worker secret");
  return "";
}

export async function do_save_settings(_api_key: string) {
  console.warn("[db] Settings removed — Gemini key is now a Worker secret");
  return {};
}

// --- SHOPPING LIST ---

export function do_subscribe_to_shopping_list_summaries(
  dispatch: (result: unknown) => void
) {
  // M2 stub: one-shot query (M5 converts this)
  (async () => {
    const db = await getDb();
    const stmt = await db.prepare(
      "SELECT id, date, status FROM shopping_lists ORDER BY date DESC"
    );
    const rows = await stmt.all();
    dispatch({ data: { shopping_lists: rows } });
  })();
  return () => {};
}

export async function do_get_shopping_list(date: number) {
  const db = await getDb();
  const stmt = await db.prepare("SELECT * FROM shopping_lists WHERE date = ?");
  return await stmt.get(date);
}

export async function do_save_shopping_list(listTuple: any) {
  const [date, status, items, linked_recipes, linked_plan_start, linked_plan_end] = listTuple;
  const db = await getDb();

  // Find existing by date, or create new
  const findStmt = await db.prepare("SELECT id FROM shopping_lists WHERE date = ?");
  const existing = await findStmt.get(date);
  const id = existing?.id || generateId();

  const stmt = await db.prepare(`
    INSERT OR REPLACE INTO shopping_lists
      (id, date, status, items, linked_recipes, linked_plan_start, linked_plan_end)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);

  await stmt.run(
    id,
    date,
    status,
    items,
    linked_recipes,
    linked_plan_start || null,
    linked_plan_end || null
  );

  return { id };
}

export function do_subscribe_to_one_shoppinglist_by_date(
  date: number,
  dispatch: (result: unknown) => void
) {
  // M2 stub: one-shot query (M5 converts this)
  (async () => {
    const row = await do_get_shopping_list(date);
    dispatch({ data: { shopping_lists: row ? [row] : [] } });
  })();
  return () => {};
}

export async function do_delete_shopping_list(id: string) {
  const db = await getDb();
  const stmt = await db.prepare("DELETE FROM shopping_lists WHERE id = ?");
  return await stmt.run(id);
}

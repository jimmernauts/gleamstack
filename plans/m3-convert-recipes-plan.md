# M3: Convert recipes locally — Implementation plan

## Goal

Convert recipe list, detail, save, and delete to use direct re-query after local SQL writes, replacing the M2 one-shot subscription stubs. The Gleam FFI signatures stay identical. After this milestone, recipe screens update immediately after writes without relying on any external sync or reactive subscription layer.

## Current state (after M2)

| Component | State |
|---|---|
| `app/src/db.ts` | SQL queries work; subscriptions are one-shot stubs that query once then return a no-op unsubscribe |
| `app/src/turso.ts` | Singleton OPFS connection with schema-version check and cloud bootstrap |
| `app/src/shared/db.gleam` | FFI bindings — calls `do_subscribe_to_recipe_summaries`, `do_subscribe_to_one_recipe_by_slug`, `do_save_recipe`, `do_delete_recipe` |
| `app/src/pages/recipe_list.gleam` | Subscribes to summaries + individual recipes via callback; decodes `{ data: { recipes: [...] } }` |
| `app/src/pages/recipe_detail.gleam` | Calls `do_save_recipe` (fire-and-forget), dispatches `DbSavedUpdatedRecipe` locally |
| `app/src/app.gleam` | On save → merges recipe into list model + navigates to detail. On delete → navigates to `/recipes` |

## Design

### Callback registry pattern

Introduce a simple **subscriber registry** in `db.ts`:

```
subscriberRegistry = {
  recipeSummaries: Set<(result) => void>,
  recipeBySlug: Map<slug, Set<(result) => void>>
}
```

- `do_subscribe_to_recipe_summaries(callback)` registers the callback in the set, fires an initial query, and returns an unsubscribe that removes it.
- `do_subscribe_to_one_recipe_by_slug(slug, callback)` registers under the slug key, fires an initial query, and returns an unsubscribe that removes it.
- `do_save_recipe(recipe)` performs the INSERT/REPLACE, then re-queries and dispatches to all summary subscribers + the saved recipe's slug subscribers.
- `do_delete_recipe(id)` performs the DELETE, then re-queries and dispatches to all summary subscribers.

This keeps behaviour local to `db.ts` and avoids needing changes in the Gleam layer.

### FFI shapes preserved

| Function | Signature (unchanged) | Return |
|---|---|---|
| `do_subscribe_to_recipe_summaries` | `(dispatch: (result) => void) => () => void` | unsubscribe function |
| `do_subscribe_to_one_recipe_by_slug` | `(slug: string, dispatch: (result) => void) => () => void` | unsubscribe function |
| `do_save_recipe` | `(recipe: JsRecipe) => Nil` | void (fire-and-forget from Gleam's view) |
| `do_delete_recipe` | `(id: string) => Nil` | void |

The dispatch envelope stays `{ data: { recipes: [...] } }` — Gleam decoders don't change.

### Why this works without a general subscription layer

The architecture doc says: "After a local write, that feature directly updates or re-queries its current screen." The registry is scoped to recipes only — no framework-level pub/sub. M4 and M5 will add their own if needed, following the same pattern.

Navigation already re-subscribes on route change (the Gleam layer calls `subscribe_to_one_recipe_by_slug` when entering detail view). The registry ensures the list view updates without navigation.

## Step-by-step plan

### Step 1: Add the subscriber registry and convert subscriptions (s-7946)

**File: `app/src/db.ts`**

1. Add a registry module-scoped:
   ```ts
   const recipeSummarySubscribers = new Set<(result: unknown) => void>();
   const recipeSlugSubscribers = new Map<string, Set<(result: unknown) => void>>();
   ```

2. Rewrite `do_subscribe_to_recipe_summaries`:
   - Add `dispatch` to `recipeSummarySubscribers`
   - Fire initial query → dispatch `{ data: { recipes: rows } }`
   - Return unsubscribe that removes from set

3. Rewrite `do_subscribe_to_one_recipe_by_slug`:
   - Add `dispatch` to `recipeSlugSubscribers.get(slug)` (create set if missing)
   - Fire initial query → dispatch `{ data: { recipes: rows } }`
   - Return unsubscribe that removes from the slug's set (delete key if empty)

4. Add internal helpers:
   ```ts
   async function notifyRecipeSummarySubscribers(): Promise<void>
   async function notifyRecipeSlugSubscribers(slug: string): Promise<void>
   ```

### Step 2: Wire writes to re-notify (s-7946 continued)

**File: `app/src/db.ts`**

1. In `do_save_recipe`: after the INSERT/REPLACE, call:
   - `notifyRecipeSummarySubscribers()`
   - `notifyRecipeSlugSubscribers(recipe.slug)`

2. In `do_delete_recipe`: look up the recipe's slug before delete (need it for slug subscribers), then after DELETE call:
   - `notifyRecipeSummarySubscribers()`
   - `notifyRecipeSlugSubscribers(deletedSlug)` (with empty result)

### Step 3: Preserve FFI shapes (s-7947)

No Gleam files change. Verify by confirming:
- `shared/db.gleam` still compiles with unchanged `@external` declarations
- `recipe_list.gleam` and `recipe_detail.gleam` decode the same envelope
- `app.gleam` route/subscription logic unchanged

### Step 4: Verify direct re-query behaviour (s-7948)

Manual verification sequence:
1. Open recipe list → recipes load
2. Navigate to a recipe detail → detail loads
3. Edit and save → list updates immediately (no page reload)
4. Delete a recipe → list updates immediately
5. Create a new recipe → list includes it immediately

### Step 5: Integration tests (s-7949)

**File: `app/src/db.test.ts`** (new)

Use `@tursodatabase/database` (in-memory) to test the repository logic without OPFS:

```ts
// Test: subscribe → initial data arrives
// Test: subscribe summaries → save recipe → callback fires again with updated data
// Test: subscribe by slug → save that recipe → callback fires with updated recipe
// Test: subscribe summaries → delete recipe → callback fires without deleted recipe
// Test: unsubscribe → save → callback does NOT fire
// Test: save recipe returns { id } and persists all fields
// Test: delete non-existent id does not throw
```

**Approach**: The tests need a way to inject a mock/local database. Add an internal `setDbForTesting(db)` escape hatch that overrides the `getDb()` singleton. This is test-only and does not affect production code.

## Files changed

| File | Change |
|---|---|
| `app/src/db.ts` | Add registry, rewrite subscribe functions, wire writes to re-notify |
| `app/src/db.test.ts` | New — integration tests for recipe CRUD + subscription re-query |
| `app/src/turso.ts` | Add `setDbForTesting()` export (test-only escape hatch) |

## Files NOT changed

| File | Reason |
|---|---|
| `app/src/shared/db.gleam` | FFI signatures preserved |
| `app/src/pages/recipe_list.gleam` | Decoding and message handling unchanged |
| `app/src/pages/recipe_detail.gleam` | Save/delete calls unchanged |
| `app/src/app.gleam` | Routing and subscription management unchanged |
| `db/migrations/*` | No schema changes |

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Re-query after write adds latency to the save path | Acceptable — local SQLite queries are <1ms; the user already waits for the navigation effect |
| Subscriber sets leak if unsubscribe is never called | Gleam's `RecipeListSubscriptionOpened` stores unsubscribe in `db_subscriptions` dict; route changes clean up. Add a defensive log if registry grows unexpectedly. |
| `@tursodatabase/database` API differs from `sync-wasm` | Both expose `prepare().all()/.run()/.get()` — verified in M1 spike. Pin test dep version. |
| Notification during initial load race | Initial query is awaited before dispatching; registry notify is async but ordered per-write. No concurrent writers in single-user app. |

## Success criteria

- [ ] Recipe list updates after save without page reload
- [ ] Recipe list updates after delete without page reload
- [ ] Recipe detail reflects saved changes immediately
- [ ] All integration tests pass
- [ ] Gleam compilation succeeds with zero FFI changes
- [ ] App loads and displays recipes after a fresh page reload

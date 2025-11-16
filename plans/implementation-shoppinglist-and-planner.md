# Shopping List and Planner Integration - Implementation Plan

## Overview

This plan implements a comprehensive shopping list feature with deep integration into the meal planner, allowing users to manage shopping lists, link recipes, and sync with their meal plans.

## Phase 1: Type System Updates

### 1.1 Add PlannedRecipe Type (shared/types.gleam)

```gleam
pub type PlannedRecipe {
  RecipeId(String)
  RecipeName(String)
}
```

### 1.2 Update PlannedMealWithStatus (domains/planner.gleam)

Change from:

```gleam
pub type PlannedMealWithStatus {
  PlannedMealWithStatus(
    for: Meal,
    title: Option(String),
    complete: Option(Bool),
  )
}
```

To:

```gleam
pub type PlannedMealWithStatus {
  PlannedMealWithStatus(
    for: Meal,
    recipe: Option(PlannedRecipe),
    complete: Option(Bool),
  )
}
```

### 1.3 Add IngredientSource Type (domains/shoppinglist.gleam)

```gleam
pub type IngredientSource {
  ManualEntry
  FromRecipe(recipe_ref: ShoppingListRecipeLink)
}

pub type ShoppingListIngredient {
  ShoppingListIngredient(
    ingredient: types.Ingredient,
    source: IngredientSource,
    checked: Bool,
  )
}
```

### 1.4 Update ShoppingList Type (domains/shoppinglist.gleam)

Change from:

```gleam
pub type ShoppingList {
  ShoppingList(
    id: Option(String),
    items: List(types.Ingredient),
    status: Status,
    date: date.Date,
    linked_recipes: List(ShoppingListRecipeLink),
    linked_plan: Option(date.Date),
  )
}
```

To:

```gleam
pub type ShoppingList {
  ShoppingList(
    id: Option(String),
    items: List(ShoppingListIngredient),
    status: Status,
    date: date.Date,
    linked_recipes: List(ShoppingListRecipeLink),
    linked_plan: Option(date.Date),
  )
}
```

## Phase 2: Database Schema

### 2.1 InstantDB Schema (db.ts or schema definition)

```typescript
// Shopping List Schema
{
  shopping_lists: {
    id: string,
    date: number, // rata_die format
    status: "Active" | "Completed" | "Archived",
    linked_plan_date: number | null, // rata_die format
  },
  shopping_list_items: {
    id: string,
    shopping_list_id: string,
    ingredient_name: string,
    ingredient_quantity: string | null,
    ingredient_units: string | null,
    ingredient_category: string | null,
    ingredient_ismain: boolean | null,
    source_type: "manual" | "recipe",
    source_recipe_id: string | null,
    source_recipe_name: string | null,
    checked: boolean,
  },
  shopping_list_recipes: {
    id: string,
    shopping_list_id: string,
    recipe_id: string | null, // null if NamedRecipe
    recipe_name: string,
  }
}
```

### 2.2 Database Functions (db.ts)

- `do_save_shopping_list(list: ShoppingList)`
- `do_retrieve_shopping_lists()`
- `do_get_shopping_list_by_date(date: Int)`
- `do_subscribe_to_shopping_list(callback, date: Int)`
- `do_get_recipe_ingredients(recipe_id: String)`
- `do_sync_plan_to_shopping_list(plan_date: Int, list_date: Int)`

## Phase 3: Routing Updates

### 3.1 Add New Routes (app.gleam)

```gleam
pub type Route {
  // ... existing routes
  ViewShoppingList  // List all shopping lists
  ViewShoppingListDetail(date: date.Date)  // View single list by date
  EditShoppingList(date: date.Date)  // Edit single list by date
}
```

### 3.2 Update on_route_change Function

```gleam
_, ["shopping-list"] -> OnRouteChange(ViewShoppingList)
_, ["shopping-list", date_str] ->
  OnRouteChange(ViewShoppingListDetail(parse_date_or_today(date_str)))
_, ["shopping-list", date_str, "edit"] ->
  OnRouteChange(EditShoppingList(parse_date_or_today(date_str)))
```

## Phase 4: Shopping List Views

### 4.1 List View (view_all_shopping_lists)

**Features:**

- Display all shopping lists grouped by status (Active, Completed, Archived)
- Show date, number of items, number of linked recipes
- Status toggle buttons for each list
- "Create New List" button
- Link to detail view for each list
- Link to planner with "Create from Plan" option

**Layout:**

```
┌─────────────────────────────────────┐
│ Shopping Lists                      │
├─────────────────────────────────────┤
│ [+ New List] [Create from Plan]     │
│                                     │
│ Active Lists:                       │
│ ┌─────────────────────────────────┐ │
│ │ Nov 18, 2025                    │ │
│ │ 12 items • 3 recipes            │ │
│ │ [View] [Edit] [✓][📦][🗄️]       │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Completed Lists:                    │
│ ┌─────────────────────────────────┐ │
│ │ Nov 11, 2025                    │ │
│ │ 8 items • 2 recipes             │ │
│ │ [View]                          │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### 4.2 Detail View (view_shopping_list_detail)

**Features:**

- Display list date and status
- Show linked plan (if any) with link to planner
- List all linked recipes with their source (ID or name)
- Display ingredients grouped by recipe source
- Show manual ingredients separately
- Checkbox for each ingredient
- Edit button to go to edit view
- Link to sync with plan (if linked)

**Layout:**

```
┌─────────────────────────────────────┐
│ Shopping List - Nov 18, 2025        │
│ Status: Active                       │
│ Linked to: Week of Nov 18 [View]    │
├─────────────────────────────────────┤
│ Linked Recipes:                      │
│ • Spaghetti Carbonara (ID: abc123)  │
│ • Chicken Stir Fry (Name only)      │
│                                      │
│ Ingredients:                         │
│ From Spaghetti Carbonara:            │
│ ☐ 400g Pasta                         │
│ ☐ 200g Bacon                         │
│                                      │
│ From Chicken Stir Fry:               │
│ ☐ 500g Chicken breast                │
│ ☐ Mixed vegetables                   │
│                                      │
│ Manual Entries:                      │
│ ☐ Milk                               │
│ ☐ Bread                              │
├─────────────────────────────────────┤
│ [🏠] [Edit] [Sync with Plan]        │
└─────────────────────────────────────┘
```

### 4.3 Edit View (edit_shopping_list)

**Features:**

- Edit list date
- Change status
- Link/unlink plan
- Add linked recipes:
  - Manual text entry for recipe name
  - Typeahead lookup for recipe by title
- For each linked recipe:
  - Button to "Add ingredients from this recipe"
  - Remove recipe button
- Add/edit/remove individual ingredients
- Mark ingredient source (manual or from which recipe)
- Save button

**Layout:**

```
┌─────────────────────────────────────┐
│ Edit Shopping List                   │
├─────────────────────────────────────┤
│ Date: [Nov 18, 2025]                │
│ Status: [Active ▼]                   │
│ Linked Plan: [Week of Nov 18 ▼]     │
│                                      │
│ Linked Recipes:                      │
│ ┌─────────────────────────────────┐ │
│ │ Spaghetti Carbonara             │ │
│ │ [Add Ingredients] [Remove]      │ │
│ └─────────────────────────────────┘ │
│ [+ Add Recipe (Name)]                │
│ [+ Find Recipe (Lookup)]             │
│                                      │
│ Ingredients:                         │
│ ┌─────────────────────────────────┐ │
│ │ Name: [Pasta]                   │ │
│ │ Qty: [400] Units: [g]           │ │
│ │ Source: Spaghetti Carbonara     │ │
│ │ [Remove]                        │ │
│ └─────────────────────────────────┘ │
│ [+ Add Ingredient]                   │
│                                      │
│ [Cancel] [Save]                      │
└─────────────────────────────────────┘
```

## Phase 5: Planner Updates

### 5.1 Update Planner Types and Functions

- Modify all functions that work with `PlannedMealWithStatus.title` to use `recipe`
- Update encoders/decoders to handle `PlannedRecipe` type
- Update view functions to display recipe name (extract from RecipeId or RecipeName)
- Update input functions to create `PlannedRecipe` from typeahead input

### 5.2 Add Shopping List Integration to Planner

**In view_planner:**

- Add button "Create Shopping List from This Week"
- If shopping list exists for this week, show link to it

**In edit_planner:**

- Keep existing functionality but use new `PlannedRecipe` type

## Phase 6: Plan-Shopping List Sync

### 6.1 Sync Logic

When a plan is linked to a shopping list:

1. Monitor changes to the plan's `PlannedMealWithStatus` entries
2. When recipes are added/removed from plan:
   - Add/remove corresponding `ShoppingListRecipeLink` entries
3. Maintain bidirectional reference:
   - Plan stores which shopping list it's linked to
   - Shopping list stores which plan it's linked to

### 6.2 Create from Plan Flow

1. User clicks "Create Shopping List from Plan" in planner
2. System creates new `ShoppingList` with:
   - `date` = plan start date
   - `status` = Active
   - `linked_plan` = Some(plan start date)
   - `linked_recipes` = all recipes from plan (both RecipeId and RecipeName)
   - `items` = empty list (user adds ingredients manually)
3. Navigate to edit view of new shopping list

### 6.3 Link Existing List to Plan

1. In shopping list edit view, select plan from dropdown
2. System copies all recipe references from plan to shopping list
3. Establishes bidirectional link
4. Future changes to plan recipes sync to shopping list

## Phase 7: Message Types

### 7.1 New ShoppingListMsg Variants

```gleam
pub type ShoppingListMsg {
  // Existing
  UserSavedCurrentList
  UserCreatedList
  UserUpdatedCurrentList(ShoppingList)
  UserRetrievedShoppingLists(List(ShoppingList))

  // New
  UserSelectedListByDate(date.Date)
  UserToggledListStatus(date.Date, Status)
  UserAddedLinkedRecipe(ShoppingListRecipeLink)
  UserRemovedLinkedRecipe(String) // recipe id or name
  UserAddedIngredientFromRecipe(String) // recipe id
  UserAddedManualIngredient(types.Ingredient)
  UserUpdatedIngredient(Int, ShoppingListIngredient) // index, new value
  UserRemovedIngredient(Int) // index
  UserToggledIngredientChecked(Int, Bool)
  UserLinkedPlan(date.Date)
  UserUnlinkedPlan
  UserCreatedListFromPlan(date.Date)
  UserSyncedWithPlan
  DbRetrievedListByDate(Option(ShoppingList))
  DbRetrievedRecipeIngredients(String, List(types.Ingredient)) // recipe_id, ingredients
}
```

### 7.2 New PlannerMsg Variants

```gleam
pub type PlannerMsg {
  // Existing messages...

  // New
  UserCreatedShoppingListFromPlan(date.Date)
  UserNavigatedToLinkedShoppingList(date.Date)
}
```

## Phase 8: Implementation Order

1. **Phase 1: Type Updates** (1-2 hours)

   - Add PlannedRecipe type
   - Update PlannedMealWithStatus
   - Add ingredient source tracking types
   - Update all type references

2. **Phase 2: Database Schema** (2-3 hours)

   - Define InstantDB schema
   - Implement database functions
   - Test database operations

3. **Phase 3: Planner Migration** (3-4 hours)

   - Update planner to use PlannedRecipe
   - Update encoders/decoders
   - Update all view and update functions
   - Test planner still works

4. **Phase 4: Routing** (1 hour)

   - Add new routes
   - Update route parsing
   - Update navigation

5. **Phase 5: Shopping List List View** (2-3 hours)

   - Implement view_all_shopping_lists
   - Add status toggle functionality
   - Add create new list button
   - Test list display

6. **Phase 6: Shopping List Detail View** (2-3 hours)

   - Implement view_shopping_list_detail
   - Display linked recipes and ingredients
   - Add ingredient checkboxes
   - Test detail view

7. **Phase 7: Shopping List Edit View** (4-5 hours)

   - Implement edit_shopping_list
   - Add manual recipe entry
   - Add recipe lookup with typeahead
   - Add ingredient management
   - Add "add ingredients from recipe" functionality
   - Test edit operations

8. **Phase 8: Plan-Shopping List Integration** (3-4 hours)

   - Add "Create from Plan" button to planner
   - Implement create from plan flow
   - Implement link existing list to plan
   - Implement bidirectional sync
   - Test integration

9. **Phase 9: Testing** (2-3 hours)
   - Write unit tests for update functions
   - Write snapshot tests for views
   - Test sync functionality
   - Test edge cases

**Total Estimated Time: 20-28 hours**

## Phase 9: Testing Strategy

### Unit Tests

- `test/unit/shoppinglist_test.gleam`

  - Test adding/removing ingredients
  - Test linking/unlinking recipes
  - Test status changes
  - Test plan linking logic

- `test/unit/planner_test.gleam`
  - Test PlannedRecipe creation
  - Test update functions with new type

### Snapshot Tests

- `test/snapshot/shoppinglist_view_test.gleam`
  - Snapshot list view with various states
  - Snapshot detail view with ingredients
  - Snapshot edit view

### Integration Tests

- Test plan-to-shopping-list sync
- Test creating shopping list from plan
- Test ingredient addition from recipe

## Notes and Considerations

1. **Data Migration**: Existing plans with `title: Option(String)` need migration to `recipe: Option(PlannedRecipe)`. Consider migration function.

2. **Performance**: Loading recipe ingredients may require multiple DB calls. Consider caching or batch loading.

3. **UX**: When adding ingredients from a recipe, should they be editable? Should quantities be adjustable?

4. **Conflict Resolution**: If plan and shopping list get out of sync, how to handle? Manual sync button gives user control.

5. **Recipe Deletion**: What happens if a recipe linked by ID is deleted? Handle gracefully.

6. **Date Uniqueness**: Enforce one shopping list per date at DB or app level?

7. **Offline Support**: Consider how InstantDB handles offline edits and conflicts.

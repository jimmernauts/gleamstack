# Shopping List and Planner Integration - Implementation Plan

> [!IMPORTANT]
> **Last Updated**: 2025-11-18
> 
> **Current Status**: Types and basic structure are complete. Database layer is functional. Views are scaffolded but need enhancement. Integration features are not yet implemented.

## Overview

This plan implements a comprehensive shopping list feature with deep integration into the meal planner, allowing users to manage shopping lists, link recipes, and sync with their meal plans.

### What's Already Done ✅

1. **Type System** - All core types are defined and working
2. **Database Layer** - Basic CRUD operations are functional
3. **Routing** - Routes exist for list view and detail view
4. **Basic Views** - Scaffolded views for list, detail, and edit (need enhancement)
5. **Planner Migration** - Already uses `PlannedRecipe` type

### What Needs to Be Done 🔨

1. **Enhanced List View** - Add status toggle buttons, better UI
2. **Enhanced Detail View** - Show linked recipes, better ingredient display
3. **Edit View** - Full implementation of inline editing
4. **Recipe Lookup** - Add typeahead for finding recipes
5. **Ingredient Management** - Add ingredients from recipes, manual entry
6. **Plan Integration** - Create list from plan, link existing list to plan
7. **Sync Functionality** - Bidirectional sync between plan and shopping list

## Phase 1: Type System Updates ✅ COMPLETE

> All type system updates are complete and working in production.

### 1.1 ✅ PlannedRecipe Type ([shared/types.gleam](file:///home/ubuntu/projects/gleamstack/client/src/shared/types.gleam#L46-L49))

 Already implemented:
```gleam
pub type PlannedRecipe {
  RecipeId(String)
  RecipeName(String)
}
```

### 1.2 ✅ PlannedMealWithStatus ([domains/planner.gleam](file:///home/ubuntu/projects/gleamstack/client/src/domains/planner.gleam#L36-L42))

Already using the updated type:

```gleam
pub type PlannedMealWithStatus {
  PlannedMealWithStatus(
    for: Meal,
    recipe: Option(PlannedRecipe),  // ✅ Already using this
    complete: Option(Bool),
  )
}
```

~~Old implementation~~ (already migrated):
```gleam
// title: Option(String),  // No longer used
```

### 1.3 ✅ IngredientSource and ShoppingListIngredient ([domains/shoppinglist.gleam](file:///home/ubuntu/projects/gleamstack/client/src/domains/shoppinglist.gleam#L47-L58))

Already implemented:
```gleam
pub type IngredientSource {
  ManualEntry
  FromRecipe(recipe_ref: types.PlannedRecipe)  // Note: Using PlannedRecipe not ShoppingListRecipeLink
}

pub type ShoppingListIngredient {
  ShoppingListIngredient(
    ingredient: types.Ingredient,
    source: IngredientSource,
    checked: Bool,
  )
}
```

### 1.4 ✅ ShoppingList Type ([domains/shoppinglist.gleam](file:///home/ubuntu/projects/gleamstack/client/src/domains/shoppinglist.gleam#L60-L68))

Already using the updated type:

```gleam
pub type ShoppingList {
  ShoppingList(
    id: Option(String),
    items: List(ShoppingListIngredient),  // ✅ Already updated
    status: Status,
    date: date.Date,
    linked_recipes: List(types.PlannedRecipe),  // ✅ Using PlannedRecipe
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

## Phase 2: Database Schema ✅ COMPLETE

> Database schema is defined and all basic CRUD functions are implemented in [`db.ts`](file:///home/ubuntu/projects/gleamstack/client/src/db.ts#L226-L290).

### 2.1 ✅ InstantDB Schema

The schema is defined in [`instant.schema.ts`](file:///home/ubuntu/projects/gleamstack/client/src/instant.schema.ts). Shopping lists store items and linked_recipes as JSON strings.

**Current structure:**
```typescript
shopping_lists: {
  id: string,
  date: number,  // rata_die format
  status: "Active" | "Completed" | "Archived",
  items: string,  // JSON stringified List(ShoppingListIngredient)
  linked_recipes: string,  // JSON stringified List(PlannedRecipe)
  linked_plan: number | null,  // rata_die format
}
```

> [!NOTE]
> Unlike the original plan, we're storing items and recipes as JSON strings rather than separate tables. This is simpler for the current use case.

### 2.2 ✅ Database Functions ([db.ts](file:///home/ubuntu/projects/gleamstack/client/src/db.ts#L226-L290))

Implemented:
- ✅ `do_save_shopping_list(listTuple)` - Upserts shopping list
- ✅ `do_retrieve_shopping_list_summaries()` - Gets all lists with minimal fields
- ✅ `do_get_shopping_list(date)` - Gets single list by date  
- ✅ `do_subscribe_to_shopping_list_by_date(date, callback)` - Real-time subscription

Not needed (simpler approach):
- ❌ ~~`do_get_recipe_ingredients(recipe_id)`~~ - Will be handled differently
- ❌ ~~`do_sync_plan_to_shopping_list(plan_date, list_date)`~~ - Will be client-side logic

## Phase 3: Routing Updates ✅ COMPLETE

> Routing for shopping lists is already implemented in [`app.gleam`](file:///home/ubuntu/projects/gleamstack/client/src/app.gleam#L96-L107).

### 3.1 ✅ Routes Defined

```gleam
pub type Route {
  // ... existing routes
  ViewShoppingLists  // ✅ List all shopping lists
  ViewShoppingList(date: date.Date)  // ✅ View single list by date
  // EditShoppingList route not defined yet - edit is handled inline
}
```

### 3.2 ✅ Route Parsing ([app.gleam:528-535](file:///home/ubuntu/projects/gleamstack/client/src/app.gleam#L528-L535))

```gleam
_, ["shopping-list"] -> OnRouteChange(ViewShoppingLists)
_, ["shopping-list", date_str] ->
  OnRouteChange(
    ViewShoppingList(result.unwrap(
      date.from_iso_string(date_str),
      date.today(),
    )),
  )
// Note: No separate edit route - editing will be inline on detail view

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

## Implementation Order (UPDATED)

### Current Status Summary

**✅ Completed (0-2 hours remaining adjustments)**
1. Phase 1: Type System - All types defined and working
2. Phase 2: Database Schema - CRUD operations functional  
3. Phase 3: Routing - Routes defined and parsing works

**🚧 In Progress - Needs Enhancement (8-12 hours)**
4. Phase 4: Shopping List Views
   - ✅ Basic list view exists
   - 🚧 **Need**: Status toggle buttons (2 hours)
   - 🚧 **Need**: Better UI styling (1 hour)
   - 🚧 **Need**: Enhanced detail view with linked recipes display (2 hours)
   - 🚧 **Need**: Full edit view implementation (3-4 hours)

**❌ Not Started (10-14 hours)**
5. Phase 5: Recipe Management Features
   - Add typeahead for recipe lookup (3 hours)
   - Add "Add ingredients from recipe" functionality (3-4 hours)
   - Handle manual ingredient entries (2 hours)

6. Phase 6: Plan-Shopping List Integration
   - Add "Create from Plan" button to planner (1 hour)
   - Implement create from plan flow (2 hours)
   - Implement link existing list to plan (2 hours)
   - Implement bidirectional sync logic (2-3 hours)

### Recommended Implementation Order

**Sprint 1: Enhanced Views (8-12 hours)**
1. Improve list view with status toggles and better UI → [`shoppinglist.gleam: view_all_shopping_lists`](file:///home/ubuntu/projects/gleamstack/client/src/domains/shoppinglist.gleam#L277-L337)
2. Enhance detail view to show grouped ingredients → [`shoppinglist.gleam: view_shopping_list_detail`](file:///home/ubuntu/projects/gleamstack/client/src/domains/shoppinglist.gleam#L401-L518)
3. Implement full edit view with forms → [`shoppinglist.gleam: edit_shopping_list`](file:///home/ubuntu/projects/gleamstack/client/src/domains/shoppinglist.gleam#L567-L601)

**Sprint 2: Recipe Features (8-10 hours)**
4. Add recipe typeahead lookup (reuse existing typeahead component)
5. Implement "add ingredients from recipe" functionality
6. Add manual ingredient entry forms
7. Test ingredient management flows

**Sprint 3: Plan Integration (5-7 hours)**  
8. Add "Create Shopping List from Plan" button to planner view
9. Implement create from plan flow
10. Implement link existing list to plan

**Sprint 4: Sync & Polish (2-3 hours)**
11. Implement bidirectional sync
12. Add UI feedback for sync actions
13. Test complete workflows
14. Fix any edge cases

**Total Estimated Remaining Time: 23-32 hours**

> [!NOTE]
> Original estimate was 20-28 hours. With types, database, and routing complete, we've saved ~5-7 hours, leaving 15-21 hours baseline + ~8 hours for discovered complexity.

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

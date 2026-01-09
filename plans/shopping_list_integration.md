# Integration of Shopping List and Planner

This plan outlines the steps to integrate the Shopping List with the Planner using a shared database module.

## User Review Required

> [!IMPORTANT]
> This change involves creating `src/shared/db.gleam` to share DB bindings between pages.

## Proposed Changes

### Shared
#### [NEW] [db.gleam](file:///home/ubuntu/projects/gleamstack/app/src/shared/db.gleam)
- Create a new module to hold all external function declarations for DB interaction.
- Move `do_get_plan`, `do_save_plan`, `do_get_recipe...`, etc. here.
- This avoids code duplication and circular dependencies.

#### [MODIFY] [types.gleam](file:///home/ubuntu/projects/gleamstack/app/src/shared/types.gleam)
- No changes expected in types, as `ShoppingList` and `PlannedRecipe` are already defined.

### Pages
#### [MODIFY] [planner.gleam](file:///home/ubuntu/projects/gleamstack/app/src/pages/planner.gleam)
- Import `shared/db`.
- Remove local external function declarations (`do_get_plan`, etc.).
- Update calls to use `db.do_get_plan` etc.

#### [MODIFY] [shoppinglist.gleam](file:///home/ubuntu/projects/gleamstack/app/src/pages/shoppinglist.gleam)
- Import `shared/db`.
- Remove local external function declarations.
- **Messages**:
    - Add `UserClickedLinkPlan(date.Date)`: To set the link to a plan.
    - Add `UserClickedImportRecipes`: To trigger fetching the linked plan.
    - Add `DbRetrievedPlanForLinking(PlanWeek)`: To handle the fetched plan data.
    - Add `UserAddedIngredientsFromLinkedRecipe(types.PlannedRecipe)`: To add ingredients from a specific linked recipe.
- **Update Logic**:
    - Handle `UserClickedLinkPlan`: Update `linked_plan` in the current list and save.
    - Handle `UserClickedImportRecipes`: Call `do_get_plan` for the `linked_plan` date.
    - Handle `DbRetrievedPlanForLinking`: Parse the plan, extract `RecipeSlug`s from `lunch` and `dinner`, and update `linked_recipes` in the shopping list.
    - Handle `UserAddedIngredientsFromLinkedRecipe`: Look up the recipe in `model.recipe_list`, map its ingredients to `ShoppingListIngredient`, and add them to the list items.
- **View**:
    - add `view_plan_linker`: UI to select a week (default to current list connection or allow selection).
    - Update `view_linked_recipes`: Add "Add to List" button next to each recipe.
    - Add "Import Recipes from Plan" button if `linked_plan` is set.
    - Add "Add All Ingredients" button (optional, but good for UX).

### Other
#### [MODIFY] [recipe_list.gleam](file:///home/ubuntu/projects/gleamstack/app/src/pages/recipe_list.gleam)
- Optional: Refactor to use `shared/db` for consistency if needed.

## Verification Plan

### Automated Tests
- Implement unit tests for the `shopping_list_update` function using `lustre.simulate`.
- Verify:
    - `UserClickedLinkPlan` updates the model correctly.
    - `DbRetrievedPlanForLinking` parses and updates linked recipes.
    - `UserAddedIngredientsFromLinkedRecipe` adds the correct ingredients.

### Manual Verification
1.  **Link Plan**:
    - Open a Shopping List.
    - Click "Link Plan" (or similar UI element).
    - Verify `linked_plan` is updated (can check Network tab or visually if UI reflects it).
2.  **Import Recipes**:
    - Ensure the linked week has some meals planned with recipes (Slugs).
    - Click "Import Recipes".
    - Verify that the "Recipes" section in the Shopping List is populated with the recipes from the plan.
3.  **Add Ingredients**:
    - Expand the "Recipes" section.
    - Click "Add to List" for one of the recipes.
    - Verify that the ingredients for that recipe appear in the main Shopping List items.

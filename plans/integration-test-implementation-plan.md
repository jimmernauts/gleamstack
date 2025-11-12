# Implementation Plan for Valid Recipe Creation Integration Test

## Problem Analysis
The current test is invalid because:
1. It starts with a fully populated recipe instead of empty/None
2. It discards effects (where real work happens) 
3. It doesn't test the actual user flow of building a recipe from scratch
4. It doesn't simulate DOM interactions or test persistence

## New Approach Using lustre/dev/simulate

### Step 1: Use Real Application with lustre/dev/simulate
Instead of creating test-specific wrappers, use the actual lustre App instance from `mealstack_client.gleam`:
- Import the real App from `mealstack_client.gleam` 
- Use `simulate.start(app, initial_args)` with the actual application
- Navigate to the recipe creation route within the simulation
- Test the real form components and event handlers that users interact with

**Simulation Details:**
- The app will need initial routing state to land on the recipe creation page
- Use `lustre/dev/query` to find actual form elements (title input, author input, etc.)
- Messages will flow through the real `mealstack_client.update` function
- The view will render the actual HTML structure from `view_recipe_detail`

### Step 2: Test the Real User Flow
1. **Start with empty state**: `None` recipe
2. **Fill form fields**: Use `simulate.input()` to update title, author, serves
3. **Submit form**: Use `simulate.submit()` to trigger save
4. **Simulate database response**: Use `simulate.message()` with `DbSavedUpdatedRecipe`
5. **Verify final state**: Check model has the saved recipe

### Step 3: Test Side Effects and Persistence
- Mock the database save function
- Capture the save effect and verify it's called with correct data
- Test the slug generation happens on save
- Test the database response updates the model

### Step 4: Add Edge Cases
- Test saving empty/invalid recipes
- Test form validation
- Test error responses from database

## Exact Implementation Steps

1. **Import real application** and set up simulation:
   ```gleam
   import mealstack_client.{app}
   import lustre/dev/simulate
   import lustre/dev/query
   ```

2. **Navigate to recipe creation**:
   - Start simulation with route to recipe creation page
   - Use `simulate.start(app, #(initial_route, initial_model))`

3. **Write main integration test** using simulate pipeline:
   ```gleam
   simulate.start(app, #(CreateRecipe, initial_model))
   |> simulate.input(on: query.find(by: [attribute("name", "title")]), value: "Test Recipe")
   |> simulate.input(on: query.find(by: [attribute("name", "author")]), value: "Test Chef") 
   |> simulate.input(on: query.find(by: [attribute("name", "serves")]), value: "4")
   |> simulate.submit(on: query.find(by: [attribute("name", "recipe-form")]), fields: [])
   |> simulate.message(RecipeDetail(DbSavedUpdatedRecipe(expected_recipe)))
   |> simulate.model
   |> expect.to_equal(#(model_with_recipe, effect.none()))
   ```

4. **Add assertions** for:
   - Slug generation: "Test Recipe" -> "test-recipe"
   - Recipe data integrity in final model
   - Proper routing after save

5. **Add helper tests** for validation and error cases:
   - Empty form submission
   - Invalid input handling
   - Database error responses

## Technical Details

### Application Setup
- Import `mealstack_client.{app}` which contains the main lustre App
- The app expects initial arguments: `#(Route, Model)` 
- Need to determine correct Route for recipe creation (likely `CreateRecipe` or similar)
- Initial model should be the standard `mealstack_client.Model` with empty recipe state

### Mock Database Setup
- Create JavaScript mock for `do_save_recipe` that captures calls for verification
- Mock should store the recipe data passed to it for test assertions
- Create JavaScript mock for `do_delete_recipe` if testing deletion flows
- Mocks should be in `test/mocks/` directory and imported with `@external`

### Query Selectors
- Use `lustre/dev/query` to find actual form elements rendered by `view_recipe_detail`
- Selectors will need to match the real HTML structure:
  - `query.find(by: [attribute("name", "title")])` for title input
  - `query.find(by: [attribute("name", "author")])` for author input
  - `query.find(by: [attribute("name", "serves")])` for serves input
  - `query.find(by: [attribute("name", "recipe-form")])` for form submission
- May need to use CSS selectors or element IDs depending on actual implementation

### Message Routing
- Messages flow through `mealstack_client.update` which routes to `recipe.detail_update`
- Need to wrap recipe messages in `RecipeDetail()` constructor
- Database responses come as `RecipeDetail(DbSavedUpdatedRecipe(recipe))`
- Final model verification should check the full `mealstack_client.Model` structure

### Test Data
- Build expected recipe data matching what the form should create
- Verify slug generation: "Test Recipe" -> "test-recipe" 
- Check that recipe is properly stored in the model's `current_recipe` field
- Test routing changes after successful save (if applicable)

This approach will actually test the integration between user interactions, form updates, effects, and persistence - making it a true integration test that will catch regressions during the refactor.

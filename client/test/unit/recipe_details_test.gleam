import startest.{describe, it}
import startest/expect
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import session.{type RecipeList, RecipeList, merge_recipe_into_model}
import utils/mock_data.{valid_recipe, minimal_recipe}

pub fn main() {
  startest.run(startest.default_config())
}

pub fn recipe_details_tests() {
  describe("Recipe Loading Workflow", [
    describe("recipe list management", [
      it("should handle complete recipe loading workflow", fn() {
        // Test the complete workflow: empty list -> add recipes -> verify state
        let empty_list = RecipeList(recipes: [], tag_options: [], group_by: None)
        let recipe1 = valid_recipe()
        let recipe2 = minimal_recipe()
        
        // Simulate loading recipes one by one (as would happen in real app)
        let step1 = merge_recipe_into_model(recipe1, empty_list)
        let step2 = merge_recipe_into_model(recipe2, step1)
        
        // Verify the workflow completed successfully
        list.length(step2.recipes)
        |> expect.to_equal(2)
        
        // Verify all recipes are present and accessible
        step2.recipes
        |> list.any(fn(r) { r.title == "Test Recipe" })
        |> expect.to_equal(True)
        
        step2.recipes
        |> list.any(fn(r) { r.title == "Minimal Recipe" })
        |> expect.to_equal(True)
      }),
      
      it("should handle recipe loading with duplicate prevention", fn() {
        // Test workflow behavior when same recipe is loaded multiple times
        let recipe = valid_recipe()
        let initial_list = RecipeList(recipes: [recipe], tag_options: [], group_by: None)
        
        // Simulate refreshing/reloading the same recipe
        let updated_list = merge_recipe_into_model(recipe, initial_list)
        
        // Workflow should prevent duplicates
        list.length(updated_list.recipes)
        |> expect.to_equal(1)
        
        // But should update with latest data
        updated_list.recipes
        |> list.first
        |> expect.to_equal(Ok(recipe))
      }),
    ]),
  ])
}

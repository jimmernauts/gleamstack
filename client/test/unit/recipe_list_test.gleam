import gleam/list
import gleam/option.{None}
import session.{Recipe, RecipeList, merge_recipe_into_model}
import startest.{describe, it}
import startest/expect
import utils/mock_data.{minimal_recipe, valid_recipe}

pub fn main() {
  startest.run(startest.default_config())
}

pub fn recipe_list_tests() {
  describe("Recipe List", [
    describe("merge_recipe_into_model", [
      it("should merge a new recipe into empty model", fn() {
        let empty_model =
          RecipeList(recipes: [], tag_options: [], group_by: None)
        let new_recipe = valid_recipe()

        let result = merge_recipe_into_model(new_recipe, empty_model)

        result.recipes
        |> expect.to_equal([new_recipe])
      }),

      it("should update existing recipe in model", fn() {
        let existing_recipe = valid_recipe()
        let updated_recipe = Recipe(..existing_recipe, title: "Updated Recipe")
        let model =
          RecipeList(
            recipes: [existing_recipe],
            tag_options: [],
            group_by: None,
          )

        let result = merge_recipe_into_model(updated_recipe, model)

        result.recipes
        |> expect.to_equal([updated_recipe])
      }),

      it("should add recipe to existing list without duplicates", fn() {
        let recipe1 = valid_recipe()
        let recipe2 = minimal_recipe()
        let model =
          RecipeList(recipes: [recipe1], tag_options: [], group_by: None)

        let result = merge_recipe_into_model(recipe2, model)

        result.recipes
        |> expect.to_equal([recipe1, recipe2])
      }),

      it("should replace recipe with same ID", fn() {
        let original = valid_recipe()
        let updated = Recipe(..original, title: "Completely Updated")
        let model =
          RecipeList(recipes: [original], tag_options: [], group_by: None)

        let result = merge_recipe_into_model(updated, model)

        expect.to_equal(list.length(result.recipes), 1)
        result.recipes
        |> list.any(fn(recipe) { recipe.id == updated.id })
        |> expect.to_equal(True)
      }),
    ]),
  ])
}

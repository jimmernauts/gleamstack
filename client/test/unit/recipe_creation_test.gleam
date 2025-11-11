import gleam/option.{type Option, None, Some}
import pages/recipe.{
  type RecipeDetail, type RecipeDetailMsg, UserUpdatedRecipeAuthor,
  UserUpdatedRecipeTitle, detail_update,
}
import startest.{describe, it}
import startest/expect
import utils/mock_data.{valid_recipe}

pub fn main() {
  startest.run(startest.default_config())
}

pub fn recipe_creation_tests() {
  describe("Recipe Creation", [
    describe("detail_update - UserUpdatedRecipeTitle", [
      it("should update recipe title when model exists", fn() {
        let recipe = valid_recipe()
        let model: RecipeDetail = Some(recipe)
        let msg = UserUpdatedRecipeTitle("New Title")

        let #(updated_model, _effect) = detail_update(model, msg)

        case updated_model {
          Some(updated_recipe) ->
            updated_recipe.title
            |> expect.to_equal("New Title")
          None -> panic as "Expected Some recipe but got None"
        }
      }),

      it("should not update when model is None", fn() {
        let model: RecipeDetail = None
        let msg = UserUpdatedRecipeTitle("New Title")

        let #(updated_model, _effect) = detail_update(model, msg)

        updated_model
        |> expect.to_equal(None)
      }),
    ]),
    describe("detail_update - UserUpdatedRecipeAuthor", [
      it("should update recipe author when model exists", fn() {
        let recipe = valid_recipe()
        let model: RecipeDetail = Some(recipe)
        let msg = UserUpdatedRecipeAuthor("New Author")

        let #(updated_model, _effect) = detail_update(model, msg)

        case updated_model {
          Some(updated_recipe) ->
            updated_recipe.author
            |> expect.to_equal(Some("New Author"))
          None -> panic as "Expected Some recipe but got None"
        }
      }),
    ]),
  ])
}

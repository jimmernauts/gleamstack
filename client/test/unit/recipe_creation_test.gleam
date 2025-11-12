import birdie
import gleam/dict
import gleam/option.{None, Some}
import lustre/dev/simulate
import lustre/element
import mealstack_client.{
  EditRecipeDetail, OnRouteChange, RecipeDetail, SlugParam,
}
import pages/recipe.{DbSavedUpdatedRecipe}
import session.{Ingredient, MethodStep, Recipe, Tag}
import startest.{describe, it}
import startest/expect

pub fn recipe_creation_workflow_tests() {
  describe("Recipe Creation Workflow", [
    it("should start on empty recipe creation route", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))
      let initial_args = OnRouteChange(initial_route)

      // Act
      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(initial_args)

      // Assert
      let model = simulate.model(simulation)
      case model {
        mealstack_client.Model(current_route: route, ..) -> {
          route
          |> expect.to_equal(EditRecipeDetail(SlugParam(slug: "")))
        }
      }
    }),
    it("should have a recipe with default title", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))
      let initial_args = OnRouteChange(initial_route)

      // Act
      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(initial_args)

      // Assert
      let model = simulate.model(simulation)
      case model {
        mealstack_client.Model(current_recipe: recipe, ..) -> {
          case recipe {
            Some(current_recipe) -> {
              current_recipe.title
              |> expect.to_equal("New Recipe")
            }
            None -> panic as "Expected recipe to exist"
          }
        }
      }
    }),
    it("should have a recipe with empty slug", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))
      let initial_args = OnRouteChange(initial_route)

      // Act
      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(initial_args)

      // Assert
      let model = simulate.model(simulation)
      case model {
        mealstack_client.Model(current_recipe: recipe, ..) -> {
          case recipe {
            Some(current_recipe) -> {
              current_recipe.slug
              |> expect.to_equal("")
            }
            None -> panic as "Expected recipe to exist"
          }
        }
      }
    }),
    it("should have a recipe with zero serves", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))
      let initial_args = OnRouteChange(initial_route)

      // Act
      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(initial_args)

      // Assert
      let model = simulate.model(simulation)
      case model {
        mealstack_client.Model(current_recipe: recipe, ..) -> {
          case recipe {
            Some(current_recipe) -> {
              current_recipe.serves
              |> expect.to_equal(0)
            }
            None -> panic as "Expected recipe to exist"
          }
        }
      }
    }),
    it("should snapshot initial view", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))
      let initial_args = OnRouteChange(initial_route)

      // Act
      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(initial_args)

      // Assert - Snapshot the initial view
      simulate.view(simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "recipe_creation_initial_view")
    }),
    it("should handle recipe update messages correctly", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))
      let initial_args = OnRouteChange(initial_route)

      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(initial_args)

      let updated_recipe =
        Recipe(
          id: None,
          title: "Test Recipe Title",
          slug: "test-recipe-title",
          cook_time: 30,
          prep_time: 15,
          serves: 4,
          author: Some("Test Chef"),
          source: None,
          tags: Some(dict.from_list([#(0, Tag("", ""))])),
          ingredients: Some(
            dict.from_list([#(0, Ingredient(None, None, None, None, None))]),
          ),
          method_steps: Some(dict.from_list([#(0, MethodStep(""))])),
          shortlisted: None,
        )

      // Act
      let final_simulation =
        simulation
        |> simulate.message(RecipeDetail(DbSavedUpdatedRecipe(updated_recipe)))

      // Assert - Check the model was updated correctly
      let final_model = simulate.model(final_simulation)
      case final_model {
        mealstack_client.Model(current_recipe: recipe, ..) -> {
          recipe
          |> expect.to_equal(Some(updated_recipe))
        }
      }
    }),
    it("should maintain route after recipe update", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))
      let initial_args = OnRouteChange(initial_route)

      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(initial_args)

      let updated_recipe =
        Recipe(
          id: None,
          title: "Test Recipe Title",
          slug: "test-recipe-title",
          cook_time: 30,
          prep_time: 15,
          serves: 4,
          author: Some("Test Chef"),
          source: None,
          tags: Some(dict.from_list([#(0, Tag("", ""))])),
          ingredients: Some(
            dict.from_list([#(0, Ingredient(None, None, None, None, None))]),
          ),
          method_steps: Some(dict.from_list([#(0, MethodStep(""))])),
          shortlisted: None,
        )

      // Act
      let final_simulation =
        simulation
        |> simulate.message(RecipeDetail(DbSavedUpdatedRecipe(updated_recipe)))

      // Assert - Check route is maintained
      let final_model = simulate.model(final_simulation)
      case final_model {
        mealstack_client.Model(current_route: route, ..) -> {
          route
          |> expect.to_equal(EditRecipeDetail(SlugParam(slug: "")))
        }
      }
    }),
    it("should snapshot final view after recipe update", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))
      let initial_args = OnRouteChange(initial_route)

      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(initial_args)

      let updated_recipe =
        Recipe(
          id: None,
          title: "Test Recipe Title",
          slug: "test-recipe-title",
          cook_time: 30,
          prep_time: 15,
          serves: 4,
          author: Some("Test Chef"),
          source: None,
          tags: Some(dict.from_list([#(0, Tag("", ""))])),
          ingredients: Some(
            dict.from_list([#(0, Ingredient(None, None, None, None, None))]),
          ),
          method_steps: Some(dict.from_list([#(0, MethodStep(""))])),
          shortlisted: None,
        )

      // Act
      let final_simulation =
        simulation
        |> simulate.message(RecipeDetail(DbSavedUpdatedRecipe(updated_recipe)))

      // Assert - Snapshot the final view
      simulate.view(final_simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "recipe_creation_final_view")
    }),
  ])
}

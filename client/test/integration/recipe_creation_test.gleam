import app.{EditRecipeDetail, OnRouteChange, RecipeDetail, SlugParam}
import birdie
import domains/recipe/recipe.{DbSavedUpdatedRecipe}
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import lustre/dev/simulate
import lustre/element
import shared/types.{Ingredient, MethodStep, Recipe, Tag}
import startest.{describe, it}
import startest/expect

pub fn recipe_creation_workflow_tests() {
  describe("Recipe Creation Workflow", [
    it("should start on empty recipe creation route", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))

      // Act
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Assert
      let model = simulate.model(simulation)
      case model {
        app.Model(current_route: route, ..) -> {
          route
          |> expect.to_equal(EditRecipeDetail(SlugParam(slug: "")))
        }
      }
    }),
    it("should have a recipe with default title", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))

      // Act
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Assert
      let model = simulate.model(simulation)
      case model {
        app.Model(current_recipe: recipe, ..) -> {
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

      // Act
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Assert
      let model = simulate.model(simulation)
      case model {
        app.Model(current_recipe: recipe, ..) -> {
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

      // Act
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Assert
      let model = simulate.model(simulation)
      case model {
        app.Model(current_recipe: recipe, ..) -> {
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

      // Act
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Assert - Snapshot the initial view
      simulate.view(simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "recipe_creation_initial_view")
    }),
    it("should handle recipe update messages correctly", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

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

      // Assert - Check the recipe was saved to recipes list
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(recipes: recipes, ..) -> {
          recipes.recipes
          |> list.any(fn(r) { r.slug == "test-recipe-title" })
          |> expect.to_equal(True)
        }
      }
    }),
    it("should maintain route after recipe update", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

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

      // Act - Save recipe and simulate the route change effect
      let final_simulation =
        simulation
        |> simulate.message(
          RecipeDetail(recipe.DbSavedUpdatedRecipe(updated_recipe)),
        )
        |> simulate.message(
          OnRouteChange(app.ViewRecipeDetail(slug: "test-recipe-title")),
        )

      // Assert - Check route changed to view after save
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(current_route: route, ..) -> {
          route
          |> expect.to_equal(app.ViewRecipeDetail(slug: "test-recipe-title"))
        }
      }
    }),
    it("should snapshot final view after recipe update", fn() {
      // Arrange
      let initial_route = EditRecipeDetail(SlugParam(slug: ""))

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

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

import app.{OnRouteChange, Upload, ViewUpload}
import birdie
import gleam/dict
import gleam/option.{None, Some}
import lustre/dev/simulate
import lustre/element
import pages/upload.{Other, ParseRecipeResponseReceived, UserUpdatedUrl}
import shared/types.{Ingredient, MethodStep, Recipe, Tag}
import startest.{describe, it}
import startest/expect

pub fn url_import_integration_tests() {
  describe("URL Import and Recipe Parsing (with server)", [
    it("should load upload route", fn() {
      // Arrange
      let initial_route = ViewUpload(None)

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
          |> expect.to_equal(ViewUpload(None))
        }
      }
    }),
    it("should start with empty URL input", fn() {
      // Arrange
      let initial_route = ViewUpload(None)

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
        app.Model(upload: upload, ..) -> {
          upload.url
          |> expect.to_equal(None)
        }
      }
    }),
    it("should update URL input field", fn() {
      // Arrange
      let initial_route = ViewUpload(None)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Act - Enter URL
      let final_simulation =
        simulation
        |> simulate.message(
          Upload(UserUpdatedUrl("https://example.com/recipe")),
        )

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(upload: upload, ..) -> {
          upload.url
          |> expect.to_equal(Some("https://example.com/recipe"))
        }
      }
    }),
    it("should handle server response with parsed recipe", fn() {
      // Arrange
      let initial_route = ViewUpload(None)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(
          Upload(UserUpdatedUrl("https://example.com/recipe")),
        )

      // Mock server response with parsed recipe data
      let parsed_recipe =
        Recipe(
          id: None,
          title: "Imported Recipe",
          slug: "imported-recipe",
          cook_time: 30,
          prep_time: 15,
          serves: 4,
          author: Some("Recipe Author"),
          source: Some("https://example.com/recipe"),
          tags: Some(dict.from_list([#(0, Tag("cuisine", "Italian"))])),
          ingredients: Some(
            dict.from_list([
              #(
                0,
                Ingredient(
                  name: Some("Pasta"),
                  ismain: Some(True),
                  quantity: Some("500"),
                  units: Some("g"),
                  category: None,
                ),
              ),
            ]),
          ),
          method_steps: Some(
            dict.from_list([#(0, MethodStep("Boil pasta until al dente"))]),
          ),
          shortlisted: None,
        )

      // Act - Simulate server response and route change
      let final_simulation =
        simulation
        |> simulate.message(
          Upload(ParseRecipeResponseReceived(Ok(parsed_recipe))),
        )
        |> simulate.message(
          OnRouteChange(
            app.EditRecipeDetail(app.RecipeParam(recipe: parsed_recipe)),
          ),
        )

      // Assert - Recipe should be in current_recipe
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(current_recipe: recipe, ..) -> {
          case recipe {
            Some(r) -> {
              r.title
              |> expect.to_equal("Imported Recipe")
            }
            None -> panic as "Expected recipe to be set"
          }
        }
      }
    }),
    it("should handle server error gracefully", fn() {
      // Arrange
      let initial_route = ViewUpload(None)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Act - Simulate server error
      let final_simulation =
        simulation
        |> simulate.message(
          Upload(
            ParseRecipeResponseReceived(Error(Other("Failed to parse recipe"))),
          ),
        )

      // Assert - Should still be on upload route
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(current_route: route, ..) -> {
          route
          |> expect.to_equal(ViewUpload(None))
        }
      }
    }),
    it("should snapshot upload view with empty state", fn() {
      // Arrange
      let initial_route = ViewUpload(None)

      // Act
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Assert - Snapshot the view
      simulate.view(simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "upload_empty_state")
    }),
    it("should snapshot upload view with URL entered", fn() {
      // Arrange
      let initial_route = ViewUpload(None)

      // Act
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(
          Upload(UserUpdatedUrl("https://example.com/recipe")),
        )

      // Assert - Snapshot the view
      simulate.view(simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "upload_with_url")
    }),
  ])
}

import app.{OnRouteChange, RecipeList, ViewRecipeList}
import birdie
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import lustre/dev/simulate
import lustre/element
import shared/database.{
  DbRetrievedRecipes, GroupByAuthor, GroupByTag, Recipe, Tag,
  UserGroupedRecipeListByAuthor, UserGroupedRecipeListByTag,
}
import startest.{describe, it}
import startest/expect

pub fn recipe_list_integration_tests() {
  describe("Recipe List Loading and Filtering", [
    it("should load recipe list route", fn() {
      // Arrange
      let initial_route = ViewRecipeList

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
          |> expect.to_equal(ViewRecipeList)
        }
      }
    }),
    it("should start with empty recipe list", fn() {
      // Arrange
      let initial_route = ViewRecipeList

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
        app.Model(recipes: recipes, ..) -> {
          recipes.recipes
          |> expect.to_equal([])
        }
      }
    }),
    it("should start with no grouping applied", fn() {
      // Arrange
      let initial_route = ViewRecipeList

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
        app.Model(recipes: recipes, ..) -> {
          recipes.group_by
          |> expect.to_equal(None)
        }
      }
    }),
    it("should handle recipe list retrieval", fn() {
      // Arrange
      let initial_route = ViewRecipeList

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let test_recipes = [
        Recipe(
          id: Some("recipe-1"),
          title: "Pasta Carbonara",
          slug: "pasta-carbonara",
          cook_time: 20,
          prep_time: 10,
          serves: 4,
          author: Some("Italian Chef"),
          source: None,
          tags: Some(
            dict.from_list([
              #(0, Tag("cuisine", "Italian")),
              #(1, Tag("difficulty", "Easy")),
            ]),
          ),
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
        Recipe(
          id: Some("recipe-2"),
          title: "Thai Green Curry",
          slug: "thai-green-curry",
          cook_time: 30,
          prep_time: 15,
          serves: 4,
          author: Some("Thai Chef"),
          source: None,
          tags: Some(
            dict.from_list([
              #(0, Tag("cuisine", "Thai")),
              #(1, Tag("difficulty", "Medium")),
            ]),
          ),
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
        Recipe(
          id: Some("recipe-3"),
          title: "Spaghetti Bolognese",
          slug: "spaghetti-bolognese",
          cook_time: 45,
          prep_time: 15,
          serves: 6,
          author: Some("Italian Chef"),
          source: None,
          tags: Some(
            dict.from_list([
              #(0, Tag("cuisine", "Italian")),
              #(1, Tag("difficulty", "Easy")),
            ]),
          ),
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
      ]

      // Act
      let final_simulation =
        simulation
        |> simulate.message(RecipeList(DbRetrievedRecipes(test_recipes)))

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(recipes: recipes, ..) -> {
          recipes.recipes
          |> list.length
          |> expect.to_equal(3)
        }
      }
    }),
    it("should group recipes by tag when requested", fn() {
      // Arrange
      let initial_route = ViewRecipeList

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let test_recipes = [
        Recipe(
          id: Some("recipe-1"),
          title: "Pasta Carbonara",
          slug: "pasta-carbonara",
          cook_time: 20,
          prep_time: 10,
          serves: 4,
          author: Some("Italian Chef"),
          source: None,
          tags: Some(
            dict.from_list([
              #(0, Tag("cuisine", "Italian")),
              #(1, Tag("difficulty", "Easy")),
            ]),
          ),
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
        Recipe(
          id: Some("recipe-2"),
          title: "Thai Green Curry",
          slug: "thai-green-curry",
          cook_time: 30,
          prep_time: 15,
          serves: 4,
          author: Some("Thai Chef"),
          source: None,
          tags: Some(
            dict.from_list([
              #(0, Tag("cuisine", "Thai")),
              #(1, Tag("difficulty", "Medium")),
            ]),
          ),
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
      ]

      // Act - Load recipes then apply tag grouping
      let final_simulation =
        simulation
        |> simulate.message(RecipeList(DbRetrievedRecipes(test_recipes)))
        |> simulate.message(RecipeList(UserGroupedRecipeListByTag("cuisine")))

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(recipes: recipes, ..) -> {
          recipes.group_by
          |> expect.to_equal(Some(GroupByTag("cuisine")))
        }
      }
    }),
    it("should toggle tag grouping off when clicked again", fn() {
      // Arrange
      let initial_route = ViewRecipeList

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let test_recipes = [
        Recipe(
          id: Some("recipe-1"),
          title: "Pasta Carbonara",
          slug: "pasta-carbonara",
          cook_time: 20,
          prep_time: 10,
          serves: 4,
          author: Some("Italian Chef"),
          source: None,
          tags: Some(dict.from_list([#(0, Tag("cuisine", "Italian"))])),
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
      ]

      // Act - Load recipes, apply grouping, then toggle off
      let final_simulation =
        simulation
        |> simulate.message(RecipeList(DbRetrievedRecipes(test_recipes)))
        |> simulate.message(RecipeList(UserGroupedRecipeListByTag("cuisine")))
        |> simulate.message(RecipeList(UserGroupedRecipeListByTag("cuisine")))

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(recipes: recipes, ..) -> {
          recipes.group_by
          |> expect.to_equal(None)
        }
      }
    }),
    it("should group recipes by author when requested", fn() {
      // Arrange
      let initial_route = ViewRecipeList

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let test_recipes = [
        Recipe(
          id: Some("recipe-1"),
          title: "Pasta Carbonara",
          slug: "pasta-carbonara",
          cook_time: 20,
          prep_time: 10,
          serves: 4,
          author: Some("Italian Chef"),
          source: None,
          tags: None,
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
        Recipe(
          id: Some("recipe-2"),
          title: "Thai Green Curry",
          slug: "thai-green-curry",
          cook_time: 30,
          prep_time: 15,
          serves: 4,
          author: Some("Thai Chef"),
          source: None,
          tags: None,
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
      ]

      // Act - Load recipes then apply author grouping
      let final_simulation =
        simulation
        |> simulate.message(RecipeList(DbRetrievedRecipes(test_recipes)))
        |> simulate.message(RecipeList(UserGroupedRecipeListByAuthor))

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(recipes: recipes, ..) -> {
          recipes.group_by
          |> expect.to_equal(Some(GroupByAuthor))
        }
      }
    }),
    it("should toggle author grouping off when clicked again", fn() {
      // Arrange
      let initial_route = ViewRecipeList

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let test_recipes = [
        Recipe(
          id: Some("recipe-1"),
          title: "Pasta Carbonara",
          slug: "pasta-carbonara",
          cook_time: 20,
          prep_time: 10,
          serves: 4,
          author: Some("Italian Chef"),
          source: None,
          tags: None,
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
      ]

      // Act - Load recipes, apply grouping, then toggle off
      let final_simulation =
        simulation
        |> simulate.message(RecipeList(DbRetrievedRecipes(test_recipes)))
        |> simulate.message(RecipeList(UserGroupedRecipeListByAuthor))
        |> simulate.message(RecipeList(UserGroupedRecipeListByAuthor))

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(recipes: recipes, ..) -> {
          recipes.group_by
          |> expect.to_equal(None)
        }
      }
    }),
    it("should snapshot recipe list view with no grouping", fn() {
      // Arrange
      let initial_route = ViewRecipeList

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let test_recipes = [
        Recipe(
          id: Some("recipe-1"),
          title: "Pasta Carbonara",
          slug: "pasta-carbonara",
          cook_time: 20,
          prep_time: 10,
          serves: 4,
          author: Some("Italian Chef"),
          source: None,
          tags: Some(dict.from_list([#(0, Tag("cuisine", "Italian"))])),
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
        Recipe(
          id: Some("recipe-2"),
          title: "Thai Green Curry",
          slug: "thai-green-curry",
          cook_time: 30,
          prep_time: 15,
          serves: 4,
          author: Some("Thai Chef"),
          source: None,
          tags: Some(dict.from_list([#(0, Tag("cuisine", "Thai"))])),
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
      ]

      // Act
      let final_simulation =
        simulation
        |> simulate.message(RecipeList(DbRetrievedRecipes(test_recipes)))

      // Assert - Snapshot the view
      simulate.view(final_simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "recipe_list_no_grouping")
    }),
    it("should snapshot recipe list view with tag grouping", fn() {
      // Arrange
      let initial_route = ViewRecipeList

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let test_recipes = [
        Recipe(
          id: Some("recipe-1"),
          title: "Pasta Carbonara",
          slug: "pasta-carbonara",
          cook_time: 20,
          prep_time: 10,
          serves: 4,
          author: Some("Italian Chef"),
          source: None,
          tags: Some(dict.from_list([#(0, Tag("cuisine", "Italian"))])),
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
        Recipe(
          id: Some("recipe-2"),
          title: "Thai Green Curry",
          slug: "thai-green-curry",
          cook_time: 30,
          prep_time: 15,
          serves: 4,
          author: Some("Thai Chef"),
          source: None,
          tags: Some(dict.from_list([#(0, Tag("cuisine", "Thai"))])),
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
      ]

      // Act
      let final_simulation =
        simulation
        |> simulate.message(RecipeList(DbRetrievedRecipes(test_recipes)))
        |> simulate.message(RecipeList(UserGroupedRecipeListByTag("cuisine")))

      // Assert - Snapshot the view
      simulate.view(final_simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "recipe_list_tag_grouping")
    }),
    it("should snapshot recipe list view with author grouping", fn() {
      // Arrange
      let initial_route = ViewRecipeList

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let test_recipes = [
        Recipe(
          id: Some("recipe-1"),
          title: "Pasta Carbonara",
          slug: "pasta-carbonara",
          cook_time: 20,
          prep_time: 10,
          serves: 4,
          author: Some("Italian Chef"),
          source: None,
          tags: None,
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
        Recipe(
          id: Some("recipe-2"),
          title: "Spaghetti Bolognese",
          slug: "spaghetti-bolognese",
          cook_time: 45,
          prep_time: 15,
          serves: 6,
          author: Some("Italian Chef"),
          source: None,
          tags: None,
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
        Recipe(
          id: Some("recipe-3"),
          title: "Thai Green Curry",
          slug: "thai-green-curry",
          cook_time: 30,
          prep_time: 15,
          serves: 4,
          author: Some("Thai Chef"),
          source: None,
          tags: None,
          ingredients: None,
          method_steps: None,
          shortlisted: None,
        ),
      ]

      // Act
      let final_simulation =
        simulation
        |> simulate.message(RecipeList(DbRetrievedRecipes(test_recipes)))
        |> simulate.message(RecipeList(UserGroupedRecipeListByAuthor))

      // Assert - Snapshot the view
      simulate.view(final_simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "recipe_list_author_grouping")
    }),
  ])
}

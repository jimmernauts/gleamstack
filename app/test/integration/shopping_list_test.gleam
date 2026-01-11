import app.{OnRouteChange, ShoppingList, ViewShoppingList}
import gleam/dict
import gleam/option.{None, Some}
import glearray
import lustre/dev/simulate
import pages/shoppinglist.{
  DbRetrievedPlanForLinking, ShoppingListModel, UserConfirmedLinkPlan,
  UserCreatedList, UserDeletedList, UserOpenedLinkPlanModal,
  UserUpdatedIngredientNameAtIndex,
}
import rada/date
import shared/types
import startest.{describe, it}
import startest/expect

pub fn shopping_list_workflow_tests() {
  describe("Shopping List Workflow", [
    it("should start on shopping list detail route", fn() {
      let today = date.today()
      let initial_route = ViewShoppingList(today)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let model = simulate.model(simulation)
      case model {
        app.Model(current_route: route, ..) -> {
          route
          |> expect.to_equal(ViewShoppingList(today))
        }
      }
    }),
    it("should create a new list", fn() {
      let today = date.today()
      let initial_route = ViewShoppingList(today)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(ShoppingList(UserCreatedList(today)))

      let model = simulate.model(simulation)
      case model {
        app.Model(shoppinglist: ShoppingListModel(current: current, ..), ..) -> {
          case current {
            Some(list) -> {
              list.date
              |> expect.to_equal(today)
            }
            None -> panic as "Expected shopping list to exist"
          }
        }
      }
    }),
    it("should add an item to the list", fn() {
      let today = date.today()
      let initial_route = ViewShoppingList(today)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(ShoppingList(UserCreatedList(today)))
        |> simulate.message(
          ShoppingList(UserUpdatedIngredientNameAtIndex(0, "Milk")),
        )

      let model = simulate.model(simulation)
      case model {
        app.Model(shoppinglist: ShoppingListModel(current: current, ..), ..) -> {
          case current {
            Some(list) -> {
              list.items
              |> glearray.length
              |> expect.to_equal(1)
            }
            None -> panic as "Expected shopping list to exist"
          }
        }
      }
    }),
    it("should delete the list", fn() {
      let today = date.today()
      let initial_route = ViewShoppingList(today)

      // Create list first
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(ShoppingList(UserCreatedList(today)))

      // Get the created list to pass to delete
      let model = simulate.model(simulation)
      let list_to_delete = case model {
        app.Model(shoppinglist: ShoppingListModel(current: Some(list), ..), ..) ->
          list
        _ -> panic as "Expected shopping list to exist"
      }

      // Delete the list
      let final_simulation =
        simulation
        |> simulate.message(ShoppingList(UserDeletedList(list_to_delete)))

      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(shoppinglist: ShoppingListModel(current: current, ..), ..) -> {
          current
          |> expect.to_be_none
        }
      }
    }),
    it("should link plan and populate recipes", fn() {
      let today = date.today()
      let initial_route = ViewShoppingList(today)

      let monday = date.floor(today, date.Monday)
      let end_date = date.add(monday, 6, date.Days)
      let plan_week =
        dict.from_list([
          #(
            monday,
            types.PlanDay(
              date: monday,
              lunch: Some(types.PlannedMeal(
                recipe: types.RecipeName("Pasta Carbonara"),
                complete: False,
              )),
              dinner: None,
            ),
          ),
        ])

      // Create list and open modal
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(ShoppingList(UserCreatedList(today)))
        |> simulate.message(ShoppingList(UserOpenedLinkPlanModal))
        |> simulate.message(ShoppingList(DbRetrievedPlanForLinking(plan_week)))

      // Verify modal is open and has preview
      let model = simulate.model(simulation)
      case model {
        app.Model(
          shoppinglist: ShoppingListModel(link_plan_modal: Some(modal), ..),
          ..,
        ) -> {
          modal.preview
          |> dict.size
          |> expect.to_equal(1)
        }
        _ -> panic as "Expected modal to be open"
      }

      // Confirm linking
      let final_simulation =
        simulation
        |> simulate.message(
          ShoppingList(UserConfirmedLinkPlan(monday, end_date)),
        )

      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(shoppinglist: ShoppingListModel(current: current, ..), ..) -> {
          case current {
            Some(list) -> {
              list.linked_plan
              |> expect.to_be_some
              |> expect.to_equal(monday)

              list.linked_recipes
              |> glearray.length
              |> expect.to_equal(1)

              list.linked_recipes
              |> glearray.get(0)
              |> expect.to_be_ok
              |> expect.to_equal(types.RecipeName("Pasta Carbonara"))
            }
            None -> panic as "Expected shopping list to exist"
          }
        }
      }
    }),
    //it("should snapshot shopping list view", fn() {
  //  let today = date.today()
  //  let initial_route = ViewShoppingList(today)
  //
  //  let simulation =
  //    simulate.application(
  //      init: app.public_init,
  //      update: app.public_update,
  //      view: app.public_view,
  //    )
  //    |> simulate.start(Nil)
  //    |> simulate.message(OnRouteChange(initial_route))
  //    |> simulate.message(ShoppingList(UserCreatedList(today)))
  //    |> simulate.message(ShoppingList(UserAddedIngredientAtIndex(0)))
  //    |> simulate.message(
  //      ShoppingList(UserUpdatedIngredientNameAtIndex(0, "Milk")),
  //    )
  //
  //  simulate.view(simulation)
  //  |> query.find(query.element(query.id("main-content")))
  //  |> result.unwrap(element.none())
  //  |> element.to_readable_string
  //  |> birdie.snap(title: "shopping_list_view")
  //}),
  ])
}

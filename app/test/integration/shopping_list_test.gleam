import app.{OnRouteChange, ShoppingList, ViewShoppingList}
import gleam/dict
import gleam/option.{None, Some}
import glearray
import lustre/dev/simulate
import pages/shoppinglist.{
  DbRetrievedPlanForLinking, ShoppingListModel, UserCreatedList, UserDeletedList,
  UserToggledLinkedPlan, UserUpdatedIngredientNameAtIndex,
  UserUpdatedLinkPlanEndDate, UserUpdatedLinkPlanStartDate,
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
    it("should link plan and populate preview", fn() {
      let today = date.today()
      let initial_route = ViewShoppingList(today)

      let monday = date.floor(today, date.Monday)
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

      // Create list and confirm link plan (which triggers db fetch)
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(ShoppingList(UserCreatedList(today)))
        // Simulate receiving the plan data
        |> simulate.message(ShoppingList(DbRetrievedPlanForLinking(plan_week)))

      // Verify preview is populated
      let model = simulate.model(simulation)
      case model {
        app.Model(
          shoppinglist: ShoppingListModel(linked_plan_preview: preview, ..),
          ..,
        ) -> {
          preview
          |> dict.size
          |> expect.to_equal(1)
        }
      }
    }),
    it("should update linked_plan_start when start date is set", fn() {
      let today = date.today()
      let initial_route = ViewShoppingList(today)
      let start_date_string = date.to_iso_string(today)

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
          ShoppingList(UserUpdatedLinkPlanStartDate(start_date_string)),
        )

      let model = simulate.model(simulation)
      case model {
        app.Model(shoppinglist: ShoppingListModel(current: current, ..), ..) -> {
          case current {
            Some(list) -> {
              list.linked_plan_start
              |> expect.to_equal(Some(today))
            }
            None -> panic as "Expected shopping list to exist"
          }
        }
      }
    }),
    it("should update linked_plan_end when end date is set", fn() {
      let today = date.today()
      let end_date = date.add(today, 7, date.Days)
      let initial_route = ViewShoppingList(today)
      let end_date_string = date.to_iso_string(end_date)

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
          ShoppingList(UserUpdatedLinkPlanEndDate(end_date_string)),
        )

      let model = simulate.model(simulation)
      case model {
        app.Model(shoppinglist: ShoppingListModel(current: current, ..), ..) -> {
          case current {
            Some(list) -> {
              list.linked_plan_end
              |> expect.to_equal(Some(end_date))
            }
            None -> panic as "Expected shopping list to exist"
          }
        }
      }
    }),
    it("should toggle linked_plan_open state", fn() {
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
        |> simulate.message(ShoppingList(UserToggledLinkedPlan))

      let model = simulate.model(simulation)
      case model {
        app.Model(
          shoppinglist: ShoppingListModel(linked_plan_open: is_open, ..),
          ..,
        ) -> {
          is_open
          |> expect.to_be_true
        }
      }
    }),
    it("should update both linked_plan_start and linked_plan_end", fn() {
      let today = date.today()
      let initial_route = ViewShoppingList(today)
      let start_date = today
      let end_date = date.add(today, 6, date.Days)

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
          ShoppingList(
            UserUpdatedLinkPlanStartDate(date.to_iso_string(start_date)),
          ),
        )
        |> simulate.message(
          ShoppingList(UserUpdatedLinkPlanEndDate(date.to_iso_string(end_date))),
        )

      let model = simulate.model(simulation)
      case model {
        app.Model(shoppinglist: ShoppingListModel(current: current, ..), ..) -> {
          case current {
            Some(list) -> {
              list.linked_plan_start
              |> expect.to_equal(Some(start_date))
              list.linked_plan_end
              |> expect.to_equal(Some(end_date))
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

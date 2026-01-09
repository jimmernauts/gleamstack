import app.{OnRouteChange, Planner, ViewPlanner}
import birdie
import gleam/dict
import pages/planner.{
  DbRetrievedPlan, Dinner, Lunch, UserDragStart, UserDrop,
  UserToggledMealComplete, UserUpdatedMealTitle,
}

import gleam/option.{None, Some}
import lustre/dev/simulate
import lustre/element
import rada/date
import shared/types
import startest.{describe, it}
import startest/expect

pub fn planner_integration_tests() {
  describe("Weekly Planner Loading and Meal Assignment", [
    it("should load planner route for current week", fn() {
      // Arrange
      let start_date = date.today()
      let initial_route = ViewPlanner(start_date)

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
          |> expect.to_equal(ViewPlanner(start_date))
        }
      }
    }),
    it("should start with empty plan week", fn() {
      // Arrange
      let start_date = date.today()
      let initial_route = ViewPlanner(start_date)

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
        app.Model(planner: planner, ..) -> {
          planner.plan_week
          |> dict.size
          |> expect.to_equal(0)
        }
      }
    }),
    it("should load plan week from database", fn() {
      // Arrange
      let start_date = date.floor(date.today(), date.Monday)
      let initial_route = ViewPlanner(start_date)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let monday = start_date
      let tuesday = date.add(monday, 1, date.Days)
      let wednesday = date.add(monday, 2, date.Days)

      let test_plan_week =
        dict.from_list([
          #(
            monday,
            types.PlanDay(
              date: monday,
              lunch: Some(types.PlannedMeal(
                recipe: types.RecipeName("Pasta Carbonara"),
                complete: False,
              )),
              dinner: Some(types.PlannedMeal(
                recipe: types.RecipeName("Thai Green Curry"),
                complete: False,
              )),
            ),
          ),
          #(
            tuesday,
            types.PlanDay(
              date: tuesday,
              lunch: Some(types.PlannedMeal(
                recipe: types.RecipeName("Spaghetti Bolognese"),
                complete: False,
              )),
              dinner: None,
            ),
          ),
          #(
            wednesday,
            types.PlanDay(date: wednesday, lunch: None, dinner: None),
          ),
        ])

      // Act
      let final_simulation =
        simulation
        |> simulate.message(Planner(DbRetrievedPlan(test_plan_week, monday)))

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(planner: planner, ..) -> {
          planner.plan_week
          |> dict.size
          |> expect.to_equal(3)
        }
      }
    }),
    it("should assign meal to a day", fn() {
      // Arrange
      let start_date = date.floor(date.today(), date.Monday)
      let initial_route = ViewPlanner(start_date)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let monday = start_date

      // Act - Assign a lunch meal
      let final_simulation =
        simulation
        |> simulate.message(
          Planner(UserUpdatedMealTitle(
            monday,
            Lunch,
            types.RecipeName("Pasta Carbonara"),
          )),
        )

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(planner: planner, ..) -> {
          let day =
            planner.plan_week
            |> dict.get(monday)
            |> expect.to_be_ok
          let meal = day.lunch |> expect.to_be_some
          meal.recipe
          |> expect.to_equal(types.RecipeName("Pasta Carbonara"))
        }
      }
    }),
    it("should assign multiple meals to same day", fn() {
      // Arrange
      let start_date = date.floor(date.today(), date.Monday)
      let initial_route = ViewPlanner(start_date)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let monday = start_date

      // Act - Assign lunch and dinner
      let final_simulation =
        simulation
        |> simulate.message(
          Planner(UserUpdatedMealTitle(
            monday,
            Lunch,
            types.RecipeName("Pasta Carbonara"),
          )),
        )
        |> simulate.message(
          Planner(UserUpdatedMealTitle(
            monday,
            Dinner,
            types.RecipeName("Thai Green Curry"),
          )),
        )

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(planner: planner, ..) -> {
          let day =
            planner.plan_week
            |> dict.get(monday)
            |> expect.to_be_ok
          let _ = day.lunch |> expect.to_be_some
          let _ = day.dinner |> expect.to_be_some
          Nil
        }
      }
    }),
    it("should update existing meal assignment", fn() {
      // Arrange
      let start_date = date.floor(date.today(), date.Monday)
      let initial_route = ViewPlanner(start_date)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let monday = start_date

      // Act - Assign a meal then update it
      let final_simulation =
        simulation
        |> simulate.message(
          Planner(UserUpdatedMealTitle(
            monday,
            Lunch,
            types.RecipeName("Pasta Carbonara"),
          )),
        )
        |> simulate.message(
          Planner(UserUpdatedMealTitle(
            monday,
            Lunch,
            types.RecipeName("Spaghetti Bolognese"),
          )),
        )

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(planner: planner, ..) -> {
          let day =
            planner.plan_week
            |> dict.get(monday)
            |> expect.to_be_ok
          let meal = day.lunch |> expect.to_be_some
          meal.recipe
          |> expect.to_equal(types.RecipeName("Spaghetti Bolognese"))
        }
      }
    }),
    it("should remove meal when set to empty string", fn() {
      // Arrange
      let start_date = date.floor(date.today(), date.Monday)
      let initial_route = ViewPlanner(start_date)

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      let monday = start_date

      // Act - Assign a meal then remove it
      let final_simulation =
        simulation
        |> simulate.message(
          Planner(UserUpdatedMealTitle(
            monday,
            Lunch,
            types.RecipeName("Pasta Carbonara"),
          )),
        )
        |> simulate.message(
          Planner(UserUpdatedMealTitle(monday, Lunch, types.RecipeName(""))),
        )

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(planner: planner, ..) -> {
          let day =
            planner.plan_week
            |> dict.get(monday)
            |> expect.to_be_ok
          day.lunch |> expect.to_be_none
        }
      }
    }),
    it("should toggle meal completion status", fn() {
      // Arrange
      let start_date = date.floor(date.today(), date.Monday)
      let initial_route = ViewPlanner(start_date)

      let monday = start_date
      let test_plan_week =
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

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(Planner(DbRetrievedPlan(test_plan_week, monday)))

      // Act - Toggle completion
      let final_simulation =
        simulation
        |> simulate.message(
          Planner(UserToggledMealComplete(monday, Lunch, True)),
        )

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(planner: planner, ..) -> {
          let day =
            planner.plan_week
            |> dict.get(monday)
            |> expect.to_be_ok
          let meal = day.lunch |> expect.to_be_some
          meal.complete |> expect.to_equal(True)
        }
      }
    }),
    it("should snapshot planner view with empty week", fn() {
      // Arrange
      let start_date = date.floor(date.today(), date.Monday)
      let initial_route = ViewPlanner(start_date)

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
      |> birdie.snap(title: "planner_empty_week")
    }),
    it("should snapshot planner view with planned meals", fn() {
      // Arrange
      let start_date = date.floor(date.today(), date.Monday)
      let initial_route = ViewPlanner(start_date)

      let monday = start_date
      let tuesday = date.add(monday, 1, date.Days)

      let test_plan_week =
        dict.from_list([
          #(
            monday,
            types.PlanDay(
              date: monday,
              lunch: Some(types.PlannedMeal(
                recipe: types.RecipeName("Pasta Carbonara"),
                complete: False,
              )),
              dinner: Some(types.PlannedMeal(
                recipe: types.RecipeName("Thai Green Curry"),
                complete: False,
              )),
            ),
          ),
          #(
            tuesday,
            types.PlanDay(
              date: tuesday,
              lunch: Some(types.PlannedMeal(
                recipe: types.RecipeName("Spaghetti Bolognese"),
                complete: False,
              )),
              dinner: None,
            ),
          ),
        ])

      // Act
      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(Planner(DbRetrievedPlan(test_plan_week, monday)))

      // Assert - Snapshot the view
      simulate.view(simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "planner_with_meals")
    }),
    it("should move meal via drag and drop", fn() {
      // Arrange
      let start_date = date.floor(date.today(), date.Monday)
      let initial_route = ViewPlanner(start_date)

      let monday = start_date
      let tuesday = date.add(monday, 1, date.Days)

      // Start with meal on Monday Lunch
      let test_plan_week =
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

      let simulation =
        simulate.application(
          init: app.public_init,
          update: app.public_update,
          view: app.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(Planner(DbRetrievedPlan(test_plan_week, monday)))

      // Act - Drag from Mon Lunch to Tue Lunch
      let final_simulation =
        simulation
        |> simulate.message(Planner(UserDragStart(monday, Lunch)))
        |> simulate.message(Planner(UserDrop(tuesday, Lunch)))

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        app.Model(planner: planner, ..) -> {
          // Monday Lunch should be None
          let mon_day =
            planner.plan_week
            |> dict.get(monday)
            |> expect.to_be_ok
          mon_day.lunch |> expect.to_be_none

          // Tuesday Lunch should be Pasta Carbonara
          let tue_day =
            planner.plan_week
            |> dict.get(tuesday)
            |> expect.to_be_ok
          let meal = tue_day.lunch |> expect.to_be_some
          meal.recipe
          |> expect.to_equal(types.RecipeName("Pasta Carbonara"))
        }
      }
    }),
  ])
}

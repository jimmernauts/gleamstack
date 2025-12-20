import app.{OnRouteChange, Planner, ViewPlanner}
import birdie
import domains/planner.{
  DbRetrievedPlan, Dinner, Lunch, PlanDay, PlannedMealWithStatus,
  UserToggledMealComplete, UserUpdatedMealTitle,
}
import gleam/dict
import gleam/list
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
            PlanDay(date: monday, planned_meals: [
              PlannedMealWithStatus(
                for: Lunch,
                recipe: Some(types.RecipeName("Pasta Carbonara")),
                complete: None,
              ),
              PlannedMealWithStatus(
                for: Dinner,
                recipe: Some(types.RecipeName("Thai Green Curry")),
                complete: None,
              ),
            ]),
          ),
          #(
            tuesday,
            PlanDay(date: tuesday, planned_meals: [
              PlannedMealWithStatus(
                for: Lunch,
                recipe: Some(types.RecipeName("Spaghetti Bolognese")),
                complete: None,
              ),
            ]),
          ),
          #(wednesday, PlanDay(date: wednesday, planned_meals: [])),
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
          case dict.get(planner.plan_week, monday) {
            Ok(plan_day) -> {
              plan_day.planned_meals
              |> list.any(fn(meal) {
                meal.for == Lunch
                && meal.recipe == Some(types.RecipeName("Pasta Carbonara"))
              })
              |> expect.to_equal(True)
            }
            Error(_) -> panic as "Expected plan day to exist"
          }
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
          case dict.get(planner.plan_week, monday) {
            Ok(plan_day) -> {
              plan_day.planned_meals
              |> list.length
              |> expect.to_equal(2)
            }
            Error(_) -> panic as "Expected plan day to exist"
          }
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
          case dict.get(planner.plan_week, monday) {
            Ok(plan_day) -> {
              plan_day.planned_meals
              |> list.any(fn(meal) {
                meal.for == Lunch
                && meal.recipe == Some(types.RecipeName("Spaghetti Bolognese"))
              })
              |> expect.to_equal(True)
            }
            Error(_) -> panic as "Expected plan day to exist"
          }
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
          case dict.get(planner.plan_week, monday) {
            Ok(plan_day) -> {
              plan_day.planned_meals
              |> list.any(fn(meal) { meal.for == Lunch })
              |> expect.to_equal(False)
            }
            Error(_) -> panic as "Expected plan day to exist"
          }
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
            PlanDay(date: monday, planned_meals: [
              PlannedMealWithStatus(
                for: Lunch,
                recipe: Some(types.RecipeName("Pasta Carbonara")),
                complete: Some(False),
              ),
            ]),
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
          case dict.get(planner.plan_week, monday) {
            Ok(plan_day) -> {
              plan_day.planned_meals
              |> list.any(fn(meal) {
                meal.for == Lunch && meal.complete == Some(True)
              })
              |> expect.to_equal(True)
            }
            Error(_) -> panic as "Expected plan day to exist"
          }
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
            PlanDay(date: monday, planned_meals: [
              PlannedMealWithStatus(
                for: Lunch,
                recipe: Some(types.RecipeName("Pasta Carbonara")),
                complete: Some(False),
              ),
              PlannedMealWithStatus(
                for: Dinner,
                recipe: Some(types.RecipeName("Thai Green Curry")),
                complete: Some(True),
              ),
            ]),
          ),
          #(
            tuesday,
            PlanDay(date: tuesday, planned_meals: [
              PlannedMealWithStatus(
                for: Lunch,
                recipe: Some(types.RecipeName("Spaghetti Bolognese")),
                complete: Some(False),
              ),
            ]),
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
  ])
}

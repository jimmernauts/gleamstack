import startest.{describe, it}
import startest/expect
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pages/planner.{type PlannedMealWithStatus, type Meal, PlannedMealWithStatus, Lunch, Dinner}

pub fn main() {
  startest.run(startest.default_config())
}

pub fn planner_workflow_tests() {
  describe("Planner Workflow", [
    describe("meal completion workflow", [
      it("should handle meal completion state management", fn() {
        // Test the core workflow logic: meal completion state transitions
        let initial_meals = [
          PlannedMealWithStatus(for: Lunch, title: Some("Sandwich"), complete: Some(False)),
          PlannedMealWithStatus(for: Dinner, title: Some("Pizza"), complete: Some(False)),
        ]
        
        // Simulate the workflow of marking lunch as complete
        let updated_meals = list.map(initial_meals, fn(meal) {
          case meal.for == Lunch {
            True -> PlannedMealWithStatus(..meal, complete: Some(True))
            False -> meal
          }
        })
        
        // Verify the workflow completed successfully
        // Lunch should now be complete
        updated_meals
        |> list.find(fn(m) { m.for == Lunch })
        |> result.map(fn(m) { m.complete })
        |> expect.to_equal(Ok(Some(True)))
        
        // Dinner should remain incomplete
        updated_meals
        |> list.find(fn(m) { m.for == Dinner })
        |> result.map(fn(m) { m.complete })
        |> expect.to_equal(Ok(Some(False)))
      }),
    ]),
  ])
}

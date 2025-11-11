import startest.{describe, it}
import birdie
import gleam/list
import gleam/string
import gleam/option.{type Option, None, Some}
import gleam/int
import gleam/pair
import gleam/dict
import lustre/element
import pages/recipe.{view_recipe_detail}
import utils/mock_data.{valid_recipe, minimal_recipe}

pub fn main() {
  startest.run(startest.default_config())
}

pub fn snapshot_tests() {
  describe("Recipe View Component Snapshots", [
    it("should snapshot view_recipe_detail with valid recipe", fn() {
      let recipe = valid_recipe()
      
      recipe
      |> view_recipe_detail
      |> element.to_readable_string
      |> birdie.snap(title: "view_recipe_detail_valid")
    }),
    
    it("should snapshot view_recipe_detail with minimal recipe", fn() {
      let recipe = minimal_recipe()
      
      recipe
      |> view_recipe_detail
      |> element.to_readable_string
      |> birdie.snap(title: "view_recipe_detail_minimal")
    }),
  ])
}

pub fn string_snapshot_tests() {
  describe("String Snapshots", [
    describe("recipe data serialization", [
      it("should snapshot recipe title formatting", fn() {
        let recipe = valid_recipe()
        
        // Create a formatted string representation of the recipe
        let recipe_summary = recipe.title <> " by " <> 
          option.unwrap(recipe.author, "Unknown Author") <> 
          " (Serves " <> int.to_string(recipe.serves) <> ")"
        
        recipe_summary
        |> birdie.snap(title: "recipe_title_summary_complete")
      }),
      
      it("should snapshot minimal recipe formatting", fn() {
        let recipe = minimal_recipe()
        
        // Create a formatted string representation of minimal recipe
        let recipe_summary = recipe.title <> 
          " (Serves " <> int.to_string(recipe.serves) <> ")"
        
        recipe_summary
        |> birdie.snap(title: "recipe_title_summary_minimal")
      }),
      
      it("should snapshot ingredient list formatting", fn() {
        let recipe = valid_recipe()
        
        // Create a formatted string of ingredients
        let ingredients_text = case recipe.ingredients {
          Some(ingredients) -> {
            ingredients
            |> dict.to_list
            |> list.sort(by: fn(a, b) { int.compare(pair.first(a), pair.first(b)) })
            |> list.map(fn(pair) { 
              let #(index, ingredient) = pair
              int.to_string(index) <> ". " <> 
              option.unwrap(ingredient.name, "Unnamed ingredient") <>
              case ingredient.quantity {
                Some(q) -> " (" <> q <> " " <> option.unwrap(ingredient.units, "") <> ")"
                None -> ""
              }
            })
            |> string.join("\n")
          }
          None -> "No ingredients listed"
        }
        
        ingredients_text
        |> birdie.snap(title: "recipe_ingredients_list")
      }),
      
      it("should snapshot method steps formatting", fn() {
        let recipe = valid_recipe()
        
        // Create a formatted string of method steps
        let method_text = case recipe.method_steps {
          Some(steps) -> {
            steps
            |> dict.to_list
            |> list.sort(by: fn(a, b) { int.compare(pair.first(a), pair.first(b)) })
            |> list.map(fn(pair) { 
              let #(index, step) = pair
              int.to_string(index) <> ". " <> step.step_text
            })
            |> string.join("\n")
          }
          None -> "No method steps listed"
        }
        
        method_text
        |> birdie.snap(title: "recipe_method_steps")
      }),
    ]),
  ])
}

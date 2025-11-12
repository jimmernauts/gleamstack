import startest.{describe, it}
import birdie
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

import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import session.{type Ingredient, type MethodStep, type Recipe, type Tag, Ingredient, IngredientCategory, MethodStep, Recipe, Tag}

pub fn valid_recipe() -> Recipe {
  Recipe(
    id: Some("test-recipe-1"),
    slug: "test-recipe",
    title: "Test Recipe",
    cook_time: 30,
    prep_time: 15,
    serves: 4,
    author: Some("Test Chef"),
    source: Some("https://example.com/recipe"),
    ingredients: Some(dict.from_list([
      #(1, Ingredient(name: Some("Test Ingredient 1"), ismain: Some(True), quantity: Some("1"), units: Some("cup"), category: Some(IngredientCategory("main")))),
      #(2, Ingredient(name: Some("Test Ingredient 2"), ismain: Some(False), quantity: Some("2"), units: Some("tsp"), category: Some(IngredientCategory("spice")))),
    ])),
    method_steps: Some(dict.from_list([
      #(1, MethodStep(step_text: "First test step")),
      #(2, MethodStep(step_text: "Second test step")),
    ])),
    tags: Some(dict.from_list([
      #(1, Tag(name: "test", value: "testing")),
      #(2, Tag(name: "category", value: "demo")),
    ])),
    shortlisted: Some(False),
  )
}

pub fn minimal_recipe() -> Recipe {
  Recipe(
    id: Some("minimal-recipe"),
    slug: "minimal-recipe",
    title: "Minimal Recipe",
    cook_time: 0,
    prep_time: 0,
    serves: 1,
    author: None,
    source: None,
    ingredients: None,
    method_steps: None,
    tags: None,
    shortlisted: None,
  )
}

pub fn recipe_list() -> List(Recipe) {
  [valid_recipe(), minimal_recipe()]
}

pub fn valid_ingredient() -> Ingredient {
  Ingredient(name: Some("Test Ingredient"), ismain: Some(True), quantity: Some("1"), units: Some("cup"), category: Some(IngredientCategory("main")))
}

pub fn valid_method_step() -> MethodStep {
  MethodStep(step_text: "Test step description")
}

pub fn valid_tag() -> Tag {
  Tag(name: "category", value: "testing")
}

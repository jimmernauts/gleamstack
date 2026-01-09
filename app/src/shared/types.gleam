import gleam/dict.{type Dict}
import gleam/option.{type Option}
import rada/date.{type Date}

pub type PlanWeek =
  Dict(Date, PlanDay)

pub type PlanDay {
  PlanDay(date: Date, lunch: Option(PlannedMeal), dinner: Option(PlannedMeal))
}

pub type PlannedMeal {
  PlannedMeal(recipe: PlannedRecipe, complete: Bool)
}

pub type Recipe {
  Recipe(
    id: Option(String),
    title: String,
    slug: String,
    cook_time: Int,
    prep_time: Int,
    serves: Int,
    author: Option(String),
    source: Option(String),
    tags: Option(Dict(Int, Tag)),
    ingredients: Option(Dict(Int, Ingredient)),
    method_steps: Option(Dict(Int, MethodStep)),
    shortlisted: Option(Bool),
  )
}

pub type TagOption {
  TagOption(id: Option(String), name: String, options: List(String))
}

pub type MethodStep {
  MethodStep(step_text: String)
}

pub type Tag {
  Tag(name: String, value: String)
}

pub type Ingredient {
  Ingredient(
    name: Option(String),
    ismain: Option(Bool),
    quantity: Option(String),
    units: Option(String),
    category: Option(IngredientCategory),
  )
}

pub type IngredientCategory {
  IngredientCategory(name: String)
}

pub type PlannedRecipe {
  RecipeSlug(String)
  RecipeName(String)
}

pub type JsPlanDay {
  JsPlanDay(date: Int, lunch: Option(String), dinner: Option(String))
}

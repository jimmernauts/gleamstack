import gleam/option.{type Option}

pub type Msg {
  OnRouteChange(Route)
  CacheUpdatedMessage(List(Recipe))
  SaveUpdatedRecipe(Recipe)
}

pub type Model {
  Model(
    current_route: Route,
    current_recipe: Option(Recipe),
    recipes: List(Recipe),
  )
}

pub type Route {
  Home
  RecipeDetail(slug: String)
  RecipeBook
  EditRecipe(slug: String)
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
  )
}

pub type Recipe {
  Recipe(
    id: Option(String),
    title: String,
    slug: String,
    cook_time: Int,
    prep_time: Int,
    serves: Int,
    tags: Option(List(Tag)),
    ingredients: Option(List(Ingredient)),
    method_steps: Option(List(MethodStep)),
  )
}

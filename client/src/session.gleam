import gleam/dict.{type Dict}
import gleam/dynamic.{
  type Dynamic, dict, field, int, list, optional_field, string,
}
import gleam/io
import gleam/javascript/array.{type Array}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option}
import gleam/result
import lib/decoders
import lustre/effect.{type Effect}

pub type RecipeListMsg {
  DbRetrievedRecipes(List(Recipe))
  DbRetrievedTagOptions(List(TagOption))
}

pub type RecipeList {
  RecipeList(recipes: List(Recipe), tag_options: List(TagOption))
}

//-UPDATE------------------------------------------------------------

pub fn merge_recipe_into_model(recipe: Recipe, model: RecipeList) -> RecipeList {
  RecipeList(
    ..model,
    recipes: model.recipes
      |> list.map(fn(a) { #(a.id, a) })
      |> dict.from_list
      |> dict.merge(dict.from_list([#(recipe.id, recipe)]))
      |> dict.values(),
  )
}

pub fn get_recipes() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_recipes()
  |> promise.map(array.to_list)
  |> promise.map(list.map(_, decode_recipe))
  |> promise.map(result.all)
  |> promise.map(result.map(_, DbRetrievedRecipes))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "./db3.ts", "do_get_recipes")
fn do_get_recipes() -> Promise(Array(Dynamic))

pub fn get_tag_options() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_tagoptions()
  |> promise.map(array.to_list)
  |> promise.map(list.map(_, decode_tag_option))
  |> promise.map(io.debug)
  |> promise.map(result.all)
  |> promise.map(result.map(_, DbRetrievedTagOptions))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "./db3.ts", "do_get_tagoptions")
fn do_get_tagoptions() -> Promise(Array(Dynamic))

//-TYPES-------------------------------------------------------------

pub type Recipe {
  Recipe(
    id: Option(String),
    title: String,
    slug: String,
    cook_time: Int,
    prep_time: Int,
    serves: Int,
    tags: Option(Dict(Int, Tag)),
    ingredients: Option(Dict(Int, Ingredient)),
    method_steps: Option(Dict(Int, MethodStep)),
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
  )
}

//-ENCODERS-DECODERS----------------------------------------------

pub fn decode_recipe(d: Dynamic) -> Result(Recipe, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode9(
      Recipe,
      optional_field("id", of: string),
      field("title", of: string),
      field("slug", of: string),
      field("cook_time", of: int),
      field("prep_time", of: int),
      field("serves", of: int),
      optional_field("tags", of: dict(decoders.stringed_int, decode_tag)),
      optional_field(
        "ingredients",
        of: dict(decoders.stringed_int, decode_ingredient),
      ),
      optional_field(
        "method_steps",
        of: dict(decoders.stringed_int, decode_method_step),
      ),
    )
  decoder(d)
}

pub fn decode_ingredient(d: Dynamic) -> Result(Ingredient, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode4(
      Ingredient,
      optional_field("name", of: string),
      optional_field("ismain", of: decoders.stringed_bool),
      optional_field("quantity", of: string),
      optional_field("units", of: string),
    )
  decoder(d)
}

pub fn decode_tag(d: Dynamic) -> Result(Tag, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode2(Tag, field("name", of: string), field("value", of: string))
  decoder(d)
}

pub fn decode_method_step(
  d: Dynamic,
) -> Result(MethodStep, dynamic.DecodeErrors) {
  let decoder = dynamic.decode1(MethodStep, field("step_text", of: string))
  decoder(d)
}

pub fn decode_tag_option(d: Dynamic) -> Result(TagOption, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode3(
      TagOption,
      optional_field("id", of: string),
      field("name", of: string),
      field("options", of: list(of: string)),
    )
  let f = decoder(d)
  io.debug(f)
}

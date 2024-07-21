import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{
  type Dynamic, dict, field, int, list, optional_field, string,
}
import gleam/int
import gleam/io
import gleam/javascript/array.{type Array}
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option}
import gleam/result
import lib/utils
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
  |> promise.map(io.debug)
  |> promise.map(dynamic.dict(dynamic.string, decode_recipe))
  |> promise.map(io.debug)
  |> promise.map(result.map(_, dict.values))
  |> promise.map(result.map(_, DbRetrievedRecipes))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "./db.ts", "do_get_recipes")
fn do_get_recipes() -> Promise(Dynamic)

pub fn get_tag_options() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_tagoptions()
  |> promise.map(dynamic.dict(dynamic.string, decode_tag_option))
  |> promise.map(result.map(_, dict.values))
  |> promise.map(result.map(_, DbRetrievedTagOptions))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "./db.ts", "do_get_tagoptions")
fn do_get_tagoptions() -> Promise(Dynamic)

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

pub fn json_encode_ingredient(ingredient: Ingredient) -> Json {
  json.object([
    #("name", json.string(option.unwrap(ingredient.name, ""))),
    #("quantity", json.string(option.unwrap(ingredient.quantity, ""))),
    #("units", json.string(option.unwrap(ingredient.units, ""))),
    #(
      "ismain",
      json.string(bool.to_string(option.unwrap(ingredient.ismain, False))),
    ),
  ])
}

pub fn json_encode_ingredient_list(dict: Dict(Int, Ingredient)) -> Json {
  dict
  |> dict.to_list
  |> list.map(fn(pair: #(Int, Ingredient)) {
    #(int.to_string(pair.0), json_encode_ingredient(pair.1))
  })
  |> json.object
}

pub fn json_encode_method_step(method_step: MethodStep) -> Json {
  json.object([#("step_text", json.string(method_step.step_text))])
}

pub fn json_encode_method_step_list(dict: Dict(Int, MethodStep)) -> Json {
  dict
  |> dict.to_list
  |> list.map(fn(pair: #(Int, MethodStep)) {
    #(int.to_string(pair.0), json_encode_method_step(pair.1))
  })
  |> json.object
}

pub fn json_encode_tag(tag: Tag) -> Json {
  json.object([
    #("name", json.string(tag.name)),
    #("value", json.string(tag.value)),
  ])
}

pub fn json_encode_tag_list(dict: Dict(Int, Tag)) -> Json {
  dict
  |> dict.to_list
  |> list.map(fn(pair: #(Int, Tag)) {
    #(int.to_string(pair.0), json_encode_tag(pair.1))
  })
  |> json.object
}

// fn json_encode_tag_option_list(tag_options: List(String)) -> Json {
//  json.array(tag_options, json.string)
//}

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
      optional_field("tags", of: decode_tags),
      optional_field("ingredients", of: decode_ingredients),
      optional_field("method_steps", of: decode_method_steps),
    )
  decoder(d)
}

fn decode_ingredients(
  d: Dynamic,
) -> Result(Dict(Int, Ingredient), dynamic.DecodeErrors) {
  let decoder =
    dict(
      decode_stringed_int,
      dynamic.decode4(
        Ingredient,
        optional_field("name", of: string),
        optional_field("ismain", of: decode_stringed_bool),
        optional_field("quantity", of: string),
        optional_field("units", of: string),
      ),
    )
  dynamic.string(d)
  |> result.map(json.decode(_, decoder))
  |> utils.result_unnest(utils.json_decodeerror_to_decodeerror)
}

fn decode_tags(d: Dynamic) -> Result(Dict(Int, Tag), dynamic.DecodeErrors) {
  let decoder =
    dict(
      decode_stringed_int,
      dynamic.decode2(
        Tag,
        field("name", of: string),
        field("value", of: string),
      ),
    )
  dynamic.string(d)
  |> result.map(json.decode(_, decoder))
  |> utils.result_unnest(utils.json_decodeerror_to_decodeerror)
}

fn decode_method_steps(
  d: Dynamic,
) -> Result(Dict(Int, MethodStep), dynamic.DecodeErrors) {
  let decoder =
    dict(
      decode_stringed_int,
      dynamic.decode1(MethodStep, field("step_text", of: string)),
    )
  dynamic.string(d)
  |> result.map(json.decode(_, decoder))
  |> utils.result_unnest(utils.json_decodeerror_to_decodeerror)
}

fn decode_tag_option(d: Dynamic) -> Result(TagOption, dynamic.DecodeErrors) {
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

pub fn decode_stringed_bool(d: Dynamic) -> Result(Bool, dynamic.DecodeErrors) {
  dynamic.string(d)
  |> result.map(fn(a) {
    case a {
      "True" -> True
      "true" -> True
      "1" -> True
      _ -> False
    }
  })
}

pub fn decode_stringed_int(d: Dynamic) -> Result(Int, dynamic.DecodeErrors) {
  let decoder = dynamic.string
  decoder(d)
  |> result.map(int.parse)
  |> result.then(result.map_error(_, fn(_x) {
    [
      dynamic.DecodeError(
        expected: "a stringed int",
        found: "something else",
        path: [""],
      ),
    ]
  }))
}

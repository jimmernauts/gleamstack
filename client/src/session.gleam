import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import lib/utils
import lustre/effect.{type Effect}

pub type RecipeListMsg {
  DbSubscriptionOpened(String, fn() -> Nil)
  DbSubscribedOneRecipe(Dynamic)
  DbSubscribedRecipes(Dynamic)
  DbRetrievedRecipes(List(Recipe))
  DbRetrievedOneRecipe(Recipe)
  DbRetrievedTagOptions(List(TagOption))
  UserGroupedRecipeListByTag(String)
  UserGroupedRecipeListByAuthor
}

pub type RecipeListGroupBy {
  GroupByTag(String)
  GroupByAuthor
}

pub type RecipeList {
  RecipeList(
    recipes: List(Recipe),
    tag_options: List(TagOption),
    group_by: Option(RecipeListGroupBy),
  )
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

pub fn get_one_recipe_by_slug(slug: String) -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_one_recipe_by_slug(slug)
  |> promise.map(decode.run(_, decode_recipe(True)))
  |> promise.map(io.debug)
  |> promise.map(result.map(_, DbRetrievedOneRecipe))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "./db.ts", "do_get_one_recipe_by_slug")
fn do_get_one_recipe_by_slug(slug: String) -> Promise(Dynamic)

pub fn subscribe_to_one_recipe_by_slug(slug: String) -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_subscribe_to_one_recipe_by_slug(slug, fn(data) {
    data
    |> DbSubscribedOneRecipe
    |> dispatch
  })
  |> DbSubscriptionOpened(slug, _)
  |> dispatch
  Nil
}

@external(javascript, "./db.ts", "do_subscribe_to_one_recipe_by_slug")
fn do_subscribe_to_one_recipe_by_slug(
  slug: String,
  callback: fn(a) -> Nil,
) -> fn() -> Nil

pub fn get_recipes() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_recipes()
  |> promise.map(decode.run(_, decode.list(decode_recipe(True))))
  |> promise.map(result.map(_, DbRetrievedRecipes))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "./db.ts", "do_get_recipes")
fn do_get_recipes() -> Promise(Dynamic)

pub fn get_tag_options() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_tagoptions()
  |> promise.map(decode.run(_, decode.list(decode_tag_option())))
  |> promise.map(result.map(_, DbRetrievedTagOptions))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "./db.ts", "do_get_tagoptions")
fn do_get_tagoptions() -> Promise(Dynamic)

pub fn subscribe_to_recipe_summaries() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_subscribe_to_recipe_summaries(fn(data) {
    data
    |> DbSubscribedRecipes
    |> dispatch
  })
  |> DbSubscriptionOpened("recipes", _)
  |> dispatch
  Nil
}

@external(javascript, "./db.ts", "do_subscribe_to_recipe_summaries")
fn do_subscribe_to_recipe_summaries(callback: fn(a) -> Nil) -> fn() -> Nil

//-TYPES-------------------------------------------------------------

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

pub fn decode_recipe(
  inner_fields_json_stringified: Bool,
) -> decode.Decoder(Recipe) {
  use id <- decode.optional_field(
    "id",
    option.None,
    decode.optional(decode.string),
  )
  use title <- decode.field("title", decode.string)
  use slug <- decode.field(
    case inner_fields_json_stringified {
      True -> "slug"
      False -> "title"
    },
    case inner_fields_json_stringified {
      True -> decode.string
      False -> decode.map(decode.string, fn(t) { utils.slugify(t) })
    },
  )
  use cook_time <- decode.field("cook_time", decode.int)
  use prep_time <- decode.field("prep_time", decode.int)
  use serves <- decode.field("serves", decode.int)
  use author <- decode.optional_field(
    "author",
    option.None,
    decode.optional(decode.string),
  )
  use source <- decode.optional_field(
    "source",
    option.None,
    decode.optional(decode.string),
  )
  use tags <- decode.optional_field("tags", option.None, case
    inner_fields_json_stringified
  {
    True ->
      decode.optional(decode_json_string(decode_tags(), dict.from_list([])))
    False -> decode.optional(decode_tags())
  })
  use ingredients <- decode.optional_field("ingredients", option.None, case
    inner_fields_json_stringified
  {
    True ->
      decode.optional(decode_json_string(
        decode_ingredients(),
        dict.from_list([]),
      ))
    False -> decode.optional(decode_ingredients_array())
  })
  use method_steps <- decode.optional_field("method_steps", option.None, case
    inner_fields_json_stringified
  {
    True ->
      decode.optional(decode_json_string(
        decode_method_steps(),
        dict.from_list([]),
      ))
    False -> decode.optional(decode_method_steps_array())
  })
  use shortlisted <- decode.optional_field(
    "shortlisted",
    option.None,
    decode.optional(decode.bool),
  )
  decode.success(Recipe(
    id:,
    title:,
    slug:,
    cook_time:,
    prep_time:,
    serves:,
    author:,
    source:,
    tags:,
    ingredients:,
    method_steps:,
    shortlisted:,
  ))
}

fn decode_tags() -> decode.Decoder(Dict(Int, Tag)) {
  let tag_decoder = {
    use name <- decode.field("name", decode.string)
    use value <- decode.field("value", decode.string)
    decode.success(Tag(name:, value:))
  }
  decode.dict(decode_stringed_int(), tag_decoder)
}

fn decode_ingredients_array() -> decode.Decoder(Dict(Int, Ingredient)) {
  let list_decoder = decode.list(ingredient_decoder())
  list_decoder
  |> decode.map(list.index_map(_, fn(v, i) { #(i, v) }))
  |> decode.map(dict.from_list)
}

fn ingredient_decoder() -> decode.Decoder(Ingredient) {
  use name <- decode.optional_field(
    "name",
    option.None,
    decode.optional(decode.string),
  )
  use ismain <- decode.optional_field(
    "ismain",
    option.None,
    decode.optional(decode_stringed_bool()),
  )
  use quantity <- decode.optional_field(
    "quantity",
    option.None,
    decode.optional(decode.string),
  )
  use units <- decode.optional_field(
    "units",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(Ingredient(
    name: name,
    ismain: ismain,
    quantity: quantity,
    units: units,
  ))
}

fn decode_ingredients() -> decode.Decoder(Dict(Int, Ingredient)) {
  decode.dict(decode_stringed_int(), ingredient_decoder())
}

fn decode_method_steps_array() -> decode.Decoder(Dict(Int, MethodStep)) {
  let method_step_decoder = {
    use step_text <- decode.field("step_text", decode.string)
    decode.success(MethodStep(step_text:))
  }
  let list_decoder = decode.list(method_step_decoder)
  list_decoder
  |> decode.map(list.index_map(_, fn(v, i) { #(i, v) }))
  |> decode.map(dict.from_list)
}

fn decode_method_steps() -> decode.Decoder(Dict(Int, MethodStep)) {
  let method_step_decoder = {
    use step_text <- decode.field("step_text", decode.string)
    decode.success(MethodStep(step_text:))
  }
  decode.dict(decode_stringed_int(), method_step_decoder)
}

fn decode_tag_option() -> decode.Decoder(TagOption) {
  use id <- decode.optional_field(
    "id",
    option.None,
    decode.optional(decode.string),
  )
  use name <- decode.field("name", decode.string)
  use options <- decode.field("options", decode.list(decode.string))
  decode.success(TagOption(id:, name:, options:))
}

fn decode_stringed_int() -> decode.Decoder(Int) {
  decode.string |> decode.map(int.parse) |> decode.map(result.unwrap(_, 0))
}

pub fn decode_stringed_bool() -> decode.Decoder(Bool) {
  decode.string
  |> decode.then(fn(d) {
    case d {
      "True" -> decode.success(True)
      "true" -> decode.success(True)
      "1" -> decode.success(True)
      _ -> decode.success(False)
    }
  })
}

pub fn decode_json_string(
  inner_decoder: decode.Decoder(a),
  default: a,
) -> decode.Decoder(a) {
  decode.string
  |> decode.then(fn(json_string) {
    case json.parse(json_string, inner_decoder) {
      Ok(a) -> decode.success(a)
      b ->
        decode.failure(
          default,
          string.concat([
            "Expected json, but I got ",
            json_string,
            "The inner error was: ",
            string.inspect(b),
          ]),
        )
    }
  })
}

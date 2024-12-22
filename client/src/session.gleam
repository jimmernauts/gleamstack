import decode
import decode/zero as decode2
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{
  type Dynamic, dict, field, int, list, optional_field, string,
}
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
  |> promise.map(decode2.run(_, decode2_recipe()))
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
  |> promise.map(dynamic.list(decode_recipe))
  |> promise.map(result.map(_, DbRetrievedRecipes))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "./db.ts", "do_get_recipes")
fn do_get_recipes() -> Promise(Dynamic)

pub fn get_tag_options() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_tagoptions()
  |> promise.map(dynamic.list(decode_tag_option))
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

pub fn decode2_recipe() -> decode2.Decoder(Recipe) {
  use id <- decode2.optional_field(
    "id",
    option.None,
    decode2.optional(decode2.string),
  )
  use title <- decode2.field("title", decode2.string)
  use slug <- decode2.field("slug", decode2.string)
  use cook_time <- decode2.field("cook_time", decode2.int)
  use prep_time <- decode2.field("prep_time", decode2.int)
  use serves <- decode2.field("serves", decode2.int)
  use author <- decode2.optional_field(
    "author",
    option.None,
    decode2.optional(decode2.string),
  )
  use source <- decode2.optional_field(
    "source",
    option.None,
    decode2.optional(decode2.string),
  )
  use tags <- decode2.optional_field(
    "tags",
    option.None,
    decode2.optional(decode2_json_string(decode2_tags(), dict.from_list([]))),
  )
  use ingredients <- decode2.optional_field(
    "ingredients",
    option.None,
    decode2.optional(decode2_json_string(
      decode2_ingredients(),
      dict.from_list([]),
    )),
  )
  use method_steps <- decode2.optional_field(
    "method_steps",
    option.None,
    decode2.optional(decode2_json_string(
      decode2_method_steps(),
      dict.from_list([]),
    )),
  )
  use shortlisted <- decode2.optional_field(
    "shortlisted",
    option.None,
    decode2.optional(decode2.bool),
  )
  decode2.success(Recipe(
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

fn decode2_tags() -> decode2.Decoder(Dict(Int, Tag)) {
  let tag_decoder = {
    use name <- decode2.field("name", decode2.string)
    use value <- decode2.field("value", decode2.string)
    decode2.success(Tag(name:, value:))
  }
  decode2.dict(decode2_stringed_int(), tag_decoder)
}

fn decode2_ingredients() -> decode2.Decoder(Dict(Int, Ingredient)) {
  let ingredient_decoder = {
    use name <- decode2.optional_field(
      "name",
      option.None,
      decode2.optional(decode2.string),
    )
    use ismain <- decode2.optional_field(
      "ismain",
      option.None,
      decode2.optional(decode2_stringed_bool()),
    )
    use quantity <- decode2.optional_field(
      "quantity",
      option.None,
      decode2.optional(decode2.string),
    )
    use units <- decode2.optional_field(
      "units",
      option.None,
      decode2.optional(decode2.string),
    )
    decode2.success(Ingredient(
      name: name,
      ismain: ismain,
      quantity: quantity,
      units: units,
    ))
  }

  decode2.dict(decode2_stringed_int(), ingredient_decoder)
}

fn decode2_method_steps() -> decode2.Decoder(Dict(Int, MethodStep)) {
  let method_step_decoder = {
    use step_text <- decode2.field("step_text", decode2.string)
    decode2.success(MethodStep(step_text:))
  }
  decode2.dict(decode2_stringed_int(), method_step_decoder)
}

fn decode2_stringed_int() -> decode2.Decoder(Int) {
  decode2.string |> decode2.map(int.parse) |> decode2.map(result.unwrap(_, 0))
}

pub fn decode2_stringed_bool() -> decode2.Decoder(Bool) {
  decode2.string
  |> decode2.then(fn(d) {
    case d {
      "True" -> decode2.success(True)
      "true" -> decode2.success(True)
      "1" -> decode2.success(True)
      _ -> decode2.success(False)
    }
  })
}

fn decode2_json_string(
  inner_decoder: decode2.Decoder(a),
  default: a,
) -> decode2.Decoder(a) {
  let wrapper = fn(a) { decode2.run(a, inner_decoder) }

  decode2.string
  |> decode2.then(fn(json_string) {
    case json.decode(json_string, wrapper) {
      Ok(a) -> decode2.success(a)
      b ->
        decode2.failure(
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

pub fn decode_recipe(d: Dynamic) -> Result(Recipe, dynamic.DecodeErrors) {
  decode.into({
    use id <- decode.parameter
    use title <- decode.parameter
    use slug <- decode.parameter
    use cook_time <- decode.parameter
    use prep_time <- decode.parameter
    use serves <- decode.parameter
    use author <- decode.parameter
    use source <- decode.parameter
    use tags <- decode.parameter
    use ingredients <- decode.parameter
    use method_steps <- decode.parameter
    use shortlisted <- decode.parameter
    Recipe(
      id: id,
      title: title,
      slug: slug,
      cook_time: cook_time,
      prep_time: prep_time,
      serves: serves,
      author: author,
      source: source,
      tags: tags,
      ingredients: ingredients,
      method_steps: method_steps,
      shortlisted: shortlisted,
    )
  })
  |> decode.field("id", decode.optional(decode.string))
  |> decode.field("title", decode.string)
  |> decode.field("slug", decode.string)
  |> decode.field("cook_time", decode.int)
  |> decode.field("prep_time", decode.int)
  |> decode.field("serves", decode.int)
  |> decode.field("author", decode.optional(decode.string))
  |> decode.field("source", decode.optional(decode.string))
  |> decode.field(
    "tags",
    decode.optional(json_string_decoder(decode_json_tags())),
  )
  |> decode.field(
    "ingredients",
    decode.optional(json_string_decoder(decode_json_ingredients())),
  )
  |> decode.field(
    "method_steps",
    decode.optional(json_string_decoder(decode_json_method_steps())),
  )
  |> decode.field("shortlisted", decode.optional(decode.bool))
  |> decode.from(d)
}

fn decode_json_ingredients() -> decode.Decoder(Dict(Int, Ingredient)) {
  let ingredient_decoder =
    decode.into({
      use name <- decode.parameter
      use ismain <- decode.parameter
      use quantity <- decode.parameter
      use units <- decode.parameter
      Ingredient(name: name, ismain: ismain, quantity: quantity, units: units)
    })
    |> decode.field("name", decode.optional(decode.string))
    |> decode.field("ismain", decode.optional(stringed_bool_decoder()))
    |> decode.field("quantity", decode.optional(decode.string))
    |> decode.field("units", decode.optional(decode.string))

  decode.dict(stringed_int_decoder(), ingredient_decoder)
}

fn decode_json_tags() -> decode.Decoder(Dict(Int, Tag)) {
  let tag_decoder =
    decode.into({
      use name <- decode.parameter
      use value <- decode.parameter
      Tag(name: name, value: value)
    })
    |> decode.field("name", decode.string)
    |> decode.field("value", decode.string)

  decode.dict(stringed_int_decoder(), tag_decoder)
}

fn decode_json_method_steps() -> decode.Decoder(Dict(Int, MethodStep)) {
  let method_step_decoder =
    decode.into({
      use step_text <- decode.parameter
      MethodStep(step_text: step_text)
    })
    |> decode.field("step_text", decode.string)

  decode.dict(stringed_int_decoder(), method_step_decoder)
}

fn decode_tag_option(d: Dynamic) -> Result(TagOption, dynamic.DecodeErrors) {
  let options_decoder = fn(d) {
    dynamic.string(d)
    |> result.map(json.decode(_, dynamic.list(of: dynamic.string)))
    |> utils.result_unnest(utils.json_decodeerror_to_decodeerror)
  }
  let decoder =
    dynamic.decode3(
      TagOption,
      optional_field("id", of: string),
      field("name", of: string),
      field("options", of: options_decoder),
    )
  decoder(d)
}

pub fn json_string_decoder(
  inner_decoder: decode.Decoder(t),
) -> decode.Decoder(t) {
  let wrapper = fn(a) { decode.from(inner_decoder, a) }

  decode.string
  |> decode.then(fn(json_string) {
    case json.decode(json_string, wrapper) {
      Ok(a) -> decode.into(a)
      b ->
        decode.fail(
          string.concat([
            "Expected a json string, but I got ",
            json_string,
            "The inner error was: ",
            string.inspect(b),
          ]),
        )
    }
  })
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

pub fn stringed_bool_decoder() -> decode.Decoder(Bool) {
  decode.string
  |> decode.then(fn(d) {
    case d {
      "True" -> decode.into(True)
      "true" -> decode.into(True)
      "1" -> decode.into(True)
      _ -> decode.into(False)
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

fn stringed_int_decoder() -> decode.Decoder(Int) {
  decode.string
  |> decode.then(fn(d) {
    case int.parse(d) {
      Ok(a) -> decode.into(a)
      _ -> decode.fail("Expected a stringed int")
    }
  })
}

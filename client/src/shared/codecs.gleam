import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import lib/utils
import shared/types.{
  type Ingredient, type IngredientCategory, type MethodStep, type Recipe,
  type Tag, type TagOption, Ingredient, IngredientCategory, MethodStep, Recipe,
  Tag, TagOption,
}

pub fn json_encode_ingredient(ingredient: Ingredient) -> Json {
  json.object([
    #("name", json.string(option.unwrap(ingredient.name, ""))),
    #("quantity", json.string(option.unwrap(ingredient.quantity, ""))),
    #("units", json.string(option.unwrap(ingredient.units, ""))),
    #(
      "ismain",
      json.string(bool.to_string(option.unwrap(ingredient.ismain, False))),
    ),
    #(
      "category",
      json_encode_ingredient_category(option.unwrap(
        ingredient.category,
        IngredientCategory(name: ""),
      )),
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

pub fn json_encode_ingredient_category(
  ingredient_category: IngredientCategory,
) -> Json {
  json.object([
    #("name", json.string(ingredient_category.name)),
  ])
}

// fn json_encode_tag_option_list(tag_options: List(String)) -> Json {
//  json.array(tag_options, json.string)
//}

pub fn decode_recipe_with_inner_json() -> decode.Decoder(Recipe) {
  use id <- decode.optional_field(
    "id",
    option.None,
    decode.optional(decode.string),
  )
  use title <- decode.field("title", decode.string)
  use slug <- decode.field("slug", decode.string)
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
  use tags <- decode.optional_field(
    "tags",
    option.None,
    decode.optional(json_string_decoder(decode_tags(), dict.from_list([]))),
  )
  use ingredients <- decode.optional_field(
    "ingredients",
    option.None,
    decode.optional(json_string_decoder(
      decode_ingredients(),
      dict.from_list([]),
    )),
  )
  use method_steps <- decode.optional_field(
    "method_steps",
    option.None,
    decode.optional(json_string_decoder(
      decode_method_steps(),
      dict.from_list([]),
    )),
  )
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

pub fn decode_recipe_no_json() -> decode.Decoder(Recipe) {
  use id <- decode.optional_field(
    "id",
    option.None,
    decode.optional(decode.string),
  )
  use title <- decode.field("title", decode.string)
  use slug <- decode.field(
    "title",
    decode.map(decode.string, fn(t) { utils.slugify(t) }),
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
  use tags <- decode.optional_field(
    "tags",
    option.None,
    decode.optional(decode_tags()),
  )
  use ingredients <- decode.optional_field(
    "ingredients",
    option.None,
    decode.optional(decode_ingredients_array()),
  )
  use method_steps <- decode.optional_field(
    "method_steps",
    option.None,
    decode.optional(decode_method_steps_array()),
  )
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

pub fn ingredient_decoder() -> decode.Decoder(Ingredient) {
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
  use category <- decode.optional_field(
    "category",
    option.None,
    decode.optional(decode_ingredient_category()),
  )
  decode.success(Ingredient(
    name: name,
    ismain: ismain,
    quantity: quantity,
    units: units,
    category: category,
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

pub fn decode_tag_option() -> decode.Decoder(TagOption) {
  use id <- decode.optional_field(
    "id",
    option.None,
    decode.optional(decode.string),
  )
  use name <- decode.field("name", decode.string)
  use options <- decode.field(
    "options",
    json_string_decoder(decode.list(decode.string), []),
  )
  decode.success(TagOption(id:, name:, options:))
}

fn decode_ingredient_category() -> decode.Decoder(IngredientCategory) {
  use name <- decode.field("name", decode.string)
  decode.success(IngredientCategory(name:))
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

pub fn json_string_decoder(
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

pub fn json_encode_planned_recipe(planned_recipe: types.PlannedRecipe) -> Json {
  case planned_recipe {
    types.RecipeSlug(slug) ->
      json.object([
        #("type", json.string("slug")),
        #("value", json.string(slug)),
      ])
    types.RecipeName(name) ->
      json.object([
        #("type", json.string("name")),
        #("value", json.string(name)),
      ])
  }
}

pub fn decode_planned_recipe() -> decode.Decoder(types.PlannedRecipe) {
  use type_ <- decode.field("type", decode.string)
  use value <- decode.field("value", decode.string)
  case type_ {
    "slug" -> decode.success(types.RecipeSlug(value))
    "name" -> decode.success(types.RecipeName(value))
    _ -> decode.failure(types.RecipeName(""), "Unknown PlannedRecipe type")
  }
}

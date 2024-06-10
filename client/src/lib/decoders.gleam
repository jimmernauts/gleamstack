import gleam/dynamic.{
  type Dynamic, bool, field, int, list, optional_field, string,
}
import types

pub fn decode_recipe(d: Dynamic) -> Result(types.Recipe, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode9(
      types.Recipe,
      optional_field("id", of: string),
      field("title", of: string),
      field("slug", of: string),
      field("cook_time", of: int),
      field("prep_time", of: int),
      field("serves", of: int),
      optional_field("tags", of: list(decode_tag)),
      optional_field("ingredients", of: list(decode_ingredient)),
      optional_field("method_steps", of: list(decode_method_step)),
    )
  decoder(d)
}

fn decode_ingredient(
  d: Dynamic,
) -> Result(types.Ingredient, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode4(
      types.Ingredient,
      optional_field("name", of: string),
      optional_field("ismain", of: bool),
      optional_field("quantity", of: string),
      optional_field("units", of: string),
    )
  decoder(d)
}

fn decode_tag(d: Dynamic) -> Result(types.Tag, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode2(
      types.Tag,
      field("name", of: string),
      field("value", of: string),
    )
  decoder(d)
}

fn decode_method_step(
  d: Dynamic,
) -> Result(types.MethodStep, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode1(types.MethodStep, field("step_text", of: string))
  decoder(d)
}

fn decode_tag_option(
  d: Dynamic,
) -> Result(types.TagOption, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode3(
      types.TagOption,
      optional_field("id", of: string),
      field("name", of: string),
      field("options", of: list(of: string)),
    )
  decoder(d)
}

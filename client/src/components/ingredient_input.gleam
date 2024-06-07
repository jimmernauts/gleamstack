import gleam/int.{to_string}
import gleam/option.{type Option, Some, unwrap}
import lustre/attribute.{
  attribute, checked, class, id, name, placeholder, type_, value,
}
import lustre/element.{text}
import lustre/element/html.{button, div, input, label, span}
import types

pub fn ingredient_input(ingredient: Option(types.Ingredient), index: Int) {
  div([class("my-0.5 w-full flex justify-between items-baseline")], [
    input([
      attribute("aria-label", "Enter ingredient name"),
      name("ingredient-name-" <> to_string(index)),
      type_("text"),
      placeholder("Ingredient"),
      class(
        "pt-0.5 w-[16ch] xxs:w-[23ch] xs:w-[28ch] sm:w-[16ch] md:w-[23ch] lg:w-[28ch] text-base input-base input-focus bg-ecru-white-100",
      ),
      value(case ingredient {
        Some(ing) -> unwrap(ing.name, "")
        _ -> ""
      }),
    ]),
    div([class("flex justify-end gap-1 items-baseline")], [
      input([
        attribute("aria-label", "Enter ingredient quanitity"),
        name("ingredient-qty-" <> to_string(index)),
        type_("text"),
        placeholder("Qty"),
        class("pt-0.5 w-[4ch] text-sm input-focus bg-ecru-white-100"),
        value(case ingredient {
          Some(ing) -> unwrap(ing.quantity, "")
          _ -> ""
        }),
      ]),
      input([
        attribute("aria-label", "Enter ingredient units"),
        name("ingredient-units-" <> to_string(index)),
        type_("text"),
        placeholder("Units"),
        class("pt-0.5 w-[5ch] text-sm mr-0 input-focus bg-ecru-white-100"),
        value(case ingredient {
          Some(ing) -> unwrap(ing.units, "")
          _ -> ""
        }),
      ]),
      div([class("flex text-xs items-baseline")], [
        label(
          [
            class("ingredient-toggle"),
            attribute("aria-label", "Toggle main ingredient"),
          ],
          [
            input([
              checked(case ingredient {
                Some(ing) -> unwrap(ing.ismain, False)
                _ -> False
              }),
              name("`ingredient-main-" <> to_string(index)),
              type_("checkbox"),
            ]),
            span([], []),
          ],
        ),
        button(
          [
            class("text-ecru-white-950"),
            type_("button"),
            id("remove-ingredient-input"),
          ],
          [text("➖")],
        ),
        button(
          [
            class("text-ecru-white-950"),
            type_("button"),
            id("add-ingredient-input"),
          ],
          [text("➕")],
        ),
      ]),
    ]),
  ])
}

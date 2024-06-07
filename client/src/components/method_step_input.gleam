import gleam/int.{to_string}
import gleam/option.{type Option, Some}
import lustre/attribute.{class, id, name, type_}
import lustre/element.{text}
import lustre/element/html.{button, div, label, textarea}
import types

pub fn method_step_input(method_step: Option(types.MethodStep), index: Int) {
  div([class("flex w-full items-baseline col-span-full px-1 mb-1")], [
    label([class("font-mono")], [text(index + 1 |> to_string)]),
    textarea(
      [
        name("method-step-" <> index |> to_string),
        id("method-step-" <> index |> to_string),
        class(
          "px-2 py-1 bg-ecru-white-100 w-full input-focus text-base resize-none",
        ),
      ],
      case method_step {
        Some(a) -> a.step_text
        _ -> ""
      },
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
  ])
}

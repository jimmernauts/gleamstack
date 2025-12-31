import gleam/dynamic/decode.{type Dynamic}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lib/utils
import lustre.{type App}
import lustre/attribute.{type Attribute, attribute, class, id, name, value}
import lustre/component.{on_attribute_change}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment, text}
import lustre/element/html.{button, div, li, textarea, ul}
import lustre/event.{on, on_click, on_focus, on_input, on_keydown}
import plinth/javascript/global
import shared/codecs
import shared/types.{type Recipe}

pub type RecipeSummary {
  RecipeSummary(title: String, slug: String)
}

pub fn app() -> App(Nil, Model, Msg) {
  lustre.component(init, update, view, [
    on_attribute_change("recipes", fn(attr_str) {
      attr_str
      |> json.parse(decode.list(decode_recipe_summary()))
      |> result.map(RetrievedSearchItems)
      |> result.map_error(fn(_x) { Nil })
    }),
    on_attribute_change("search-term", fn(attr_str) {
      json.parse(attr_str, codecs.planned_recipe_decoder())
      |> result.map(RetrievedInitialSearchTerm)
      |> result.map_error(fn(_x) { Nil })
    }),
  ])
}

pub fn typeahead(attrs: List(Attribute(msg))) -> Element(msg) {
  element.element("type-ahead-2", attrs, [])
}

pub fn recipes(all: List(Recipe)) -> Attribute(msg) {
  attribute.attribute(
    "recipes",
    json.to_string(
      json.array(all, fn(r) {
        json.object([
          #("title", json.string(r.title)),
          #("slug", json.string(r.slug)),
        ])
      }),
    ),
  )
}

pub fn search_term(term: types.PlannedRecipe) -> Attribute(msg) {
  attribute.attribute(
    "search-term",
    json.to_string(codecs.encode_planned_recipe(term)),
  )
}

pub fn class_list(class_list: String) -> Attribute(msg) {
  attribute.attribute("class", class_list)
}

//-MODEL------------------------------------------------------

pub type Model {
  Model(
    elem_id: String,
    search_items: List(RecipeSummary),
    search_term: types.PlannedRecipe,
    found_items: List(RecipeSummary),
    is_open: Bool,
    is_focused: Bool,
    blur_debounce_timer: Option(global.TimerID),
    hovered_item: Option(Int),
  )
}

fn init(_) -> #(Model, Effect(Msg)) {
  let elem_id = int.to_string(int.random(999_999))
  #(
    Model(elem_id, [], types.RecipeName(""), [], False, False, None, None),
    effect.none(),
  )
}

//-UPDATE------------------------------------------------------

pub type Msg {
  RetrievedSearchItems(List(RecipeSummary))
  RetrievedInitialSearchTerm(types.PlannedRecipe)
  UserTypedInSearchInput(String)
  UserSelectedValue(String)
  UserSelectedOption(RecipeSummary)
  UserHoveredOption(Int)
  UserUnHoveredOption(Int)
  UserFocusedSearchInput
  UserMousedDownOption
  UserBlurredSearchInput
  UserClearedSearchInput
  UserClosedOptionList
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    RetrievedInitialSearchTerm(a) -> {
      #(Model(..model, search_term: a), effect.none())
    }
    RetrievedSearchItems(a) -> {
      #(Model(..model, search_items: a, found_items: a), effect.none())
    }
    UserTypedInSearchInput(a) -> {
      #(
        Model(
          ..model,
          search_term: types.RecipeName(a),
          found_items: {
            case string.length(a) {
              num if num < 1 -> []
              _ ->
                list.filter(model.search_items, fn(r) {
                  string.contains(
                    string.lowercase(r.title),
                    string.lowercase(a),
                  )
                })
            }
          },
          is_open: !list.any(model.search_items, fn(r) { r.title == a }),
        ),
        effect.none(),
      )
    }
    UserSelectedValue(a) -> {
      #(
        model,
        event.emit(
          "typeahead-change",
          json.string(
            json.to_string(codecs.encode_planned_recipe(types.RecipeName(a))),
          ),
        ),
      )
    }
    UserSelectedOption(a) -> {
      #(
        Model(..model, is_open: False, search_term: types.RecipeSlug(a.slug)),
        event.emit(
          "typeahead-change",
          json.string(
            json.to_string(
              codecs.encode_planned_recipe(types.RecipeSlug(a.slug)),
            ),
          ),
        ),
      )
    }
    UserFocusedSearchInput -> {
      #(
        Model(
          ..model,
          is_focused: True,
          is_open: !list.any(model.search_items, fn(r) {
            case model.search_term {
              types.RecipeName(a) -> r.title == a
              types.RecipeSlug(a) -> r.slug == a
            }
          }),
        ),
        effect.none(),
      )
    }
    UserMousedDownOption -> {
      #(model, effect.none())
    }
    UserBlurredSearchInput -> {
      #(Model(..model, is_focused: False, is_open: False), effect.none())
    }
    UserClosedOptionList -> {
      #(
        Model(..model, is_open: False, is_focused: False, hovered_item: None),
        effect.none(),
      )
    }
    UserHoveredOption(a) -> {
      #(Model(..model, hovered_item: Some(a)), effect.none())
    }
    UserUnHoveredOption(_a) -> {
      #(Model(..model, hovered_item: None), effect.none())
    }
    UserClearedSearchInput -> {
      #(
        Model(
          ..model,
          search_term: types.RecipeName(""),
          hovered_item: None,
          is_focused: False,
          is_open: False,
        ),
        {
          use dispatch <- effect.from
          UserSelectedValue("") |> dispatch
        },
      )
    }
  }
}

//-VIEW--------------------------------------------------------

fn search_result(
  model: Model,
  result_value: RecipeSummary,
  index: Int,
) -> Element(Msg) {
  li(
    [
      attribute("role", "option"),
      attribute("data-index", int.to_string(index)),
      class({
        case model.hovered_item == Some(index) {
          True -> "bg-ecru-white-100"
          _ -> ""
        }
      }),
      class("px-1"),
      on_click(UserSelectedOption(result_value)),
      on("mouseover", {
        use index <- decode.subfield(
          ["target", "dataset", "index"],
          decode.string
            |> decode.then(fn(s) {
              case int.parse(s) {
                Ok(i) -> decode.success(i)
                Error(_) -> decode.failure(0, "Expected integer string")
              }
            }),
        )
        decode.success(UserHoveredOption(index))
      }),
      on("mouseout", {
        use index <- decode.subfield(
          ["target", "dataset", "index"],
          decode.string
            |> decode.then(fn(s) {
              case int.parse(s) {
                Ok(i) -> decode.success(i)
                Error(_) -> decode.failure(0, "Expected integer string")
              }
            }),
        )
        decode.success(UserUnHoveredOption(index))
      }),
      event.advanced("mousedown", {
        decode.success(event.handler(UserMousedDownOption, True, False))
      }),
    ],
    [text(result_value.title)],
  )
}

fn find_recipe_in_list_by_slug(
  slug: String,
  list: List(RecipeSummary),
) -> Option(RecipeSummary) {
  list |> list.find(fn(r) { r.slug == slug }) |> option.from_result
}

fn view(model: Model) -> Element(Msg) {
  let found_term = case model.search_term {
    types.RecipeName(a) -> a
    types.RecipeSlug(a) ->
      find_recipe_in_list_by_slug(a, model.search_items)
      |> option.map(fn(r) { r.title })
      |> option.unwrap("")
  }
  fragment([
    div([class("relative")], [
      textarea(
        [
          id("meal-input-" <> model.elem_id),
          attribute.styles([
            #("field-sizing", "content"),
            #("overflow-x", "hidden"),
            #("width", "100%"),
            #(
              "font-family",
              "Charter, 'Bitstream Charter', 'Sitka Text', Cambria, serif",
            ),
            #(
              "font-size",
              "clamp(1.125rem, calc(1.125rem + ((1.25 - 1.125) * ((100vw - 20rem) / (96 - 20)))), 1.25rem)",
            ),
            #("line-height", "1.6"),
            #("color", "rgb(47 40 27)"),
            #("background-color", "rgb(241 241 227)"),
            #("border-width", "0px"),
            #("border-bottom-width", "0px"),
            #("padding-top", "0px"),
            #("padding-bottom", "0px"),
            #("line-height", "inherit"),
            #("resize", "none"),
          ]),
          class(case string.length(found_term) {
            num if num > 38 -> "text-base"
            num if num > 17 -> "text-lg"
            _ -> "text-xl"
          }),
          value(found_term),
          attribute("autocapitalize", "none"),
          attribute("autocomplete", "off"),
          attribute("aria-autocomplete", "list"),
          attribute("role", "combobox"),
          name("meal-input"),
          on_input(UserTypedInSearchInput),
          on("change", {
            use val <- decode.subfield(["target", "value"], decode.string)
            decode.success(UserSelectedValue(val))
          }),
          on_focus(UserFocusedSearchInput),
          on("blur", decode.success(UserBlurredSearchInput)),
        ],
        "",
      ),
      button(
        [
          class("absolute top-1 right-1 cursor-pointer text-xs opacity-80"),
          on_click(UserClearedSearchInput),
        ],
        [text("✖️")],
      ),
    ]),
    ul(
      [
        id("search-results-" <> model.elem_id),
        class(
          "font-mono z-10 absolute bg-ecru-white-50 border border-ecru-white-950 text-xs max-h-full overflow-x-visible overflow-y-scroll",
        ),
        attribute("role", "listbox"),
        attribute.styles(case model.is_open, list.length(model.found_items) {
          True, 0 -> [#("display", "none")]
          True, _ -> [#("display", "block")]
          False, _ -> [#("display", "none")]
        }),
        attribute("aria-expanded", case model.is_open {
          True -> "true"
          False -> "false"
        }),
      ],
      {
        model.found_items
        |> list.index_map(fn(a, i) { search_result(model, a, i) })
      },
    ),
  ])
}

//----DECODERS & TYPES-------------------------------------------------------------------------

pub fn decode_stringed_bool(
  d: Dynamic,
) -> Result(Bool, List(decode.DecodeError)) {
  decode.run(d, decode.string)
  |> result.map(fn(a) {
    case a {
      "True" -> True
      "true" -> True
      "1" -> True
      _ -> False
    }
  })
}

pub fn decode_stringed_int(d: Dynamic) -> Result(Int, List(decode.DecodeError)) {
  decode.run(d, decode.string)
  |> result.map(int.parse)
  |> result.try(
    result.map_error(_, fn(_x) {
      [
        decode.DecodeError(
          expected: "a stringed int",
          found: "something else",
          path: [""],
        ),
      ]
    }),
  )
}

fn decode_recipe_summary() -> decode.Decoder(RecipeSummary) {
  use title <- decode.field("title", decode.string)
  use slug <- decode.field("slug", decode.string)
  decode.success(RecipeSummary(title:, slug:))
}

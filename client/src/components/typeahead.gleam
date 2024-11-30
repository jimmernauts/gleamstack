import gleam/dict.{type Dict}
import gleam/dynamic.{type Decoder, type Dynamic}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lib/utils
import lustre.{type App}
import lustre/attribute.{type Attribute, attribute, class, id, name, value}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment, text}
import lustre/element/html.{li, option, textarea, ul}
import lustre/event.{on, on_click, on_focus, on_input, on_keydown}
import plinth/javascript/global

pub fn app() -> App(Nil, Model, Msg) {
  lustre.component(init, update, view, on_attribute_change())
}

pub fn typeahead(attrs: List(Attribute(msg))) -> Element(msg) {
  element.element("type-ahead", attrs, [])
}

pub fn recipe_titles(all: List(String)) -> Attribute(msg) {
  attribute.property("recipe-titles", all)
}

pub fn search_term(term: String) -> Attribute(msg) {
  attribute.property("search-term", term)
}

pub fn class_list(class_list: String) -> Attribute(msg) {
  attribute.attribute("class", class_list)
}

//-MODEL------------------------------------------------------

pub type Model {
  Model(
    elem_id: String,
    search_items: List(String),
    search_term: String,
    found_items: List(String),
    is_open: Bool,
    is_focused: Bool,
    blur_debounce_timer: Option(global.TimerID),
    hovered_item: Option(Int),
  )
}

fn init(_) -> #(Model, Effect(Msg)) {
  let elem_id = int.to_string(int.random(999_999))
  #(Model(elem_id, [], "", [], False, False, None, None), effect.none())
}

//-UPDATE------------------------------------------------------

pub type Msg {
  RetrievedSearchItems(List(String))
  RetrievedInitialSearchTerm(String)
  UserTypedInSearchInput(String)
  UserPressedKeyInSearchInput(String)
  UserSelectedValue(String)
  UserSelectedOption(String)
  UserHoveredOption(Int)
  UserUnHoveredOption(Int)
  UserFocusedSearchInput
  UserMousedDownOption
  UserBlurredSearchInput
  UserClosedOptionList
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  io.debug(msg)
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
          search_term: a,
          found_items: {
            case string.length(a) {
              num if num < 1 -> []
              _ ->
                list.filter(model.search_items, fn(r) {
                  string.contains(string.lowercase(r), string.lowercase(a))
                })
            }
          },
          is_open: !list.contains(model.search_items, a),
        ),
        effect.none(),
      )
    }
    UserSelectedValue(a) -> {
      #(model, event.emit("typeahead-change", json.string(a)))
    }
    UserSelectedOption(a) -> {
      #(Model(..model, is_open: False), {
        use dispatch <- effect.from
        UserSelectedValue(a) |> dispatch
      })
    }
    UserFocusedSearchInput -> {
      #(
        Model(
          ..model,
          is_focused: True,
          is_open: !list.contains(model.search_items, model.search_term),
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
    UserPressedKeyInSearchInput(a) -> {
      case a, model.is_focused, model.is_open {
        _, False, _ -> #(model, effect.none())
        "ArrowDown", True, True -> {
          #(
            Model(
              ..model,
              hovered_item: case
                model.hovered_item,
                list.length(model.found_items)
              {
                None, _ -> Some(0)
                Some(a), b -> Some(int.min(a + 1, b))
              },
            ),
            effect.none(),
          )
        }
        "ArrowDown", True, False -> {
          #(Model(..model, is_open: True), effect.none())
        }
        "ArrowUp", True, True -> {
          #(
            Model(
              ..model,
              hovered_item: case model.hovered_item {
                None -> None
                Some(a) -> Some(int.max(0, a - 1))
              },
            ),
            effect.none(),
          )
        }
        "Enter", True, _ -> {
          case model.hovered_item, model.is_open {
            None, False -> #(Model(..model, is_open: True), effect.none())
            Some(a), True -> {
              #(Model(..model, is_open: False, hovered_item: None), {
                use dispatch <- effect.from
                UserSelectedOption(option.unwrap(
                  utils.list_at(model.found_items, a),
                  "",
                ))
                |> dispatch
              })
            }
            _, _ -> #(model, effect.none())
          }
        }
        "Escape", True, True -> {
          #(Model(..model, is_open: False, hovered_item: None), {
            use dispatch <- effect.from
            UserBlurredSearchInput |> dispatch
          })
        }
        _, _, _ -> {
          #(model, effect.none())
        }
      }
    }
    UserHoveredOption(a) -> {
      #(Model(..model, hovered_item: Some(a)), effect.none())
    }
    UserUnHoveredOption(_a) -> {
      #(Model(..model, hovered_item: None), effect.none())
    }
  }
}

fn on_attribute_change() -> Dict(String, Decoder(Msg)) {
  dict.from_list([
    #("recipe-titles", fn(attribute) {
      attribute
      |> dynamic.list(dynamic.string)
      |> result.map(RetrievedSearchItems)
    }),
    #("search-term", fn(attribute) {
      attribute
      |> dynamic.string
      |> result.map(RetrievedInitialSearchTerm)
    }),
  ])
}

//-VIEW--------------------------------------------------------

fn search_result(model: Model, result_value: String, index: Int) -> Element(Msg) {
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
      on("mouseover", fn(evt) {
        evt
        |> dynamic.field(
          "target",
          dynamic.field("dataset", dynamic.field("index", decode_stringed_int)),
        )
        |> result.map(UserHoveredOption)
      }),
      on("mouseout", fn(evt) {
        evt
        |> dynamic.field(
          "target",
          dynamic.field("dataset", dynamic.field("index", decode_stringed_int)),
        )
        |> result.map(UserUnHoveredOption)
      }),
      on("mousedown", fn(evt) {
        event.prevent_default(evt)
        Ok(UserMousedDownOption)
      }),
    ],
    [text(result_value)],
  )
}

fn view(model: Model) -> Element(Msg) {
  fragment([
    textarea(
      [
        id("meal-input-" <> model.elem_id),
        attribute.style([
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
        class(case string.length(model.search_term) {
          num if num > 38 -> "text-base"
          num if num > 17 -> "text-lg"
          _ -> "text-xl"
        }),
        value(model.search_term),
        attribute("autocapitalize", "none"),
        attribute("autocomplete", "off"),
        attribute("aria-autocomplete", "list"),
        attribute("role", "combobox"),
        name("meal-input"),
        on_input(UserTypedInSearchInput),
        on("change", fn(event) {
          event
          |> dynamic.field("target", dynamic.field("value", dynamic.string))
          |> result.map(UserSelectedValue)
        }),
        on_keydown(UserPressedKeyInSearchInput),
        on_focus(UserFocusedSearchInput),
        on("blur", fn(_event) { Ok(UserBlurredSearchInput) }),
      ],
      "",
    ),
    ul(
      [
        id("search-results-" <> model.elem_id),
        class(
          "font-mono z-10 absolute bg-ecru-white-50 border border-ecru-white-950 text-xs max-h-full overflow-x-visible overflow-y-scroll w-[240px]",
        ),
        attribute("role", "listbox"),
        attribute.style(case model.is_open, list.length(model.found_items) {
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
        |> list.map(fn(a: String) { a })
        |> list.index_map(fn(a, i) { search_result(model, a, i) })
      },
    ),
  ])
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

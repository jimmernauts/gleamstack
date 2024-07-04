import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Decoder}
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import lustre.{type App}
import lustre/attribute.{type Attribute, attribute, class, id, name, value}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment, text}
import lustre/element/html.{datalist, div, input, option, textarea}
import lustre/event.{on, on_click, on_input}
import session.{type Recipe}

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
    search_items: List(String),
    search_term: String,
    found_items: List(String),
    class_list: String,
  )
}

fn init(_) -> #(Model, Effect(Msg)) {
  #(Model([], "", [], ""), effect.none())
}

//-UPDATE------------------------------------------------------

pub type Msg {
  RetrievedSearchItems(List(String))
  UserUpdatedSearchTerm(String)
  UserChangedValue(String)
  UserUpdatedClassList(String)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  io.debug(msg)
  case msg {
    UserUpdatedClassList(a) -> {
      #(Model(..model, class_list: a), effect.none())
    }
    RetrievedSearchItems(a) -> {
      #(Model(..model, search_items: a), effect.none())
    }
    UserUpdatedSearchTerm(a) -> {
      #(
        Model(
          ..model,
          search_term: a,
          found_items: {
            case string.length(a) {
              num if num < 3 -> model.search_items
              _ ->
                list.filter(model.search_items, fn(r) {
                  string.contains(string.lowercase(r), string.lowercase(a))
                })
            }
          },
        ),
        effect.none(),
      )
    }
    UserChangedValue(a) -> {
      #(model, event.emit("typeahead-change", json.string(a)))
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
      |> result.map(UserUpdatedSearchTerm)
    }),
    #("class", fn(attribute) {
      attribute
      |> dynamic.string
      |> result.map(UserUpdatedClassList)
    }),
  ])
}

//-VIEW--------------------------------------------------------

fn search_result(res: String) -> Element(Msg) {
  option([], res)
}

fn view(model: Model) -> Element(Msg) {
  fragment([
    element.element(
      "fit-text",
      [class("contents"), attribute("data-target", "input")],
      [
        textarea(
          [
            id("meal-input"),
            class(
              "[field-sizing:_content;] overflow-x-hidden input-base w-full input-focus font-transitional resize-none italic text-ecru-white-950  text-xl bg-ecru-white-100",
            ),
            class(case string.length(model.search_term) {
              num if num > 38 -> "text-base"
              num if num > 17 -> "text-lg"
              _ -> "text-xl"
            }),
            class(model.class_list),
            value(model.search_term),
            attribute("list", "search_results"),
            on_input(UserUpdatedSearchTerm),
            on("change", fn(event) {
              event
              |> dynamic.field("target", dynamic.field("value", dynamic.string))
              |> result.map(UserChangedValue)
            }),
          ],
          "",
        ),
        datalist([id("search_results")], {
          model.found_items
          |> list.map(fn(a: String) { a })
          |> list.map(search_result)
        }),
      ],
    ),
  ])
}

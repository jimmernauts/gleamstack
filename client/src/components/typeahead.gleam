import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Decoder}
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import lustre.{type App}
import lustre/attribute.{attribute, class, id, value}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment}
import lustre/element/html.{datalist, div, input, option, textarea}
import lustre/event.{on, on_click, on_input}
import session.{type Recipe}

pub fn app() -> App(Nil, Model, Msg) {
  lustre.component(init, update, view, on_attribute_change())
}

pub const name = "type-ahead"

//-MODEL------------------------------------------------------

pub type Model {
  Model(
    search_items: List(String),
    search_term: String,
    found_items: List(String),
  )
}

pub fn init(_) -> #(Model, Effect(Msg)) {
  #(Model([], "", []), effect.none())
}

//-UPDATE------------------------------------------------------

pub type Msg {
  RetrievedSearchItems(List(String))
  UserUpdatedSearchTerm(String)
  UserSelectedItem(String)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  io.debug(#("typeahead update fn:", model, msg))
  case msg {
    RetrievedSearchItems(a) -> {
      io.debug(msg)
      #(Model(..model, search_items: a), effect.none())
    }
    UserUpdatedSearchTerm(a) -> #(
      Model(
        ..model,
        search_term: a,
        found_items: {
          list.filter(model.search_items, fn(r) {
            use <- bool.guard(when: string.length(a) > 3, return: False)
            string.contains(r, a)
          })
        },
      ),
      effect.none(),
    )
    _ -> {
      io.debug(_)
      #(model, effect.none())
    }
  }
}

pub fn on_attribute_change() -> Dict(String, Decoder(Msg)) {
  dict.from_list([
    #("recipe-titles", fn(attribute) {
      attribute
      |> dynamic.string
      |> result.map(json.decode(_, dynamic.list(dynamic.string)))
      |> result.map(result.map_error(_, fn(_e) {
        [
          dynamic.DecodeError("a json array of strings", "something else", ["*"]),
        ]
      }))
      |> result.flatten
      |> result.map(RetrievedSearchItems)
      |> io.debug
    }),
    #("search-term", fn(attribute) {
      attribute
      |> dynamic.string
      |> result.map(UserUpdatedSearchTerm)
    }),
  ])
}

//-VIEW--------------------------------------------------------

pub fn search_result(res: String) -> Element(Msg) {
  option([value(res)], "")
}

pub fn view(model: Model) -> Element(Msg) {
  fragment([
    input([
      value(model.search_term),
      attribute("list", "search_results"),
      on_input(UserUpdatedSearchTerm),
      on("change", fn(target) {
        target
        |> dynamic.string
        |> result.map(UserSelectedItem)
      }),
    ]),
    datalist([id("search_results")], {
      model.found_items
      |> list.map(fn(a: String) { a })
      |> list.map(search_result)
    }),
  ])
}

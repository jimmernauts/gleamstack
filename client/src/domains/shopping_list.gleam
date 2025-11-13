import components/nav_footer.{nav_footer}
import components/page_title.{page_title}
import gleam/dynamic/decode.{type Decoder, type Dynamic}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{a, div, section, text}
import rada/date
import shared/database

//-TYPES--------------------------------------------------------------

pub type ShoppingListMsg {
  UserSavedCurrentList
  UserCreatedList
  UserUpdatedCurrentList(ShoppingList)
  UserRetrievedShoppingLists(List(ShoppingList))
}

pub type ShoppingListModel {
  ShoppingListModel(
    all_lists: List(ShoppingList),
    current: Option(ShoppingList),
  )
}

pub type ShoppingList {
  ShoppingList(
    id: Option(String),
    items: List(database.Ingredient),
    status: Status,
    date: date.Date,
  )
}

pub type Status {
  Active
  Completed
  Archived
}

//-UPDATE-------------------------------------------------------------

pub fn shopping_list_update(
  model: ShoppingListModel,
  msg: ShoppingListMsg,
) -> #(ShoppingListModel, Effect(ShoppingListMsg)) {
  case msg {
    UserCreatedList -> {
      #(
        ShoppingListModel(
          all_lists: model.all_lists,
          current: Some(ShoppingList(
            id: None,
            items: [],
            status: Active,
            date: date.today(),
          )),
        ),
        effect.none(),
      )
    }
    UserSavedCurrentList -> {
      case model.current {
        Some(list) -> do_save_shopping_list(list)
        _ -> Nil
      }
      #(model, effect.none())
    }
    UserUpdatedCurrentList(list) -> #(
      ShoppingListModel(..model, current: Some(list)),
      effect.none(),
    )
    UserRetrievedShoppingLists(lists) -> #(
      ShoppingListModel(
        all_lists: lists,
        current: lists
          |> list.filter(fn(x) { x.status == Active })
          |> list.first
          |> option.from_result,
      ),
      effect.none(),
    )
  }
}

@external(javascript, ".././db.ts", "do_save_shopping_list")
fn do_save_shopping_list(list: ShoppingList) -> Nil

@external(javascript, ".././db.ts", "do_retrieve_shopping_lists")
fn do_retrieve_shopping_lists() -> Promise(Dynamic)

pub fn retrieve_shopping_lists() -> Effect(ShoppingListMsg) {
  use dispatch <- effect.from
  do_retrieve_shopping_lists()
  |> promise.map(decode.run(_, decode.list(shopping_list_decoder())))
  |> promise.map(result.map(_, UserRetrievedShoppingLists))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

//-DECODER------------------------------------------------------------

pub fn shopping_list_decoder() -> Decoder(ShoppingList) {
  use id <- decode.field("id", decode.optional(decode.string))
  use items <- decode.field("items", decode.list(database.ingredient_decoder()))
  use status <- decode.field("status", shopping_list_status_decoder())
  use date <- decode.field("date", decode.int)
  decode.success(ShoppingList(
    id: id,
    items: items,
    status: status,
    date: date.from_rata_die(date),
  ))
}

pub fn shopping_list_status_decoder() -> Decoder(Status) {
  use decoded_string <- decode.then(decode.string)
  case decoded_string {
    // Return succeeding decoders for valid strings
    "Active" -> decode.success(Active)
    "Completed" -> decode.success(Completed)
    "Archived" -> decode.success(Archived)
    // Return a failing decoder for any other strings
    _ -> decode.failure(Archived, "Status")
  }
}

//-VIEW---------------------------------------------------------------

pub fn view_shopping_list(model: ShoppingListModel) -> Element(ShoppingListMsg) {
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
    ],
    [
      page_title(
        "Shopping List",
        "underline-purple col-span-full md:col-span-11",
      ),
      div(
        [
          class("col-span-full flex flex-wrap items-center justify-start gap-3"),
        ],
        [text("content goes here")],
      ),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a([href("/planner"), class("text-center")], [text("📅")]),
      ]),
    ],
  )
}

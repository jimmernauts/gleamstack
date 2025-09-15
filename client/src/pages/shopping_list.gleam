import gleam/dynamic/decode.{type Dynamic}
import gleam/javascript/promise.{type Promise}
import gleam/result
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import session

//-TYPES--------------------------------------------------------------

pub type ShoppingListMsg {
  UserSavedShoppingList
  UserRetrievedShoppingList(List(session.Ingredient))
}

pub type ShoppingListModel {
  ShoppingListModel(items: List(session.Ingredient))
}

//-UPDATE-------------------------------------------------------------

pub fn shopping_list_update(
  model: ShoppingListModel,
  msg: ShoppingListMsg,
) -> #(ShoppingListModel, Effect(ShoppingListMsg)) {
  case msg {
    UserSavedShoppingList -> {
      do_save_shopping_list(model.items)
      #(model, effect.none())
    }
    UserRetrievedShoppingList(items_from_db) -> #(
      ShoppingListModel(..model, items: items_from_db),
      effect.none(),
    )
  }
}

@external(javascript, ".././db.ts", "do_save_shopping_list")
fn do_save_shopping_list(items: List(session.Ingredient)) -> Nil

pub fn retrieve_shopping_list() -> Effect(ShoppingListMsg) {
  use dispatch <- effect.from
  do_retrieve_shopping_list()
  |> promise.map(decode.run(_, decode.list(session.ingredient_decoder())))
  |> promise.map(result.map(_, UserRetrievedShoppingList))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, ".././db.ts", "do_retrieve_shopping_list")
fn do_retrieve_shopping_list() -> Promise(Dynamic)

//-VIEW---------------------------------------------------------------

pub fn view_shopping_list(model: ShoppingListModel) -> Element(ShoppingListMsg) {
  todo
}

import components/nav_footer.{nav_footer}
import components/page_title.{page_title}
import gleam/dynamic/decode.{type Decoder, type Dynamic}
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import glearray.{type Array}
import lib/utils
import lustre/attribute.{
  attribute, class, href, id, name, placeholder, type_, value,
}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  a, button, div, h2, h3, input, label, section, span, text, textarea,
}
import lustre/event.{on_click, on_input}
import rada/date
import shared/codecs
import shared/types

//-TYPES--------------------------------------------------------------

pub type ShoppingListMsg {
  UserCreatedList(date.Date)
  UserRemovedIngredientAtIndex(Int)
  UserAddedIngredientAtIndex(Int)
  UserUpdatedIngredientNameAtIndex(Int, String)
  UserToggledItemCheckedAtIndex(Int)
  UserDeletedList(ShoppingList)
  ShoppingListSubscriptionOpened(date.Date, fn() -> Nil)
  DbSubscribedListSummaries(Dynamic)
  DbRetrievedListSummaries(List(ShoppingList))
  DbSubscribedOneList(Dynamic)
  DbRetrievedOneList(ShoppingList)
}

pub type ShoppingListModel {
  ShoppingListModel(
    all_lists: List(ShoppingList),
    current: Option(ShoppingList),
    new_item_name: String,
  )
}

pub type IngredientSource {
  ManualEntry
  FromRecipe(recipe_ref: types.PlannedRecipe)
}

pub type ShoppingListIngredient {
  ShoppingListIngredient(
    ingredient: types.Ingredient,
    source: IngredientSource,
    checked: Bool,
  )
}

pub type ShoppingList {
  ShoppingList(
    id: Option(String),
    items: Array(ShoppingListIngredient),
    status: Status,
    date: date.Date,
    linked_recipes: List(types.PlannedRecipe),
    linked_plan: Option(date.Date),
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
    // SubscriptionOpened is handled in the layer above
    // Not sure if this is really a great pattern....
    ShoppingListSubscriptionOpened(_date, _callback) -> #(model, effect.none())
    UserCreatedList(list_date) -> {
      let new_list =
        ShoppingList(
          id: None,
          items: glearray.new(),
          status: Active,
          date: list_date,
          linked_recipes: [],
          linked_plan: None,
        )
      do_save_shopping_list(new_list)
      #(
        ShoppingListModel(
          all_lists: [new_list, ..model.all_lists],
          current: Some(new_list),
          new_item_name: "",
        ),
        effect.none(),
      )
    }
    UserAddedIngredientAtIndex(index) -> {
      case model.current {
        Some(list) -> {
          let new_item =
            ShoppingListIngredient(
              ingredient: types.Ingredient(
                name: None,
                quantity: None,
                units: None,
                category: None,
                ismain: None,
              ),
              source: ManualEntry,
              checked: False,
            )
          let updated_list =
            ShoppingList(
              ..list,
              items: list.items
                |> glearray.copy_insert(index, new_item)
                |> result.unwrap(list.items),
            )
          do_save_shopping_list(updated_list)
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserRemovedIngredientAtIndex(index) -> {
      case model.current {
        Some(list) -> {
          let updated_items = utils.remove_at_index(list.items, index)
          let updated_list = ShoppingList(..list, items: updated_items)
          do_save_shopping_list(updated_list)
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserToggledItemCheckedAtIndex(index) -> {
      case model.current {
        Some(list) -> {
          let updated_items =
            list.items
            |> glearray.to_list
            |> list.index_map(fn(item, i) {
              case i == index {
                True -> ShoppingListIngredient(..item, checked: !item.checked)
                False -> item
              }
            })
            |> glearray.from_list
          let updated_list = ShoppingList(..list, items: updated_items)
          do_save_shopping_list(updated_list)
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserUpdatedIngredientNameAtIndex(index, name) -> {
      case model.current {
        Some(list) -> {
          let updated_items =
            list.items
            |> glearray.to_list
            |> list.index_map(fn(item, i) {
              case i == index {
                True ->
                  ShoppingListIngredient(
                    ..item,
                    ingredient: types.Ingredient(
                      name: Some(name),
                      quantity: None,
                      units: None,
                      category: None,
                      ismain: None,
                    ),
                  )
                False -> item
              }
            })
            |> glearray.from_list
          let updated_list = ShoppingList(..list, items: updated_items)
          do_save_shopping_list(updated_list)
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    DbSubscribedListSummaries(jsdata) -> {
      let decoder = {
        use data <- decode.subfield(
          ["data", "shopping_lists"],
          decode.list(shopping_list_summary_decoder()),
        )
        decode.success(data)
      }
      let try_decode = decode.run(jsdata, decoder)
      let try_effect = case try_decode {
        Ok(list) -> {
          use dispatch <- effect.from
          DbRetrievedListSummaries(list) |> dispatch
        }
        Error(e) -> {
          effect.none()
        }
      }
      #(model, try_effect)
    }
    DbRetrievedListSummaries(lists) -> #(
      ShoppingListModel(
        all_lists: lists,
        current: lists
          |> list.filter(fn(x) { x.status == Active })
          |> list.first
          |> option.from_result,
        new_item_name: "",
      ),
      effect.none(),
    )
    DbSubscribedOneList(jsdata) -> {
      let decoder = {
        use data <- decode.subfield(
          ["data", "shopping_lists", "0"],
          shopping_list_decoder(),
        )
        decode.success(data)
      }
      let try_decode = decode.run(jsdata, decoder)
      let try_effect = case try_decode {
        Ok(list) -> {
          use dispatch <- effect.from
          DbRetrievedOneList(list) |> dispatch
        }
        Error(e) -> {
          echo e
          effect.none()
        }
      }
      #(model, try_effect)
    }
    DbRetrievedOneList(list) -> #(
      ShoppingListModel(
        all_lists: [list, ..model.all_lists],
        current: Some(list),
        new_item_name: "",
      ),
      effect.none(),
    )
    UserDeletedList(list) -> {
      let updated_lists =
        list.filter(model.all_lists, fn(l) { l.id != list.id })
      do_delete_shopping_list(option.unwrap(list.id, ""))
      #(
        ShoppingListModel(..model, all_lists: updated_lists, current: None),
        effect.none(),
      )
    }
  }
}

@external(javascript, ".././db.ts", "do_save_shopping_list")
fn do_save_shopping_list_external(
  list_obj: #(Int, String, String, String, Int),
) -> Nil

@external(javascript, ".././db.ts", "do_delete_shopping_list")
fn do_delete_shopping_list(id: String) -> Nil

fn do_save_shopping_list(list: ShoppingList) -> Nil {
  // Convert to a plain object with proper types for TypeScript
  let list_obj = #(
    date.to_rata_die(list.date),
    case list.status {
      // Return succeeding decoders for valid strings
      Active -> "Active"
      Completed -> "Completed"
      Archived -> "Archived"
      // Return a failing decoder for any other strings
    },
    list.items
      |> glearray.to_list
      |> list.map(encode_shopping_list_ingredient)
      |> json.array(fn(x) { x })
      |> json.to_string,
    list.linked_recipes
      |> list.map(encode_planned_recipe)
      |> json.array(fn(x) { x })
      |> json.to_string,
    case list.linked_plan {
      Some(plan_date) -> date.to_rata_die(plan_date)
      None -> 0
    },
  )
  do_save_shopping_list_external(list_obj)
}

@external(javascript, ".././db.ts", "do_subscribe_to_shopping_list_summaries")
fn do_subscribe_to_shopping_list_summaries(callback: fn(a) -> Nil) -> Nil

pub fn subscribe_to_shopping_list_summaries() -> Effect(ShoppingListMsg) {
  use dispatch <- effect.from
  do_subscribe_to_shopping_list_summaries(fn(data) {
    data
    |> DbSubscribedListSummaries
    |> dispatch
  })
  Nil
}

@external(javascript, ".././db.ts", "do_subscribe_to_one_shoppinglist_by_date")
fn do_subscribe_to_one_shoppinglist_by_date(
  date: Int,
  callback: fn(a) -> Nil,
) -> fn() -> Nil

pub fn subscribe_to_one_shoppinglist_by_date(
  date: date.Date,
) -> Effect(ShoppingListMsg) {
  use dispatch <- effect.from
  do_subscribe_to_one_shoppinglist_by_date(date.to_rata_die(date), fn(data) {
    data
    |> DbSubscribedOneList
    |> dispatch
  })
  |> ShoppingListSubscriptionOpened(date, _)
  |> dispatch
  Nil
}

//-VIEW---------------------------------------------------------------

pub fn view_all_shopping_lists(
  model: ShoppingListModel,
) -> Element(ShoppingListMsg) {
  let active_lists = list.filter(model.all_lists, fn(l) { l.status == Active })
  let completed_lists =
    list.filter(model.all_lists, fn(l) { l.status == Completed })
  let archived_lists =
    list.filter(model.all_lists, fn(l) { l.status == Archived })

  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
    ],
    [
      page_title(
        "Shopping Lists",
        "underline-purple col-span-full md:col-span-11",
      ),
      div(
        [
          class("col-span-full flex flex-col gap-4 overflow-y-auto p-4"),
        ],
        [
          // Active lists
          view_shopping_list_group("Active Lists", active_lists),
          // Completed lists
          view_shopping_list_group("Completed Lists", completed_lists),
          // Archived lists
          view_shopping_list_group("Archived Lists", archived_lists),
        ],
      ),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a(
          [
            href("/shopping-list/" <> date.to_iso_string(date.today())),
            class("text-center"),
          ],
          [text("➕")],
        ),
        a([href("/planner"), class("text-center")], [text("📅")]),
      ]),
    ],
  )
}

fn view_shopping_list_group(
  title: String,
  lists: List(ShoppingList),
) -> Element(ShoppingListMsg) {
  case lists {
    [] -> element.none()
    _ ->
      div([class("mb-6")], [
        h2([class("text-xl font-bold mb-3")], [text(title)]),
        div(
          [class("flex flex-col gap-2")],
          list.map(lists, view_shopping_list_card),
        ),
      ])
  }
}

fn view_shopping_list_card(list: ShoppingList) -> Element(ShoppingListMsg) {
  let date_str = date.to_iso_string(list.date)

  div(
    [
      class(
        "border border-ecru-white-950 rounded p-4 bg-ecru-white-50 shadow-sm relative",
      ),
    ],
    [
      div([class("flex justify-between items-start mb-2")], [
        h3([class("text-lg font-semibold")], [
          text(date.to_iso_string(list.date)),
        ]),
        div([class("flex gap-2")], [
          a(
            [
              href("/shopping-list/" <> date_str),
              class("text-sm text-blue-600 hover:underline"),
            ],
            [text("View")],
          ),
          button(
            [
              class("text-sm text-red-600 hover:underline"),
              event.on_click(UserDeletedList(list)),
            ],
            [text("Delete")],
          ),
        ]),
      ]),
    ],
  )
}

pub fn view_shopping_list_detail(
  model: ShoppingListModel,
  list_date: date.Date,
) -> Element(ShoppingListMsg) {
  let maybe_list =
    model.all_lists
    |> list.find(fn(l) { l.date == list_date })
  let list = case maybe_list {
    Ok(list) -> list
    Error(_) ->
      ShoppingList(
        id: None,
        date: list_date,
        items: glearray.new(),
        status: Active,
        linked_plan: None,
        linked_recipes: [],
      )
  }
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
    ],
    [
      page_title(
        date.to_iso_string(list_date),
        "underline-purple col-span-full md:col-span-11",
      ),
      div([class("col-span-full flex flex-col gap-4 overflow-y-auto p-4")], [
        // Status badge
        div([class("flex items-center justify-between")], [
          div([class("flex items-center gap-2")], [
            text("Status: "),
            span(
              [
                class(case list.status {
                  Active -> "px-2 py-1 bg-green-100 text-green-800 rounded"
                  Completed -> "px-2 py-1 bg-blue-100 text-blue-800 rounded"
                  Archived -> "px-2 py-1 bg-gray-100 text-gray-800 rounded"
                }),
              ],
              [
                text(case list.status {
                  Active -> "Active"
                  Completed -> "Completed"
                  Archived -> "Archived"
                }),
              ],
            ),
          ]),
        ]),
        div([class("flex flex-col gap-4")], [
          div(
            [class("flex flex-col gap-2")],
            list.index_map(list.items |> glearray.to_list, shopping_list_item),
          ),
        ]),
      ]),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a([href("/shopping-list"), class("text-center")], [text("📋")]),
      ]),
    ],
  )
}

fn shopping_list_item(item: ShoppingListIngredient, index: Int) {
  div([class("flex w-full items-baseline col-span-full px-1 mb-1 text-base")], [
    html.label([class("font-mono text-sm")], [
      text(index + 1 |> int.to_string <> "."),
    ]),
    html.input([
      attribute("aria-label", "Enter ingredient name"),
      name("ingredient-name-" <> int.to_string(index)),
      type_("text"),
      placeholder("Ingredient"),
      class(
        "text-base input-base max-w-[20ch] md:max-w-[34ch] input-focus bg-ecru-white-100",
      ),
      value(item.ingredient.name |> option.unwrap("")),
      on_input(UserUpdatedIngredientNameAtIndex(index, _)),
    ]),
    button(
      [
        class("text-ecru-white-950 text-xs cursor-pointer"),
        type_("button"),
        id("remove-ingredient-input"),
        on_click(UserRemovedIngredientAtIndex(index)),
      ],
      [text("➖")],
    ),
  ])
}

//-DECODER------------------------------------------------------------

pub fn shopping_list_ingredient_decoder() -> Decoder(ShoppingListIngredient) {
  use ingredient <- decode.field("ingredient", codecs.ingredient_decoder())
  use source_type <- decode.optional_field(
    "source_type",
    "manual",
    decode.string,
  )
  use checked <- decode.optional_field("checked", False, decode.bool)
  let source = case source_type {
    "manual" -> ManualEntry
    // For now, we'll default to ManualEntry for recipe sources
    // Full implementation will need to decode recipe_ref
    _ -> ManualEntry
  }
  decode.success(ShoppingListIngredient(
    ingredient: ingredient,
    source: source,
    checked: checked,
  ))
}

pub fn shopping_list_decoder() -> Decoder(ShoppingList) {
  use id <- decode.field("id", decode.optional(decode.string))
  use items <- decode.field(
    "items",
    codecs.json_string_decoder(
      decode.list(shopping_list_ingredient_decoder()),
      [],
    ),
  )
  use status <- decode.field("status", shopping_list_status_decoder())
  use date <- decode.field("date", decode.int)
  use linked_recipes <- decode.optional_field(
    "linked_recipes",
    [],
    codecs.json_string_decoder(decode.list(planned_recipe_decoder()), []),
  )
  use linked_plan <- decode.optional_field(
    "linked_plan",
    None,
    decode.optional(decode.int),
  )
  decode.success(
    ShoppingList(
      id: id,
      items: glearray.from_list(items),
      status: status,
      date: date.from_rata_die(date),
      linked_recipes: linked_recipes,
      linked_plan: case linked_plan {
        Some(plan_date) -> Some(date.from_rata_die(plan_date))
        None -> None
      },
    ),
  )
}

fn shopping_list_summary_decoder() -> Decoder(ShoppingList) {
  use id <- decode.field("id", decode.optional(decode.string))
  use status <- decode.field("status", shopping_list_status_decoder())
  use date <- decode.field("date", decode.int)
  decode.success(ShoppingList(
    id: id,
    items: glearray.new(),
    status: status,
    date: date.from_rata_die(date),
    linked_recipes: [],
    linked_plan: None,
  ))
}

fn planned_recipe_decoder() -> Decoder(types.PlannedRecipe) {
  use recipe_name <- decode.optional_field("recipe_name", "", decode.string)
  use recipe_id <- decode.optional_field("recipe_id", "", decode.string)
  case recipe_name, recipe_id {
    "", "" -> decode.failure(types.RecipeName(""), "PlannedRecipe")
    "", id -> decode.success(types.RecipeId(id))
    name, _ -> decode.success(types.RecipeName(name))
  }
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

//-ENCODER------------------------------------------------------------

fn encode_shopping_list_ingredient(item: ShoppingListIngredient) -> Json {
  json.object([
    #("ingredient", codecs.json_encode_ingredient(item.ingredient)),
    #(
      "source_type",
      json.string(case item.source {
        ManualEntry -> "manual"
        FromRecipe(_) -> "recipe"
      }),
    ),
    #("checked", json.bool(item.checked)),
  ])
}

fn encode_planned_recipe(recipe: types.PlannedRecipe) -> Json {
  case recipe {
    types.RecipeName(name) -> json.object([#("recipe_name", json.string(name))])
    types.RecipeId(id) -> json.object([#("recipe_id", json.string(id))])
  }
}

pub fn encode_shopping_list(list: ShoppingList) -> Json {
  json.object([
    #("date", json.int(date.to_rata_die(list.date))),
    #(
      "status",
      json.string(case list.status {
        Active -> "Active"
        Completed -> "Completed"
        Archived -> "Archived"
      }),
    ),
    #(
      "items",
      json.string(
        list.items
        |> glearray.to_list
        |> list.map(encode_shopping_list_ingredient)
        |> json.array(fn(x) { x })
        |> json.to_string,
      ),
    ),
    #(
      "linked_recipes",
      json.string(
        list.linked_recipes
        |> list.map(encode_planned_recipe)
        |> json.array(fn(x) { x })
        |> json.to_string,
      ),
    ),
    #("linked_plan", case list.linked_plan {
      Some(plan_date) -> json.int(date.to_rata_die(plan_date))
      None -> json.null()
    }),
  ])
}

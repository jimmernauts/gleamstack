/////////////////////////
//// 
//// 
//// WIP
//// Persistence doesn't work
//// Need to fetch data in route handler
//// Need to model more closely on the recipe view/edit page

import components/nav_footer.{nav_footer}
import components/page_title.{page_title}
import gleam/dynamic/decode.{type Decoder, type Dynamic}
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{a, button, div, h2, h3, input, section, span, text}
import lustre/event
import rada/date
import shared/codecs
import shared/types

//-TYPES--------------------------------------------------------------

pub type ShoppingListMsg {
  UserCreatedList(date.Date)
  UserAddedIngredient(types.Ingredient)
  UserRemovedIngredient(Int)
  UserToggledItemChecked(Int)
  ShoppingListSubscriptionOpened(date.Date, fn() -> Nil)
  DbRetrievedListSummaries(List(ShoppingList))
  DbSubscribedOneList(Dynamic)
  DbRetrievedOneList(ShoppingList)
}

pub type ShoppingListModel {
  ShoppingListModel(
    all_lists: List(ShoppingList),
    current: Option(ShoppingList),
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
    items: List(ShoppingListIngredient),
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
          items: [],
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
        ),
        effect.none(),
      )
    }
    UserAddedIngredient(ingredient) -> {
      case model.current {
        Some(list) -> {
          let new_item =
            ShoppingListIngredient(
              ingredient: ingredient,
              source: ManualEntry,
              checked: False,
            )
          let updated_list =
            ShoppingList(..list, items: [new_item, ..list.items])
          do_save_shopping_list(updated_list)
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserRemovedIngredient(index) -> {
      case model.current {
        Some(list) -> {
          let updated_items =
            list.items
            |> list.index_fold([], fn(acc, item, i) {
              case i == index {
                True -> acc
                False -> [item, ..acc]
              }
            })
            |> list.reverse
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
    UserToggledItemChecked(index) -> {
      case model.current {
        Some(list) -> {
          let updated_items =
            list.items
            |> list.index_map(fn(item, i) {
              case i == index {
                True -> ShoppingListIngredient(..item, checked: !item.checked)
                False -> item
              }
            })
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
    DbRetrievedListSummaries(lists) -> #(
      ShoppingListModel(
        all_lists: lists,
        current: lists
          |> list.filter(fn(x) { x.status == Active })
          |> list.first
          |> option.from_result,
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
      ),
      effect.none(),
    )
  }
}

@external(javascript, ".././db.ts", "do_save_shopping_list")
fn do_save_shopping_list_external(
  list_obj: #(Int, String, String, String, Int),
) -> Nil

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

@external(javascript, ".././db.ts", "do_retrieve_shopping_list_summaries")
fn do_retrieve_shopping_list_summaries() -> Promise(Dynamic)

pub fn retrieve_shopping_list_summaries() -> Effect(ShoppingListMsg) {
  use dispatch <- effect.from
  do_retrieve_shopping_list_summaries()
  |> promise.map(decode.run(_, decode.list(shopping_list_summary_decoder())))
  |> promise.map(result.map(_, DbRetrievedListSummaries))
  |> promise.tap(result.map(_, dispatch))
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

// TODO: improve UI, hook up to Msg firing events
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
          // Action buttons
          div([class("flex gap-2 mb-4")], [
            a(
              [
                href("/shopping-list/" <> date.to_iso_string(date.today())),
                class(
                  "px-4 py-2 bg-purple-600 text-white rounded hover:bg-purple-700",
                ),
              ],
              [text("+ New List")],
            ),
            a(
              [
                href("/planner"),
                class(
                  "px-4 py-2 bg-orange-600 text-white rounded hover:bg-orange-700",
                ),
              ],
              [text("Create from Plan")],
            ),
          ]),
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
  let item_count = list.items |> list.length
  let recipe_count = list.linked_recipes |> list.length
  let date_str = date.to_iso_string(list.date)

  div(
    [
      class(
        "border border-ecru-white-950 rounded p-4 bg-ecru-white-50 shadow-sm",
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
          a(
            [
              href("/shopping-list/" <> date_str <> "/edit"),
              class("text-sm text-blue-600 hover:underline"),
            ],
            [text("Edit")],
          ),
        ]),
      ]),
      div([class("text-sm text-gray-600")], [
        text(
          int.to_string(item_count)
          <> " items • "
          <> int.to_string(recipe_count)
          <> " recipes",
        ),
      ]),
    ],
  )
}

pub fn view_shopping_list_detail(
  model: ShoppingListModel,
  list_date: date.Date,
) -> Element(ShoppingListMsg) {
  // Find list for this date or show create button
  let maybe_list =
    model.all_lists
    |> list.find(fn(l) { l.date == list_date })

  case maybe_list {
    Ok(list) -> view_existing_list(list, list_date)
    Error(_) -> view_create_list_prompt(list_date)
  }
}

fn view_create_list_prompt(list_date: date.Date) -> Element(ShoppingListMsg) {
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
    ],
    [
      page_title(
        "Shopping List - " <> date.to_iso_string(list_date),
        "underline-purple col-span-full md:col-span-11",
      ),
      div(
        [
          class(
            "col-span-full flex flex-col items-center justify-center gap-4 p-8",
          ),
        ],
        [
          text("No shopping list exists for this date."),
          button(
            [
              attribute.type_("button"),
              event.on_click(UserCreatedList(list_date)),
              class(
                "px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700",
              ),
            ],
            [text("Create Shopping List")],
          ),
        ],
      ),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a([href("/shopping-list"), class("text-center")], [text("📋")]),
      ]),
    ],
  )
}

fn view_existing_list(
  list: ShoppingList,
  list_date: date.Date,
) -> Element(ShoppingListMsg) {
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
    ],
    [
      page_title(
        "Shopping List - " <> date.to_iso_string(list_date),
        "underline-purple col-span-full md:col-span-11",
      ),
      div([class("col-span-full flex flex-col gap-4 overflow-y-auto p-4")], [
        // Status badge
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
        // Items list
        case list.items {
          [] ->
            div([class("text-gray-500 italic")], [
              text("No items yet. Click Edit to add items."),
            ])
          items ->
            div(
              [class("flex flex-col gap-2")],
              list.index_map(items, view_shopping_list_item),
            )
        },
      ]),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a([href("/shopping-list"), class("text-center")], [text("📋")]),
        a(
          [
            href("/shopping-list/" <> date.to_iso_string(list_date) <> "/edit"),
            class("text-center"),
          ],
          [text("✏️")],
        ),
      ]),
    ],
  )
}

fn view_shopping_list_item(
  item: ShoppingListIngredient,
  index: Int,
) -> Element(ShoppingListMsg) {
  div(
    [
      class(
        "flex items-center gap-3 p-3 border border-gray-200 rounded bg-white",
      ),
    ],
    [
      input([
        attribute.type_("checkbox"),
        attribute.checked(item.checked),
        event.on_check(fn(_) { UserToggledItemChecked(index) }),
        class("w-5 h-5"),
      ]),
      div([class("flex-1")], [
        span(
          [
            class(case item.checked {
              True -> "line-through text-gray-500"
              False -> ""
            }),
          ],
          [
            text({
              let name = option.unwrap(item.ingredient.name, "Unknown")
              let quantity_text = case item.ingredient.quantity {
                Some(q) -> " - " <> q
                None -> ""
              }
              let units_text = case item.ingredient.units {
                Some(u) -> " " <> u
                None -> ""
              }
              name <> quantity_text <> units_text
            }),
          ],
        ),
      ]),
    ],
  )
}

// TODO: remove specific edit view, make this an inline edit

pub fn edit_shopping_list(
  _model: ShoppingListModel,
  list_date: date.Date,
) -> Element(ShoppingListMsg) {
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
    ],
    [
      page_title(
        "Edit Shopping List - " <> date.to_iso_string(list_date),
        "underline-purple col-span-full md:col-span-11",
      ),
      div(
        [
          class("col-span-full flex flex-wrap items-center justify-start gap-3"),
        ],
        [text("Edit view - coming soon")],
      ),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a([href("/shopping-list"), class("text-center")], [text("📋")]),
        a(
          [
            href("/shopping-list/" <> date.to_iso_string(list_date)),
            class("text-center"),
          ],
          [text("👁️")],
        ),
      ]),
    ],
  )
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
      items: items,
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
    items: [],
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

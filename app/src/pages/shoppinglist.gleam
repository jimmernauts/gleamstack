import components/nav_footer.{nav_footer}
import components/page_title.{page_title}
import components/typeahead_2 as typeahead
import gleam/dict.{type Dict}
import gleam/dynamic/decode.{type Decoder, type Dynamic}
import gleam/int
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
import lustre/element/html.{a, button, div, input, label, section, span, text}
import lustre/event.{on_click, on_input}
import pages/recipe_list
import rada/date
import shared/codecs
import shared/types

//-TYPES--------------------------------------------------------------

pub type ShoppingListMsg {
  UserCreatedList(date.Date)
  // TODO: add clone list feature
  UserRemovedIngredientAtIndex(Int)
  UserAddedIngredientAtIndex(Int)
  UserUpdatedIngredientNameAtIndex(Int, String)
  UserUpdatedIngredientMainAtIndex(Int, Bool)
  UserUpdatedIngredientQtyAtIndex(Int, String)
  UserUpdatedIngredientUnitsAtIndex(Int, String)
  UserToggledItemCheckedAtIndex(Int)
  UserToggledRecipeList
  UserMarkedCurrentListAsCompleted
  UserMarkedCurrentListAsActive
  UserDeletedList(ShoppingList)
  UserSavedList
  UserRemovedLinkedRecipeAtIndex(Int)
  UserAddedLinkedRecipeAtIndex(Int)
  UserUpdatedLinkedRecipeAtIndex(Int, types.PlannedRecipe)
  ShoppingListSubscriptionOpened(date.Date, fn() -> Nil)
  DbSubscribedListSummaries(Dynamic)
  DbRetrievedListSummaries(Dict(date.Date, ShoppingList))
  DbSubscribedOneList(Dynamic)
  DbRetrievedOneList(ShoppingList)
}

pub type ShoppingListModel {
  ShoppingListModel(
    all_lists: Dict(date.Date, ShoppingList),
    recipe_list_open: Bool,
    current: Option(ShoppingList),
    recipe_list: recipe_list.RecipeListModel,
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
    linked_recipes: Array(types.PlannedRecipe),
    linked_plan: Option(date.Date),
  )
}

pub type Status {
  Active
  Completed
}

pub fn new_list(date: date.Date) -> ShoppingList {
  ShoppingList(
    id: None,
    items: [new_ingredient()]
      |> glearray.from_list,
    status: Active,
    date: date,
    linked_recipes: glearray.new(),
    linked_plan: None,
  )
}

pub fn new_ingredient() -> ShoppingListIngredient {
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
    UserToggledRecipeList -> {
      // TODO: maybe add 1 when toggling it open if there are 0 linked recipes currently?
      #(
        ShoppingListModel(..model, recipe_list_open: !model.recipe_list_open),
        effect.none(),
      )
    }
    UserCreatedList(list_date) -> {
      save_shopping_list(new_list(list_date))
      #(
        ShoppingListModel(
          ..model,
          all_lists: model.all_lists
            |> dict.upsert(list_date, fn(_old) { new_list(list_date) }),
          current: Some(new_list(list_date)),
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
                |> glearray.copy_insert(index + 1, new_item)
                |> result.unwrap(list.items),
            )
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
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserUpdatedIngredientMainAtIndex(index, ismain) -> {
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
                      name: item.ingredient.name,
                      quantity: item.ingredient.quantity,
                      units: item.ingredient.units,
                      category: item.ingredient.category,
                      ismain: Some(ismain),
                    ),
                  )
                False -> item
              }
            })
            |> glearray.from_list
          let updated_list = ShoppingList(..list, items: updated_items)
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserUpdatedIngredientQtyAtIndex(index, qty) -> {
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
                      name: item.ingredient.name,
                      quantity: Some(qty),
                      units: item.ingredient.units,
                      category: item.ingredient.category,
                      ismain: item.ingredient.ismain,
                    ),
                  )
                False -> item
              }
            })
            |> glearray.from_list
          let updated_list = ShoppingList(..list, items: updated_items)
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserUpdatedIngredientUnitsAtIndex(index, units) -> {
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
                      name: item.ingredient.name,
                      quantity: item.ingredient.quantity,
                      units: Some(units),
                      category: item.ingredient.category,
                      ismain: item.ingredient.ismain,
                    ),
                  )
                False -> item
              }
            })
            |> glearray.from_list
          let updated_list = ShoppingList(..list, items: updated_items)
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserMarkedCurrentListAsCompleted -> {
      case model.current {
        Some(list) -> {
          let updated_list = ShoppingList(..list, status: Completed)
          save_shopping_list(updated_list)
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserMarkedCurrentListAsActive -> {
      case model.current {
        Some(list) -> {
          let updated_list = ShoppingList(..list, status: Active)
          save_shopping_list(updated_list)
          find_any_other_active_lists_and_complete_them(
            model.all_lists,
            updated_list.date,
          )
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserSavedList -> {
      case model.current {
        Some(list) -> {
          save_shopping_list(list)
          #(ShoppingListModel(..model, current: Some(list)), effect.none())
        }
        None -> #(model, effect.none())
      }
    }
    UserAddedLinkedRecipeAtIndex(index) -> {
      case model.current {
        Some(list) -> {
          let updated_list =
            ShoppingList(
              ..list,
              linked_recipes: glearray.copy_insert(
                  list.linked_recipes,
                  case index {
                    0 -> index
                    _ -> index + 1
                  },
                  types.RecipeName(""),
                )
                |> result.unwrap(list.linked_recipes),
            )
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserRemovedLinkedRecipeAtIndex(index) -> {
      case model.current {
        Some(list) -> {
          let updated_list =
            ShoppingList(
              ..list,
              linked_recipes: utils.remove_at_index(list.linked_recipes, index),
            )
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }
    UserUpdatedLinkedRecipeAtIndex(index, recipe) -> {
      // TODO: lookup recipe by slug and add its ingredients to the list
      case model.current {
        Some(list) -> {
          let updated_list =
            ShoppingList(
              ..list,
              linked_recipes: glearray.copy_set(
                  list.linked_recipes,
                  index,
                  recipe,
                )
                |> result.unwrap(list.linked_recipes),
            )
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
        Ok(list_of_lists) -> {
          use dispatch <- effect.from
          let grouped =
            list_of_lists
            |> list.group(fn(x) { x.date })
            |> dict.map_values(fn(k, v) {
              list.first(v)
              |> result.unwrap(ShoppingList(
                id: None,
                items: glearray.new(),
                status: Active,
                date: k,
                linked_recipes: glearray.new(),
                linked_plan: None,
              ))
            })
          DbRetrievedListSummaries(grouped) |> dispatch
        }
        Error(_e) -> {
          effect.none()
        }
      }
      #(model, try_effect)
    }
    DbRetrievedListSummaries(lists) -> #(
      ShoppingListModel(..model, all_lists: lists),
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
        ..model,
        all_lists: dict.merge(
          model.all_lists,
          dict.from_list([#(list.date, list)]),
        ),
        current: Some(list),
      ),
      effect.none(),
    )
    UserDeletedList(list) -> {
      let updated_lists = dict.drop(model.all_lists, [list.date])
      do_delete_shopping_list(option.unwrap(list.id, ""))
      #(
        ShoppingListModel(..model, all_lists: updated_lists, current: None),
        effect.none(),
      )
    }
  }
}

@external(javascript, ".././db.ts", "do_save_shopping_list")
fn do_save_shopping_list(list_obj: #(Int, String, String, String, Int)) -> Nil

@external(javascript, ".././db.ts", "do_delete_shopping_list")
fn do_delete_shopping_list(id: String) -> Nil

fn save_shopping_list(list: ShoppingList) -> Nil {
  // Convert to a plain object with proper types for TypeScript
  let list_obj = #(
    date.to_rata_die(list.date),
    case list.status {
      Active -> "Active"
      Completed -> "Completed"
    },
    list.items
      |> glearray.to_list
      |> list.map(encode_shopping_list_ingredient)
      |> json.array(fn(x) { x })
      |> json.to_string,
    list.linked_recipes
      |> glearray.to_list
      |> list.map(codecs.encode_planned_recipe)
      |> json.array(fn(x) { x })
      |> json.to_string,
    case list.linked_plan {
      Some(plan_date) -> date.to_rata_die(plan_date)
      None -> 0
    },
  )
  do_save_shopping_list(list_obj)
}

fn find_any_other_active_lists_and_complete_them(
  all_lists: Dict(date.Date, ShoppingList),
  date: date.Date,
) -> Nil {
  let other_active_lists =
    dict.filter(all_lists, fn(k, v) { v.status == Active && k != date })
  case dict.size(other_active_lists) {
    0 -> Nil
    _ -> {
      let updated_lists =
        dict.map_values(other_active_lists, fn(_k, v) {
          ShoppingList(..v, status: Completed)
        })
      dict.values(updated_lists)
      |> list.map(save_shopping_list)
      Nil
    }
  }
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
  section(
    [
      class(
        "h-env-screen grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
    ],
    [
      page_title(
        "Shopping Lists",
        "underline-purple col-span-full md:col-span-11",
      ),
      div(
        [
          class(
            "col-span-full grid grid-cols-12 grid-rows-[repeat(12,minmax(min-content,35px))] gap-y-2",
          ),
          id("main-content"),
        ],
        list.map(model.all_lists |> dict.values, view_shopping_list_card),
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

fn view_shopping_list_card(list: ShoppingList) -> Element(ShoppingListMsg) {
  let date_str = date.to_iso_string(list.date)
  a(
    [
      href("/shopping-list/" <> date_str),
      class(
        "subgrid-cols col-span-full grid-flow-row-dense col-span-full text-xl subgrid-cols border-b border-b-gray-200",
      ),
    ],
    [
      span([class("col-span-1")], [
        {
          case list.status {
            Active -> text("🛒")
            Completed -> text("✅")
          }
        },
      ]),
      span([class("col-start-2 col-span-10")], [
        text(date.to_iso_string(list.date)),
      ]),
    ],
  )
}

pub fn view_shopping_list_detail(
  current_list: Option(ShoppingList),
  recipe_list_open: Bool,
  recipes: List(types.Recipe),
) -> Element(ShoppingListMsg) {
  let list = case current_list {
    Some(list) -> list
    None ->
      ShoppingList(
        id: None,
        date: date.today(),
        items: glearray.new(),
        status: Active,
        linked_plan: None,
        linked_recipes: glearray.new(),
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
        date.to_iso_string(list.date),
        "underline-purple col-span-full col-start-1 md:col-span-11",
      ),
      div(
        [
          class(
            "subgrid-cols grid-rows-[repeat(12,minmax(min-content,20px))] overflow-y-scroll col-span-full gap-y-2",
          ),
        ],
        [
          div(
            [
              class(
                "col-span-full flex justify-between items-baseline text-base",
              ),
            ],
            [
              div(
                [
                  class(
                    "font-mono pt-0.5 bg-ecru-white-100 border border-ecru-white-950 px-1 text-xs",
                  ),
                  case list.status {
                    Active -> on_click(UserMarkedCurrentListAsCompleted)
                    Completed -> on_click(UserMarkedCurrentListAsActive)
                  },
                ],
                [
                  text(case list.status {
                    Active -> "🛒 Active"
                    Completed -> "✅ Completed"
                  }),
                ],
              ),
              div(
                [
                  class(
                    "font-mono bg-ecru-white-100 border border-ecru-white-950 px-1 text-xs",
                  ),
                  on_click(UserToggledRecipeList),
                ],
                [
                  text(
                    "Recipes: "
                    <> list.linked_recipes
                    |> glearray.to_list
                    |> list.length
                    |> int.to_string,
                  ),
                ],
              ),
            ],
          ),
          div(
            [
              class(
                "col-span-full subgrid-cols gap-y-1 bg-ecru-white-50 border border-ecru-white-950 p-1 text-xs",
              ),
              case recipe_list_open {
                False -> class("hidden")
                True -> attribute.none()
              },
            ],
            [
              view_linked_recipes(list.linked_recipes, recipes),
            ],
          ),
          element.fragment(list.index_map(
            list.items |> glearray.to_list,
            shopping_list_item,
          )),
        ],
      ),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a([href("/shopping-list"), class("text-center")], [text("❎")]),
        button(
          [
            type_("button"),
            class("text-center"),
            on_click(UserDeletedList(list)),
          ],
          [text("🗑️")],
        ),
        button(
          [
            type_("button"),
            class("text-center"),
            on_click(UserSavedList),
          ],
          [text("💾")],
        ),
      ]),
    ],
  )
}

fn view_linked_recipes(
  linked_recipes: Array(types.PlannedRecipe),
  recipes: List(types.Recipe),
) -> Element(ShoppingListMsg) {
  element.fragment([
    case glearray.length(linked_recipes) {
      0 ->
        button(
          [
            type_("button"),
            class("text-center"),
            on_click(UserAddedLinkedRecipeAtIndex(0)),
          ],
          [text("➕")],
        )
      _ -> element.none()
    },
    linked_recipes
      |> glearray.to_list
      |> list.index_map(fn(recipe, index) {
        linked_recipe_input(index, recipe, recipes)
      })
      |> element.fragment,
  ])
}

fn linked_recipe_input(
  index: Int,
  selected_recipe: types.PlannedRecipe,
  recipe_list: List(types.Recipe),
) -> Element(ShoppingListMsg) {
  element.fragment([
    typeahead.typeahead([
      typeahead.recipes(recipe_list),
      typeahead.search_term(selected_recipe),
      event.on("typeahead-change", {
        use res <- decode.subfield(["detail"], decode.string)
        let decoded = json.parse(res, codecs.planned_recipe_decoder())
        case decoded {
          Ok(planned_recipe) ->
            decode.success(UserUpdatedLinkedRecipeAtIndex(index, planned_recipe))
          Error(_) ->
            decode.failure(
              UserUpdatedLinkedRecipeAtIndex(index, types.RecipeName("")),
              "Failed to decode PlannedRecipe",
            )
        }
      }),
      class("col-span-10"),
    ]),
    button(
      [
        class("text-ecru-white-950 cursor-pointer col-start-11 col-span-1"),
        type_("button"),
        id("remove-linked-recipe-input"),
        on_click(UserRemovedLinkedRecipeAtIndex(index)),
      ],
      [text("➖")],
    ),
    button(
      [
        class("text-ecru-white-950 cursor-pointer col-start-12 col-span-1"),
        type_("button"),
        id("add-linked-recipe-input"),
        on_click(UserAddedLinkedRecipeAtIndex(index)),
      ],
      [text("➕")],
    ),
  ])
}

fn shopping_list_item(item: ShoppingListIngredient, index: Int) {
  let update_name_with_index = fn(index) {
    UserUpdatedIngredientNameAtIndex(index, _)
  }
  let update_main_with_index = fn(index) {
    UserUpdatedIngredientMainAtIndex(index, _)
  }
  let update_qty_with_index = fn(index) {
    UserUpdatedIngredientQtyAtIndex(index, _)
  }
  let update_units_with_index = fn(index) {
    UserUpdatedIngredientUnitsAtIndex(index, _)
  }
  div(
    [class("my-1 col-span-full flex justify-between items-baseline  text-base")],
    [
      input([
        attribute("aria-label", "Enter ingredient name"),
        name("ingredient-name-" <> int.to_string(index)),
        type_("text"),
        placeholder("Ingredient"),
        class(
          "text-base input-base w-[20ch] md:w-[34ch] input-focus bg-ecru-white-100",
        ),
        value(option.unwrap(item.ingredient.name, "")),
        on_input(update_name_with_index(index)),
      ]),
      div([class("flex justify-end gap-1 items-baseline")], [
        input([
          attribute("aria-label", "Enter ingredient quanitity"),
          name("ingredient-qty-" <> int.to_string(index)),
          type_("text"),
          placeholder("Qty"),
          class("pt-0.5 w-[3ch] text-sm input-focus bg-ecru-white-100"),
          value(option.unwrap(item.ingredient.quantity, "")),
          on_input(update_qty_with_index(index)),
        ]),
        input([
          attribute("aria-label", "Enter ingredient units"),
          name("ingredient-units-" <> int.to_string(index)),
          type_("text"),
          placeholder("Units"),
          class("pt-0.5 w-[3.5ch] text-sm mr-0 input-focus bg-ecru-white-100"),
          value(option.unwrap(item.ingredient.units, "")),
          on_input(update_units_with_index(index)),
        ]),
        div([class("flex text-xs items-baseline")], [
          label(
            [
              class("ingredient-toggle"),
              attribute("aria-label", "Toggle main ingredient"),
            ],
            [
              input([
                attribute.checked(option.unwrap(item.ingredient.ismain, False)),
                name("`ingredient-main-" <> int.to_string(index)),
                type_("checkbox"),
                event.on_check(update_main_with_index(index)),
              ]),
              span([], []),
            ],
          ),
          button(
            [
              class("text-ecru-white-950 cursor-pointer"),
              type_("button"),
              id("remove-ingredient-input"),
              on_click(UserRemovedIngredientAtIndex(index)),
            ],
            [text("➖")],
          ),
          button(
            [
              class("text-ecru-white-950 cursor-pointer"),
              type_("button"),
              id("add-ingredient-input"),
              on_click(UserAddedIngredientAtIndex(index)),
            ],
            [text("➕")],
          ),
        ]),
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
    codecs.json_string_decoder(decode.list(codecs.planned_recipe_decoder()), []),
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
      linked_recipes: linked_recipes |> glearray.from_list,
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
    linked_recipes: glearray.new(),
    linked_plan: None,
  ))
}

pub fn shopping_list_status_decoder() -> Decoder(Status) {
  use decoded_string <- decode.then(decode.string)
  case decoded_string {
    // Return succeeding decoders for valid strings
    "Active" -> decode.success(Active)
    "Completed" -> decode.success(Completed)
    // Return a failing decoder for any other strings
    _ -> decode.failure(Active, "Status")
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

pub fn encode_shopping_list(list: ShoppingList) -> Json {
  json.object([
    #("date", json.int(date.to_rata_die(list.date))),
    #(
      "status",
      json.string(case list.status {
        Active -> "Active"
        Completed -> "Completed"
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
        |> glearray.to_list
        |> list.map(codecs.encode_planned_recipe)
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

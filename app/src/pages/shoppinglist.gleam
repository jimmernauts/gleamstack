import components/nav_footer.{nav_footer}
import components/page_title.{page_title}
import components/typeahead_2 as typeahead
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/int
import gleam/javascript/promise
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
import shared/db
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
  // Link Plan Modal messages
  UserUpdatedLinkPlanStartDate(String)
  UserUpdatedLinkPlanEndDate(String)
  UserConfirmedLinkPlan(date.Date, date.Date)
  DbRetrievedPlanForLinking(types.PlanWeek)
  UserAddedIngredientsFromLinkedRecipe(types.PlannedRecipe)
}

pub type ShoppingListModel {
  ShoppingListModel(
    all_lists: Dict(date.Date, ShoppingList),
    recipe_list_open: Bool,
    current: Option(ShoppingList),
    recipe_list: recipe_list.RecipeListModel,
    linked_plan_preview: types.PlanWeek,
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
    linked_plan_start: Option(date.Date),
    linked_plan_end: Option(date.Date),
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
    linked_plan_start: None,
    linked_plan_end: None,
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
    UserUpdatedLinkPlanStartDate(new_start_date_as_string) -> {
      let new_start =
        date.from_iso_string(new_start_date_as_string) |> option.from_result
      case model.current {
        Some(current_list) -> {
          let new_list =
            ShoppingList(..current_list, linked_plan_start: new_start)
          #(ShoppingListModel(..model, current: Some(new_list)), effect.none())
        }
        None -> #(model, effect.none())
      }
    }
    UserUpdatedLinkPlanEndDate(new_end_date_as_string) -> {
      let new_end =
        date.from_iso_string(new_end_date_as_string) |> option.from_result
      case model.current {
        Some(current_list) -> {
          let new_list = ShoppingList(..current_list, linked_plan_end: new_end)
          #(ShoppingListModel(..model, current: Some(new_list)), effect.none())
        }
        None -> #(model, effect.none())
      }
    }
    UserConfirmedLinkPlan(start_date, end_date) -> {
      case model.current {
        Some(_current_list) -> {
          let effect = {
            use dispatch <- effect.from
            db.do_get_plan(
              start_date |> date.to_rata_die(),
              end_date |> date.to_rata_die(),
            )
            |> promise.map(codecs.decode_plan_week)
            |> promise.map(DbRetrievedPlanForLinking)
            |> promise.tap(dispatch)
            Nil
          }
          #(model, effect)
        }
        None -> #(model, effect.none())
      }
    }
    DbRetrievedPlanForLinking(plan_week) -> {
      // Update the preview with the fetched plan data
      #(
        ShoppingListModel(..model, linked_plan_preview: plan_week),
        effect.none(),
      )
    }
    UserAddedIngredientsFromLinkedRecipe(planned_recipe) -> {
      case model.current {
        Some(list) -> {
          let recipe_slug = case planned_recipe {
            types.RecipeSlug(slug) -> slug
            types.RecipeName(_) -> ""
          }
          let ingredients_to_add =
            model.recipe_list.recipes
            |> list.find(fn(r) { r.slug == recipe_slug })
            |> result.map(fn(r) {
              r.ingredients
              |> option.unwrap(dict.new())
              |> dict.values
              |> list.map(fn(i) {
                ShoppingListIngredient(
                  ingredient: i,
                  source: FromRecipe(planned_recipe),
                  checked: False,
                )
              })
            })
            |> result.unwrap([])
            |> glearray.from_list

          let updated_items =
            list.items
            |> glearray.to_list
            |> list.append(glearray.to_list(ingredients_to_add))
            |> glearray.from_list

          let updated_list = ShoppingList(..list, items: updated_items)

          save_shopping_list(updated_list)
          #(
            ShoppingListModel(..model, current: Some(updated_list)),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
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
                linked_plan_start: None,
                linked_plan_end: None,
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
      db.do_delete_shopping_list(option.unwrap(list.id, ""))
      #(
        ShoppingListModel(..model, all_lists: updated_lists, current: None),
        effect.none(),
      )
    }
  }
}

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
    case list.linked_plan_start {
      Some(plan_date) -> date.to_rata_die(plan_date)
      None -> 0
    },
    case list.linked_plan_end {
      Some(plan_date) -> date.to_rata_die(plan_date)
      None -> 0
    },
  )
  db.do_save_shopping_list(list_obj)
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

pub fn subscribe_to_shopping_list_summaries() -> Effect(ShoppingListMsg) {
  use dispatch <- effect.from
  db.do_subscribe_to_shopping_list_summaries(fn(data) {
    data
    |> DbSubscribedListSummaries
    |> dispatch
  })
  Nil
}

pub fn subscribe_to_one_shoppinglist_by_date(
  date: date.Date,
) -> Effect(ShoppingListMsg) {
  use dispatch <- effect.from
  db.do_subscribe_to_one_shoppinglist_by_date(date.to_rata_die(date), fn(data) {
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
  recipes: List(types.Recipe),
  linked_plan_preview: types.PlanWeek,
) -> Element(ShoppingListMsg) {
  let list = case current_list {
    Some(list) -> list
    None ->
      ShoppingList(
        id: None,
        date: date.today(),
        items: glearray.new(),
        status: Active,
        linked_recipes: glearray.new(),
        linked_plan_start: None,
        linked_plan_end: None,
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
              div([], [
                div([class("flex flex-col gap-2")], [
                  // Date inputs and link button row
                  div([class("flex flex-wrap gap-2 items-end")], [
                    div([class("flex flex-col gap-0.5")], [
                      label([class("text-xs font-mono")], [text("From:")]),
                      input([
                        type_("date"),
                        class(
                          "border border-ecru-white-950 px-1 py-0.5 font-mono text-xs",
                        ),
                        value(case list.linked_plan_start {
                          Some(start_date) -> date.to_iso_string(start_date)
                          None -> ""
                        }),
                        on_input(UserUpdatedLinkPlanStartDate),
                      ]),
                    ]),
                    div([class("flex flex-col gap-0.5")], [
                      label([class("text-xs font-mono")], [text("To:")]),
                      input([
                        type_("date"),
                        class(
                          "border border-ecru-white-950 px-1 py-0.5 font-mono text-xs",
                        ),
                        value(case list.linked_plan_end {
                          Some(end_date) -> date.to_iso_string(end_date)
                          None -> ""
                        }),
                        on_input(UserUpdatedLinkPlanEndDate),
                      ]),
                    ]),
                    button(
                      [
                        class(
                          "bg-orange-200 hover:bg-orange-300 border border-ecru-white-950 px-2 py-0.5 text-xs font-mono cursor-pointer",
                        ),
                        on_click({
                          case list.linked_plan_start, list.linked_plan_end {
                            Some(start_date), Some(end_date) ->
                              UserConfirmedLinkPlan(start_date, end_date)
                            None, Some(end_date) ->
                              UserConfirmedLinkPlan(date.today(), end_date)
                            Some(start_date), None ->
                              UserConfirmedLinkPlan(
                                start_date,
                                date.add(start_date, 7, date.Days),
                              )
                            None, None ->
                              UserConfirmedLinkPlan(date.today(), date.today())
                          }
                        }),
                      ],
                      [text("🗓️")],
                    ),
                  ]),
                ]),
              ]),
              element.fragment(list.index_map(
                list.items |> glearray.to_list,
                shopping_list_item,
              )),
            ],
          ),
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

fn view_plan_preview(
  shopping_list: ShoppingList,
  recipes: List(types.Recipe),
  preview: types.PlanWeek,
) -> Element(ShoppingListMsg) {
  // Get recipe title from PlannedRecipe
  let get_recipe_title = fn(planned_recipe: types.PlannedRecipe) -> String {
    case planned_recipe {
      types.RecipeName(name) -> name
      types.RecipeSlug(slug) ->
        recipes
        |> list.find(fn(r) { r.slug == slug })
        |> result.map(fn(r) { r.title })
        |> result.unwrap(slug)
    }
  }
  let preview_rows = preview |> dict.to_list
  // Preview grid (date | lunch | dinner)
  case list.length(preview_rows) {
    0 ->
      div([class("text-xs text-ecru-white-500 italic")], [
        text("Select dates and preview will appear here"),
      ])
    _ ->
      div(
        [
          class("grid grid-cols-[auto_1fr_1fr] gap-x-2 gap-y-0.5 text-xs"),
        ],
        // Header row
        list.flatten([
          [
            span([class("font-mono font-bold")], [text("Date")]),
            span([class("font-mono font-bold")], [text("Lunch")]),
            span([class("font-mono font-bold")], [text("Dinner")]),
          ],
          // Data rows
          list.flat_map(preview_rows, fn(entry) {
            let #(day_date, plan_day) = entry
            let lunch_text = case plan_day.lunch {
              Some(meal) -> get_recipe_title(meal.recipe)
              None -> "-"
            }
            let dinner_text = case plan_day.dinner {
              Some(meal) -> get_recipe_title(meal.recipe)
              None -> "-"
            }
            [
              span([class("font-mono text-ecru-white-500")], [
                text(date.to_iso_string(day_date)),
              ]),
              span([class("truncate")], [text(lunch_text)]),
              span([class("truncate")], [text(dinner_text)]),
            ]
          }),
        ]),
      )
  }
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
  use linked_plan_start <- decode.optional_field(
    "linked_plan_start",
    None,
    decode.optional(decode.int),
  )
  use linked_plan_end <- decode.optional_field(
    "linked_plan_end",
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
      linked_plan_start: case linked_plan_start {
        Some(plan_date) -> Some(date.from_rata_die(plan_date))
        None -> None
      },
      linked_plan_end: case linked_plan_end {
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
    linked_plan_start: None,
    linked_plan_end: None,
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
    #("linked_plan_start", case list.linked_plan_start {
      Some(plan_date) -> json.int(date.to_rata_die(plan_date))
      None -> json.null()
    }),
    #("linked_plan_end", case list.linked_plan_end {
      Some(plan_date) -> json.int(date.to_rata_die(plan_date))
      None -> json.null()
    }),
  ])
}

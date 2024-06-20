import components/page_title.{page_title}
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{
  type Dynamic, bool, dict, field, int, list, optional_field, string,
}
import gleam/function
import gleam/int
import gleam/io
import gleam/javascript/array.{type Array}
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/string
import justin.{kebab_case}
import lib/utils
import lustre/attribute.{
  attribute, checked, class, disabled, for, href, id, name, placeholder,
  selected, style, type_, value,
}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment, text}
import lustre/element/html.{
  a, button, div, fieldset, form, input, label, legend, li, nav, ol, option,
  section, select, span, textarea,
}
import lustre/event.{on_check, on_click, on_input}

//-MODEL---------------------------------------------

pub type RecipeDetailMsg {
  UserUpdatedRecipeTitle(String)
  UserUpdatedRecipePrepTimeHrs(String)
  UserUpdatedRecipePrepTimeMins(String)
  UserUpdatedRecipeCookTimeHrs(String)
  UserUpdatedRecipeCookTimeMins(String)
  UserUpdatedRecipeServes(String)
  UserUpdatedIngredientNameAtIndex(Int, String)
  UserUpdatedIngredientMainAtIndex(Int, Bool)
  UserUpdatedIngredientQtyAtIndex(Int, String)
  UserUpdatedIngredientUnitsAtIndex(Int, String)
  UserAddedIngredientAtIndex(Int)
  UserRemovedIngredientAtIndex(Int)
  UserUpdatedMethodStepAtIndex(Int, String)
  UserAddedMethodStepAtIndex(Int)
  UserRemovedMethodStepAtIndex(Int)
  UserSavedUpdatedRecipe(Recipe)
  DbSavedUpdatedRecipe(Recipe)
}

pub type RecipeListMsg {
  DbRetrievedRecipes(List(Recipe))
  DbRetrievedTagOptions(List(TagOption))
}

pub type RecipeList {
  RecipeList(recipes: List(Recipe), tag_options: List(TagOption))
}

pub type RecipeDetail =
  Option(Recipe)

//-UPDATE---------------------------------------------

pub fn merge_recipe_into_model(recipe: Recipe, model: RecipeList) -> RecipeList {
  RecipeList(
    ..model,
    recipes: model.recipes
      |> list.map(fn(a) { #(a.id, a) })
      |> dict.from_list
      |> dict.merge(dict.from_list([#(recipe.id, recipe)]))
      |> dict.values(),
  )
}

pub fn get_recipes() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_recipes()
  |> promise.map(array.to_list)
  |> promise.map(list.map(_, decode_recipe))
  |> promise.map(result.all)
  |> promise.map(result.map(_, DbRetrievedRecipes))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, ".././db.ts", "do_get_recipes")
fn do_get_recipes() -> Promise(Array(Dynamic))

pub fn get_tag_options() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_tagoptions()
  |> promise.map(array.to_list)
  |> promise.map(list.map(_, decode_tag_option))
  |> promise.map(result.all)
  |> promise.map(result.map(_, DbRetrievedTagOptions))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, ".././db.ts", "do_get_tagoptions")
fn do_get_tagoptions() -> Promise(Array(Dynamic))

fn save_recipe(recipe: Recipe) -> Effect(RecipeDetailMsg) {
  let js_recipe =
    JSRecipe(
      id: option.unwrap(recipe.id, ""),
      title: recipe.title,
      slug: recipe.slug,
      cook_time: recipe.cook_time,
      prep_time: recipe.prep_time,
      serves: recipe.serves,
      tags: option.unwrap(
        option.map(recipe.tags, array.from_list),
        array.from_list([]),
      ),
      ingredients: recipe.ingredients
        |> json.nullable(json_encode_ingredient_list),
      method_steps: recipe.method_steps
        |> json.nullable(json_encode_method_step_list),
    )
  use dispatch <- effect.from
  do_save_recipe(js_recipe)
  DbSavedUpdatedRecipe(recipe) |> dispatch
}

@external(javascript, ".././db.ts", "addOrUpdateRecipe")
fn do_save_recipe(recipe: JSRecipe) -> Nil

type JSRecipe {
  JSRecipe(
    id: String,
    title: String,
    slug: String,
    cook_time: Int,
    prep_time: Int,
    serves: Int,
    tags: Array(Tag),
    ingredients: Json,
    method_steps: Json,
  )
}

pub fn detail_update(
  model: RecipeDetail,
  msg: RecipeDetailMsg,
) -> #(RecipeDetail, Effect(RecipeDetailMsg)) {
  case msg {
    UserUpdatedRecipeTitle(newtitle) -> {
      case model {
        Some(a) -> #(Some(Recipe(..a, title: newtitle)), effect.none())
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedRecipePrepTimeHrs(newpreptimehrs) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              prep_time: newpreptimehrs
                |> int.parse
                |> result.map(fn(b) { { b * 60 } + a.prep_time % 60 })
                |> result.unwrap(0),
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedRecipePrepTimeMins(newpreptimemins) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              prep_time: newpreptimemins
                |> int.parse
                |> result.map(fn(b) {
                  { a.prep_time - { a.prep_time % 60 } } + b
                })
                |> result.unwrap(0),
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedRecipeCookTimeHrs(newcooktimehrs) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              cook_time: newcooktimehrs
                |> int.parse
                |> result.map(fn(b) { { b * 60 } + a.cook_time % 60 })
                |> result.unwrap(0),
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedRecipeCookTimeMins(newcooktimemins) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              cook_time: newcooktimemins
                |> int.parse
                |> result.map(fn(b) {
                  { a.cook_time - { a.cook_time % 60 } } + b
                })
                |> result.unwrap(0),
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedRecipeServes(newserves) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              serves: newserves
                |> int.parse
                |> result.unwrap(0),
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedIngredientNameAtIndex(i, new_ingredient_name) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              ingredients: {
                a.ingredients
                |> option.map(utils.dict_update(
                  _,
                  i,
                  fn(ing) { Ingredient(..ing, name: Some(new_ingredient_name)) },
                ))
              },
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedIngredientMainAtIndex(i, new_ingredient_ismain) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              ingredients: {
                a.ingredients
                |> option.map(utils.dict_update(
                  _,
                  i,
                  fn(ing) {
                    Ingredient(..ing, ismain: Some(new_ingredient_ismain))
                  },
                ))
              },
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedIngredientQtyAtIndex(i, new_ingredient_qty) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              ingredients: {
                a.ingredients
                |> option.map(utils.dict_update(
                  _,
                  i,
                  fn(ing) {
                    Ingredient(..ing, quantity: Some(new_ingredient_qty))
                  },
                ))
              },
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedIngredientUnitsAtIndex(i, new_ingredient_units) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              ingredients: {
                a.ingredients
                |> option.map(utils.dict_update(
                  _,
                  i,
                  fn(ing) {
                    Ingredient(..ing, units: Some(new_ingredient_units))
                  },
                ))
              },
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserAddedIngredientAtIndex(_i) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              ingredients: case a.ingredients {
                Some(b) ->
                  Some(dict.insert(
                    b,
                    dict.size(b),
                    Ingredient(None, None, None, None),
                  ))
                _ ->
                  Some(
                    dict.from_list([#(0, Ingredient(None, None, None, None))]),
                  )
              },
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserRemovedIngredientAtIndex(i) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              ingredients: a.ingredients
                |> option.map(dict.drop(_, [i]))
                |> option.map(utils.dict_reindex),
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserAddedMethodStepAtIndex(_i) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              method_steps: case a.method_steps {
                Some(b) -> Some(dict.insert(b, dict.size(b), MethodStep("")))
                _ -> Some(dict.from_list([#(0, MethodStep(""))]))
              },
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserRemovedMethodStepAtIndex(i) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              method_steps: a.method_steps
                |> option.map(dict.drop(_, [i]))
                |> option.map(utils.dict_reindex),
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedMethodStepAtIndex(i, new_method_step) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(
              ..a,
              method_steps: {
                a.method_steps
                |> option.map(utils.dict_update(
                  _,
                  i,
                  fn(_step) { MethodStep(step_text: new_method_step) },
                ))
              },
            ),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserSavedUpdatedRecipe(recipe) -> {
      #(Some(recipe), {
        save_recipe(Recipe(..recipe, slug: kebab_case(recipe.title)))
      })
    }
    DbSavedUpdatedRecipe(recipe) -> {
      #(Some(recipe), effect.none())
    }
  }
}

pub fn list_update(
  model: RecipeList,
  msg: RecipeListMsg,
) -> #(RecipeList, Effect(RecipeListMsg)) {
  case msg {
    DbRetrievedRecipes(recipes) -> #(
      RecipeList(..model, recipes: recipes),
      effect.none(),
    )
    DbRetrievedTagOptions(tag_options) -> #(
      RecipeList(..model, tag_options: tag_options),
      effect.none(),
    )
  }
}

//-VIEWS-------------------------------------------------------------

pub fn view_recipe_list(model: RecipeList) {
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr]",
      ),
    ],
    [
      page_title("Recipe Book", "underline-green"),
      nav(
        [
          class(
            "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4",
          ),
        ],
        [a([href("/"), class("text-center")], [text("🏠")])],
      ),
      // div([class("col-span-full flex flex-wrap items-center justify-start gap-3")],[
      // TODO: Group By tag buttons go here
      //])
      div([class("contents")], list.map(model.recipes, view_recipe_summary)),
    ],
  )
}

pub fn lookup_and_view_recipe(maybe_recipe: RecipeDetail) {
  case maybe_recipe {
    Some(a) -> view_recipe_detail(a)
    _ -> page_title("Recipe not found", "")
  }
}

pub fn lookup_and_edit_recipe(
  maybe_recipe: RecipeDetail,
  tag_options: List(TagOption),
) {
  case maybe_recipe {
    Some(a) -> edit_recipe_detail(a, tag_options)
    _ -> page_title("Recipe not found", "")
  }
}

pub fn edit_recipe_detail(
  recipe: Recipe,
  tag_options: List(TagOption),
) -> Element(RecipeDetailMsg) {
  form(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr] gap-y-2",
      ),
      id("create_recipe_form"),
      event.on_submit(UserSavedUpdatedRecipe(recipe)),
    ],
    [
      div(
        [
          class(
            "mt-4 mb-2 sm:mb-4 mr-2 flex col-start-1 col-span-11 sm:col-start-1 sm:col-span-8",
          ),
        ],
        [
          textarea(
            [
              id("title"),
              name("title"),
              class(
                "placeholder:underline-blue underline-blue min-h-[56px] max-h-[140px] overflow-x-hidden px-0 pb-1 ml-2 input-base w-full input-focus font-transitional resize-none font-bold italic text-ecru-white-950  text-7xl bg-ecru-white-100",
              ),
              attribute("title", "recipe title"),
              on_input(UserUpdatedRecipeTitle),
            ],
            recipe.title,
          ),
        ],
      ),
      fieldset(
        [
          class(
            "mt-0 sm:mt-4 sm:mx-4 row-start-2 col-span-5 col-start-8 sm:row-start-1 sm:col-span-3 sm:col-start-9",
          ),
        ],
        [
          fieldset(
            [class("flex flex-wrap justify-between items-baseline mb-2")],
            [
              label(
                [class("justify-self-start font-mono italic"), for("prep_time")],
                [text("Prep:")],
              ),
              div([class("justify-self-start")], [
                div(
                  [class("after:content-['h'] after:text-base inline-block")],
                  [
                    input([
                      id("prep_time_hrs"),
                      class(
                        "bg-ecru-white-100 input-base input-focus pr-0.5 mr-0.5 w-[2ch] text-right text-base",
                      ),
                      type_("number"),
                      name("prep_time_hrs"),
                      attribute("title", "prep time in hours"),
                      value(
                        int.floor_divide(recipe.prep_time, 60)
                        |> result.unwrap(0)
                        |> int.to_string
                        |> string.replace("0", ""),
                      ),
                      on_input(UserUpdatedRecipePrepTimeHrs),
                    ]),
                  ],
                ),
                div(
                  [class("after:content-['m'] after:text-base inline-block")],
                  [
                    input([
                      id("prep_time_mins"),
                      class(
                        "bg-ecru-white-100 input-base input-focus pr-0.5 mr-0.5 w-[3ch] text-right text-base",
                      ),
                      type_("number"),
                      name("prep_time_mins"),
                      attribute("title", "prep time in minutes"),
                      value(
                        recipe.prep_time % 60
                        |> int.to_string,
                      ),
                      on_input(UserUpdatedRecipePrepTimeMins),
                    ]),
                  ],
                ),
              ]),
            ],
          ),
          fieldset(
            [class("flex flex-wrap justify-between items-baseline mb-2")],
            [
              label(
                [class("justify-self-start font-mono italic"), for("prep_time")],
                [text("Cook:")],
              ),
              div([class("justify-self-start")], [
                div(
                  [class("after:content-['h'] after:text-base inline-block")],
                  [
                    input([
                      id("cook_time_hrs"),
                      class(
                        "bg-ecru-white-100 input-base input-focus pr-0.5 w-[2ch] text-right text-base",
                      ),
                      type_("number"),
                      name("cook_time_hrs"),
                      attribute("title", "cook time in hours"),
                      value(
                        int.floor_divide(recipe.cook_time, 60)
                        |> result.unwrap(0)
                        |> int.to_string
                        |> string.replace("0", ""),
                      ),
                      on_input(UserUpdatedRecipeCookTimeHrs),
                    ]),
                  ],
                ),
                div(
                  [class("after:content-['m'] after:text-base inline-block")],
                  [
                    input([
                      id("cook_time_mins"),
                      class(
                        "bg-ecru-white-100 input-base input-focus pr-0.5 w-[3ch] text-right text-base",
                      ),
                      type_("number"),
                      name("cook_time_mins"),
                      attribute("title", "cook time in minutes"),
                      value(
                        recipe.cook_time % 60
                        |> int.to_string,
                      ),
                      on_input(UserUpdatedRecipeCookTimeMins),
                    ]),
                  ],
                ),
              ]),
            ],
          ),
          fieldset(
            [class("flex flex-wrap justify-between items-baseline mb-2")],
            [
              label(
                [class("justify-self-start font-mono italic"), for("serves")],
                [text("Serves:")],
              ),
              input([
                id("serves"),
                class(
                  "pr-0.5 mr-2 sm:mr-4  justify-self-start col-span-3 input-base input-focus w-[3ch] text-right text-base bg-ecru-white-100",
                ),
                type_("number"),
                name("serves"),
                value(recipe.serves |> int.to_string),
                on_input(UserUpdatedRecipeServes),
              ]),
            ],
          ),
        ],
      ),
      nav(
        [
          class(
            "flex flex-col justify-start items-middle col-span-1 col-start-12 text-sm sm:text-base md:text-lg my-4 text-center",
          ),
        ],
        [
          a([href("/"), class("text-center")], [text("🏠")]),
          a([href("/recipes/" <> recipe.slug), class("text-center")], [
            text("❎"),
          ]),
          button([type_("submit"), class("")], [text("💾")]),
        ],
      ),
      fieldset(
        [
          class(
            "col-span-7 row-start-2 content-start sm:col-span-full flex flex-wrap gap-1 items-baseline mx-1 gap-3",
          ),
        ],
        case recipe.tags {
          Some(a) ->
            list.index_map(a, fn(tag, i) {
              tag_input(tag_options, i, Some(tag))
            })
          _ -> [element.none()]
        },
      ),
      //TODO : TAG PICKER HERE
      fieldset(
        [
          class(
            "col-span-full my-1 mb-6 pt-1 pb-2 px-2 mr-1 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-5 [box-shadow:1px_1px_0_#9edef1]",
          ),
        ],
        [
          legend([class("mx-2 px-1 font-mono italic")], [text("Ingredients")]),
          case recipe.ingredients {
            Some(ings) -> {
              let children =
                ings
                |> dict.to_list
                |> list.sort(by: fn(a, b) {
                  int.compare(pair.first(a), pair.first(b))
                })
                |> list.map(fn(a) {
                  #(
                    int.to_string(pair.first(a)),
                    ingredient_input(pair.first(a), Some(pair.second(a))),
                  )
                })
              element.keyed(html.div([], _), children)
            }
            _ -> ingredient_input(0, None)
          },
        ],
      ),
      fieldset(
        [
          class(
            "col-span-full my-1 mb-6 pt-1 pb-2 px-2 ml-1 mr-1 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-7 [box-shadow:1px_1px_0_#9edef1]",
          ),
        ],
        [
          legend([class("mx-2 px-1 font-mono italic")], [text("Method")]),
          case recipe.method_steps {
            Some(steps) -> {
              let children =
                steps
                |> dict.to_list
                |> list.sort(by: fn(a, b) {
                  int.compare(pair.first(a), pair.first(b))
                })
                |> list.map(fn(a) {
                  #(
                    int.to_string(pair.first(a)),
                    method_step_input(pair.first(a), Some(pair.second(a))),
                  )
                })
              element.keyed(html.div([], _), children)
            }
            _ -> ingredient_input(0, None)
          },
        ],
      ),
    ],
  )
}

pub fn view_recipe_detail(recipe: Recipe) {
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr] gap-y-2",
      ),
    ],
    [
      page_title(recipe.title, "underline-green"),
      fieldset(
        [
          class(
            "sm:mt-4 lg:mx-4 row-start-2 col-start-9 col-span-4 sm:row-start-1 sm:col-span-3 sm:col-start-9",
          ),
        ],
        [
          fieldset(
            [class("flex flex-wrap justify-between items-baseline mb-2")],
            [
              label([for("prep_time"), class("font-mono italic")], [
                text("Prep:"),
              ]),
              div([class("text-base")], [
                text(
                  case recipe.prep_time > 59 {
                    True ->
                      int.floor_divide(recipe.prep_time, 60)
                      |> result.unwrap(0)
                      |> int.to_string
                      |> string.replace("0", "")
                      <> "h "
                    _ -> ""
                  }
                  <> recipe.prep_time % 60
                  |> int.to_string
                  <> "m",
                ),
              ]),
            ],
          ),
          fieldset(
            [class("flex flex-wrap justify-between items-baseline mb-2")],
            [
              label([for("cook_time"), class("font-mono italic")], [
                text("Cook:"),
              ]),
              div([class("text-base")], [
                text(
                  case recipe.cook_time > 59 {
                    True ->
                      int.floor_divide(recipe.cook_time, 60)
                      |> result.unwrap(0)
                      |> int.to_string
                      |> string.replace("0", "")
                      <> "h "
                    _ -> ""
                  }
                  <> recipe.cook_time % 60
                  |> int.to_string
                  <> "m",
                ),
              ]),
            ],
          ),
          fieldset(
            [class("flex flex-wrap justify-between items-baseline mb-2")],
            [
              label([for("cook_time"), class("font-mono italic")], [
                text("Serves:"),
              ]),
              div([class("mr-2 sm:mr-4 text-base")], [
                text(int.to_string(recipe.serves)),
              ]),
            ],
          ),
        ],
      ),
      nav(
        [
          class(
            "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4",
          ),
        ],
        [
          a([href("/"), class("text-center")], [text("🏠")]),
          a(
            [href("/recipes/" <> recipe.slug <> "/edit"), class("text-center")],
            [text("✏️")],
          ),
        ],
      ),
      fieldset(
        [
          class(
            "col-span-7 row-start-2 content-start sm:col-span-full flex flex-wrap gap-1 items-baseline mx-1 gap-3",
          ),
        ],
        case recipe.tags {
          Some(a) -> list.map(a, fn(tag) { view_tag(tag) })
          _ -> [element.none()]
        },
      ),
      fieldset(
        [
          class(
            "col-span-full text-base my-1 mb-6 pt-1 pb-2 px-2 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-5 [box-shadow:1px_1px_0_#a3d2ab] mr-1",
          ),
        ],
        [
          legend([class("mx-2 px-1 text-lg font-mono italic")], [
            text("Ingredients"),
          ]),
          case recipe.ingredients {
            Some(ings) -> {
              let children =
                ings
                |> dict.to_list
                |> list.sort(by: fn(a, b) {
                  int.compare(pair.first(a), pair.first(b))
                })
                |> list.map(fn(a) {
                  #(
                    int.to_string(pair.first(a)),
                    view_ingredient(pair.second(a)),
                  )
                })
              element.keyed(html.div([], _), children)
            }
            _ -> element.none()
          },
        ],
      ),
      fieldset(
        [
          class(
            "flex justify-start flex-wrap col-span-full my-1 mb-6 pt-1 mr-1 sm:mr-2 ml-1 pb-2 px-2 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-7 [box-shadow:1px_1px_0_#a3d2ab]",
          ),
        ],
        [
          legend([class("mx-2 px-1 font-mono italic")], [text("Method")]),
          ol(
            [
              class(
                "flex flex-wrap w-full mb-1 list-decimal marker:text-sm marker:font-mono text-base items-baseline col-span-full",
              ),
            ],
            [
              case recipe.method_steps {
                Some(steps) -> {
                  let children =
                    steps
                    |> dict.to_list
                    |> list.sort(by: fn(a, b) {
                      int.compare(pair.first(a), pair.first(b))
                    })
                    |> list.map(fn(a) {
                      #(
                        int.to_string(pair.first(a)),
                        view_method_step(pair.second(a)),
                      )
                    })
                  element.keyed(html.div([], _), children)
                }
                _ -> element.none()
              },
            ],
          ),
        ],
      ),
    ],
  )
}

//-COMPONENTS--------------------------------------------------

fn view_recipe_summary(recipe: Recipe) {
  div(
    [
      class(
        "col-span-full flex flex-wrap items-baseline justify-start my-1 text-base",
      ),
    ],
    [
      div([class("text-xl flex flex-nowrap gap-1 my-1 ml-2 items-baseline")], [
        a([href(string.append("/recipes/", recipe.slug))], [
          span([], [text(recipe.title)]),
          span([class("text-sm")], [
            text(" • "),
            case recipe.prep_time + recipe.cook_time > 59 {
              True ->
                text(
                  int.floor_divide({ recipe.prep_time + recipe.cook_time }, 60)
                  |> result.unwrap(0)
                  |> int.to_string()
                  <> "h",
                )
              _ -> element.none()
            },
            text(
              { recipe.prep_time + recipe.cook_time } % 60
              |> int.to_string(),
            ),
            text("m"),
          ]),
        ]),
      ]),
    ],
  )
}

fn ingredient_input(index: Int, ingredient: Option(Ingredient)) {
  let update_name_with_index = function.curry2(UserUpdatedIngredientNameAtIndex)
  let update_main_with_index = function.curry2(UserUpdatedIngredientMainAtIndex)
  let update_qty_with_index = function.curry2(UserUpdatedIngredientQtyAtIndex)
  let update_units_with_index =
    function.curry2(UserUpdatedIngredientUnitsAtIndex)

  div([class("my-0.5 w-full flex justify-between items-baseline  text-base")], [
    input([
      attribute("aria-label", "Enter ingredient name"),
      name("ingredient-name-" <> int.to_string(index)),
      type_("text"),
      placeholder("Ingredient"),
      class(
        "w-[16ch] xxs:w-[23ch] xs:w-[28ch] sm:w-[16ch] md:w-[23ch] lg:w-[28ch] text-base input-base input-focus bg-ecru-white-100",
      ),
      value(case ingredient {
        Some(ing) -> option.unwrap(ing.name, "")
        _ -> ""
      }),
      on_input(update_name_with_index(index)),
    ]),
    div([class("flex justify-end gap-1 items-baseline")], [
      input([
        attribute("aria-label", "Enter ingredient quanitity"),
        name("ingredient-qty-" <> int.to_string(index)),
        type_("text"),
        placeholder("Qty"),
        class("pt-0.5 w-[4ch] text-sm input-focus bg-ecru-white-100"),
        value(case ingredient {
          Some(ing) -> option.unwrap(ing.quantity, "")
          _ -> ""
        }),
        on_input(update_qty_with_index(index)),
      ]),
      input([
        attribute("aria-label", "Enter ingredient units"),
        name("ingredient-units-" <> int.to_string(index)),
        type_("text"),
        placeholder("Units"),
        class("pt-0.5 w-[5ch] text-sm mr-0 input-focus bg-ecru-white-100"),
        value(case ingredient {
          Some(ing) -> option.unwrap(ing.units, "")
          _ -> ""
        }),
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
              checked(case ingredient {
                Some(ing) -> option.unwrap(ing.ismain, False)
                _ -> False
              }),
              name("`ingredient-main-" <> int.to_string(index)),
              type_("checkbox"),
              on_check(update_main_with_index(index)),
            ]),
            span([], []),
          ],
        ),
        button(
          [
            class("text-ecru-white-950"),
            type_("button"),
            id("remove-ingredient-input"),
            on_click(UserRemovedIngredientAtIndex(index)),
          ],
          [text("➖")],
        ),
        button(
          [
            class("text-ecru-white-950"),
            type_("button"),
            id("add-ingredient-input"),
            on_click(UserAddedIngredientAtIndex(index)),
          ],
          [text("➕")],
        ),
      ]),
    ]),
  ])
}

fn method_step_input(index: Int, method_step: Option(MethodStep)) {
  let update_methodstep_at_index = function.curry2(UserUpdatedMethodStepAtIndex)
  div([class("flex w-full items-baseline col-span-full px-1 mb-1 text-base")], [
    label([class("font-mono text-sm")], [
      text(index + 1 |> int.to_string <> "."),
    ]),
    textarea(
      [
        name("method-step-" <> index |> int.to_string),
        id("method-step-" <> index |> int.to_string),
        class("mx-3 bg-ecru-white-100 w-full input-focus text-base resize-none"),
        attribute("rows", "3"),
        on_input(update_methodstep_at_index(index)),
      ],
      case method_step {
        Some(a) -> a.step_text
        _ -> ""
      },
    ),
    button(
      [
        class("text-ecru-white-950 text-xs"),
        type_("button"),
        id("remove-ingredient-input"),
        on_click(UserRemovedMethodStepAtIndex(index)),
      ],
      [text("➖")],
    ),
    button(
      [
        class("text-ecru-white-950 text-xs"),
        type_("button"),
        id("add-ingredient-input"),
        on_click(UserAddedMethodStepAtIndex(index)),
      ],
      [text("➕")],
    ),
  ])
}

fn view_ingredient(ingredient: Ingredient) {
  let bold = case ingredient.ismain {
    Some(True) -> " font-bold"
    _ -> ""
  }
  div([class("flex justify-start col-span-6 items-baseline")], [
    div([class("flex-grow-[2] text-left flex justify-start" <> bold)], [
      option.unwrap(option.map(ingredient.name, text(_)), element.none()),
    ]),
    div([class("col-span-1 text-sm")], [
      option.unwrap(option.map(ingredient.quantity, text(_)), element.none()),
    ]),
    div([class("col-span-1 text-sm")], [
      option.unwrap(option.map(ingredient.units, text(_)), element.none()),
    ]),
  ])
}

fn view_method_step(method_step: MethodStep) {
  li([class("w-full justify-self-start list-decimal text-left ml-8 pr-6")], [
    text(method_step.step_text),
  ])
}

fn view_tag(tag: Tag) {
  div([class("flex")], [
    div(
      [
        class(
          "font-mono bg-ecru-white-100 border border-ecru-white-950 px-1 text-xs",
        ),
      ],
      [text(tag.name)],
    ),
    div(
      [
        class(
          "font-mono bg-ecru-white-50 border border-l-0 border-ecru-white-950  px-1 text-xs",
        ),
      ],
      [text(tag.value)],
    ),
  ])
}

fn tag_input(
  available_tags: List(TagOption),
  index: Int,
  input: Option(Tag),
) -> Element(RecipeDetailMsg) {
  let selected_name = case input {
    Some(a) -> a.name
    _ -> ""
  }
  let tagnames = list.map(available_tags, fn(x) { x.name })
  fieldset(
    [
      id("tag-input-" <> int.to_string(index)),
      class("flex col-span-6 sm:col-span-4 min-w-0"),
    ],
    [
      select(
        [
          attribute("style", "width: auto;"),
          class(
            "inline bg-ecru-white-100 col-span-4 row-span-1 pl-1 p-0 mb-1 text-xs font-mono custom-select",
          ),
          id("tag-name-selector"),
          name("tag-name-" <> int.to_string(index)),
        ],
        [
          option(
            [
              class(
                "text-xs font-mono custom-select input-focus bg-ecru-white-100",
              ),
              attribute("hidden", ""),
              disabled(True),
              value(""),
              selected(string.is_empty(selected_name)),
            ],
            "",
          ),
          fragment(
            list.map(tagnames, fn(tag_name) {
              option(
                [
                  value(tag_name),
                  selected(tag_name == selected_name),
                  class(
                    "text-xs font-mono custom-select input-focus bg-ecru-white-50",
                  ),
                ],
                tag_name,
              )
            }),
          ),
        ],
      ),
      case input {
        Some(input) -> {
          select(
            [
              style([
                case string.length(input.value) > 7 {
                  True -> #(
                    "width",
                    int.to_string(string.length(input.value)) <> "ch",
                  )
                  _ -> #(
                    "width",
                    int.to_string(string.length(input.value) + 1) <> "ch",
                  )
                },
              ]),
              class(
                "inline bg-ecru-white-100 col-span-4 row-span-1 pl-1 p-0 mb-1 text-xs font-mono custom-select",
              ),
            ],
            [
              option(
                [
                  class(
                    "text-xs font-mono custom-select input-focus bg-ecru-white-100",
                  ),
                  attribute("hidden", ""),
                  disabled(True),
                  value(""),
                  selected(string.is_empty(selected_name)),
                ],
                "",
              ),
              {
                let is_selected = fn(x: TagOption) { x.name == selected_name }
                let options = fn(x: TagOption) {
                  list.map(x.options, fn(a) {
                    option(
                      [
                        value(a),
                        selected(a == selected_name),
                        class(
                          "text-xs font-mono custom-select input-focus bg-ecru-white-50",
                        ),
                      ],
                      a,
                    )
                  })
                }
                list.find(available_tags, is_selected)
                |> result.map(options)
                |> result.unwrap([element.none()])
                |> fragment
              },
            ],
          )
        }
        _ -> element.none()
      },
      button(
        [
          class("col-span-1 mb-1 text-ecru-white-950 text-xs"),
          id("remove-tag-input"),
          type_("button"),
        ],
        [text("➖")],
      ),
      button(
        [
          class("col-span-1 mb-1 text-ecru-white-950 text-xs"),
          id("add-tag-input"),
          type_("button"),
        ],
        [text("➕")],
      ),
    ],
  )
}

//-TYPES-------------------------------------------------------------

pub type Recipe {
  Recipe(
    id: Option(String),
    title: String,
    slug: String,
    cook_time: Int,
    prep_time: Int,
    serves: Int,
    tags: Option(List(Tag)),
    ingredients: Option(Dict(Int, Ingredient)),
    method_steps: Option(Dict(Int, MethodStep)),
  )
}

pub type TagOption {
  TagOption(id: Option(String), name: String, options: List(String))
}

pub type MethodStep {
  MethodStep(step_text: String)
}

pub type Tag {
  Tag(name: String, value: String)
}

pub type Ingredient {
  Ingredient(
    name: Option(String),
    ismain: Option(Bool),
    quantity: Option(String),
    units: Option(String),
  )
}

//-ENCODERS-DECODERS----------------------------------------------

fn json_encode_ingredient(ingredient: Ingredient) -> Json {
  json.object([
    #("name", json.string(option.unwrap(ingredient.name, ""))),
    #("quantity", json.string(option.unwrap(ingredient.quantity, ""))),
    #("units", json.string(option.unwrap(ingredient.units, ""))),
    #(
      "ismain",
      json.string(bool.to_string(option.unwrap(ingredient.ismain, False))),
    ),
  ])
}

fn json_encode_ingredient_list(dict: Dict(Int, Ingredient)) -> Json {
  dict
  |> dict.to_list
  |> list.map(fn(pair: #(Int, Ingredient)) {
    #(int.to_string(pair.0), json_encode_ingredient(pair.1))
  })
  |> json.object
}

fn json_encode_method_step(method_step: MethodStep) -> Json {
  json.object([#("step_text", json.string(method_step.step_text))])
}

fn json_encode_method_step_list(dict: Dict(Int, MethodStep)) -> Json {
  dict
  |> dict.to_list
  |> list.map(fn(pair: #(Int, MethodStep)) {
    #(int.to_string(pair.0), json_encode_method_step(pair.1))
  })
  |> json.object
}

pub fn decode_recipe(d: Dynamic) -> Result(Recipe, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode9(
      Recipe,
      optional_field("id", of: string),
      field("title", of: string),
      field("slug", of: string),
      field("cook_time", of: int),
      field("prep_time", of: int),
      field("serves", of: int),
      optional_field("tags", of: list(decode_tag)),
      optional_field(
        "ingredients",
        of: dict(decode_stringed_int, decode_ingredient),
      ),
      optional_field(
        "method_steps",
        of: dict(decode_stringed_int, decode_method_step),
      ),
    )
  io.debug(d)
  decoder(d)
}

fn decode_stringed_int(d: Dynamic) -> Result(Int, dynamic.DecodeErrors) {
  let decoder = dynamic.string
  decoder(d)
  |> result.map(int.parse)
  |> result.map(result.map_error(_, fn(_x) {
    [
      dynamic.DecodeError(
        expected: "a stringed int",
        found: "something else",
        path: [""],
      ),
    ]
  }))
  |> result.flatten
}

fn decode_stringed_bool(d: Dynamic) -> Result(Bool, dynamic.DecodeErrors) {
  dynamic.string(d)
  |> result.map(fn(a) {
    case a {
      "True" -> True
      _ -> False
    }
  })
}

fn decode_ingredient(d: Dynamic) -> Result(Ingredient, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode4(
      Ingredient,
      optional_field("name", of: string),
      optional_field("ismain", of: decode_stringed_bool),
      optional_field("quantity", of: string),
      optional_field("units", of: string),
    )
  decoder(d)
}

fn decode_tag(d: Dynamic) -> Result(Tag, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode2(Tag, field("name", of: string), field("value", of: string))
  decoder(d)
}

fn decode_method_step(d: Dynamic) -> Result(MethodStep, dynamic.DecodeErrors) {
  let decoder = dynamic.decode1(MethodStep, field("step_text", of: string))
  decoder(d)
}

fn decode_tag_option(d: Dynamic) -> Result(TagOption, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode3(
      TagOption,
      optional_field("id", of: string),
      field("name", of: string),
      field("options", of: list(of: string)),
    )
  decoder(d)
}

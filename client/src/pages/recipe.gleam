import components/nav_footer.{nav_footer}
import components/page_title.{page_title}
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/string
import gleam/uri
import lib/utils
import lustre/attribute.{
  attribute, checked, class, disabled, for, href, id, name, placeholder,
  selected, styles, type_, value,
}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{
  a, button, details, div, fieldset, form, input, label, legend, li, ol, option,
  section, select, span, summary, textarea,
}
import lustre/element/keyed
import lustre/event.{on_check, on_click, on_input}
import session.{
  type Ingredient, type MethodStep, type Recipe, type RecipeList, type Tag,
  type TagOption, Ingredient, MethodStep, Recipe, RecipeList, Tag,
  decode_recipe_with_inner_json,
}

//-MODEL---------------------------------------------

pub type RecipeDetailMsg {
  UserUpdatedRecipeTitle(String)
  UserUpdatedRecipeAuthor(String)
  UserUpdatedRecipeSource(String)
  UserUpdatedRecipePrepTimeHrs(String)
  UserUpdatedRecipePrepTimeMins(String)
  UserUpdatedRecipeCookTimeHrs(String)
  UserUpdatedRecipeCookTimeMins(String)
  UserUpdatedRecipeServes(String)
  UserAddedTagAtIndex(Int)
  UserRemovedTagAtIndex(Int)
  UserUpdatedTagNameAtIndex(Int, String)
  UserUpdatedTagValueAtIndex(Int, String)
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
  UserDeletedRecipe(Recipe)
  DbDeletedRecipe(String)
}

pub type RecipeDetail =
  Option(Recipe)

//-UPDATE---------------------------------------------

fn save_recipe(recipe: session.Recipe) -> Effect(RecipeDetailMsg) {
  let js_recipe =
    JsRecipe(
      id: option.unwrap(recipe.id, ""),
      title: recipe.title,
      slug: recipe.slug,
      cook_time: recipe.cook_time,
      prep_time: recipe.prep_time,
      serves: recipe.serves,
      author: option.unwrap(recipe.author, ""),
      source: option.unwrap(recipe.source, ""),
      tags: recipe.tags
        |> json.nullable(session.json_encode_tag_list)
        |> json.to_string,
      ingredients: recipe.ingredients
        |> json.nullable(session.json_encode_ingredient_list)
        |> json.to_string,
      method_steps: recipe.method_steps
        |> json.nullable(session.json_encode_method_step_list)
        |> json.to_string,
      shortlisted: option.unwrap(recipe.shortlisted, False),
    )
  use dispatch <- effect.from
  do_save_recipe(js_recipe)
  DbSavedUpdatedRecipe(recipe) |> dispatch
}

@external(javascript, ".././db.ts", "do_save_recipe")
fn do_save_recipe(recipe: JsRecipe) -> Nil

@external(javascript, ".././db.ts", "do_delete_recipe")
fn do_delete_recipe(id: String) -> Nil

type JsRecipe {
  JsRecipe(
    id: String,
    title: String,
    slug: String,
    cook_time: Int,
    prep_time: Int,
    serves: Int,
    author: String,
    source: String,
    tags: String,
    ingredients: String,
    method_steps: String,
    shortlisted: Bool,
  )
}

pub fn detail_update(
  model: RecipeDetail,
  msg: RecipeDetailMsg,
) -> #(RecipeDetail, Effect(RecipeDetailMsg)) {
  case msg {
    UserUpdatedRecipeTitle(newtitle) -> {
      case model {
        Some(a) -> {
          #(Some(Recipe(..a, title: newtitle)), effect.none())
        }
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedRecipeAuthor(newauthor) -> {
      case model {
        Some(a) -> #(Some(Recipe(..a, author: Some(newauthor))), effect.none())
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedRecipeSource(newsource) -> {
      case model {
        Some(a) -> #(Some(Recipe(..a, source: Some(newsource))), effect.none())
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
    UserUpdatedTagNameAtIndex(i, new_tag_name) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(..a, tags: {
              case a.tags {
                Some(x) ->
                  x
                  |> utils.dict_update(i, fn(_tag) {
                    Tag(name: new_tag_name, value: "")
                  })
                  |> Some
                _ ->
                  Some(
                    dict.from_list([#(0, Tag(name: new_tag_name, value: ""))]),
                  )
              }
            }),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserUpdatedTagValueAtIndex(i, new_tag_value) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(..a, tags: {
              a.tags
              |> option.map(
                utils.dict_update(_, i, fn(tag) {
                  Tag(..tag, value: new_tag_value)
                }),
              )
            }),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserAddedTagAtIndex(_i) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(..a, tags: case a.tags {
              Some(b) -> Some(dict.insert(b, dict.size(b), Tag("", "")))
              _ -> Some(dict.from_list([#(0, Tag("", ""))]))
            }),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserRemovedTagAtIndex(i) -> {
      case model {
        Some(a) -> #(
          Some(
            Recipe(..a, tags: {
              a.tags
              |> option.map(dict.drop(_, [i]))
              |> option.map(utils.dict_reindex)
            }),
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
            Recipe(..a, ingredients: {
              a.ingredients
              |> option.map(
                utils.dict_update(_, i, fn(ing) {
                  Ingredient(..ing, name: Some(new_ingredient_name))
                }),
              )
            }),
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
            Recipe(..a, ingredients: {
              a.ingredients
              |> option.map(
                utils.dict_update(_, i, fn(ing) {
                  Ingredient(..ing, ismain: Some(new_ingredient_ismain))
                }),
              )
            }),
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
            Recipe(..a, ingredients: {
              a.ingredients
              |> option.map(
                utils.dict_update(_, i, fn(ing) {
                  Ingredient(..ing, quantity: Some(new_ingredient_qty))
                }),
              )
            }),
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
            Recipe(..a, ingredients: {
              a.ingredients
              |> option.map(
                utils.dict_update(_, i, fn(ing) {
                  Ingredient(..ing, units: Some(new_ingredient_units))
                }),
              )
            }),
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
            Recipe(..a, ingredients: case a.ingredients {
              Some(b) ->
                Some(dict.insert(
                  b,
                  dict.size(b),
                  Ingredient(None, None, None, None, None),
                ))
              _ ->
                Some(
                  dict.from_list([
                    #(0, Ingredient(None, None, None, None, None)),
                  ]),
                )
            }),
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
            Recipe(..a, method_steps: case a.method_steps {
              Some(b) -> Some(dict.insert(b, dict.size(b), MethodStep("")))
              _ -> Some(dict.from_list([#(0, MethodStep(""))]))
            }),
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
            Recipe(..a, method_steps: {
              a.method_steps
              |> option.map(
                utils.dict_update(_, i, fn(_step) {
                  MethodStep(step_text: new_method_step)
                }),
              )
            }),
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }
    UserSavedUpdatedRecipe(recipe) -> {
      #(Some(recipe), {
        save_recipe(Recipe(..recipe, slug: utils.slugify(recipe.title)))
      })
    }
    //DbSavedUpdatedRecipe is handled in the layer above in mealstack_client.gleam
    DbSavedUpdatedRecipe(recipe) -> #(Some(recipe), effect.none())
    UserDeletedRecipe(recipe) -> #(None, {
      use dispatch <- effect.from
      case recipe.id {
        None -> DbDeletedRecipe("") |> dispatch
        Some(id) -> {
          do_delete_recipe(id)
          DbDeletedRecipe(id) |> dispatch
        }
      }
    })
    //DbDeletedRecipe is handled in the layer above in mealstack_client.gleam
    DbDeletedRecipe(_id) -> #(None, effect.none())
  }
}

pub fn list_update(
  model: session.RecipeList,
  msg: session.RecipeListMsg,
) -> #(RecipeList, Effect(session.RecipeListMsg)) {
  case msg {
    // we actually handle DbSubscriptionOpened in the top layer of the model in app.gleam
    session.DbSubscriptionOpened(_key, _callback) -> #(model, effect.none())
    session.DbSubscribedOneRecipe(jsdata) -> {
      let decoder = {
        use data <- decode.subfield(
          ["data", "recipes", "0"],
          decode_recipe_with_inner_json(),
        )
        decode.success(data)
      }
      let try_decode = decode.run(jsdata, decoder)
      let try_effect = case try_decode {
        Ok(recipe) -> {
          use dispatch <- effect.from
          session.DbRetrievedOneRecipe(recipe) |> dispatch
        }
        Error(e) -> {
          echo e
          effect.none()
        }
      }
      #(model, try_effect)
    }
    session.DbSubscribedRecipes(jsdata) -> {
      let decoder = {
        use data <- decode.subfield(
          ["data", "recipes"],
          decode.list(decode_recipe_with_inner_json()),
        )
        decode.success(data)
      }
      let try_decode = decode.run(jsdata, decoder)
      let try_effect = case try_decode {
        Ok(recipes) -> {
          use dispatch <- effect.from
          session.DbRetrievedRecipes(recipes) |> dispatch
        }
        Error(_) -> effect.none()
      }

      #(model, try_effect)
    }
    session.DbRetrievedRecipes(recipes) -> #(
      RecipeList(..model, recipes: recipes),
      effect.none(),
    )
    session.DbRetrievedOneRecipe(recipe) -> #(
      session.merge_recipe_into_model(recipe, model),
      effect.none(),
    )
    session.DbRetrievedTagOptions(tag_options) -> #(
      RecipeList(..model, tag_options: tag_options),
      effect.none(),
    )
    session.UserGroupedRecipeListByTag(tag) -> {
      case model.group_by {
        Some(session.GroupByTag(a)) if a == tag -> #(
          RecipeList(..model, group_by: None),
          effect.none(),
        )
        _ -> #(
          RecipeList(..model, group_by: Some(session.GroupByTag(tag))),
          effect.none(),
        )
      }
    }
    session.UserGroupedRecipeListByAuthor -> {
      case model.group_by {
        Some(session.GroupByAuthor) -> #(
          RecipeList(..model, group_by: None),
          effect.none(),
        )
        _ -> #(
          RecipeList(..model, group_by: Some(session.GroupByAuthor)),
          effect.none(),
        )
      }
    }
  }
}

//-VIEWS-------------------------------------------------------------

pub fn view_recipe_list(model: session.RecipeList) {
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
    ],
    [
      page_title(
        "Recipe Book",
        "underline-green  col-span-full md:col-span-[11]",
      ),
      div(
        [
          class(
            "subgrid-cols overflow-y-scroll col-span-full grid-rows-[repeat(12,_fit-content(100px))] gap-y-2",
          ),
        ],
        [
          div(
            [
              class(
                "col-span-full flex flex-wrap items-center justify-start gap-3",
              ),
            ],
            view_recipe_groupby(model),
          ),
          {
            case model.group_by {
              Some(session.GroupByTag(tag)) ->
                element.fragment(view_recipe_tag_groups(model.recipes, tag))
              Some(session.GroupByAuthor) ->
                element.fragment(view_recipe_author_groups(model.recipes))
              _ ->
                element.fragment(
                  list.map(model.recipes, view_recipe_summary(_, "")),
                )
            }
          },
        ],
      ),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a([href("/planner"), class("text-center")], [text("📅")]),
      ]),
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
        "grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
      id("create_recipe_form"),
      event.on_submit(fn(_x) { UserSavedUpdatedRecipe(recipe) }),
    ],
    [
      textarea(
        [
          id("page-title-input"),
          name("title"),
          class(
            "field-sizing-content mt-4 mr-2 [grid-area:header] col-span-full md:col-span-[11] placeholder:underline-blue underline-blue min-h-[56px] max-h-[140px] overflow-hidden px-0 pb-2 input-base input-focus resize-none font-bold italic text-ecru-white-950 bg-ecru-white-100",
          ),
          class(case string.length(recipe.title) {
            num if num > 30 -> "text-4xl md:text-5xl"
            num if num > 27 -> "text-5xl"
            num if num > 24 -> "text-5.5xl"
            _ -> "text-7xl"
          }),
          attribute("title", "recipe title"),
          on_input(UserUpdatedRecipeTitle),
        ],
        recipe.title,
      ),
      div([class("subgrid-cols gap-y-2 overflow-auto [grid-area:content]")], [
        div([class("subgrid-cols col-span-full items-baseline")], [
          div([class("col-start-1 col-span-6 md:col-span-5 flex gap-1  ")], [
            label([class("font-mono text-sm"), for("author")], [
              text("🧾"),
            ]),
            input([
              id("author"),
              class(
                "input-base pr-0.5 max-w-[15ch] md:max-w-none text-left text-base bg-ecru-white-100",
              ),
              type_("text"),
              name("author"),
              attribute("title", "author"),
              value(recipe.author |> option.unwrap("")),
              on_input(UserUpdatedRecipeAuthor),
            ]),
          ]),
          div([class("col-start-7 md:col-start-6 col-span-6 flex gap-1")], [
            label([class(" font-mono text-sm"), for("source")], [text("📗")]),
            input([
              id("source"),
              class(
                "max-w-[15ch] md:max-w-[58ch] bg-ecru-white-100 input-base input-focus pr-0.5 text-left text-base",
              ),
              type_("text"),
              name("source"),
              attribute("title", "source"),
              value(recipe.source |> option.unwrap("")),
              on_input(UserUpdatedRecipeSource),
            ]),
          ]),
        ]),
        fieldset(
          [
            class(
              "flex flex-row gap-2 col-span-full sm:col-span-5 sm:col-start-1",
            ),
          ],
          [
            fieldset([class("flex flex-wrap justify-between items-baseline")], [
              label([class("text-base"), for("prep_time")], [
                text("Prep:"),
              ]),

              div([class("after:content-['h'] after:text-base inline-block")], [
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
              ]),
              div([class("after:content-['m'] after:text-base inline-block")], [
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
              ]),
            ]),
            fieldset([class("flex flex-wrap justify-between items-baseline")], [
              label([class("text-base"), for("cook_time")], [
                text("Cook:"),
              ]),
              div([class("after:content-['h'] after:text-base inline-block")], [
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
              ]),
              div([class("after:content-['m'] after:text-base inline-block")], [
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
              ]),
            ]),
            fieldset([class("flex flex-wrap justify-between items-baseline")], [
              label([class("text-base "), for("serves")], [
                text("Serves:"),
              ]),
              div([class("inline-block")], [
                input([
                  id("serves"),
                  class(
                    "pr-0.5 mr-2 sm:mr-4 col-span-3 input-base input-focus w-[3ch] text-right text-base bg-ecru-white-100",
                  ),
                  type_("number"),
                  name("serves"),
                  value(recipe.serves |> int.to_string),
                  on_input(UserUpdatedRecipeServes),
                ]),
              ]),
            ]),
          ],
        ),
        fieldset(
          [
            class(
              "sm:ml-1 col-span-full content-start sm:col-start-6 sm:col-span-7 sm:mt-2 flex flex-wrap items-baseline gap-3",
            ),
          ],
          [
            case recipe.tags, option.map(recipe.tags, dict.is_empty) {
              Some(tags), Some(False) -> {
                let children =
                  tags
                  |> dict.to_list
                  |> list.sort(by: fn(a, b) {
                    int.compare(pair.first(a), pair.first(b))
                  })
                  |> list.map(fn(a) {
                    #(
                      int.to_string(pair.first(a)),
                      tag_input(
                        tag_options,
                        pair.first(a),
                        Some(pair.second(a)),
                      ),
                    )
                  })
                keyed.element("div", [class("contents")], children)
              }
              _, _ ->
                span(
                  [class("cursor-pointer"), on_click(UserAddedTagAtIndex(0))],
                  [
                    text("🏷️"),
                  ],
                )
            },
          ],
        ),
        fieldset(
          [
            class(
              "col-span-full mr-2 p-2 h-[fit-content] border-ecru-white-950 border-[1px] rounded-[1px] sm:col-span-5 [box-shadow:1px_1px_0_#9edef1]",
            ),
          ],
          [
            legend([class("mx-2 px-1 text-base ")], [text("Ingredients")]),
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
                keyed.element("div", [class("contents")], children)
              }
              _ -> ingredient_input(0, None)
            },
          ],
        ),
        fieldset(
          [
            class(
              "col-span-full mr-2 p-2 gap-2 flex flex-col h-[fit-content] border-ecru-white-950 border-[1px] rounded-[1px] sm:col-span-7 [box-shadow:1px_1px_0_#9edef1]",
            ),
          ],
          [
            legend([class("mx-2 px-1 text-base ")], [text("Method")]),
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
                keyed.element("div", [class("contents")], children)
              }
              _ -> ingredient_input(0, None)
            },
          ],
        ),
      ]),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a([href("/recipes/" <> recipe.slug), class("text-center")], [
          text("❎"),
        ]),
        button(
          [
            type_("button"),
            on_click(UserDeletedRecipe(recipe)),
            class(""),
          ],
          [text("🗑️")],
        ),
        button([type_("submit"), class("")], [text("💾")]),
      ]),
    ],
  )
}

pub fn view_recipe_detail(recipe: Recipe) {
  element.fragment([
    section(
      [
        class(
          "grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
        ),
      ],
      [
        page_title(
          recipe.title,
          "underline-green [grid-area:header] col-span-full md:col-span-[11]",
        ),
        div([class("subgrid-cols gap-y-2 overflow-auto [grid-area:content]")], [
          case recipe.author, recipe.source {
            None, None -> element.none()
            _, _ ->
              fieldset(
                [
                  class("flex gap-1 items-baseline col-span-full sm:col-span-5"),
                ],
                list.flatten([
                  case recipe.author {
                    Some(a) -> [
                      html.span([class("text-sm")], [text("🧾")]),
                      html.span(
                        [
                          class("text-base"),
                          {
                            case string.length(a) > 19 {
                              True ->
                                class(
                                  "w-["
                                  <> int.to_string(string.length(a))
                                  <> "]",
                                )
                              _ -> class("w-[19ch]")
                            }
                          },
                        ],
                        [text(a)],
                      ),
                    ]
                    _ -> []
                  },
                  case recipe.source {
                    Some(source) -> [
                      html.span([class("text-sm")], [text("📗")]),
                      case uri.parse(source) {
                        Ok(uri) ->
                          html.a([class("text-base"), href(source)], [
                            text(option.unwrap(uri.host, uri.path)),
                          ])
                        Error(_) ->
                          html.span([class("text-base")], [text(source)])
                      },
                    ]
                    _ -> []
                  },
                ]),
              )
          },
          fieldset(
            [
              class(
                "flex flex-row gap-2 col-span-full sm:col-span-5 sm:col-start-1",
              ),
            ],
            [
              fieldset([class("flex flex-wrap justify-start items-baseline")], [
                label([for("prep_time"), class("text-base")], [text("Prep:")]),
                div([class("text-lg ml-2")], [
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
              ]),
              fieldset([class("flex flex-wrap justify-start items-baseline")], [
                label([for("cook_time"), class("text-base")], [text("Cook:")]),
                div([class("text-lg ml-2")], [
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
              ]),
              fieldset([class("flex flex-wrap justify-start items-baseline")], [
                label([for("cook_time"), class("text-base")], [text("Serves:")]),
                div([class("mr-2 sm:mr-4 ml-2 text-lg")], [
                  text(int.to_string(recipe.serves)),
                ]),
              ]),
            ],
          ),
          case recipe.tags {
            Some(tags) -> {
              let children =
                tags
                |> dict.to_list
                |> list.sort(by: fn(a, b) {
                  int.compare(pair.first(a), pair.first(b))
                })
                |> list.map(fn(a) {
                  #(int.to_string(pair.first(a)), view_tag(pair.second(a)))
                })
              fieldset(
                [
                  class(
                    "col-span-full content-start flex flex-wrap items-baseline gap-3
                      sm:ml-1 sm:col-start-6 sm:col-span-7 sm:mt-2",
                  ),
                ],
                [keyed.element("div", [class("contents")], children)],
              )
            }
            _ -> element.none()
          },
          fieldset(
            [
              class(
                "col-span-full text-base p-2 mr-2 h-[fit-content] border-ecru-white-950 border-[1px] rounded-[1px]
                sm:row-start-3 sm:col-span-5 [box-shadow:1px_1px_0_#a3d2ab]",
              ),
            ],
            [
              legend([class("mx-2 px-1 text-base")], [text("Ingredients")]),
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
                  keyed.element("div", [class("contents")], children)
                }
                _ -> element.none()
              },
            ],
          ),
          fieldset(
            [
              class(
                "flex justify-start flex-wrap col-span-full p-2 mr-2 h-[fit-content]  border-ecru-white-950 border-[1px] rounded-[1px]  sm:col-span-7 sm:row-start-3   [box-shadow:1px_1px_0_#a3d2ab]",
              ),
            ],
            [
              legend([class("mx-2 px-1 text-base")], [text("Method")]),
              ol(
                [
                  class(
                    "flex flex-wrap justify-start gap-2 w-full list-decimal marker:text-sm marker:font-mono text-base items-baseline col-span-full",
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
                      keyed.element("div", [class("contents")], children)
                    }
                    _ -> element.none()
                  },
                ],
              ),
            ],
          ),
        ]),
        nav_footer([
          a([href("/"), class("text-center")], [text("🏠")]),
          a([href("/recipes"), class("text-center")], [text("📖")]),
          a(
            [
              href("/recipes/" <> recipe.slug <> "/edit"),
              class("text-center"),
            ],
            [text("✏️")],
          ),
        ]),
      ],
    ),
  ])
}

//-COMPONENTS--------------------------------------------------

pub fn view_recipe_groupby(model: session.RecipeList) {
  let tags =
    model.recipes
    |> list.map(fn(x) {
      case x.tags {
        Some(a) -> list.map(dict.values(a), fn(x) { x.name })
        _ -> []
      }
    })
    |> list.flatten
    |> list.unique
  list.append(
    list.map(tags, fn(a) {
      button(
        [
          class(
            "font-mono bg-ecru-white-100 border border-ecru-white-950 px-1 cursor-pointer text-xs",
          ),
          on_click(session.UserGroupedRecipeListByTag(a)),
        ],
        [text(a)],
      )
    }),
    [
      button(
        [
          class(
            "font-mono bg-ecru-white-100 border border-ecru-white-950 px-1 cursor-pointer text-xs",
          ),
          on_click(session.UserGroupedRecipeListByAuthor),
        ],
        [text("Author")],
      ),
    ],
  )
}

pub fn view_recipe_tag_groups(recipes: List(session.Recipe), tag: String) {
  let groups =
    list.group(recipes, fn(a) {
      case a.tags {
        Some(a) ->
          list.filter(dict.values(a), fn(b) { b.name == tag })
          |> list.map(fn(x) { x.value })
          |> list.first
          |> result.unwrap("")
        _ -> "none"
      }
    })
  groups
  |> dict.map_values(fn(k, v) {
    details(
      [
        class(
          "col-span-full subgrid-cols gap-y-2 details-content:[display:grid] details-content:gap-y-2 details-content:[grid-column:1/-1] details-content:[grid-template-columns:subgrid]",
        ),
      ],
      [
        summary(
          [
            class(
              "flex gap-2 col-span-full border-b border-b-gray-200 text-base cursor-pointer marker:content-none",
            ),
            case k {
              "none" -> class("italic")
              _ -> attribute.none()
            },
          ],
          [text(k)],
        ),
        element.fragment(list.map(v, view_recipe_summary(_, "text-lg"))),
      ],
    )
  })
  |> dict.to_list
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
  |> list.map(pair.second)
}

pub fn view_recipe_author_groups(recipes: List(session.Recipe)) {
  let groups =
    list.group(recipes, fn(a) {
      case a.author {
        Some(a) -> a
        _ -> "none"
      }
    })
  groups
  |> dict.map_values(fn(k, v) {
    details(
      [
        class(
          "col-span-full subgrid-cols gap-y-2 details-content:[display:grid] details-content:gap-y-2 details-content:[grid-column:1/-1] details-content:[grid-template-columns:subgrid]",
        ),
      ],
      [
        summary(
          [
            class(
              "flex gap-2 col-span-full border-b border-b-gray-200 text-base cursor-pointer marker:content-none",
            ),
          ],
          [text(k)],
        ),
        element.fragment(list.map(v, view_recipe_summary(_, "text-lg"))),
      ],
    )
  })
  |> dict.values
}

fn view_recipe_summary(recipe: Recipe, class_props: String) {
  div(
    [
      class("col-span-full text-xl subgrid-cols border-b border-b-gray-200"),
      class(class_props),
    ],
    [
      a(
        [
          href(string.append("/recipes/", recipe.slug)),
          class("subgrid-cols col-span-full grid-flow-row-dense"),
        ],
        [
          span([class("col-span-10")], [text(recipe.title)]),
          span([class("text-sm col-start-12")], [
            text(case recipe.prep_time + recipe.cook_time {
              n if n > 60 ->
                int.floor_divide(n, 60)
                |> result.unwrap(0)
                |> int.to_string
                <> "h"
                <> case n % 60 {
                  0 -> ""
                  rem if rem < 10 -> "0" <> int.to_string(rem)
                  _ -> int.to_string(n % 60)
                }
              _ ->
                { recipe.prep_time + recipe.cook_time } |> int.to_string()
                <> "m"
            }),
          ]),
        ],
      ),
    ],
  )
}

fn view_ingredient(ingredient: Ingredient) {
  let bold = case ingredient.ismain {
    Some(True) -> " font-bold"
    _ -> ""
  }
  div([class("flex justify-start items-baseline")], [
    div([class("flex-grow-[2] text-left flex text-lg justify-start" <> bold)], [
      option.unwrap(option.map(ingredient.name, text), element.none()),
    ]),
    div([class("col-span-1 text-sm")], [
      option.unwrap(option.map(ingredient.quantity, text), element.none()),
    ]),
    div([class("col-span-1 text-sm")], [
      option.unwrap(option.map(ingredient.units, text), element.none()),
    ]),
  ])
}

fn view_method_step(method_step: MethodStep) {
  li(
    [
      class(
        "w-full justify-self-start list-decimal text-lg text-left ml-8 pr-2",
      ),
    ],
    [text(method_step.step_text)],
  )
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
  let update_name_with_index = fn(index) { UserUpdatedTagNameAtIndex(index, _) }
  let update_value_with_index = fn(index) {
    UserUpdatedTagValueAtIndex(index, _)
  }

  let tagnames = list.map(available_tags, fn(x) { x.name })
  let tag = option.unwrap(input, Tag("", ""))
  fieldset(
    [
      id("tag-input-" <> int.to_string(index)),
      class("flex col-span-6 sm:col-span-4 min-w-0"),
    ],
    [
      select(
        [
          styles([
            case string.length(tag.name) {
              num if num > 0 -> #("width", int.to_string(num + 1) <> "ch")
              _ -> #("width", "5ch")
            },
          ]),
          class(
            "inline bg-ecru-white-100 col-span-4 row-span-1 pl-1 p-0 text-xs font-mono custom-select",
          ),
          id("tag-name-selector"),
          name("tag-name-" <> int.to_string(index)),
          value(tag.name),
          on_input(update_name_with_index(index)),
        ],
        list.append(
          [
            option(
              [
                class(
                  "text-xs font-mono custom-select input-focus bg-ecru-white-100",
                ),
                attribute("hidden", ""),
                disabled(True),
                value(""),
                selected(string.is_empty(tag.name)),
              ],
              "",
            ),
          ],
          list.map(tagnames, fn(tag_name) {
            option(
              [
                value(tag_name),
                selected(tag_name == tag.name),
                class(
                  "text-xs font-mono custom-select input-focus bg-ecru-white-50",
                ),
              ],
              tag_name,
            )
          }),
        ),
      ),
      {
        select(
          [
            styles([
              case string.length(tag.value) {
                num if num > 0 -> #("width", int.to_string(num + 1) <> "ch")
                _ -> #("width", "5ch")
              },
            ]),
            class(
              "inline bg-ecru-white-50 col-span-4 row-span-1 pl-1 p-0 text-xs font-mono custom-select",
            ),
            on_input(update_value_with_index(index)),
            value(tag.value),
          ],
          list.append(
            [
              option(
                [
                  class(
                    "text-xs font-mono custom-select input-focus bg-ecru-white-50",
                  ),
                  attribute("hidden", ""),
                  disabled(True),
                  value(""),
                  selected(string.is_empty(tag.value)),
                ],
                "",
              ),
            ],
            {
              let is_selected = fn(x: TagOption) { x.name == tag.name }
              let options = fn(x: TagOption) {
                list.map(x.options, fn(a) {
                  option(
                    [
                      value(a),
                      selected(a == tag.value),
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
            },
          ),
        )
      },
      button(
        [
          class("col-span-1 my-1 text-ecru-white-950 text-xs cursor-pointer"),
          id("remove-tag-input"),
          type_("button"),
          on_click(UserRemovedTagAtIndex(index)),
        ],
        [text("➖")],
      ),
      button(
        [
          class("col-span-1 my-1 text-ecru-white-950 text-xs cursor-pointer"),
          id("add-tag-input"),
          type_("button"),
          on_click(UserAddedTagAtIndex(index)),
        ],
        [text("➕")],
      ),
    ],
  )
}

fn ingredient_input(index: Int, ingredient: Option(Ingredient)) {
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

  div([class("my-1 w-full flex justify-between items-baseline  text-base")], [
    input([
      attribute("aria-label", "Enter ingredient name"),
      name("ingredient-name-" <> int.to_string(index)),
      type_("text"),
      placeholder("Ingredient"),
      class(
        "text-base input-base max-w-[20ch] md:max-w-[34ch] input-focus bg-ecru-white-100",
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
        class("pt-0.5 max-w-[3ch] text-sm input-focus bg-ecru-white-100"),
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
        class("pt-0.5 max-w-[3ch] text-sm mr-0 input-focus bg-ecru-white-100"),
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
  ])
}

fn method_step_input(index: Int, method_step: Option(MethodStep)) {
  let update_methodstep_at_index = fn(index) {
    UserUpdatedMethodStepAtIndex(index, _)
  }
  div([class("flex w-full items-baseline col-span-full px-1 mb-1 text-base")], [
    label([class("font-mono text-sm")], [
      text(index + 1 |> int.to_string <> "."),
    ]),
    textarea(
      [
        name("method-step-" <> index |> int.to_string),
        id("method-step-" <> index |> int.to_string),
        class(
          "mx-3 bg-ecru-white-100 w-full input-focus text-base resize-none [field-sizing:content]",
        ),
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
        class("text-ecru-white-950 text-xs cursor-pointer"),
        type_("button"),
        id("remove-ingredient-input"),
        on_click(UserRemovedMethodStepAtIndex(index)),
      ],
      [text("➖")],
    ),
    button(
      [
        class("text-ecru-white-950 text-xs cursor-pointer"),
        type_("button"),
        id("add-ingredient-input"),
        on_click(UserAddedMethodStepAtIndex(index)),
      ],
      [text("➕")],
    ),
  ])
}
//-TYPES-------------------------------------------------------------

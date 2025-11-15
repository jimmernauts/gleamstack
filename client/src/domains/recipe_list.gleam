import components/nav_footer.{nav_footer}
import components/page_title.{page_title}
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/string
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element.{text}
import lustre/element/html.{a, button, details, div, li, section, span, summary}
import lustre/event.{on_click}
import shared/codecs.{decode_recipe_with_inner_json}
import shared/types.{type Recipe, type TagOption}

//-MODEL-------------------------------------------------------------

pub type RecipeListMsg {
  RecipeListSubscriptionOpened(String, fn() -> Nil)
  DbSubscribedOneRecipe(Dynamic)
  DbRetrievedOneRecipe(Recipe)
  DbSubscribedRecipes(Dynamic)
  DbRetrievedRecipes(List(Recipe))
  DbRetrievedTagOptions(List(TagOption))
  UserGroupedRecipeListByTag(String)
  UserGroupedRecipeListByAuthor
}

pub type RecipeListGroupBy {
  GroupByTag(String)
  GroupByAuthor
}

pub type RecipeListModel {
  RecipeListModel(
    recipes: List(Recipe),
    tag_options: List(TagOption),
    group_by: Option(RecipeListGroupBy),
  )
}

//-UPDATE------------------------------------------------------------

pub fn list_update(
  model: RecipeListModel,
  msg: RecipeListMsg,
) -> #(RecipeListModel, Effect(RecipeListMsg)) {
  case msg {
    // SubscriptionOpened is handled in the layer above
    RecipeListSubscriptionOpened(_key, _callback) -> #(model, effect.none())
    DbSubscribedOneRecipe(jsdata) -> {
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
          DbRetrievedOneRecipe(recipe) |> dispatch
        }
        Error(e) -> {
          echo e
          effect.none()
        }
      }
      #(model, try_effect)
    }
    DbSubscribedRecipes(jsdata) -> {
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
          DbRetrievedRecipes(recipes) |> dispatch
        }
        Error(_) -> effect.none()
      }

      #(model, try_effect)
    }
    DbRetrievedRecipes(recipes) -> #(
      RecipeListModel(..model, recipes: recipes),
      effect.none(),
    )
    DbRetrievedOneRecipe(recipe) -> #(
      merge_recipe_into_model(recipe, model),
      effect.none(),
    )
    DbRetrievedTagOptions(tag_options) -> #(
      RecipeListModel(..model, tag_options: tag_options),
      effect.none(),
    )
    UserGroupedRecipeListByTag(tag) -> {
      case model.group_by {
        Some(GroupByTag(a)) if a == tag -> #(
          RecipeListModel(..model, group_by: None),
          effect.none(),
        )
        _ -> #(
          RecipeListModel(..model, group_by: Some(GroupByTag(tag))),
          effect.none(),
        )
      }
    }
    UserGroupedRecipeListByAuthor -> {
      case model.group_by {
        Some(GroupByAuthor) -> #(
          RecipeListModel(..model, group_by: None),
          effect.none(),
        )
        _ -> #(
          RecipeListModel(..model, group_by: Some(GroupByAuthor)),
          effect.none(),
        )
      }
    }
  }
}

pub fn merge_recipe_into_model(
  recipe: Recipe,
  model: RecipeListModel,
) -> RecipeListModel {
  RecipeListModel(
    ..model,
    recipes: model.recipes
      |> list.map(fn(a) { #(a.id, a) })
      |> dict.from_list
      |> dict.merge(dict.from_list([#(recipe.id, recipe)]))
      |> dict.values(),
  )
}

//-VIEW--------------------------------------------------------------

pub fn view_recipe_list(model: RecipeListModel) {
  section(
    [
      class(
        "h-env-screen grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
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
            "subgrid-cols grid-rows-[repeat(12,minmax(min-content,35px))] overflow-y-scroll  col-span-full gap-y-2",
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
              Some(GroupByTag(tag)) ->
                element.fragment(view_recipe_tag_groups(model.recipes, tag))
              Some(GroupByAuthor) ->
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

pub fn view_recipe_groupby(model: RecipeListModel) {
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
          on_click(UserGroupedRecipeListByTag(a)),
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
          on_click(UserGroupedRecipeListByAuthor),
        ],
        [text("Author")],
      ),
    ],
  )
}

pub fn view_recipe_tag_groups(recipes: List(Recipe), tag: String) {
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
          "col-span-full subgrid-cols gap-y-2 details-content:grid details-content:gap-y-2 details-content:col-span-full details-content:grid-cols-subgrid",
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

pub fn view_recipe_author_groups(recipes: List(Recipe)) {
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
          "col-span-full subgrid-cols gap-y-2 details-content:grid details-content:gap-y-2 details-content:col-span-full details-content:grid-cols-subgrid",
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

fn view_ingredient(ingredient: types.Ingredient) {
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

fn view_method_step(method_step: types.MethodStep) {
  li(
    [
      class(
        "w-full justify-self-start list-decimal text-lg text-left ml-8 pr-2",
      ),
    ],
    [text(method_step.step_text)],
  )
}

fn view_tag(tag: types.Tag) {
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

//-DATABASE----------------------------------------------------------

pub fn get_one_recipe_by_slug(slug: String) -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_one_recipe_by_slug(slug)
  |> promise.map(decode.run(_, decode_recipe_with_inner_json()))
  |> promise.map(result.map(_, DbRetrievedOneRecipe))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "../db.ts", "do_get_one_recipe_by_slug")
fn do_get_one_recipe_by_slug(slug: String) -> Promise(Dynamic)

pub fn subscribe_to_one_recipe_by_slug(slug: String) -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_subscribe_to_one_recipe_by_slug(slug, fn(data) {
    data
    |> DbSubscribedOneRecipe
    |> dispatch
  })
  |> RecipeListSubscriptionOpened(slug, _)
  |> dispatch
  Nil
}

@external(javascript, "../db.ts", "do_subscribe_to_one_recipe_by_slug")
fn do_subscribe_to_one_recipe_by_slug(
  slug: String,
  callback: fn(a) -> Nil,
) -> fn() -> Nil

pub fn get_recipes() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_recipes()
  |> promise.map(decode.run(_, decode.list(decode_recipe_with_inner_json())))
  |> promise.map(result.map(_, DbRetrievedRecipes))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "../db.ts", "do_get_recipes")
fn do_get_recipes() -> Promise(Dynamic)

pub fn get_tag_options() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_get_tagoptions()
  |> promise.map(decode.run(_, decode.list(codecs.decode_tag_option())))
  |> promise.map(result.map(_, DbRetrievedTagOptions))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "../db.ts", "do_get_tagoptions")
fn do_get_tagoptions() -> Promise(Dynamic)

pub fn subscribe_to_recipe_summaries() -> Effect(RecipeListMsg) {
  use dispatch <- effect.from
  do_subscribe_to_recipe_summaries(fn(data) {
    data
    |> DbSubscribedRecipes
    |> dispatch
  })
  |> RecipeListSubscriptionOpened("recipes", _)
  |> dispatch
  Nil
}

@external(javascript, "../db.ts", "do_subscribe_to_recipe_summaries")
fn do_subscribe_to_recipe_summaries(callback: fn(a) -> Nil) -> fn() -> Nil

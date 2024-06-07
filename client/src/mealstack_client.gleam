import components/page_title.{page_title}
import gleam/dynamic.{
  type Dynamic, bool, field, int, list, optional_field, string,
}
import gleam/int.{floor_divide, to_string}
import gleam/io.{debug}
import gleam/javascript/array.{type Array}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string.{append}
import gleam/uri.{type Uri}
import lustre
import lustre/attribute.{class, for, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment, none, text}
import lustre/element/html.{
  a, div, fieldset, label, legend, li, nav, ol, section, span,
}
import modem
import pages/edit_recipe.{edit_recipe}
import pages/view_recipe.{view_recipe}
import tardis
import types.{
  type Model, type Msg, CacheUpdatedMessage, EditRecipe, Home, Model,
  OnRouteChange, RecipeBook, RecipeDetail, SaveUpdatedRecipe,
}

// MAIN ------------------------------------------------------------------------

// WITHOUT DEBUGGER

// pub fn main() {
//  let app = lustre.application(init, update, view)
//  let assert Ok(_) = lustre.start(app, "#app", Nil)
// }

// WITH DEBUGGER

pub fn main() {
  let assert Ok(main) = tardis.single("main")

  lustre.application(init, update, view)
  |> tardis.wrap(with: main)
  |> lustre.start("#app", Nil)
  |> tardis.activate(with: main)
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model(current_route: Home, current_recipe: None, recipes: []),
    modem.init(on_route_change),
  )
}

// MODEL -----------------------------------------------------------------------

fn decode_recipe(d: Dynamic) -> Result(types.Recipe, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode9(
      types.Recipe,
      optional_field("id", of: string),
      field("title", of: string),
      field("slug", of: string),
      field("cook_time", of: int),
      field("prep_time", of: int),
      field("serves", of: int),
      optional_field("tags", of: list(decode_tag)),
      optional_field("ingredients", of: list(decode_ingredient)),
      optional_field("method_steps", of: list(decode_method_step)),
    )
  decoder(d)
}

fn decode_ingredient(
  d: Dynamic,
) -> Result(types.Ingredient, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode4(
      types.Ingredient,
      optional_field("name", of: string),
      optional_field("ismain", of: bool),
      optional_field("quantity", of: string),
      optional_field("units", of: string),
    )
  decoder(d)
}

fn decode_tag(d: Dynamic) -> Result(types.Tag, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode2(
      types.Tag,
      field("name", of: string),
      field("value", of: string),
    )
  decoder(d)
}

fn decode_method_step(
  d: Dynamic,
) -> Result(types.MethodStep, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode1(types.MethodStep, field("step_text", of: string))
  decoder(d)
}

fn decode_tag_option(
  d: Dynamic,
) -> Result(types.TagOption, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode3(
      types.TagOption,
      optional_field("id", of: string),
      field("name", of: string),
      field("options", of: list(of: string)),
    )
  decoder(d)
}

// UPDATE ----------------------------------------------------------------------

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(RecipeBook) -> #(
      Model(..model, current_route: RecipeBook),
      get_recipes(),
    )
    OnRouteChange(RecipeDetail(slug: slug)) -> #(
      Model(
        ..model,
        current_route: RecipeDetail(slug: slug),
        current_recipe: lookup_recipe_by_slug(model, slug),
      ),
      effect.none(),
    )
    OnRouteChange(EditRecipe(slug: slug)) -> #(
      Model(
        ..model,
        current_route: EditRecipe(slug: slug),
        current_recipe: lookup_recipe_by_slug(model, slug),
      ),
      effect.none(),
    )
    OnRouteChange(route) -> #(
      Model(..model, current_route: route),
      effect.none(),
    )
    CacheUpdatedMessage(recipes) -> #(
      Model(..model, recipes: recipes),
      effect.none(),
    )
    // TODO ACTUALLY SAVE THE RECIPE PROPERLY
    SaveUpdatedRecipe(recipe) -> #(
      Model(..model, recipes: [recipe, ..model.recipes]),
      effect.none(),
    )
  }
}

fn lookup_recipe_by_slug(model: Model, slug: String) -> Option(types.Recipe) {
  option.from_result(list.find(model.recipes, fn(a) { a.slug == slug }))
}

fn on_route_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    ["recipes", slug, "edit"] -> OnRouteChange(EditRecipe(slug: slug))
    ["recipes", slug] -> OnRouteChange(RecipeDetail(slug: slug))
    ["recipes"] -> OnRouteChange(RecipeBook)
    _ -> OnRouteChange(Home)
  }
}

fn get_recipes() -> Effect(Msg) {
  use dispatch <- effect.from
  do_get_recipes()
  |> promise.map(array.to_list)
  |> promise.map(list.map(_, decode_recipe))
  |> promise.map(result.all)
  |> promise.map(result.map(_, CacheUpdatedMessage))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, "./db.ts", "do_get_recipes")
fn do_get_recipes() -> Promise(Array(Dynamic))

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let page = case model.current_route {
    Home -> view_home()
    RecipeBook -> view_recipe_list(model)
    RecipeDetail(slug: _slug) -> lookup_and_view_recipe(model.current_recipe)
    EditRecipe(slug: _slug) -> lookup_and_edit_recipe(model.current_recipe)
  }
  view_base(page)
}

fn view_base(children) {
  html.main(
    [
      class(
        "grid ml-1 mr-2 gap-2
    2xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_105ch_[main-end]_3fr_[full-end]_1fr_[end]]
    xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95ch_[main-end]_3fr_[full-end]_1fr_[end]]
    lg:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_85ch_[main-end]_3fr_[full-end]_1fr_[end]]
    md:grid-cols-[[start_full-start]_1fr_[main-start]_85ch_[main-end]_1fr_[full-end_end]]
    grid-cols-[[start_full-start_main-start]_100%_[main-end_full-end_end]]
    min-h-[90vh]",
      ),
    ],
    [children],
  )
}

fn view_home() {
  section([class("grid-cols-12 col-start-[main-start]")], [
    page_title(
      "Mealstack",
      "text-9xl placeholder:underline-pink underline-pink col-span-full xxs:col-span-11",
    ),
    nav(
      [
        class(
          "subgrid-cols my-6 gap-y-12 col-span-full text-6xl mx-2 font-mono",
        ),
      ],
      [
        a(
          [
            class(
              "flex items-baseline col-span-full sm:col-span-6 justify-between pr-4",
            ),
            href("/planner"),
          ],
          [
            span([class("underline-orange")], [text("Plan")]),
            span([class("text-5xl")], [text("📅")]),
          ],
        ),
        a(
          [
            class(
              "flex items-baseline col-span-full sm:col-span-6 justify-between pr-4",
            ),
            href("/recipes"),
          ],
          [
            span([class("underline-green")], [text("Book")]),
            span([class("text-5xl")], [text("📑")]),
          ],
        ),
        a(
          [
            class(
              "flex items-baseline col-span-full sm:col-span-6 justify-between pr-4",
            ),
            href("/recipes/new"),
          ],
          [
            span([class("underline-blue")], [text("New")]),
            span([class("text-5xl")], [text("📝")]),
          ],
        ),
        a(
          [
            class(
              "flex items-baseline col-span-full sm:col-span-6 justify-between pr-4",
            ),
            href("/import"),
          ],
          [
            span([class("underline-yellow")], [text("Import")]),
            span([class("text-5xl")], [text("📩")]),
          ],
        ),
      ],
    ),
  ])
}

fn view_recipe_list(model: Model) {
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

fn view_recipe_summary(recipe: types.Recipe) {
  div(
    [
      class(
        "col-span-full flex flex-wrap items-baseline justify-start my-1 text-base",
      ),
    ],
    [
      div([class("text-xl flex flex-nowrap gap-1 my-1 ml-2 items-baseline")], [
        a([href(append("/recipes/", recipe.slug))], [
          span([], [text(recipe.title)]),
          span([class("text-sm")], [
            text(" • "),
            text(
              floor_divide({ recipe.prep_time + recipe.cook_time }, 60)
              |> result.unwrap(0)
              |> to_string(),
            ),
            text("h"),
            text(
              { recipe.prep_time + recipe.cook_time }
              |> to_string(),
            ),
            text("m"),
          ]),
        ]),
      ]),
    ],
  )
}

fn lookup_and_view_recipe(maybe_recipe: Option(types.Recipe)) {
  case maybe_recipe {
    Some(a) -> view_recipe(a)
    _ -> page_title("Recipe not found", "")
  }
}

fn lookup_and_edit_recipe(maybe_recipe: Option(types.Recipe)) {
  case maybe_recipe {
    Some(a) -> edit_recipe(a)
    _ -> page_title("Recipe not found", "")
  }
}

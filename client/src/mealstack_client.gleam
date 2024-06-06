import components/view_title.{view_title}
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
import lustre/attribute.{class, for, href, id, name, type_, value}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment, none, text}
import lustre/element/html.{
  a, div, fieldset, form, input, label, legend, li, nav, ol, section, span,
  textarea,
}
import modem
import tardis

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

type Model {
  Model(
    current_route: Route,
    current_recipe: Option(Recipe),
    recipes: List(Recipe),
  )
}

type Route {
  Home
  RecipeDetail(slug: String)
  RecipeBook
  EditRecipe(slug: Option(String))
}

type Recipe {
  Recipe(
    id: Option(String),
    title: String,
    slug: String,
    cook_time: Int,
    prep_time: Int,
    serves: Int,
    tags: Option(List(Tag)),
    ingredients: Option(List(Ingredient)),
    method_steps: Option(List(MethodStep)),
  )
}

fn decode_recipe(d: Dynamic) -> Result(Recipe, dynamic.DecodeErrors) {
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
      optional_field("ingredients", of: list(decode_ingredient)),
      optional_field("method_steps", of: list(decode_method_step)),
    )
  decoder(d)
}

type Ingredient {
  Ingredient(
    name: Option(String),
    ismain: Option(Bool),
    quantity: Option(String),
    units: Option(String),
  )
}

fn decode_ingredient(d: Dynamic) -> Result(Ingredient, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode4(
      Ingredient,
      optional_field("name", of: string),
      optional_field("ismain", of: bool),
      optional_field("quantity", of: string),
      optional_field("units", of: string),
    )
  decoder(d)
}

type Tag {
  Tag(name: String, value: String)
}

fn decode_tag(d: Dynamic) -> Result(Tag, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode2(Tag, field("name", of: string), field("value", of: string))
  decoder(d)
}

type MethodStep {
  MethodStep(step_text: String)
}

fn decode_method_step(d: Dynamic) -> Result(MethodStep, dynamic.DecodeErrors) {
  let decoder = dynamic.decode1(MethodStep, field("step_text", of: string))
  decoder(d)
}

type TagOption {
  TagOption(id: Option(String), name: String, options: List(String))
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

// UPDATE ----------------------------------------------------------------------

pub opaque type Msg {
  OnRouteChange(Route)
  CacheUpdatedMessage(List(Recipe))
}

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
    OnRouteChange(EditRecipe(None)) -> #(
      Model(..model, current_route: EditRecipe(None), current_recipe: None),
      effect.none(),
    )
    OnRouteChange(EditRecipe(slug: Some(slug))) -> #(
      Model(
        ..model,
        current_route: EditRecipe(slug: Some(slug)),
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
  }
}

fn lookup_recipe_by_slug(model: Model, slug: String) -> Option(Recipe) {
  option.from_result(list.find(model.recipes, fn(a) { a.slug == slug }))
}

fn on_route_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    ["recipes", "new"] -> OnRouteChange(EditRecipe(None))
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
    RecipeBook -> view_recipe_book(model)
    RecipeDetail(slug: slug) -> view_lookup_recipe_detail(model.current_recipe)
    EditRecipe(slug: slug) -> view_edit_recipe(model.current_recipe)
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
    view_title(
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

fn view_recipe_book(model: Model) {
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr]",
      ),
    ],
    [
      view_title("Recipe Book", "underline-green"),
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

fn view_recipe_summary(recipe: Recipe) {
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

fn view_lookup_recipe_detail(maybe_recipe: Option(Recipe)) {
  case maybe_recipe {
    Some(a) -> view_recipe_detail(a)
    _ -> view_title("Recipe not found", "")
  }
}

fn view_edit_recipe(maybe_recipe: Option(Recipe)) {
  form(
    [class("grid grid-cols-12 gap-y-2 col-span-full"), id("create_recipe_form")],
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
                "min-h-[56px] max-h-[140px] sm:max-h-[170px] overflow-x-hidden px-0 pb-1 input-base w-full input-focus font-transitional resize-none font-bold italic text-ecru-white-950  text-7xl bg-ecru-white-100`",
              ),
            ],
            case maybe_recipe {
              Some(a) -> a.title
              _ -> ""
            },
          ),
        ],
      ),
      fieldset(
        [
          class(
            "mx-2 sm:mx-0 mt-0 sm:mt-4 flex sm:flex-wrap justify-between row-start-2 col-span-full sm:row-start-1 sm:col-span-3 sm:col-start-9",
          ),
        ],
        [
          fieldset([class("flex flex-wrap items-baseline mb-2")], [
            label(
              [class("justify-self-start font-mono italic"), for("prep_time")],
              [text("Prep:")],
            ),
            div([class("justify-self-start")], [
              div([class("after:content-['h'] after:text-xs inline-block")], [
                input([
                  id("prep_time_hrs"),
                  class(
                    "bg-ecru-white-100 input-base input-focus pr-0.5 w-[3ch] text-right text-base",
                  ),
                  type_("number"),
                  name("prep_time_hrs"),
                  value(case maybe_recipe {
                    Some(a) ->
                      int.floor_divide(a.prep_time, 60)
                      |> result.unwrap(0)
                      |> to_string
                      |> string.replace("0", "")
                    _ -> ""
                  }),
                ]),
              ]),
            ]),
          ]),
        ],
      ),
    ],
  )
}

fn view_recipe_detail(recipe: Recipe) {
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr]",
      ),
    ],
    [
      view_title(recipe.title, "underline-green"),
      fieldset(
        [
          class(
            "mx-2 sm:mx-0 mt-0 sm:mt-4 flex sm:flex-wrap justify-between row-start-2 col-span-full sm:row-start-1 sm:col-span-3 sm:col-start-9",
          ),
        ],
        [
          fieldset(
            [class("flex flex-wrap sm:justify-between items-baseline mb-2")],
            [
              label(
                [for("prep_time"), class("justify-self-start font-mono italic")],
                [text("Prep:")],
              ),
              div([class("mx-4 justify-self-start")], [
                text(to_string(recipe.prep_time)),
              ]),
            ],
          ),
          fieldset(
            [class("flex flex-wrap sm:justify-between items-baseline mb-2")],
            [
              label(
                [for("cook_time"), class("justify-self-start font-mono italic")],
                [text("Cook:")],
              ),
              div([class("mx-4 justify-self-start")], [
                text(to_string(recipe.cook_time)),
              ]),
            ],
          ),
          fieldset(
            [class("flex flex-wrap sm:justify-between items-baseline mb-2")],
            [
              label(
                [for("cook_time"), class("justify-self-start font-mono italic")],
                [text("Serves:")],
              ),
              div([class("mx-4 justify-self-start")], [
                text(to_string(recipe.serves)),
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
        [a([href("/"), class("text-center")], [text("🏠")])],
      ),
      fieldset(
        [
          class(
            "flex flex-wrap gap-1 items-baseline mx-1 col-span-full gap-x-3",
          ),
        ],
        case recipe.tags {
          Some(a) -> list.map(a, fn(tag) { view_tag(tag) })
          _ -> [none()]
        },
      ),
      fieldset(
        [
          class(
            "col-span-full my-1 mb-6 pt-1 pb-2 px-2 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-6 [box-shadow:1px_1px_0_#a3d2ab] mr-1",
          ),
        ],
        [
          legend([class("mx-2 px-1 font-mono italic")], [text("Ingredients")]),
          recipe.ingredients
            |> option.map(list.map(_, view_ingredient))
            |> option.unwrap([none()])
            |> fragment,
        ],
      ),
      fieldset(
        [
          class(
            "flex justify-start flex-wrap col-span-full my-1 mb-6 pt-1 pb-2 px-2 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-6 [box-shadow:1px_1px_0_#a3d2ab] mr-1",
          ),
        ],
        [
          legend([class("mx-2 px-1 font-mono italic")], [text("Method")]),
          ol(
            [
              class(
                "list-decimal flex flex-wrap w-full items-baseline col-span-full pr-1 pl-2 ml-1 mb-1",
              ),
            ],
            [
              recipe.method_steps
              |> option.map(list.map(_, view_method_step))
              |> option.unwrap([none()])
              |> fragment,
            ],
          ),
        ],
      ),
    ],
  )
}

fn view_ingredient(ingredient: Ingredient) {
  div([class("flex justify-start col-span-6 text-sm items-baseline")], [
    div([class("flex-grow-[2] text-left flex justify-start")], [
      option.unwrap(option.map(ingredient.name, text(_)), none()),
    ]),
    div([class("col-span-1 text-xs")], [
      option.unwrap(option.map(ingredient.quantity, text(_)), none()),
    ]),
    div([class("col-span-1 text-xs")], [
      option.unwrap(option.map(ingredient.units, text(_)), none()),
    ]),
  ])
}

fn view_method_step(method_step: MethodStep) {
  li(
    [
      class(
        "marker:text-base w-full justify-self-start list-decimal text-left pl-1 ml-2 leading-snug my-2",
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

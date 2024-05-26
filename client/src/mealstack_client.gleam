import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option}
import gleam/string
import gleam/uri.{type Uri}
import lustre
import lustre/attribute.{class, href, id}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{a, button, div, h1, nav, p, section, span}
import lustre/event
import modem

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model(current_route: Home(title: "Mealstack"), recipes: []),
    modem.init(on_route_change),
  )
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(current_route: Route, recipes: List(Recipe))
}

type Route {
  Home(title: String)
  RecipeDetail(title: String, slug: String)
  RecipeBook(title: String)
}

type Recipe {
  Recipe(
    id: Option(Int),
    title: String,
    slug: String,
    cook_time: Int,
    prep_time: Int,
    serves: Int,
    ingredients: Option(List(Ingredient)),
  )
}

type Ingredient {
  Ingredient(
    name: Option(String),
    ismain: Option(Bool),
    quantity: Option(String),
    units: Option(String),
  )
}

// UPDATE ----------------------------------------------------------------------

pub opaque type Msg {
  OnRouteChange(Route)
  CacheUpdatedMessage(List(Recipe))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(RecipeBook("Recipes")) -> #(
      Model(..model, current_route: RecipeBook("Recipes")),
      get_recipes(),
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

fn on_route_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    ["recipes", slug] -> OnRouteChange(RecipeDetail(slug, "Recipe"))
    ["recipes"] -> OnRouteChange(RecipeBook("Recipes"))
    _ -> OnRouteChange(Home("Mealstack"))
  }
}

fn get_recipes() -> Effect(Msg) {
  use dispatch <- effect.from
  do_get_recipes()
  |> promise.map(CacheUpdatedMessage)
  |> promise.tap(dispatch)

  Nil
}

@external(javascript, "./db.ts", "do_get_recipes")
fn do_get_recipes() -> Promise(List(Recipe))

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let page = case model.current_route {
    Home("Mealstack") -> view_home(model)
    RecipeBook("Recipes") -> view_recipe_book(model)

    // RecipeDetail(slug: String) -> view_recipe_detail(model,slug)
    _ -> view_home(model)
  }
  view_base(page)
}

fn view_base(children) {
  html.main(
    [
      class(
        "grid ml-1 mr-2 gap-2
    lg:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_85ch_[main-end]_3fr_[full-end]_1fr_[end]]
    grid-cols-[[start_full-start_main-start]_100%_[main-end_full-end_end]]
    min-h-[90vh]",
      ),
    ],
    [children],
  )
}

fn view_home(model: Model) {
  section([class("grid-cols-12 col-start-[main-start]")], [
    view_title(
      model,
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

fn view_title(model: Model, styles: String) {
  div(
    [
      class(styles),
      class(
        "mt-4 mb-2 sm:mb-4 mx-2 flex col-start-1 col-span-11 sm:col-start-1 sm:col-span-8 text-7xl",
      ),
    ],
    [
      h1(
        [
          id("title"),
          class(
            "min-h-[56px] max-h-[140px] sm:max-h-[170px] overflow-hidden px-0 pb-1 w-full font-transitional font-bold italic text-ecru-white-950",
          ),
        ],
        [text(model.current_route.title)],
      ),
    ],
  )
}

fn view_recipe_book(model: Model) {
  section([class("grid-cols-12 col-start-[main-start]")], [
    view_title(model, "underline-green"),
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
  ])
}

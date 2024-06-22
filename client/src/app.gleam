import components/page_title.{page_title}
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/uri.{type Uri, Uri}
import lustre
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{a, nav, section, span}
import modem
import pages/planner
import pages/recipe
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
    Model(
      current_route: Home,
      current_recipe: None,
      recipes: recipe.RecipeList(recipes: [], tag_options: []),
      planner: dict.new(),
    ),
    modem.init(on_route_change),
  )
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(
    current_route: Route,
    current_recipe: recipe.RecipeDetail,
    recipes: recipe.RecipeList,
    planner: planner.PlanWeek,
  )
}

pub type Route {
  Home
  ViewRecipeDetail(slug: String)
  EditRecipeDetail(slug: String)
  ViewRecipeList
  ViewPlanner
  EditPlanner
}

pub type Msg {
  OnRouteChange(Route)
  RecipeDetail(recipe.RecipeDetailMsg)
  RecipeList(recipe.RecipeListMsg)
  Planner(planner.PlannerMsg)
}

// UPDATE ----------------------------------------------------------------------

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(ViewRecipeList) -> #(
      Model(..model, current_route: ViewRecipeList),
      effect.batch([
        effect.map(recipe.get_recipes(), RecipeList),
        effect.map(recipe.get_tag_options(), RecipeList),
      ]),
    )
    OnRouteChange(ViewRecipeDetail(slug: slug)) -> #(
      Model(
        ..model,
        current_route: ViewRecipeDetail(slug: slug),
        current_recipe: lookup_recipe_by_slug(model, slug),
      ),
      effect.none(),
    )
    OnRouteChange(EditRecipeDetail(slug: "")) -> #(
      Model(
        ..model,
        current_route: EditRecipeDetail(slug: ""),
        current_recipe: Some(recipe.Recipe(
          None,
          "New Recipe",
          "",
          0,
          0,
          0,
          Some(dict.from_list([#(0, recipe.Tag("", ""))])),
          Some(
            dict.from_list([#(0, recipe.Ingredient(None, None, None, None))]),
          ),
          Some(dict.from_list([#(0, recipe.MethodStep(""))])),
        )),
      ),
      effect.map(recipe.get_tag_options(), RecipeList),
    )
    OnRouteChange(EditRecipeDetail(slug: slug)) -> #(
      Model(
        ..model,
        current_route: EditRecipeDetail(slug: slug),
        current_recipe: lookup_recipe_by_slug(model, slug),
      ),
      effect.none(),
    )
    OnRouteChange(ViewPlanner) -> #(
      Model(..model, current_route: ViewPlanner),
      effect.map(planner.get_plan(), Planner),
    )
    OnRouteChange(EditPlanner) -> #(
      Model(..model, current_route: EditPlanner),
      effect.none(),
    )
    OnRouteChange(route) -> #(
      Model(..model, current_route: route, current_recipe: None),
      effect.none(),
    )
    RecipeList(list_msg) -> {
      let #(child_model, child_effect) =
        recipe.list_update(model.recipes, list_msg)
      #(
        Model(..model, recipes: child_model),
        effect.map(child_effect, RecipeList),
      )
    }
    RecipeDetail(recipe.DbSavedUpdatedRecipe(new_recipe)) -> {
      #(
        Model(
          ..model,
          recipes: recipe.merge_recipe_into_model(new_recipe, model.recipes),
        ),
        // TODO: Better handle navigating in response to the updated data
        {
          use dispatch <- effect.from
          OnRouteChange(ViewRecipeDetail(slug: new_recipe.slug)) |> dispatch
        },
      )
    }
    RecipeDetail(detail_msg) -> {
      let #(child_model, child_effect) =
        recipe.detail_update(model.current_recipe, detail_msg)
      #(
        Model(..model, current_recipe: child_model),
        effect.map(child_effect, RecipeDetail),
      )
    }
    Planner(planner_msg) -> {
      let #(child_model, child_effect) =
        planner.planner_update(model.planner, planner_msg)
      #(Model(..model, planner: child_model), effect.map(child_effect, Planner))
    }
  }
}

fn lookup_recipe_by_slug(model: Model, slug: String) -> Option(recipe.Recipe) {
  option.from_result(list.find(model.recipes.recipes, fn(a) { a.slug == slug }))
}

fn on_route_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    ["recipes", "new"] -> OnRouteChange(EditRecipeDetail(slug: ""))
    ["recipes", slug, "edit"] -> OnRouteChange(EditRecipeDetail(slug: slug))
    ["recipes", slug] -> OnRouteChange(ViewRecipeDetail(slug: slug))
    ["recipes"] -> OnRouteChange(ViewRecipeList)
    ["planner", "edit"] -> OnRouteChange(EditPlanner)
    ["planner"] -> OnRouteChange(ViewPlanner)
    _ -> OnRouteChange(Home)
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let page = case model.current_route {
    Home -> view_home()
    ViewRecipeList ->
      element.map(recipe.view_recipe_list(model.recipes), RecipeList)
    ViewRecipeDetail(slug: _slug) ->
      element.map(
        recipe.lookup_and_view_recipe(model.current_recipe),
        RecipeDetail,
      )
    EditRecipeDetail(slug: _slug) ->
      element.map(
        recipe.lookup_and_edit_recipe(
          model.current_recipe,
          model.recipes.tag_options,
        ),
        RecipeDetail,
      )
    ViewPlanner -> element.map(planner.view_planner(model.planner), Planner)
    EditPlanner -> planner.edit_planner(model.planner)
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
    md:grid-cols-[[start_full-start]_1fr_[main-start]_70ch_[main-end]_1fr_[full-end_end]]
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

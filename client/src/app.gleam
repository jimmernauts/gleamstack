import components/page_title.{page_title}
import components/typeahead
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
import pages/ingest
import pages/planner
import pages/recipe
import rada/date
import session
import tardis

// MAIN ------------------------------------------------------------------------

// WITHOUT DEBUGGER

// pub fn main() {
//   lustre.register(typeahead.app(), "type-ahead")
//  let app = lustre.application(init, update, view)
//  let assert Ok(_) = lustre.start(app, "#app", Nil)
// }

// WITH DEBUGGER

pub fn main() {
  let assert Ok(main) = tardis.single("main")
  lustre.register(typeahead.app(), "type-ahead")
  lustre.application(init, update, view)
  |> tardis.wrap(with: main)
  |> lustre.start("#app", Nil)
  |> tardis.activate(with: main)
  main
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model(
      current_route: Home,
      current_recipe: None,
      recipes: session.RecipeList(recipes: [], tag_options: []),
      planner: planner.Model(
        plan_week: dict.new(),
        recipe_list: [],
        start_date: date.floor(date.today(), date.Monday),
      ),
      import_url: ingest.ImportModel(url: ""),
    ),
    effect.batch([
      modem.init(on_route_change),
      effect.map(session.get_recipes(), RecipeList),
      effect.map(session.get_tag_options(), RecipeList),
    ]),
  )
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(
    current_route: Route,
    current_recipe: recipe.RecipeDetail,
    recipes: session.RecipeList,
    planner: planner.Model,
    import_url: ingest.ImportModel,
  )
}

pub type Route {
  Home
  ViewRecipeDetail(slug: String)
  EditRecipeDetail(RouteParams)
  ViewRecipeList
  ViewPlanner
  EditPlanner
  ImportRecipe
}

pub type RouteParams {
  SlugParam(slug: String)
  RecipeParam(recipe: session.Recipe)
}

pub type Msg {
  OnRouteChange(Route)
  RecipeDetail(recipe.RecipeDetailMsg)
  RecipeList(session.RecipeListMsg)
  Planner(planner.PlannerMsg)
  Import(ingest.ImportMsg)
}

// UPDATE ----------------------------------------------------------------------

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(ViewRecipeList) -> #(
      Model(..model, current_route: ViewRecipeList),
      effect.batch([
        effect.map(session.get_recipes(), RecipeList),
        effect.map(session.get_tag_options(), RecipeList),
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
    OnRouteChange(EditRecipeDetail(SlugParam(slug: ""))) -> #(
      Model(
        ..model,
        current_route: EditRecipeDetail(SlugParam(slug: "")),
        current_recipe: Some(session.Recipe(
          None,
          "New Recipe",
          "",
          0,
          0,
          0,
          Some(dict.from_list([#(0, session.Tag("", ""))])),
          Some(
            dict.from_list([#(0, session.Ingredient(None, None, None, None))]),
          ),
          Some(dict.from_list([#(0, session.MethodStep(""))])),
        )),
      ),
      effect.map(session.get_tag_options(), RecipeList),
    )
    OnRouteChange(EditRecipeDetail(SlugParam(slug: slug))) -> #(
      Model(
        ..model,
        current_route: EditRecipeDetail(SlugParam(slug: slug)),
        current_recipe: lookup_recipe_by_slug(model, slug),
      ),
      effect.none(),
    )
    OnRouteChange(EditRecipeDetail(RecipeParam(recipe: recipe))) -> #(
      Model(
        ..model,
        current_route: EditRecipeDetail(RecipeParam(recipe: recipe)),
        current_recipe: Some(recipe),
      ),
      effect.none(),
    )
    OnRouteChange(ViewPlanner) -> #(
      Model(..model, current_route: ViewPlanner),
      effect.map(
        planner.get_plan(date.floor(date.today(), date.Monday)),
        Planner,
      ),
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
        Model(
          ..model,
          recipes: child_model,
          planner: planner.Model(
            plan_week: model.planner.plan_week,
            recipe_list: list.map(child_model.recipes, fn(a) { a.title }),
            start_date: model.planner.start_date,
          ),
        ),
        effect.map(child_effect, RecipeList),
      )
    }
    RecipeDetail(recipe.DbSavedUpdatedRecipe(new_recipe)) -> {
      #(
        Model(
          ..model,
          recipes: session.merge_recipe_into_model(new_recipe, model.recipes),
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
    Planner(planner.DbSavedPlan(date)) -> {
      #(
        Model(
          ..model,
          planner: planner.Model(..model.planner, start_date: date),
        ),
        // TODO: Better handle navigating in response to the updated data
        {
          use dispatch <- effect.from
          OnRouteChange(ViewPlanner) |> dispatch
        },
      )
    }
    Planner(planner_msg) -> {
      let #(child_model, child_effect) =
        planner.planner_update(model.planner, planner_msg)
      #(Model(..model, planner: child_model), effect.map(child_effect, Planner))
    }
    Import(ingest.ParsedRecipefromUrl(recipe)) -> {
      #(Model(..model, current_recipe: Some(recipe)), {
        use dispatch <- effect.from
        OnRouteChange(EditRecipeDetail(RecipeParam(recipe))) |> dispatch
      })
    }
    Import(import_msg) -> {
      let #(child_model, child_effect) =
        ingest.update(model.import_url, import_msg)
      #(
        Model(..model, import_url: child_model),
        effect.map(child_effect, Import),
      )
    }
  }
}

fn lookup_recipe_by_slug(model: Model, slug: String) -> Option(session.Recipe) {
  option.from_result(list.find(model.recipes.recipes, fn(a) { a.slug == slug }))
}

fn on_route_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    ["recipes", "new"] -> OnRouteChange(EditRecipeDetail(SlugParam(slug: "")))
    ["recipes", slug, "edit"] ->
      OnRouteChange(EditRecipeDetail(SlugParam(slug: slug)))
    ["recipes", slug] -> OnRouteChange(ViewRecipeDetail(slug: slug))
    ["recipes"] -> OnRouteChange(ViewRecipeList)
    ["planner", "edit"] -> OnRouteChange(EditPlanner)
    ["planner"] -> OnRouteChange(ViewPlanner)
    ["import"] -> OnRouteChange(ImportRecipe)
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
    EditRecipeDetail(SlugParam(slug: _slug)) ->
      element.map(
        recipe.lookup_and_edit_recipe(
          model.current_recipe,
          model.recipes.tag_options,
        ),
        RecipeDetail,
      )
    EditRecipeDetail(RecipeParam(recipe: recipe)) ->
      element.map(
        recipe.edit_recipe_detail(recipe, model.recipes.tag_options),
        RecipeDetail,
      )
    ViewPlanner ->
      element.map(
        planner.view_planner(planner.Model(
          plan_week: model.planner.plan_week,
          recipe_list: list.map(model.recipes.recipes, fn(a) { a.title }),
          start_date: model.planner.start_date,
        )),
        Planner,
      )
    EditPlanner ->
      element.map(
        planner.edit_planner(planner.Model(
          plan_week: model.planner.plan_week,
          recipe_list: list.map(model.recipes.recipes, fn(a) { a.title }),
          start_date: model.planner.start_date,
        )),
        Planner,
      )
    ImportRecipe ->
      element.map(ingest.view(ingest.ImportModel(model.import_url.url)), Import)
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
            span([class("underline-green")], [text("List  ")]),
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

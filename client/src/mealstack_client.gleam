import components/page_title.{page_title}
import components/typeahead
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import lustre
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{a, nav, section, span}
import modem
import pages/planner
import pages/recipe
import pages/settings
import pages/upload
import rada/date
import session

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let _ = lustre.register(typeahead.app(), "type-ahead")
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  let initial_route =
    modem.initial_uri()
    |> result.map(on_route_change)
    |> result.map(fn(x) {
      case x {
        OnRouteChange(route) -> route
        _ -> Home
      }
    })
  #(
    Model(
      current_route: result.unwrap(initial_route, Home),
      current_recipe: None,
      recipes: session.RecipeList(recipes: [], tag_options: [], group_by: None),
      planner: planner.Model(
        plan_week: dict.new(),
        recipe_list: [],
        start_date: date.floor(date.today(), date.Monday),
      ),
      db_subscriptions: dict.from_list([]),
      settings: settings.SettingsModel(api_key: None),
      upload: upload.UploadModel(
        status: upload.NotStarted,
        file_name: None,
        file_data: None,
        raw_file_change_event: None,
        url: None,
        text: None,
      ),
    ),
    effect.batch([
      modem.init(on_route_change),
      {
        use dispatch <- effect.from
        OnRouteChange(result.unwrap(initial_route, Home)) |> dispatch
      },
      effect.map(session.subscribe_to_recipe_summaries(), RecipeList),
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
    db_subscriptions: Dict(String, fn() -> Nil),
    settings: settings.SettingsModel,
    upload: upload.UploadModel,
  )
}

pub type Route {
  Home
  ViewRecipeDetail(slug: String)
  EditRecipeDetail(RouteParams)
  ViewRecipeList
  ViewPlanner(start_date: date.Date)
  EditPlanner(start_date: date.Date)
  ViewSettings
  ViewUpload
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
  Settings(settings.SettingsMsg)
  Upload(upload.UploadMsg)
}

// UPDATE ----------------------------------------------------------------------

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let step1 = case msg {
    OnRouteChange(ViewRecipeList) -> #(
      Model(..model, current_route: ViewRecipeList),
      effect.none(),
    )
    OnRouteChange(ViewRecipeDetail(slug: slug)) -> {
      let effect_to_run = case dict.get(model.db_subscriptions, slug) {
        Ok(_) -> effect.none()
        _ ->
          effect.map(session.subscribe_to_one_recipe_by_slug(slug), RecipeList)
      }
      #(
        Model(
          ..model,
          current_route: ViewRecipeDetail(slug: slug),
          current_recipe: lookup_recipe_by_slug(model, slug),
        ),
        effect_to_run,
      )
    }
    OnRouteChange(EditRecipeDetail(SlugParam(slug: ""))) -> #(
      Model(
        ..model,
        current_route: EditRecipeDetail(SlugParam(slug: "")),
        current_recipe: Some(session.Recipe(
          id: None,
          title: "New Recipe",
          slug: "",
          cook_time: 0,
          prep_time: 0,
          serves: 0,
          author: None,
          source: None,
          tags: Some(dict.from_list([#(0, session.Tag("", ""))])),
          ingredients: Some(
            dict.from_list([#(0, session.Ingredient(None, None, None, None))]),
          ),
          method_steps: Some(dict.from_list([#(0, session.MethodStep(""))])),
          shortlisted: None,
        )),
      ),
      effect.none(),
    )
    OnRouteChange(EditRecipeDetail(SlugParam(slug: slug))) -> {
      let effect_to_run = case dict.get(model.db_subscriptions, slug) {
        Ok(_) -> effect.none()
        _ ->
          effect.map(session.subscribe_to_one_recipe_by_slug(slug), RecipeList)
      }
      #(
        Model(
          ..model,
          current_route: EditRecipeDetail(SlugParam(slug: slug)),
          current_recipe: lookup_recipe_by_slug(model, slug),
        ),
        effect_to_run,
      )
    }
    OnRouteChange(EditRecipeDetail(RecipeParam(recipe: recipe))) -> #(
      Model(
        ..model,
        current_route: EditRecipeDetail(RecipeParam(recipe: recipe)),
        current_recipe: Some(recipe),
      ),
      effect.none(),
    )
    OnRouteChange(ViewPlanner(start_date)) -> #(
      Model(..model, current_route: ViewPlanner(start_date)),
      effect.batch([
        effect.map(
          planner.subscribe_to_plan(date.floor(start_date, date.Monday)),
          Planner,
        ),
        case list.length(model.recipes.recipes) {
          0 -> effect.map(session.get_recipes(), RecipeList)
          _ -> effect.none()
        },
      ]),
    )
    OnRouteChange(EditPlanner(start_date)) -> #(
      Model(..model, current_route: EditPlanner(start_date)),
      effect.none(),
    )
    OnRouteChange(ViewSettings) -> #(
      Model(..model, current_route: ViewSettings),
      effect.map(settings.retrieve_settings(), Settings),
    )
    OnRouteChange(ViewUpload) -> #(
      Model(
        ..model,
        current_route: ViewUpload,
        current_recipe: None,
        upload: upload.UploadModel(
          status: upload.NotStarted,
          file_name: None,
          file_data: None,
          raw_file_change_event: None,
          url: None,
          text: None,
        ),
      ),
      effect.none(),
    )
    OnRouteChange(route) -> #(
      Model(..model, current_route: route, current_recipe: None),
      effect.none(),
    )
    RecipeList(session.DbRetrievedOneRecipe(recipe)) -> {
      #(
        Model(
          ..model,
          current_recipe: Some(recipe),
          recipes: session.merge_recipe_into_model(recipe, model.recipes),
        ),
        effect.none(),
      )
    }
    RecipeList(session.DbSubscriptionOpened(key, callback)) -> #(
      Model(
        ..model,
        db_subscriptions: dict.upsert(
          in: model.db_subscriptions,
          update: key,
          with: fn(_) { callback },
        ),
      ),
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
        effect.batch([
          {
            use dispatch <- effect.from
            OnRouteChange(ViewRecipeDetail(slug: new_recipe.slug)) |> dispatch
          },
          modem.push("/recipes/" <> new_recipe.slug, None, None),
        ]),
      )
    }
    RecipeDetail(recipe.DbDeletedRecipe(_id)) -> #(
      Model(..model, current_recipe: None),
      modem.push("/recipes", None, None),
    )
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
          OnRouteChange(ViewPlanner(date)) |> dispatch
        },
      )
    }
    Planner(planner.DbRetrievedPlan(plan_week, start_date)) -> {
      #(
        Model(
          ..model,
          current_route: ViewPlanner(start_date),
          planner: planner.Model(..model.planner, plan_week: plan_week),
        ),
        effect.none(),
      )
    }
    Planner(planner.DbSubscriptionOpened(key, callback)) -> #(
      Model(
        ..model,
        db_subscriptions: dict.upsert(
          in: model.db_subscriptions,
          update: date.to_iso_string(key),
          with: fn(_) { callback },
        ),
      ),
      effect.none(),
    )
    Planner(planner_msg) -> {
      let #(child_model, child_effect) =
        planner.planner_update(model.planner, planner_msg)
      #(Model(..model, planner: child_model), effect.map(child_effect, Planner))
    }
    Settings(settings_msg) -> {
      let #(settings_model, settings_effect) =
        settings.settings_update(model.settings, settings_msg)
      #(
        Model(..model, settings: settings_model),
        effect.map(settings_effect, Settings),
      )
    }
    Upload(upload.ParseRecipeResponseReceived(Ok(recipe))) -> {
      #(
        Model(
          ..model,
          current_recipe: Some(recipe),
          upload: upload.UploadModel(
            status: upload.Finished,
            file_name: None,
            file_data: None,
            raw_file_change_event: None,
            url: None,
            text: None,
          ),
        ),
        {
          use dispatch <- effect.from
          OnRouteChange(EditRecipeDetail(RecipeParam(recipe: recipe)))
          |> dispatch
        },
      )
    }
    Upload(upload_msg) -> {
      let #(upload_model, upload_effect) =
        upload.upload_update(model.upload, upload_msg)
      #(Model(..model, upload: upload_model), effect.map(upload_effect, Upload))
    }
  }
  case model.current_route {
    EditRecipeDetail(SlugParam(slug: slug)) | ViewRecipeDetail(slug) -> {
      case msg, dict.get(model.db_subscriptions, slug) {
        OnRouteChange(EditRecipeDetail(SlugParam(_slug))), _ -> #(
          step1.0,
          step1.1,
        )
        OnRouteChange(ViewRecipeDetail(_slug)), _ -> #(step1.0, step1.1)
        OnRouteChange(_), Ok(_) -> #(
          Model(
            ..step1.0,
            db_subscriptions: dict.drop(model.db_subscriptions, [slug]),
          ),
          {
            let _ =
              dict.get(model.db_subscriptions, slug)
              |> result.map(fn(a) { a() })
            step1.1
          },
        )
        _, _ -> #(step1.0, step1.1)
      }
    }
    ViewPlanner(start_date) | EditPlanner(start_date) -> {
      case
        msg,
        dict.get(model.db_subscriptions, date.to_iso_string(start_date))
      {
        OnRouteChange(ViewPlanner(_start_date)), _ -> #(step1.0, step1.1)
        OnRouteChange(EditPlanner(_start_date)), _ -> #(step1.0, step1.1)
        OnRouteChange(_), Ok(_) -> #(
          Model(
            ..step1.0,
            db_subscriptions: dict.drop(model.db_subscriptions, [
              date.to_iso_string(start_date),
            ]),
          ),
          {
            let _ =
              dict.get(model.db_subscriptions, date.to_iso_string(start_date))
              |> result.map(fn(a) { a() })
            step1.1
          },
        )
        _, _ -> #(step1.0, step1.1)
      }
    }
    _ -> #(step1.0, step1.1)
  }
}

fn lookup_recipe_by_slug(model: Model, slug: String) -> Option(session.Recipe) {
  option.from_result(list.find(model.recipes.recipes, fn(a) { a.slug == slug }))
}

fn on_route_change(uri: Uri) -> Msg {
  case uri.query, uri.path_segments(uri.path) {
    Some(query), ["planner", "edit"] -> {
      case uri.parse_query(query) {
        Ok([#("date", v)]) ->
          OnRouteChange(
            EditPlanner(result.unwrap(date.from_iso_string(v), date.today())),
          )
        _ -> OnRouteChange(EditPlanner(date.today()))
      }
    }
    Some(query), ["planner"] -> {
      case uri.parse_query(query) {
        Ok([#("date", v)]) ->
          OnRouteChange(
            ViewPlanner(result.unwrap(date.from_iso_string(v), date.today())),
          )
        _ -> OnRouteChange(ViewPlanner(date.today()))
      }
    }
    _, ["recipes", "new"] ->
      OnRouteChange(EditRecipeDetail(SlugParam(slug: "")))
    _, ["recipes", slug, "edit"] ->
      OnRouteChange(EditRecipeDetail(SlugParam(slug: slug)))
    _, ["recipes", slug] -> OnRouteChange(ViewRecipeDetail(slug: slug))
    _, ["recipes"] -> OnRouteChange(ViewRecipeList)
    _, ["planner", "edit"] -> OnRouteChange(EditPlanner(date.today()))
    _, ["planner"] -> OnRouteChange(ViewPlanner(date.today()))
    _, ["settings"] -> OnRouteChange(ViewSettings)
    _, ["import"] -> OnRouteChange(ViewUpload)
    _, _ -> OnRouteChange(Home)
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
    EditRecipeDetail(SlugParam(slug: _slug)) -> {
      element.map(
        recipe.lookup_and_edit_recipe(
          model.current_recipe,
          model.recipes.tag_options,
        ),
        RecipeDetail,
      )
    }
    EditRecipeDetail(RecipeParam(recipe: recipe)) ->
      element.map(
        recipe.edit_recipe_detail(recipe, model.recipes.tag_options),
        RecipeDetail,
      )
    ViewPlanner(start_date) ->
      element.map(
        planner.view_planner(planner.Model(
          plan_week: model.planner.plan_week,
          recipe_list: list.map(model.recipes.recipes, fn(a) { a.title }),
          start_date: start_date,
        )),
        Planner,
      )
    EditPlanner(start_date) ->
      element.map(
        planner.edit_planner(planner.Model(
          plan_week: model.planner.plan_week,
          recipe_list: list.map(model.recipes.recipes, fn(a) { a.title }),
          start_date: start_date,
        )),
        Planner,
      )
    ViewSettings ->
      element.map(settings.view_settings(model.settings), Settings)
    ViewUpload -> element.map(upload.view_upload(model.upload), Upload)
  }
  view_base(page)
}

fn view_base(children) {
  html.main(
    [
      class(
        "grid ml-2 mr-2 gap-2
      2xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_90%_[main-end]_3fr_[full-end]_1fr_[end]]
      xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95%_[main-end]_3fr_[full-end]_1fr_[end]]
      lg:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95%_[main-end]_3fr_[full-end]_1fr_[end]]
      md:grid-cols-[[start_full-start]_1fr_[main-start]_95%_[main-end]_1fr_[full-end_end]]
      grid-cols-[[start_full-start_main-start]_100%_[main-end_full-end_end]]
      grid-rows-[[content]_95%_[footer]_1fr]
      bg-ecru-white-50  text-ecru-white-950 font-transitional text-lg",
      ),
    ],
    [children],
  )
}

fn view_home() {
  section([class("grid grid-cols-12 col-start-[main-start] gap-y-12")], [
    page_title(
      "Mealstack",
      "text-9xl placeholder:underline-pink underline-pink col-span-11",
    ),
    nav(
      [
        class(
          "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4",
        ),
      ],
      [a([href("/settings"), class("text-center")], [text("⚙️")])],
    ),
    nav(
      [
        class(
          "subgrid-cols my-6 gap-y-12 col-span-full text-6xl mx-2 font-mono",
        ),
      ],
      [
        #("📅", "Plan", "planner", " underline-orange"),
        #("📑", "List", "recipes", " underline-green"),
        #("📝", "New", "recipes/new", " underline-blue"),
        #("📤", "Import", "import", " underline-yellow"),
      ]
        |> list.map(fn(t) {
          a(
            [
              class(
                "col-span-full subgrid-cols sm:col-span-6 items-baseline pr-4",
              ),
              href("/" <> string.lowercase(t.2)),
            ],
            [
              span([class("text-5xl col-start-2 sm:col-start-1")], [text(t.0)]),
              span(
                [
                  class(
                    "col-start-4 sm:col-start-3 lg:col-start-2 lg:ml-4" <> t.3,
                  ),
                ],
                [text(t.1)],
              ),
            ],
          )
        }),
    ),
  ])
}

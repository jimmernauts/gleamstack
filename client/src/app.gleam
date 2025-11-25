import components/page_title.{page_title}
import components/typeahead
import domains/planner
import domains/recipe_detail
import domains/recipe_list
import domains/settings
import domains/shoppinglist
import domains/upload
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import glearray
import lustre
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{a, nav, section, span}
import modem
import rada/date
import shared/types.{type Recipe, Ingredient, MethodStep, Recipe, Tag}

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
      recipes: recipe_list.RecipeListModel(
        recipes: [],
        tag_options: [],
        group_by: None,
      ),
      planner: planner.PlannerModel(
        plan_week: dict.new(),
        recipe_list: [],
        start_date: date.floor(date.today(), date.Monday),
      ),
      db_subscriptions: dict.new(),
      shoppinglist: shoppinglist.ShoppingListModel(
        all_lists: dict.new(),
        current: None,
      ),
      settings: settings.SettingsModel(api_key: None),
      upload: upload.UploadModel(
        status: upload.NotStarted,
        api_key: None,
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
      effect.map(recipe_list.subscribe_to_recipe_summaries(), RecipeList),
      effect.map(recipe_list.get_tag_options(), RecipeList),
    ]),
  )
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(
    current_route: Route,
    current_recipe: recipe_detail.RecipeDetail,
    recipes: recipe_list.RecipeListModel,
    planner: planner.PlannerModel,
    db_subscriptions: Dict(String, fn() -> Nil),
    settings: settings.SettingsModel,
    upload: upload.UploadModel,
    shoppinglist: shoppinglist.ShoppingListModel,
  )
}

pub type Route {
  Home
  ViewRecipeDetail(slug: String)
  EditRecipeDetail(RouteParams)
  ViewRecipeList
  ViewPlanner(start_date: date.Date)
  EditPlanner(start_date: date.Date)
  ViewShoppingLists
  ViewShoppingList(date: date.Date)
  ViewSettings
  ViewUpload
}

pub type RouteParams {
  SlugParam(slug: String)
  RecipeParam(recipe: Recipe)
}

pub type Msg {
  OnRouteChange(Route)
  RecipeDetail(recipe_detail.RecipeDetailMsg)
  RecipeList(recipe_list.RecipeListMsg)
  Planner(planner.PlannerMsg)
  Settings(settings.SettingsMsg)
  Upload(upload.UploadMsg)
  ShoppingList(shoppinglist.ShoppingListMsg)
  DbSubscriptionOpened(String, fn() -> Nil)
}

// UPDATE ----------------------------------------------------------------------

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  echo msg
  // this is the main part of the update function
  let step1 = case msg {
    OnRouteChange(ViewRecipeList) -> #(
      Model(..model, current_route: ViewRecipeList),
      effect.none(),
    )
    OnRouteChange(ViewRecipeDetail(slug: slug)) -> {
      let effect_to_run = case dict.get(model.db_subscriptions, slug) {
        Ok(_) -> effect.none()
        _ ->
          effect.map(
            recipe_list.subscribe_to_one_recipe_by_slug(slug),
            RecipeList,
          )
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
        current_recipe: Some(Recipe(
          id: None,
          title: "New Recipe",
          slug: "",
          cook_time: 0,
          prep_time: 0,
          serves: 0,
          author: None,
          source: None,
          tags: Some(dict.from_list([#(0, Tag("", ""))])),
          ingredients: Some(
            dict.from_list([
              #(0, Ingredient(None, None, None, None, None)),
            ]),
          ),
          method_steps: Some(dict.from_list([#(0, MethodStep(""))])),
          shortlisted: None,
        )),
      ),
      effect.none(),
    )
    OnRouteChange(EditRecipeDetail(SlugParam(slug: slug))) -> {
      let effect_to_run = case dict.get(model.db_subscriptions, slug) {
        Ok(_) -> effect.none()
        _ ->
          effect.map(
            recipe_list.subscribe_to_one_recipe_by_slug(slug),
            RecipeList,
          )
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
      effect.map(
        planner.subscribe_to_plan(date.floor(start_date, date.Monday)),
        Planner,
      ),
    )
    OnRouteChange(EditPlanner(start_date)) -> #(
      Model(..model, current_route: EditPlanner(start_date)),
      effect.none(),
    )
    OnRouteChange(ViewSettings) -> #(
      Model(..model, current_route: ViewSettings),
      effect.map(settings.retrieve_settings(), Settings),
    )
    OnRouteChange(ViewUpload) -> {
      case model.settings.api_key {
        Some(api_key) -> #(
          Model(
            ..model,
            current_route: ViewUpload,
            current_recipe: None,
            upload: upload.UploadModel(
              status: upload.NotStarted,
              api_key: Some(api_key),
              file_name: None,
              file_data: None,
              raw_file_change_event: None,
              url: None,
              text: None,
            ),
          ),
          effect.none(),
        )
        None -> #(
          Model(
            ..model,
            current_route: ViewUpload,
            current_recipe: None,
            upload: upload.UploadModel(
              status: upload.NotStarted,
              api_key: None,
              file_name: None,
              file_data: None,
              raw_file_change_event: None,
              url: None,
              text: None,
            ),
          ),
          effect.map(settings.retrieve_settings(), Settings),
        )
      }
    }
    OnRouteChange(ViewShoppingLists) -> #(
      Model(..model, current_route: ViewShoppingLists),
      effect.map(
        shoppinglist.subscribe_to_shopping_list_summaries(),
        ShoppingList,
      ),
    )
    OnRouteChange(ViewShoppingList(date: list_date)) -> {
      let default_list =
        shoppinglist.ShoppingList(
          id: None,
          items: [
            shoppinglist.ShoppingListIngredient(
              ingredient: types.Ingredient(
                name: None,
                ismain: None,
                quantity: None,
                units: None,
                category: None,
              ),
              source: shoppinglist.ManualEntry,
              checked: False,
            ),
          ]
            |> glearray.from_list(),
          status: shoppinglist.Active,
          date: list_date,
          linked_recipes: [],
          linked_plan: None,
        )
      let find_list =
        model.shoppinglist.all_lists
        |> dict.get(list_date)
        |> result.try_recover(fn(_) { Ok(default_list) })
        |> option.from_result

      #(
        Model(
          ..model,
          current_route: ViewShoppingList(date: list_date),
          shoppinglist: shoppinglist.ShoppingListModel(
            ..model.shoppinglist,
            current: find_list,
          ),
        ),
        effect.map(
          shoppinglist.subscribe_to_one_shoppinglist_by_date(list_date),
          ShoppingList,
        ),
      )
    }
    OnRouteChange(route) -> #(
      Model(..model, current_route: route, current_recipe: None),
      effect.none(),
    )
    RecipeList(recipe_list.DbRetrievedOneRecipe(recipe)) -> {
      #(
        Model(
          ..model,
          current_recipe: Some(recipe),
          recipes: recipe_list.merge_recipe_into_model(recipe, model.recipes),
        ),
        effect.none(),
      )
    }
    RecipeList(recipe_list.RecipeListSubscriptionOpened(key, callback)) -> {
      #(
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
    }
    DbSubscriptionOpened(key, callback) -> #(
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
        recipe_list.list_update(model.recipes, list_msg)
      #(
        Model(
          ..model,
          recipes: child_model,
          planner: planner.PlannerModel(
            plan_week: model.planner.plan_week,
            recipe_list: list.map(child_model.recipes, fn(a) { a.title }),
            start_date: model.planner.start_date,
          ),
        ),
        effect.map(child_effect, RecipeList),
      )
    }
    RecipeDetail(recipe_detail.DbSavedUpdatedRecipe(new_recipe)) -> {
      #(
        Model(
          ..model,
          recipes: recipe_list.merge_recipe_into_model(
            new_recipe,
            model.recipes,
          ),
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
    RecipeDetail(recipe_detail.DbDeletedRecipe(_id)) -> #(
      Model(..model, current_recipe: None),
      modem.push("/recipes", None, None),
    )
    RecipeDetail(detail_msg) -> {
      let #(child_model, child_effect) =
        recipe_detail.detail_update(model.current_recipe, detail_msg)
      #(
        Model(..model, current_recipe: child_model),
        effect.map(child_effect, RecipeDetail),
      )
    }
    Planner(planner.DbSavedPlan(date)) -> {
      #(
        Model(
          ..model,
          planner: planner.PlannerModel(..model.planner, start_date: date),
        ),
        effect.none(),
      )
    }
    Planner(planner.DbRetrievedPlan(plan_week, start_date)) -> {
      #(
        Model(
          ..model,
          current_route: ViewPlanner(start_date),
          planner: planner.PlannerModel(..model.planner, plan_week: plan_week),
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
    Settings(settings.UserRetrievedSettings(api_key)) -> #(
      Model(
        ..model,
        settings: settings.SettingsModel(api_key: api_key),
        upload: upload.UploadModel(..model.upload, api_key: api_key),
      ),
      effect.none(),
    )
    Settings(settings_msg) -> {
      let #(settings_model, settings_effect) =
        settings.settings_update(model.settings, settings_msg)
      #(
        Model(..model, settings: settings_model),
        effect.map(settings_effect, Settings),
      )
    }
    ShoppingList(shoppinglist.ShoppingListSubscriptionOpened(date, callback)) -> #(
      Model(
        ..model,
        db_subscriptions: dict.upsert(
          in: model.db_subscriptions,
          update: date.to_iso_string(date),
          with: fn(_) { callback },
        ),
      ),
      effect.none(),
    )
    ShoppingList(shoppinglist_msg) -> {
      let #(child_model, child_effect) =
        shoppinglist.shopping_list_update(model.shoppinglist, shoppinglist_msg)
      #(
        Model(..model, shoppinglist: child_model),
        effect.map(child_effect, ShoppingList),
      )
    }
    Upload(upload.ParseRecipeResponseReceived(Ok(recipe))) -> {
      #(
        Model(
          ..model,
          upload: upload.UploadModel(
            status: upload.Finished,
            api_key: model.upload.api_key,
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
  // this 'second part' of the update case statement handles dropping the query
  // subscriptions if we are navigating away from a page that uses one, so we
  // don't hold onto a subscription forever
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
    ViewShoppingList(date) -> {
      case msg, dict.get(model.db_subscriptions, date.to_iso_string(date)) {
        OnRouteChange(ViewShoppingList(_date)), _ -> #(step1.0, step1.1)
        OnRouteChange(_), Ok(_) -> #(
          Model(
            ..step1.0,
            db_subscriptions: dict.drop(model.db_subscriptions, [
              date.to_iso_string(date),
            ]),
          ),
          {
            // retrieve the subscription callback from the model
            // and call it to unsubscribe
            let _ =
              dict.get(model.db_subscriptions, date.to_iso_string(date))
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

fn lookup_recipe_by_slug(model: Model, slug: String) -> Option(Recipe) {
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
    _, ["shopping-list"] -> OnRouteChange(ViewShoppingLists)
    _, ["shopping-list", date_str] ->
      OnRouteChange(
        ViewShoppingList(result.unwrap(
          date.from_iso_string(date_str),
          date.today(),
        )),
      )
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
      element.map(recipe_list.view_recipe_list(model.recipes), RecipeList)
    ViewRecipeDetail(slug: _slug) ->
      element.map(
        recipe_detail.lookup_and_view_recipe(model.current_recipe),
        RecipeDetail,
      )
    EditRecipeDetail(SlugParam(slug: _slug)) -> {
      element.map(
        recipe_detail.lookup_and_edit_recipe(
          model.current_recipe,
          model.recipes.tag_options,
        ),
        RecipeDetail,
      )
    }
    EditRecipeDetail(RecipeParam(recipe: _recipe)) -> {
      element.map(
        recipe_detail.lookup_and_edit_recipe(
          model.current_recipe,
          model.recipes.tag_options,
        ),
        RecipeDetail,
      )
    }
    ViewPlanner(start_date) ->
      element.map(
        planner.view_planner(planner.PlannerModel(
          plan_week: model.planner.plan_week,
          recipe_list: list.map(model.recipes.recipes, fn(a) { a.title }),
          start_date: start_date,
        )),
        Planner,
      )
    EditPlanner(start_date) ->
      element.map(
        planner.edit_planner(planner.PlannerModel(
          plan_week: model.planner.plan_week,
          recipe_list: list.map(model.recipes.recipes, fn(a) { a.title }),
          start_date: start_date,
        )),
        Planner,
      )
    ViewSettings ->
      element.map(settings.view_settings(model.settings), Settings)
    ViewShoppingLists ->
      element.map(
        shoppinglist.view_all_shopping_lists(model.shoppinglist),
        ShoppingList,
      )
    ViewShoppingList(date: list_date) ->
      element.map(
        shoppinglist.view_shopping_list_detail(model.shoppinglist.current),
        ShoppingList,
      )
    ViewUpload -> element.map(upload.view_upload(model.upload), Upload)
  }
  view_base(page)
}

fn view_base(children: Element(Msg)) -> Element(Msg) {
  html.main(
    [
      class(
        "h-env-screen grid ml-2 mr-2 gap-2
      2xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_90%_[main-end]_3fr_[full-end]_1fr_[end]]
      xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95%_[main-end]_3fr_[full-end]_1fr_[end]]
      lg:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95%_[main-end]_3fr_[full-end]_1fr_[end]]
      md:grid-cols-[[start_full-start]_1fr_[main-start]_95%_[main-end]_1fr_[full-end_end]]
      grid-cols-[[start_full-start_main-start]_100%_[main-end_full-end_end]]
      text-ecru-white-950 font-transitional text-lg",
      ),
    ],
    [children],
  )
}

fn view_home() {
  section(
    [class("grid auto-rows-min grid-cols-12 col-start-[main-start] gap-y-12")],
    [
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
          class("subgrid-cols gap-y-12 col-span-full text-6xl mx-2 font-mono"),
        ],
        [
          #("📅", "Plan", "planner", " underline-orange"),
          #("🛒", "Shop", "shopping-list", " underline-purple"),
          #("📖", "List", "recipes", " underline-green"),
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
    ],
  )
}

// Export core functions for testing
pub fn public_init(flags) -> #(Model, Effect(Msg)) {
  init(flags)
}

pub fn public_update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  update(model, msg)
}

pub fn public_view(model: Model) -> Element(Msg) {
  view(model)
}

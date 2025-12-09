import components/nav_footer.{nav_footer}
import components/page_title.{page_title}
import components/typeahead.{typeahead}
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import lib/utils
import lustre/attribute.{attribute, checked, class, href, id, styles, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment, text}
import lustre/element/html.{a, button, div, form, h2, input, section}
import lustre/element/keyed
import lustre/event.{on_submit}
import rada/date.{type Date}
import shared/codecs
import shared/types

//-TYPES-------------------------------------------------------------

pub type PlanDay {
  PlanDay(date: Date, planned_meals: List(PlannedMealWithStatus))
}

pub type JsPlanDay {
  JsPlanDay(date: Int, planned_meals: String)
}

pub type PlannedMealWithStatus {
  PlannedMealWithStatus(
    for: Meal,
    recipe: Option(types.PlannedRecipe),
    complete: Option(Bool),
  )
}

pub type PlannerMsg {
  DbSubscriptionOpened(Date, fn() -> Nil)
  UserUpdatedMealTitle(Date, Meal, String)
  UserToggledMealComplete(Date, Meal, Bool)
  UserFetchedPlan(Date)
  DbRetrievedPlan(PlanWeek, Date)
  DbSubscribedPlan(Dynamic)
  DbSavedPlan(Date)
  UserSavedPlan
}

pub type PlanWeek =
  Dict(Date, PlanDay)

pub type PlannerModel {
  PlannerModel(plan_week: PlanWeek, recipe_list: List(String), start_date: Date)
}

pub type Meal {
  Lunch
  Dinner
}

//-UPDATE---------------------------------------------

// Helper function to extract recipe name from PlannedRecipe
fn recipe_name(recipe: Option(types.PlannedRecipe)) -> String {
  case recipe {
    Some(types.RecipeSlug(slug)) -> slug
    Some(types.RecipeName(name)) -> name
    None -> ""
  }
}

fn update_meal_title_in_plan(
  current: PlanWeek,
  date: Date,
  meal: Meal,
  value: String,
) -> PlanWeek {
  dict.upsert(current, date, fn(a) {
    PlanDay(date: date, planned_meals: case a {
      Some(a) ->
        case value {
          "" ->
            a.planned_meals
            |> list.filter(fn(a) { a.for != meal })
          _ -> {
            let tup =
              a.planned_meals
              |> list.split_while(fn(b) { b.for == meal })
            case tup {
              #([], b) ->
                list.append(
                  [
                    PlannedMealWithStatus(
                      for: meal,
                      recipe: Some(types.RecipeName(value)),
                      complete: None,
                    ),
                  ],
                  b,
                )
              #([a], b) ->
                list.append(
                  [
                    PlannedMealWithStatus(
                      ..a,
                      recipe: Some(types.RecipeName(value)),
                    ),
                  ],
                  b,
                )
              #(_, _) -> []
            }
          }
        }
      None -> [
        PlannedMealWithStatus(
          for: meal,
          recipe: Some(types.RecipeName(value)),
          complete: None,
        ),
      ]
    })
  })
}

fn toggle_meal_complete_in_plan(
  current: PlanWeek,
  date: Date,
  meal: Meal,
  complete: Bool,
) -> PlanWeek {
  utils.dict_update(current, date, fn(a) {
    PlanDay(
      date: date,
      planned_meals: a.planned_meals
        |> list.map(fn(b) {
          case b.for == meal {
            True -> PlannedMealWithStatus(..b, complete: Some(complete))
            False -> b
          }
        }),
    )
  })
}

pub fn planner_update(
  model: PlannerModel,
  msg: PlannerMsg,
) -> #(PlannerModel, Effect(PlannerMsg)) {
  case msg {
    UserUpdatedMealTitle(date, meal, value) -> {
      let result = update_meal_title_in_plan(model.plan_week, date, meal, value)
      #(PlannerModel(..model, plan_week: result), effect.none())
    }
    UserToggledMealComplete(date, meal, complete) -> {
      let result =
        toggle_meal_complete_in_plan(model.plan_week, date, meal, complete)
      #(PlannerModel(..model, plan_week: result), {
        use dispatch <- effect.from
        dispatch(UserSavedPlan)
      })
    }
    UserSavedPlan -> {
      #(model, save_plan(model.plan_week))
    }
    UserFetchedPlan(date) -> {
      #(PlannerModel(..model, start_date: date), get_plan(date))
    }
    //DbRetrievedPlan is handled in the layer above in app.gleam
    DbRetrievedPlan(_plan_week, _start_date) -> {
      #(model, effect.none())
    }
    // DbSubscriptionOpened is handled in the layer above in app.gleam
    DbSubscriptionOpened(_key, _callback) -> #(model, effect.none())
    DbSubscribedPlan(jsdata) -> {
      let decoder = {
        use data <- decode.subfield(
          ["data", "plan"],
          decode.list(plan_day_decoder()),
        )
        decode.success(data)
      }
      let try_decode = decode.run(jsdata, decoder)
      let try_effect = case try_decode {
        Ok([]) -> effect.none()
        Ok(plan_days) -> {
          let sorted =
            list.sort(plan_days, fn(a, b) {
              int.compare(date.to_rata_die(a.date), date.to_rata_die(b.date))
            })
          case sorted {
            [first, ..] -> {
              use dispatch <- effect.from
              sorted
              |> list.map(fn(x: PlanDay) { #(x.date, x) })
              |> dict.from_list
              |> DbRetrievedPlan(first.date)
              |> dispatch
            }
            [] -> effect.none()
          }
        }
        Error(_) -> effect.none()
      }
      #(model, try_effect)
    }
    DbSavedPlan(_date) -> {
      #(model, effect.none())
    }
  }
}

pub fn get_plan(start_date: Date) -> Effect(PlannerMsg) {
  use dispatch <- effect.from
  do_get_plan(
    date.to_rata_die(start_date),
    date.to_rata_die(date.add(start_date, 1, date.Weeks)),
  )
  |> echo
  |> promise.map(decode.run(_, decode.list(plan_day_decoder())))
  |> promise.map(result.map(_, list.map(_, fn(x: PlanDay) { #(x.date, x) })))
  |> promise.map(result.map(_, dict.from_list))
  |> promise.map(result.map(_, DbRetrievedPlan(_, start_date)))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, ".././db.ts", "do_get_plan")
fn do_get_plan(start_date: Int, end_date: Int) -> Promise(Dynamic)

pub fn subscribe_to_plan(start_date: Date) -> Effect(PlannerMsg) {
  use dispatch <- effect.from
  do_subscribe_to_plan(
    fn(data) {
      data
      |> DbSubscribedPlan
      |> dispatch
    },
    date.to_rata_die(start_date),
    date.to_rata_die(date.add(start_date, 6, date.Days)),
  )
  |> DbSubscriptionOpened(start_date, _)
  |> dispatch
  Nil
}

@external(javascript, ".././db.ts", "do_subscribe_to_plan")
fn do_subscribe_to_plan(
  callback: fn(a) -> Nil,
  start_date: Int,
  end_date: Int,
) -> fn() -> Nil

pub fn save_plan(planweek: PlanWeek) -> Effect(PlannerMsg) {
  use dispatch <- effect.from
  do_save_plan(list.map(dict.values(planweek), encode_plan_day))

  let first_day =
    dict.keys(planweek)
    |> list.sort(date.compare)
    |> list.first
  result.unwrap(first_day, date.today())
  |> DbSavedPlan
  |> dispatch
}

@external(javascript, ".././db.ts", "do_save_plan")
fn do_save_plan(planweek: List(JsPlanDay)) -> Nil

//-VIEWS-------------------------------------------------------------

pub fn view_planner(model: PlannerModel) {
  let start_of_week = date.floor(model.start_date, date.Monday)
  let find_in_week = fn(a) {
    result.unwrap(dict.get(model.plan_week, a), PlanDay(a, []))
  }
  let week =
    dict.from_list([
      #(start_of_week, find_in_week(start_of_week)),
      #(
        date.add(start_of_week, 1, date.Days),
        find_in_week(date.add(start_of_week, 1, date.Days)),
      ),
      #(
        date.add(start_of_week, 2, date.Days),
        find_in_week(date.add(start_of_week, 2, date.Days)),
      ),
      #(
        date.add(start_of_week, 3, date.Days),
        find_in_week(date.add(start_of_week, 3, date.Days)),
      ),
      #(
        date.add(start_of_week, 4, date.Days),
        find_in_week(date.add(start_of_week, 4, date.Days)),
      ),
      #(
        date.add(start_of_week, 5, date.Days),
        find_in_week(date.add(start_of_week, 5, date.Days)),
      ),
      #(
        date.add(start_of_week, 6, date.Days),
        find_in_week(date.add(start_of_week, 6, date.Days)),
      ),
    ])
  section(
    [
      class(
        "grid grid-cols-12 h-env-screen col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
    ],
    [
      page_title(
        "Week of " <> utils.month_date_string(start_of_week),
        "underline-orange col-span-full md:col-span-11",
      ),
      section(
        [
          id("active-week"),
          class(
            "mb-2 text-sm p-1
            overflow-x-hidden overflow-y-scroll md:overflow-x-scroll md:overflow-y-hidden snap-mandatory snap-always
            col-span-full row-start-2 grid gap-1 
            grid-cols-[minmax(0,15%)_minmax(0,45%)_minmax(0,45%)] grid-rows-[fit-content(10%)_repeat(7,20%)]
            snap-y scroll-pt-[9%]
            md:text-base md:grid-cols-[fit-content(10%)_repeat(7,_15vw)] md:grid-rows-[fit-content(20%)_minmax(20vh,1fr)_minmax(20vh,1fr)]
            md:snap-x md:scroll-pl-[9%] md:scroll-pt-0
            xl:grid-cols-[fit-content(10%)_repeat(7,_11.5vw)]",
          ),
        ],
        [
          planner_header_row(week),
          fragment({
            dict.values(week)
            |> list.sort(fn(a, b) { date.compare(a.date, b.date) })
            |> list.index_map(fn(x, i) { planner_meal_card(x, i, Lunch) })
          }),
          fragment({
            dict.values(week)
            |> list.sort(fn(a, b) { date.compare(a.date, b.date) })
            |> list.index_map(fn(x, i) { planner_meal_card(x, i, Dinner) })
          }),
        ],
      ),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a(
          [
            href("/planner/edit?date=" <> date.to_iso_string(start_of_week)),
            class("text-center"),
          ],
          [text("✏️")],
        ),
        a(
          [
            href(
              "/planner?date="
              <> date.to_iso_string(date.add(start_of_week, -1, date.Weeks)),
            ),
            class("text-center"),
          ],
          [text("⬅️")],
        ),
        a(
          [
            href(
              "/planner?date="
              <> date.to_iso_string(date.add(start_of_week, 1, date.Weeks)),
            ),
            class("text-center"),
          ],
          [text("➡️")],
        ),
      ]),
    ],
  )
}

pub fn edit_planner(model: PlannerModel) {
  let start_of_week = date.floor(model.start_date, date.Monday)
  let find_in_week = fn(a) {
    result.unwrap(dict.get(model.plan_week, a), PlanDay(a, []))
  }
  let week =
    dict.from_list([
      #(start_of_week, find_in_week(start_of_week)),
      #(
        date.add(start_of_week, 1, date.Days),
        find_in_week(date.add(start_of_week, 1, date.Days)),
      ),
      #(
        date.add(start_of_week, 2, date.Days),
        find_in_week(date.add(start_of_week, 2, date.Days)),
      ),
      #(
        date.add(start_of_week, 3, date.Days),
        find_in_week(date.add(start_of_week, 3, date.Days)),
      ),
      #(
        date.add(start_of_week, 4, date.Days),
        find_in_week(date.add(start_of_week, 4, date.Days)),
      ),
      #(
        date.add(start_of_week, 5, date.Days),
        find_in_week(date.add(start_of_week, 5, date.Days)),
      ),
      #(
        date.add(start_of_week, 6, date.Days),
        find_in_week(date.add(start_of_week, 6, date.Days)),
      ),
    ])
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
    ],
    [
      page_title(
        "Week of " <> utils.month_date_string(start_of_week),
        "underline-orange col-span-full md:col-span-11",
      ),
      form(
        [
          id("active-week"),
          class(
            "mb-2 text-sm p-1 
            overflow-x-hidden overflow-y-scroll md:overflow-x-scroll md:overflow-y-hidden snap-mandatory snap-always
            col-span-full row-start-2 grid gap-1 
            grid-cols-[minmax(0,15%)_minmax(0,45%)_minmax(0,45%)] grid-rows-[fit-content(10%)_repeat(7,20%)]
            snap-y scroll-pt-[9%]
            md:text-base md:grid-cols-[fit-content(10%)_repeat(7,_15vw)] md:grid-rows-[fit-content(20%)_minmax(20vh,1fr)_minmax(20vh,1fr)]
            md:snap-x md:scroll-pl-[9%] md:scroll-pt-0
            xl:grid-cols-[fit-content(10%)_repeat(7,_11.5vw)]",
          ),
          on_submit(fn(_x) { UserSavedPlan }),
        ],
        [
          planner_header_row(week),
          planner_input_row(Lunch, week, model.recipe_list),
          planner_input_row(Dinner, week, model.recipe_list),
        ],
      ),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        a(
          [
            href("/planner?date=" <> date.to_iso_string(start_of_week)),
            class("text-center"),
          ],
          [text("❎")],
        ),
        button([type_("submit"), attribute("form", "active-week"), class("")], [
          text("💾"),
        ]),
        a(
          [
            href(
              "/planner/edit?date="
              <> date.to_iso_string(date.add(start_of_week, -1, date.Weeks)),
            ),
            class("text-center"),
          ],
          [text("⬅️")],
        ),
        a(
          [
            href(
              "/planner/edit?date="
              <> date.to_iso_string(date.add(start_of_week, 1, date.Weeks)),
            ),
            class("text-center"),
          ],
          [text("➡️")],
        ),
      ]),
    ],
  )
}

//-COMPONENTS--------------------------------------------------

fn planner_header_row(dates: PlanWeek) -> Element(PlannerMsg) {
  let date_keys =
    dict.to_list(dates)
    |> list.map(pair.map_first(_, fn(d) { date.weekday(d) }))
    |> dict.from_list

  let monday =
    dict.get(date_keys, date.Mon)
    |> result.map(fn(d) { utils.date_num_string(d.date) })
    |> result.unwrap("")
  let tuesday =
    dict.get(date_keys, date.Tue)
    |> result.map(fn(d) { utils.date_num_string(d.date) })
    |> result.unwrap("")
  let wednesday =
    dict.get(date_keys, date.Wed)
    |> result.map(fn(d) { utils.date_num_string(d.date) })
    |> result.unwrap("")
  let thursday =
    dict.get(date_keys, date.Thu)
    |> result.map(fn(d) { utils.date_num_string(d.date) })
    |> result.unwrap("")
  let friday =
    dict.get(date_keys, date.Fri)
    |> result.map(fn(d) { utils.date_num_string(d.date) })
    |> result.unwrap("")
  let saturday =
    dict.get(date_keys, date.Sat)
    |> result.map(fn(d) { utils.date_num_string(d.date) })
    |> result.unwrap("")
  let sunday =
    dict.get(date_keys, date.Sun)
    |> result.map(fn(d) { utils.date_num_string(d.date) })
    |> result.unwrap("")

  element.fragment([
    div(
      [
        class(
          "subgrid-cols md:col-start-1 row-start-1 subgrid-rows col-span-full md:row-span-full md:col-span-1 sticky left-[-.25rem] top-[-.25rem] outline-1 outline-ecru-white-50 border  border-ecru-white-50 bg-ecru-white-50 min-h-full min-w-full",
        ),
      ],
      [
        div(
          [
            class(
              "md:row-start-2 md:col-start-1 font-mono col-start-2 flex justify-center items-center border border-ecru-white-950 shadow-orangep-0 bg-ecru-white-50",
            ),
          ],
          [h2([class("mx-2 ")], [text("Lunch")])],
        ),
        div(
          [
            class(
              "md:row-start-3 md:col-start-1 font-mono col-start-3 flex justify-center items-center border border-ecru-white-950  shadow-orange sticky left-0 top-0 bg-ecru-white-50",
            ),
          ],
          [h2([class("mx-2 ")], [text("Dinner")])],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-2 md:row-start-1 font-mono row-start-2 border border-ecru-white-950 flex justify-center items-center shadow-orange",
        ),
      ],
      [
        h2(
          [
            styles([
              #("--shortMon", "'Mon " <> monday <> "'"),
              #("--longMon", "'Monday " <> monday <> "'"),
            ]),
            class(
              "text-center  before:content-(--shortMon) before:sm:content-(--longMon)",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-3 md:row-start-1 font-mono row-start-3  border border-ecru-white-950   flex justify-center items-center shadow-orange",
        ),
      ],
      [
        h2(
          [
            styles([
              #("--shortTue", "'Tue " <> tuesday <> "'"),
              #("--longTue", "'Tuesday " <> tuesday <> "'"),
            ]),
            class(
              "text-center  before:content-(--shortTue) before:sm:content-(--longTue)",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-4 md:row-start-1 font-mono row-start-4  border border-ecru-white-950   flex justify-center items-center shadow-orange",
        ),
      ],
      [
        h2(
          [
            styles([
              #("--shortWed", "'Wed " <> wednesday <> "'"),
              #("--longWed", "'Wednesday " <> wednesday <> "'"),
            ]),
            class(
              "text-center  before:content-(--shortWed) before:sm:content-(--longWed)",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-5 md:row-start-1 font-mono row-start-5  border border-ecru-white-950   flex justify-center items-center shadow-orange",
        ),
      ],
      [
        h2(
          [
            styles([
              #("--shortThu", "'Thu " <> thursday <> "'"),
              #("--longThu", "'Thursday " <> thursday <> "'"),
            ]),
            class(
              "text-center  before:content-(--shortThu) before:sm:content-(--longThu)",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-6 md:row-start-1 font-mono row-start-6  border border-ecru-white-950   flex justify-center items-center shadow-orange",
        ),
      ],
      [
        h2(
          [
            styles([
              #("--shortFri", "'Fri " <> friday <> "'"),
              #("--longFri", "'Friday " <> friday <> "'"),
            ]),
            class(
              "text-center  before:content-(--shortFri) before:sm:content-(--longFri)",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-7 md:row-start-1 font-mono row-start-7  border border-ecru-white-950  flex justify-center items-center shadow-orange",
        ),
      ],
      [
        h2(
          [
            styles([
              #("--shortSat", "'Sat " <> saturday <> "'"),
              #("--longSat", "'Saturday " <> saturday <> "'"),
            ]),
            class(
              "text-center  before:content-(--shortSat) before:sm:content-(--longSat)",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-8 md:row-start-1 font-mono row-start-8 border border-ecru-white-950   flex justify-center items-center shadow-orange",
        ),
      ],
      [
        h2(
          [
            styles([
              #("--shortSun", "'Sun " <> sunday <> "'"),
              #("--longSun", "'Sunday " <> sunday <> "'"),
            ]),
            class(
              "text-center  before:content-(--shortSun) before:sm:content-(--longSun)",
            ),
          ],
          [],
        ),
      ],
    ),
  ])
}

fn planner_input_row(
  for: Meal,
  week: PlanWeek,
  recipe_list: List(String),
) -> Element(PlannerMsg) {
  keyed.fragment({
    dict.values(week)
    |> list.sort(fn(a, b) { date.compare(a.date, b.date) })
    |> list.index_map(fn(x, i) {
      #(int.to_string(i), planner_meal_input(x, i, for, recipe_list))
    })
  })
}

fn planner_meal_card(pd: PlanDay, i: Int, for: Meal) -> Element(PlannerMsg) {
  let row = case for {
    Lunch -> "col-start-2 md:row-start-2"
    Dinner -> "col-start-3 md:row-start-3"
  }
  let card = {
    use <- bool.guard(when: pd.planned_meals == [], return: element.none())
    list.filter(pd.planned_meals, fn(a) { a.for == for })
    |> list.map(inner_card(pd.date, _))
    |> element.fragment
  }
  div(
    [class("flex outline-1 outline-ecru-white-950 outline outline-offset-[-1px]
                row-start-[var(--dayPlacement)]
                md:col-start-[var(--dayPlacement)] 
                snap-start scroll-p-[-40px] " <> row), styles([
        #("--dayPlacement", int.to_string(i + 2)),
      ])],
    [card],
  )
}

fn inner_card(date: Date, meal: PlannedMealWithStatus) -> Element(PlannerMsg) {
  let PlannedMealWithStatus(_f, r, c) = meal
  div(
    [
      class("flex flex-row gap-1 overflow-y-scroll items-baseline h-11/12 m-1"),
    ],
    [
      input([
        type_("checkbox"),
        class("inline"),
        event.on_check(fn(a) { UserToggledMealComplete(date, meal.for, a) }),
        checked(option.unwrap(meal.complete, False)),
      ]),
      h2(
        [
          class("text-xl text-wrap"),
          styles([
            #("text-decoration", {
              use <- bool.guard(
                when: option.unwrap(c, False),
                return: "line-through",
              )
              "none"
            }),
          ]),
        ],
        [text(recipe_name(r))],
      ),
    ],
  )
}

fn planner_meal_input(
  pd: PlanDay,
  i: Int,
  for: Meal,
  recipe_titles: List(String),
) -> Element(PlannerMsg) {
  let row = case for {
    Lunch -> "col-start-2 md:row-start-2"
    Dinner -> "col-start-3 md:row-start-3"
  }
  let card = {
    use <- bool.guard(
      when: pd.planned_meals == [],
      return: inner_input(pd.date, for, "", recipe_titles),
    )
    use <- bool.guard(
      when: list.filter(pd.planned_meals, fn(a) { a.for == for }) == [],
      return: inner_input(pd.date, for, "", recipe_titles),
    )
    list.filter(pd.planned_meals, fn(a) { a.for == for })
    |> list.map(fn(a) {
      inner_input(pd.date, for, recipe_name(a.recipe), recipe_titles)
    })
    |> element.fragment
  }
  div(
    [class("flex outline-1 outline-ecru-white-950 outline outline-offset-[-1px]
                row-start-[var(--dayPlacement)]
                md:col-start-[var(--dayPlacement)] 
                snap-start scroll-p-[-40px] " <> row), styles([
        #("--dayPlacement", int.to_string(i + 2)),
      ])],
    [card],
  )
}

fn inner_input(
  date: Date,
  for: Meal,
  title: String,
  recipe_titles: List(String),
) -> Element(PlannerMsg) {
  div([class("flex justify-center w-11/12 h-11/12 flex-col m-1 sm:m-2")], [
    typeahead([
      typeahead.recipe_titles(recipe_titles),
      typeahead.search_term(title),
      event.on("typeahead-change", {
        use res <- decode.subfield(["detail"], decode.string)
        decode.success(UserUpdatedMealTitle(date, for, res))
      }),
    ]),
  ])
}

//-ENCODERS-DECODERS----------------------------------------------

fn plan_day_decoder() -> decode.Decoder(PlanDay) {
  use date <- decode.field(
    "date",
    decode.int |> decode.map(fn(a) { date.from_rata_die(a) }),
  )
  use planned_meals <- decode.field(
    "planned_meals",
    codecs.json_string_decoder(planned_meals_decoder(), []),
  )
  decode.success(PlanDay(date: date, planned_meals: planned_meals))
}

fn planned_meals_decoder() -> decode.Decoder(List(PlannedMealWithStatus)) {
  let enum_decoder = {
    use decoded_string <- decode.then(decode.string)
    case decoded_string {
      "lunch" -> decode.success(Lunch)
      "dinner" -> decode.success(Dinner)
      _ -> decode.failure(Lunch, "Meal")
    }
  }
  let recipe_name_decoder = {
    use recipe_str <- decode.then(decode.string)
    decode.success(types.RecipeName(recipe_str))
  }
  let recipe_id_decoder = {
    use recipe_str <- decode.then(decode.string)
    decode.success(types.RecipeSlug(recipe_str))
  }
  let record_decoder = {
    use for <- decode.field("for", enum_decoder)
    use title <- decode.optional_field(
      "title",
      option.None,
      decode.optional(recipe_name_decoder),
    )
    use recipe_id <- decode.optional_field(
      "recipe_id",
      option.None,
      decode.optional(recipe_id_decoder),
    )
    use recipe_name <- decode.optional_field(
      "recipe_name",
      option.None,
      decode.optional(recipe_name_decoder),
    )
    use complete <- decode.optional_field(
      "complete",
      option.None,
      decode.optional(codecs.decode_stringed_bool()),
    )
    let maybe_recipe = case title, recipe_name, recipe_id {
      Some(title), _, _ -> Some(title)
      _, Some(recipe_name), _ -> Some(recipe_name)
      _, _, Some(recipe_id) -> Some(recipe_id)
      _, _, _ -> None
    }
    decode.success(PlannedMealWithStatus(
      for: for,
      recipe: maybe_recipe,
      complete: complete,
    ))
  }
  codecs.json_string_decoder(decode.list(of: record_decoder), [])
}

fn encode_plan_day(plan_day: PlanDay) -> JsPlanDay {
  JsPlanDay(
    date: date.to_rata_die(plan_day.date),
    planned_meals: json.to_string(json_encode_planned_meals(
      plan_day.planned_meals,
    )),
  )
}

fn json_encode_planned_meals(input: List(PlannedMealWithStatus)) -> Json {
  input
  |> json.array(of: json_encode_planned_meal_with_status)
}

fn json_encode_planned_meal_with_status(meal: PlannedMealWithStatus) -> Json {
  case meal.recipe {
    Some(recipe) ->
      json.object([
        case recipe {
          types.RecipeName(name) -> #("recipe_name", json.string(name))
          types.RecipeSlug(slug) -> #("recipe_slug", json.string(slug))
        },
        #(
          "for",
          json.string(case meal.for {
            Lunch -> "lunch"
            Dinner -> "dinner"
          }),
        ),
        #(
          "complete",
          json.string(bool.to_string(option.unwrap(meal.complete, False))),
        ),
      ])
    None -> json.null()
  }
}

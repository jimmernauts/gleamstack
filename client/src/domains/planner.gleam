import components/nav_footer.{nav_footer}
import components/page_title.{page_title}
import components/typeahead_2
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
import gleam/string
import lib/utils
import lustre/attribute.{checked, class, href, id, styles, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment, text}
import lustre/element/html.{a, button, div, h2, input, section}
import lustre/event
import rada/date.{type Date}
import shared/codecs
import shared/types

//-TYPES-------------------------------------------------------------

pub type PlannedMeal {
  PlannedMeal(recipe: types.PlannedRecipe, complete: Bool)
}

pub type PlanDay {
  PlanDay(date: Date, lunch: Option(PlannedMeal), dinner: Option(PlannedMeal))
}

pub type JsPlanDay {
  JsPlanDay(date: Int, lunch: Option(String), dinner: Option(String))
}

pub type EditingMeal {
  EditingMeal(day: PlanDay, meal: Meal)
}

pub type PlannerMsg {
  DbSubscriptionOpened(Date, fn() -> Nil)
  UserUpdatedMealTitle(Date, Meal, types.PlannedRecipe)
  UserToggledMealComplete(Date, Meal, Bool)
  UserFetchedPlan(Date)
  DbRetrievedPlan(PlanWeek, Date)
  DbSubscribedPlan(Dynamic)
  DbSavedPlan(Date)
  UserSavedPlan
  UserClickedEditMeal(PlanDay, Meal)
  UserCancelledEditMeal
  UserSavedEditMeal
  PlannerNoOp
}

pub type PlanWeek =
  Dict(Date, PlanDay)

pub type PlannerModel {
  PlannerModel(
    plan_week: PlanWeek,
    recipe_list: List(types.Recipe),
    start_date: Date,
    editing: Option(EditingMeal),
  )
}

pub type Meal {
  Lunch
  Dinner
}

//-UPDATE---------------------------------------------

fn update_meal_title_in_plan(
  current: PlanWeek,
  date: Date,
  meal: Meal,
  value: types.PlannedRecipe,
) -> PlanWeek {
  dict.upsert(current, date, fn(a) {
    let day =
      a
      |> option.lazy_unwrap(fn() {
        PlanDay(date: date, lunch: None, dinner: None)
      })
    case meal {
      Lunch ->
        case value {
          types.RecipeName("") -> PlanDay(..day, lunch: None)
          _ ->
            PlanDay(
              ..day,
              lunch: Some(
                day.lunch
                |> option.map(fn(m) { PlannedMeal(..m, recipe: value) })
                |> option.lazy_unwrap(fn() { PlannedMeal(value, False) }),
              ),
            )
        }
      Dinner ->
        case value {
          types.RecipeName("") -> PlanDay(..day, dinner: None)
          _ ->
            PlanDay(
              ..day,
              dinner: Some(
                day.dinner
                |> option.map(fn(m) { PlannedMeal(..m, recipe: value) })
                |> option.lazy_unwrap(fn() { PlannedMeal(value, False) }),
              ),
            )
        }
    }
  })
}

fn toggle_meal_complete_in_plan(
  current: PlanWeek,
  date: Date,
  meal: Meal,
  complete: Bool,
) -> PlanWeek {
  utils.dict_update(current, date, fn(day) {
    case meal {
      Lunch ->
        PlanDay(
          ..day,
          lunch: option.map(day.lunch, fn(m) { PlannedMeal(..m, complete:) }),
        )
      Dinner ->
        PlanDay(
          ..day,
          dinner: option.map(day.dinner, fn(m) { PlannedMeal(..m, complete:) }),
        )
    }
  })
}

pub fn planner_update(
  model: PlannerModel,
  msg: PlannerMsg,
) -> #(PlannerModel, Effect(PlannerMsg)) {
  echo msg
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
    UserClickedEditMeal(day, meal) -> {
      #(
        PlannerModel(..model, editing: Some(EditingMeal(day, meal))),
        effect.none(),
      )
    }
    UserCancelledEditMeal -> {
      #(PlannerModel(..model, editing: None), effect.none())
    }
    UserSavedEditMeal -> {
      #(PlannerModel(..model, editing: None), {
        use dispatch <- effect.from
        UserSavedPlan |> dispatch
      })
    }
    PlannerNoOp -> #(model, effect.none())
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
    result.unwrap(
      dict.get(model.plan_week, a),
      PlanDay(date: a, lunch: None, dinner: None),
    )
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
            "m-1 text-sm
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
          case model.editing {
            None -> element.none()
            Some(EditingMeal(day, meal)) ->
              view_edit_popover(day, meal, model.recipe_list)
          },
        ],
      ),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
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
          "subgrid-cols md:col-start-1 row-start-1 subgrid-rows col-span-full md:row-span-full md:col-span-1 sticky left-0 top-0 outline-1 outline-ecru-white-50 border  border-ecru-white-50 bg-ecru-white-50 min-h-full min-w-full  z-100",
        ),
      ],
      [
        div(
          [
            class(
              "md:row-start-2 md:col-start-1 font-mono col-start-2 flex justify-center items-center border border-ecru-white-950 shadow-orange bg-ecru-white-50",
            ),
          ],
          [h2([class("mx-2 ")], [text("Lunch")])],
        ),
        div(
          [
            class(
              "md:row-start-3 md:col-start-1 font-mono col-start-3 flex justify-center items-center border border-ecru-white-950  shadow-orange bg-ecru-white-50 z-100",
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

fn planner_meal_card(pd: PlanDay, i: Int, for: Meal) -> Element(PlannerMsg) {
  let row = case for {
    Lunch -> "col-start-2 md:row-start-2"
    Dinner -> "col-start-3 md:row-start-3"
  }
  let card = case for {
    Lunch -> inner_card(pd.date, Lunch, pd.lunch)
    Dinner -> inner_card(pd.date, Dinner, pd.dinner)
  }
  div(
    [
      class(
        "group relative flex min-h-full min-w-full outline-1 outline-ecru-white-950 outline outline-offset-[-1px]
                row-start-[var(--dayPlacement)]
                md:col-start-[var(--dayPlacement)]
                snap-start scroll-p-[-40px] cursor-pointer hover:bg-ecru-white-100 "
        <> row,
      ),
      styles([#("--dayPlacement", int.to_string(i + 2))]),
      event.on_click(UserClickedEditMeal(pd, for)),
    ],
    [card],
  )
}

fn inner_card(
  date: Date,
  for: Meal,
  planned_meal: Option(PlannedMeal),
) -> Element(PlannerMsg) {
  let recipe_title = case planned_meal {
    Some(m) ->
      case m.recipe {
        types.RecipeSlug(slug) -> slug
        types.RecipeName(name) -> name
      }
    None -> ""
  }

  let is_complete = case planned_meal {
    Some(m) -> m.complete
    None -> False
  }

  let card = case recipe_title == "" {
    True -> element.none()
    False ->
      div(
        [
          class(
            "flex m-2 flex-row items-baseline gap-1 overflow-y-auto overflow-x-hidden",
          ),
        ],
        [
          input([
            type_("checkbox"),
            class("absolute top-2 right-2 cursor-pointer"),
            event.on_check(fn(a) { UserToggledMealComplete(date, for, a) }),
            event.advanced(
              "click",
              decode.success(event.handler(PlannerNoOp, False, True)),
            ),
            checked(is_complete),
          ]),
          h2(
            [
              class("text-xl text-wrap leading-tight"),
              styles([
                #("text-decoration", {
                  use <- bool.guard(when: is_complete, return: "line-through")
                  "none"
                }),
              ]),
            ],
            [text(recipe_title)],
          ),
        ],
      )
  }
  card
}

fn view_edit_popover(
  day: PlanDay,
  meal: Meal,
  recipe_list: List(types.Recipe),
) -> Element(PlannerMsg) {
  let current_meal = case meal {
    Lunch -> day.lunch
    Dinner -> day.dinner
  }
  let day_index = date.weekday_number(day.date)

  let current_planned_recipe = case current_meal {
    Some(m) -> Some(m.recipe)
    None -> Some(types.RecipeName(""))
  }

  div(
    [
      class(
        "col-span-2 col-start-2 w-full h-full z-[100] flex items-center justify-center bg-ecru-white-50",
      ),
      class("md:col-start-" <> int.to_string(day_index + 1)),
      class(
        "md:row-start-"
        <> {
          case meal {
            Lunch -> "2"
            Dinner -> "3"
          }
        },
      ),
      class("row-start-" <> int.to_string(day_index + 1)),
      event.on_click(UserCancelledEditMeal),
    ],
    [
      html.fieldset(
        [
          class(
            "relative w-full max-w-lg h-full grid gap-1 grid-rows-[1fr_auto] border border-ecru-white-950 bg-ecru-white-50 px-2 pt-1 shadow-orange overflow-auto",
          ),
          event.advanced(
            "click",
            decode.success(event.handler(PlannerNoOp, False, True)),
          ),
        ],
        [
          html.legend([class("mx-2 px-1 text-sm font-mono")], [
            text(case meal {
              Lunch -> "Lunch"
              Dinner -> "Dinner"
            }),
          ]),
          typeahead_2.typeahead([
            typeahead_2.recipes(recipe_list),
            typeahead_2.search_term(option.unwrap(
              current_planned_recipe,
              types.RecipeName(""),
            )),
            event.on("typeahead-change", {
              use res <- decode.subfield(["detail"], decode.string)
              case json.parse(res, codecs.planned_recipe_decoder()) {
                Ok(planned_recipe) ->
                  decode.success(UserUpdatedMealTitle(
                    day.date,
                    meal,
                    planned_recipe,
                  ))
                Error(_) ->
                  decode.failure(
                    UserUpdatedMealTitle(day.date, meal, types.RecipeName("")),
                    "PlannedRecipe",
                  )
              }
            }),
          ]),
          div(
            [class("flex flex-row flex-wrap text-base gap-2 justify-around")],
            [
              button(
                [
                  class("cursor-pointer"),
                  event.on_click(UserCancelledEditMeal),
                ],
                [text("⬅️")],
              ),
              button(
                [
                  class("cursor-pointer"),
                  event.on_click(UserSavedEditMeal),
                ],
                [text("💾")],
              ),
            ],
          ),
        ],
      ),
    ],
  )
}

//-ENCODERS-DECODERS----------------------------------------------

fn plan_day_decoder() -> decode.Decoder(PlanDay) {
  use date <- decode.field(
    "date",
    decode.int |> decode.map(fn(a) { date.from_rata_die(a) }),
  )
  use lunch <- decode.optional_field(
    "lunch",
    option.None,
    decode.optional(codecs.json_string_decoder(
      planned_meal_decoder(),
      PlannedMeal(types.RecipeName(""), False),
    )),
  )
  use dinner <- decode.optional_field(
    "dinner",
    option.None,
    decode.optional(codecs.json_string_decoder(
      planned_meal_decoder(),
      PlannedMeal(types.RecipeName(""), False),
    )),
  )
  decode.success(PlanDay(date: date, lunch: lunch, dinner: dinner))
}

fn planned_meal_decoder() -> decode.Decoder(PlannedMeal) {
  use recipe <- decode.field("recipe", codecs.planned_recipe_decoder())
  use complete <- decode.field("complete", decode.bool)
  decode.success(PlannedMeal(recipe:, complete:))
}

fn encode_plan_day(plan_day: PlanDay) -> JsPlanDay {
  JsPlanDay(
    date: date.to_rata_die(plan_day.date),
    lunch: plan_day.lunch
      |> option.map(json_encode_planned_meal)
      |> option.map(json.to_string),
    dinner: plan_day.dinner
      |> option.map(json_encode_planned_meal)
      |> option.map(json.to_string),
  )
}

fn json_encode_planned_meal(input: PlannedMeal) -> Json {
  json.object([
    #("recipe", codecs.encode_planned_recipe(input.recipe)),
    #("complete", json.bool(input.complete)),
  ])
}

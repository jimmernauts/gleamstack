import components/page_title.{page_title}
import components/typeahead.{typeahead}
import decipher
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/io
import gleam/javascript/array.{type Array}
import gleam/javascript/map.{type Map}
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import lib/utils
import lustre/attribute.{attribute, checked, class, href, id, style, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element, element, fragment, text}
import lustre/element/html.{
  a, button, div, form, h2, input, nav, option, section,
}
import lustre/event.{on_submit}
import rada/date.{type Date}
import session

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
    title: Option(String),
    complete: Option(Bool),
  )
}

pub type PlannerMsg {
  UserUpdatedMealTitle(Date, Meal, String)
  UserToggledMealComplete(Date, Meal, Bool)
  UserFetchedPlan(Date)
  DbRetrievedPlan(PlanWeek, Date)
  DbSavedPlan(Date)
  UserSavedPlan
}

pub type PlanWeek =
  Dict(Date, PlanDay)

pub type Model {
  Model(plan_week: PlanWeek, recipe_list: List(String), start_date: Date)
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
  value: String,
) -> PlanWeek {
  dict.upsert(current, date, fn(a) {
    PlanDay(date: date, planned_meals: case a {
      Some(a) ->
        case value {
          "" ->
            a.planned_meals
            |> list.filter(fn(a) { a.for != meal })
          _ ->
            a.planned_meals
            |> list.map(fn(b) {
              case b.for == meal {
                True -> PlannedMealWithStatus(..b, title: Some(value))
                False -> b
              }
            })
        }
      None -> [
        PlannedMealWithStatus(for: meal, title: Some(value), complete: None),
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
  model: Model,
  msg: PlannerMsg,
) -> #(Model, Effect(PlannerMsg)) {
  io.debug(msg)
  case msg {
    //TODO: have a separate event handler for the checkboxes that operates on the individual mealday, not the whole week
    UserUpdatedMealTitle(date, meal, value) -> {
      let result = update_meal_title_in_plan(model.plan_week, date, meal, value)
      #(Model(..model, plan_week: result), effect.none())
    }
    UserToggledMealComplete(date, meal, complete) -> {
      let result =
        toggle_meal_complete_in_plan(model.plan_week, date, meal, complete)
      #(Model(..model, plan_week: result), save_plan(result))
    }
    UserSavedPlan -> {
      #(model, save_plan(model.plan_week))
    }
    UserFetchedPlan(date) -> {
      #(Model(..model, start_date: date), get_plan(date))
    }
    //DbRetrievedPlan is handled in the layer above in app.gleam
    DbRetrievedPlan(_plan_week, _start_date) -> {
      #(model, effect.none())
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
  |> promise.map(dynamic.dict(decode_string_day, decode_plan_day))
  |> promise.map(result.map(_, DbRetrievedPlan(_, start_date)))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, ".././db3.ts", "do_get_plan")
fn do_get_plan(start_date: Int, end_date: Int) -> Promise(Dynamic)

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

@external(javascript, ".././db3.ts", "do_save_plan")
fn do_save_plan(planweek: List(JsPlanDay)) -> Nil

//-VIEWS-------------------------------------------------------------

pub fn view_planner(model: Model) {
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

  fragment([
    section(
      [
        class(
          "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(65px)] gap-y-2",
        ),
      ],
      [
        page_title(
          "Week of " <> utils.month_date_string(start_of_week),
          "underline-orange",
        ),
        nav(
          [
            class(
              "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4",
            ),
          ],
          [
            a([href("/"), class("text-center")], [text("🏠")]),
            a([href("/planner/edit"), class("text-center")], [text("✏️")]),
            div([class("flex flex-row justify-evenly px-1")], [
              button(
                [
                  class("text-center"),
                  event.on_click(
                    UserFetchedPlan(date.add(start_of_week, -1, date.Weeks)),
                  ),
                ],
                [text("⬅️")],
              ),
              button(
                [
                  type_("button"),
                  class("text-center"),
                  event.on_click(
                    UserFetchedPlan(date.add(start_of_week, 1, date.Weeks)),
                  ),
                ],
                [text("➡️")],
              ),
            ]),
          ],
        ),
      ],
    ),
    section(
      [
        id("active-week"),
        class(
          "mb-2 text-sm p-1 min-h-[70vh]
            overflow-x-hidden overflow-y-scroll md:overflow-x-scroll md:overflow-y-hidden snap-mandatory snap-always
            col-span-full row-start-2 grid gap-1 
            grid-cols-[minmax(0,15%)_minmax(0,45%)_minmax(0,45%)] grid-rows-[fit-content(10%)_repeat(7,20%)]
            snap-y scroll-pt-[9%]
            md:col-start-[full-start] md:col-end-[full-end]
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
  ])
}

pub fn edit_planner(model: Model) {
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

  fragment([
    section(
      [
        class(
          "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(65px)] gap-y-2",
        ),
      ],
      [
        page_title(
          "Week of " <> utils.month_date_string(start_of_week),
          "underline-orange",
        ),
        nav(
          [
            class(
              "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4",
            ),
          ],
          [
            a([href("/"), class("text-center")], [text("🏠")]),
            a([href("/planner/"), class("text-center")], [text("❎")]),
            button(
              [type_("submit"), attribute("form", "active-week"), class("")],
              [text("💾")],
            ),
          ],
        ),
      ],
    ),
    form(
      [
        id("active-week"),
        class(
          "mb-2 text-sm p-1 min-h-[70vh]
            overflow-x-hidden overflow-y-scroll md:overflow-x-scroll md:overflow-y-hidden snap-mandatory snap-always  
            col-span-full row-start-2 grid gap-1 
            grid-cols-[minmax(0,15%)_minmax(0,45%)_minmax(0,45%)] grid-rows-[fit-content(10%)_repeat(7,20%)]
            snap-y scroll-pt-[9%]
            md:col-start-[full-start] md:col-end-[full-end]
            md:text-base md:grid-cols-[fit-content(10%)_repeat(7,_15vw)] md:grid-rows-[fit-content(20%)_minmax(20vh,1fr)_minmax(20vh,1fr)]
            md:snap-x md:scroll-pl-[9%] md:scroll-pt-0
            xl:grid-cols-[fit-content(10%)_repeat(7,_11.5vw)]",
        ),
        on_submit(UserSavedPlan),
      ],
      [
        planner_header_row(week),
        fragment({
          dict.values(week)
          |> list.sort(fn(a, b) { date.compare(a.date, b.date) })
          |> list.index_map(fn(x, i) {
            planner_meal_input(x, i, Lunch, model.recipe_list)
          })
        }),
        fragment({
          dict.values(week)
          |> list.sort(fn(a, b) { date.compare(a.date, b.date) })
          |> list.index_map(fn(x, i) {
            planner_meal_input(x, i, Dinner, model.recipe_list)
          })
        }),
      ],
    ),
  ])
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
          "subgrid-cols md:col-start-1 row-start-1 subgrid-rows col-span-full md:row-span-full md:col-span-1 sticky left-[-.25rem] top-[-.25rem] outline outline-1 outline-ecru-white-50 border  border-ecru-white-50 bg-ecru-white-50 min-h-full min-w-full",
        ),
      ],
      [
        div(
          [
            class(
              "md:row-start-2 md:col-start-1 font-mono col-start-2 flex justify-center items-center border border-ecru-white-950 [box-shadow:1px_1px_0_#ff776a] sticky left-0 top-0 bg-ecru-white-50",
            ),
          ],
          [h2([class("mx-2")], [text("Lunch")])],
        ),
        div(
          [
            class(
              "md:row-start-3 md:col-start-1 font-mono col-start-3 flex justify-center items-center border border-ecru-white-950  [box-shadow:1px_1px_0_#ff776a] sticky left-0 top-0 bg-ecru-white-50",
            ),
          ],
          [h2([class("mx-2")], [text("Dinner")])],
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
            style([
              #("--shortMon", "'Mon " <> monday <> "'"),
              #("--longMon", "'Monday " <> monday <> "'"),
            ]),
            class(
              "text-center before:content-[var(--shortMon)] before:sm:content-[var(--longMon)]",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-3 md:row-start-1 font-mono row-start-3  border border-ecru-white-950   flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
        ),
      ],
      [
        h2(
          [
            style([
              #("--shortTue", "'Tue " <> tuesday <> "'"),
              #("--longTue", "'Tuesday " <> tuesday <> "'"),
            ]),
            class(
              "text-center before:content-[var(--shortTue)] before:sm:content-[var(--longTue)]",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-4 md:row-start-1 font-mono row-start-4  border border-ecru-white-950   flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
        ),
      ],
      [
        h2(
          [
            style([
              #("--shortWed", "'Wed " <> wednesday <> "'"),
              #("--longWed", "'Wednesday " <> wednesday <> "'"),
            ]),
            class(
              "text-center before:content-[var(--shortWed)] before:sm:content-[var(--longWed)]",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-5 md:row-start-1 font-mono row-start-5  border border-ecru-white-950   flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
        ),
      ],
      [
        h2(
          [
            style([
              #("--shortThu", "'Thu " <> thursday <> "'"),
              #("--longThu", "'Thursday " <> thursday <> "'"),
            ]),
            class(
              "text-center before:content-[var(--shortThu)] before:sm:content-[var(--longThu)]",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-6 md:row-start-1 font-mono row-start-6  border border-ecru-white-950   flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
        ),
      ],
      [
        h2(
          [
            style([
              #("--shortFri", "'Fri " <> friday <> "'"),
              #("--longFri", "'Friday " <> friday <> "'"),
            ]),
            class(
              "text-center before:content-[var(--shortFri)] before:sm:content-[var(--longFri)]",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-7 md:row-start-1 font-mono row-start-7  border border-ecru-white-950  flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
        ),
      ],
      [
        h2(
          [
            style([
              #("--shortSat", "'Sat " <> saturday <> "'"),
              #("--longSat", "'Saturday " <> saturday <> "'"),
            ]),
            class(
              "text-center before:content-[var(--shortSat)] before:sm:content-[var(--longSat)]",
            ),
          ],
          [],
        ),
      ],
    ),
    div(
      [
        class(
          "md:col-start-8 md:row-start-1 font-mono row-start-8 border border-ecru-white-950   flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
        ),
      ],
      [
        h2(
          [
            style([
              #("--shortSun", "'Sun " <> sunday <> "'"),
              #("--longSun", "'Sunday " <> sunday <> "'"),
            ]),
            class(
              "text-center before:content-[var(--shortSun)] before:sm:content-[var(--longSun)]",
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
                snap-start scroll-p-[-40px] " <> row), style([
        #("--dayPlacement", int.to_string(i + 2)),
      ])],
    [card],
  )
}

fn inner_card(date: Date, meal: PlannedMealWithStatus) -> Element(PlannerMsg) {
  let PlannedMealWithStatus(_f, t, c) = meal
  div(
    [
      class(
        "flex justify-center w-11/12 h-11/12 flex-col justify-between m-1 sm:m-2 overflow-hidden",
      ),
    ],
    [
      h2(
        [
          class("font-transitional text-xl text-wrap"),
          style([
            #("text-decoration", {
              use <- bool.guard(
                when: option.unwrap(c, False),
                return: "line-through",
              )
              "none"
            }),
          ]),
        ],
        [text(option.unwrap(t, ""))],
      ),
      div([class("flex justify-end place-self-start sm:mx-2")], [
        input([
          type_("checkbox"),
          event.on_check(fn(a) { UserToggledMealComplete(date, meal.for, a) }),
          checked(option.unwrap(meal.complete, False)),
        ]),
      ]),
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
      inner_input(pd.date, for, option.unwrap(a.title, ""), recipe_titles)
    })
    |> element.fragment
  }
  div(
    [class("flex outline-1 outline-ecru-white-950 outline outline-offset-[-1px]
                row-start-[var(--dayPlacement)]
                md:col-start-[var(--dayPlacement)] 
                snap-start scroll-p-[-40px] " <> row), style([
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
  div(
    [
      class(
        "flex justify-center w-11/12 h-11/12 flex-col justify-between m-1 sm:m-2 overflow-hidden",
      ),
    ],
    [
      typeahead([
        typeahead.recipe_titles(recipe_titles),
        typeahead.search_term(title),
        event.on("typeahead-change", fn(target) {
          target
          |> dynamic.field("detail", dynamic.string)
          |> result.map(fn(a) { UserUpdatedMealTitle(date, for, a) })
        }),
      ]),
    ],
  )
}

//-ENCODERS-DECODERS----------------------------------------------

fn decode_plan_day(d: Dynamic) -> Result(PlanDay, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode2(
      PlanDay,
      dynamic.field("date", of: decode_int_day),
      dynamic.field("planned_meals", of: decode_planned_meals),
    )
  decoder(d)
}

fn decode_int_day(d: Dynamic) -> Result(Date, dynamic.DecodeErrors) {
  let decoder = dynamic.int
  decoder(d)
  |> result.map(fn(a) { date.from_rata_die(a) })
}

fn decode_string_day(d: Dynamic) -> Result(Date, dynamic.DecodeErrors) {
  let decoder = dynamic.string
  decoder(d)
  |> result.map(int.parse)
  |> result.map(fn(a) { date.from_rata_die(result.unwrap(a, 0)) })
}

fn decode_planned_meals(
  d: Dynamic,
) -> Result(List(PlannedMealWithStatus), dynamic.DecodeErrors) {
  let decoder =
    dynamic.list(dynamic.decode3(
      PlannedMealWithStatus,
      dynamic.field(
        "for",
        decipher.enum([#("lunch", Lunch), #("dinner", Dinner)]),
      ),
      dynamic.optional_field("title", dynamic.string),
      dynamic.optional_field("complete", session.decode_stringed_bool),
    ))
  dynamic.string(d)
  |> result.map(json.decode(_, decoder))
  |> utils.result_unnest(utils.json_decodeerror_to_decodeerror)
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
  json.object([
    #("title", json.string(option.unwrap(meal.title, ""))),
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
}

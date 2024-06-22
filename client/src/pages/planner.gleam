import birl
import birl/duration
import components/page_title.{page_title}
import decipher
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/javascript/array.{type Array}
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import lib/decoders
import lustre/attribute.{
  attribute, checked, class, disabled, for, href, id, name, placeholder,
  selected, style, type_, value,
}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment, text}
import lustre/element/html.{
  a, button, div, fieldset, form, h2, input, label, legend, li, nav, ol, option,
  section, select, span, textarea,
}
import lustre/event.{on, on_check, on_click, on_input}

//-MODEL---------------------------------------------

pub type PlannerMsg {
  UserAddedMealToPlan
  UserRemovedMealFromPlan
  DbRetrievedPlan(PlanWeek)
  DbSavedPlan
}

pub type PlanWeek =
  Dict(birl.Time, PlanDay)

//-UPDATE---------------------------------------------

pub fn planner_update(
  model: PlanWeek,
  msg: PlannerMsg,
) -> #(PlanWeek, Effect(PlannerMsg)) {
  case msg {
    UserAddedMealToPlan -> {
      todo
    }
    UserRemovedMealFromPlan -> {
      todo
    }
    DbRetrievedPlan(plan_week) -> {
      #(plan_week, effect.none())
    }
    DbSavedPlan -> {
      #(model, effect.none())
    }
  }
}

pub fn get_plan() -> Effect(PlannerMsg) {
  use dispatch <- effect.from
  do_get_plan()
  |> promise.map(array.to_list)
  |> promise.map(list.map(_, decode_plan_day))
  |> promise.map(result.all)
  |> promise.map(result.map(_, list.map(_, fn(a: PlanDay) { #(a.date, a) })))
  |> promise.map(result.map(_, dict.from_list))
  |> promise.map(result.map(_, DbRetrievedPlan))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, ".././db.ts", "do_get_plan")
fn do_get_plan() -> Promise(Array(Dynamic))

pub fn save_plan(planweek: PlanWeek) -> Effect(PlannerMsg) {
  use dispatch <- effect.from
  do_save_plan(list.map(dict.values(planweek), encode_plan_day))
  DbSavedPlan |> dispatch
}

@external(javascript, ".././db.ts", "do_save_plan")
fn do_save_plan(planweek: List(JsPlanDay)) -> Nil

//-VIEWS-------------------------------------------------------------

pub fn view_planner(model: PlanWeek) {
  let today = birl.set_time_of_day(birl.now(), birl.TimeOfDay(0, 0, 0, 0))
  let day = case dict.size(model) {
    num if num > 0 -> list.first(dict.keys(model))
    _ -> Ok(today)
  }
  let start_of_week =
    result.map(day, fn(d) {
      case birl.weekday(d) {
        birl.Mon -> d
        birl.Tue -> birl.add(d, duration.days(-1))
        birl.Wed -> birl.add(d, duration.days(-2))
        birl.Thu -> birl.add(d, duration.days(-3))
        birl.Fri -> birl.add(d, duration.days(-4))
        birl.Sat -> birl.add(d, duration.days(-5))
        birl.Sun -> birl.add(d, duration.days(-6))
      }
    })
    |> result.unwrap(birl.set_time_of_day(
      birl.now(),
      birl.TimeOfDay(0, 0, 0, 0),
    ))
  let find_in_week = fn(a) {
    result.unwrap(dict.get(model, a), PlanDay(a, None, None))
  }
  let week =
    dict.from_list([
      #(start_of_week, find_in_week(start_of_week)),
      #(
        birl.add(start_of_week, duration.days(1)),
        find_in_week(birl.add(start_of_week, duration.days(1))),
      ),
      #(
        birl.add(start_of_week, duration.days(2)),
        find_in_week(birl.add(start_of_week, duration.days(2))),
      ),
      #(
        birl.add(start_of_week, duration.days(3)),
        find_in_week(birl.add(start_of_week, duration.days(3))),
      ),
      #(
        birl.add(start_of_week, duration.days(4)),
        find_in_week(birl.add(start_of_week, duration.days(4))),
      ),
      #(
        birl.add(start_of_week, duration.days(5)),
        find_in_week(birl.add(start_of_week, duration.days(5))),
      ),
      #(
        birl.add(start_of_week, duration.days(6)),
        find_in_week(birl.add(start_of_week, duration.days(6))),
      ),
    ])

  fragment([
    section(
      [
        class(
          "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr] gap-y-2",
        ),
      ],
      [
        page_title(
          "Week of " <> month_date_string(start_of_week),
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
          ],
        ),
      ],
    ),
    section(
      [
        id("active-week"),
        class(
          "mb-2 text-sm p-1 
        overflow-x-scroll overflow-y-scroll snap-mandatory snap-always
        col-span-full row-start-3 grid gap-1 
        grid-cols-[minmax(0,15%)_minmax(0,45%)_minmax(0,45%)] grid-rows-[fit-content(10%)_repeat(7,20%)]
        snap-y scroll-pt-[9%]
        xs:col-start-[full-start] xs:col-end-[full-end]
        xs:text-base xs:grid-cols-[fit-content(10%)_repeat(7,_1fr)] xs:grid-rows-[fit-content(20%)_minmax(20vh,1fr)_minmax(20vh,1fr)]
        xs:snap-x xs:scroll-pl-[9%] xs:scroll-pt-0",
        ),
      ],
      [planner_header_row(week)],
    ),
  ])
}

pub fn edit_planner(model: PlanWeek) {
  todo
}

//-COMPONENTS--------------------------------------------------

fn month_date_string(day: birl.Time) -> String {
  let n = date_num_string(day)
  let s =
    day
    |> birl.string_weekday
  let m =
    day
    |> birl.string_month
  m <> " " <> n
}

fn long_date_string(day: birl.Time) -> String {
  let n = date_num_string(day)
  let s =
    day
    |> birl.weekday
    |> birl.weekday_to_string
  s <> " " <> n
}

fn short_date_string(day: birl.Time) -> String {
  let n = date_num_string(day)
  let s =
    day
    |> birl.weekday
    |> birl.weekday_to_short_string
  s <> " " <> n
}

fn date_num_string(day: birl.Time) -> String {
  day
  |> birl.get_day
  |> fn(d: birl.Day) { d.date }
  |> int.to_string
}

fn planner_header(date: birl.Time) -> Element(PlannerMsg) {
  todo
}

// FIX HEADER ROW
fn planner_header_row(dates: PlanWeek) -> Element(PlannerMsg) {
  let date_keys =
    dict.to_list(dates)
    |> list.map(pair.map_first(_, fn(d) { birl.weekday(d) }))
    |> dict.from_list

  let monday =
    dict.get(date_keys, birl.Mon)
    |> result.map(fn(d) { date_num_string(d.date) })
    |> result.unwrap("")
  let tuesday =
    dict.get(date_keys, birl.Tue)
    |> result.map(fn(d) { date_num_string(d.date) })
    |> result.unwrap("")
  let wednesday =
    dict.get(date_keys, birl.Wed)
    |> result.map(fn(d) { date_num_string(d.date) })
    |> result.unwrap("")
  let thursday =
    dict.get(date_keys, birl.Thu)
    |> result.map(fn(d) { date_num_string(d.date) })
    |> result.unwrap("")
  let friday =
    dict.get(date_keys, birl.Fri)
    |> result.map(fn(d) { date_num_string(d.date) })
    |> result.unwrap("")
  let saturday =
    dict.get(date_keys, birl.Sat)
    |> result.map(fn(d) { date_num_string(d.date) })
    |> result.unwrap("")
  let sunday =
    dict.get(date_keys, birl.Sun)
    |> result.map(fn(d) { date_num_string(d.date) })
    |> result.unwrap("")

  element.fragment([
    div(
      [
        class(
          "subgrid-cols subgrid-rows col-span-full xs:row-span-full xs:col-span-1 sticky left-[-.25rem] top-[-.25rem] outline outline-1 outline-ecru-white-50 border  border-ecru-white-50 bg-ecru-white-50 min-h-full min-w-full",
        ),
      ],
      [
        div(
          [
            class(
              "xs:row-start-2 xs:col-start-1 font-mono col-start-2 flex justify-center items-center border border-ecru-white-950 [box-shadow:1px_1px_0_#ff776a] sticky left-0 top-0 bg-ecru-white-50",
            ),
          ],
          [h2([class("mx-2")], [text("Lunch")])],
        ),
        div(
          [
            class(
              "xs:row-start-3 xs:col-start-1 font-mono col-start-3 flex justify-center items-center border border-ecru-white-950  [box-shadow:1px_1px_0_#ff776a] sticky left-0 top-0 bg-ecru-white-50",
            ),
          ],
          [h2([class("mx-2")], [text("Dinner")])],
        ),
      ],
    ),
    div(
      [
        class(
          "xs:col-start-2 xs:row-start-1 font-mono row-start-2 border border-ecru-white-950 flex justify-center items-center shadow-orange",
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
          "xs:col-start-3 xs:row-start-1 font-mono row-start-3  border border-ecru-white-950   flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
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
          "xs:col-start-4 xs:row-start-1 font-mono row-start-4  border border-ecru-white-950   flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
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
          "xs:col-start-5 xs:row-start-1 font-mono row-start-5  border border-ecru-white-950   flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
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
          "xs:col-start-6 xs:row-start-1 font-mono row-start-6  border border-ecru-white-950   flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
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
          "xs:col-start-7 xs:row-start-1 font-mono row-start-7  border border-ecru-white-950  flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
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
          "xs:col-start-8 xs:row-start-1 font-mono row-start-8 border border-ecru-white-950   flex justify-center items-center [box-shadow:1px_1px_0_#ff776a]",
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

//-TYPES-------------------------------------------------------------

pub type PlanDay {
  PlanDay(
    date: birl.Time,
    lunch: Option(MealWithStatus),
    dinner: Option(MealWithStatus),
  )
}

pub type JsPlanDay {
  JsPlanDay(date: String, lunch: Json, dinner: Json)
}

pub type MealWithStatus {
  RecipeWithStatus(recipe_id: String, complete: Bool)
  MealWithStatus(meal: String, complete: Bool)
}

//-ENCODERS-DECODERS----------------------------------------------

fn decode_plan_day(d: Dynamic) -> Result(PlanDay, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode3(
      PlanDay,
      dynamic.field("date", of: decode_stringed_day),
      dynamic.optional_field("lunch", of: decode_meal_status),
      dynamic.optional_field("dinner", of: decode_meal_status),
    )
  decoder(d)
}

fn decode_stringed_day(d: Dynamic) -> Result(birl.Time, dynamic.DecodeErrors) {
  let decoder = dynamic.string
  result.map(decoder(d), fn(a) {
    a
    |> birl.from_naive
    |> result.map_error(fn(_x) {
      [dynamic.DecodeError("a stringed day", "something else", ["*"])]
    })
  })
  |> result.flatten
}

fn decode_meal_status(
  d: Dynamic,
) -> Result(MealWithStatus, dynamic.DecodeErrors) {
  let decoder =
    decipher.tagged_union(dynamic.field("type", dynamic.string), [
      #(
        "RecipeWithStatus",
        dynamic.decode2(
          RecipeWithStatus,
          dynamic.field("recipe_id", dynamic.string),
          dynamic.field("complete", decoders.stringed_bool),
        ),
      ),
      #(
        "MealWithStatus",
        dynamic.decode2(
          MealWithStatus,
          dynamic.field("meal", dynamic.string),
          dynamic.field("complete", decoders.stringed_bool),
        ),
      ),
    ])

  decoder(d)
}

fn encode_plan_day(plan_day: PlanDay) -> JsPlanDay {
  JsPlanDay(
    date: birl.to_naive_date_string(plan_day.date),
    lunch: {
      case plan_day.lunch {
        Some(RecipeWithStatus(a, b)) ->
          json.object([
            #("type", json.string("RecipeWithStatus")),
            #("recipe_id", json.string(a)),
            #("complete", json.string(bool.to_string(b))),
          ])
        Some(MealWithStatus(a, b)) ->
          json.object([
            #("type", json.string("MealWithStatus")),
            #("recipe_id", json.string(a)),
            #("complete", json.string(bool.to_string(b))),
          ])
        None -> json.object([])
      }
    },
    dinner: {
      case plan_day.dinner {
        Some(RecipeWithStatus(a, b)) ->
          json.object([
            #("type", json.string("RecipeWithStatus")),
            #("recipe_id", json.string(a)),
            #("complete", json.string(bool.to_string(b))),
          ])
        Some(MealWithStatus(a, b)) ->
          json.object([
            #("type", json.string("MealWithStatus")),
            #("recipe_id", json.string(a)),
            #("complete", json.string(bool.to_string(b))),
          ])
        None -> json.object([])
      }
    },
  )
}

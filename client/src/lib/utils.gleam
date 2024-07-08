import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import lustre/effect.{type Effect}
import rada/date.{type Date}

/// Update a dictionary with a given key and function.
/// If the key does not exist, the dictionary is returned unchanged.
/// 
pub fn dict_update(
  in dict: Dict(k, v),
  update key: k,
  with fun: fn(v) -> v,
) -> Dict(k, v) {
  let item =
    dict
    |> dict.get(key)
    |> option.from_result
  case item {
    Some(item) -> item |> fun |> dict.insert(dict, key, _)
    _ -> dict
  }
}

pub fn dict_reindex(in dict: Dict(Int, v)) -> Dict(Int, v) {
  dict
  |> dict.to_list
  |> list.sort(by: fn(a, b) { int.compare(pair.first(a), pair.first(b)) })
  |> list.index_map(fn(x, i) { #(i, pair.second(x)) })
  |> dict.from_list
}

/// Return the `n`th element of a list, or `None` if the list is too short.
pub fn list_at(list: List(a), n: Int) -> Option(a) {
  case list {
    [] -> None
    [x, ..] if n == 0 -> Some(x)
    [x, ..xs] -> list_at(xs, n - 1)
  }
}

/// Update child view of a given view.
///
/// The `model` and `msg` must be the child view's, the `updater` is the child
/// view's `update` function, and the `mapper` maps the child model's emitted
/// effect into the parent model's effect.
pub fn update_child(
  model: a,
  msg: b,
  updater: fn(a, b) -> #(a, Effect(b)),
  mapper: fn(b) -> d,
) {
  let #(new_model, new_effect) = updater(model, msg)
  let new_effect = effect.map(new_effect, mapper)
  #(new_model, new_effect)
}

pub fn month_date_string(day: Date) -> String {
  let n = date_num_string(day)
  let s =
    day
    |> date.weekday
  let m =
    day
    |> date.month
    |> fn(a) {
      case a {
        date.Jan -> "January"
        date.Feb -> "February"
        date.Mar -> "March"
        date.Apr -> "April"
        date.May -> "May"
        date.Jun -> "June"
        date.Jul -> "July"
        date.Aug -> "August"
        date.Sep -> "September"
        date.Oct -> "October"
        date.Nov -> "November"
        date.Dec -> "December"
      }
    }
  m <> " " <> n
}

pub fn long_date_string(day: Date) -> String {
  let n = date_num_string(day)
  let s =
    day
    |> date.weekday
    |> fn(a) {
      case a {
        date.Sun -> "Sunday"
        date.Mon -> "Monday"
        date.Tue -> "Tuesday"
        date.Wed -> "Wednesday"
        date.Thu -> "Thursday"
        date.Fri -> "Friday"
        date.Sat -> "Saturday"
      }
    }
  s <> " " <> n
}

pub fn short_date_string(day: Date) -> String {
  let n = date_num_string(day)
  let s =
    day
    |> date.weekday
    |> fn(a) {
      case a {
        date.Sun -> "Sun"
        date.Mon -> "Mon"
        date.Tue -> "Tue"
        date.Wed -> "Wed"
        date.Thu -> "Thu"
        date.Fri -> "Fri"
        date.Sat -> "Sat"
      }
    }
  s <> " " <> n
}

pub fn date_num_string(day: Date) -> String {
  day
  |> date.day
  |> int.to_string
}

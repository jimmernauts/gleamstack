import gleam/dict.{type Dict}
import gleam/option.{Some}
import lustre/effect.{type Effect}

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

import gleam/dynamic.{type Dynamic}
import gleam/javascript/promise.{type Promise}
import shared/types.{type JsPlanDay}

@external(javascript, ".././db.ts", "do_get_plan")
pub fn do_get_plan(start_date: Int, end_date: Int) -> Promise(Dynamic)

@external(javascript, ".././db.ts", "do_subscribe_to_plan")
pub fn do_subscribe_to_plan(
  callback: fn(Dynamic) -> Nil,
  start_date: Int,
  end_date: Int,
) -> fn() -> Nil

@external(javascript, ".././db.ts", "do_save_plan")
pub fn do_save_plan(planweek: List(JsPlanDay)) -> Nil

@external(javascript, ".././db.ts", "do_save_shopping_list")
pub fn do_save_shopping_list(
  list_obj: #(Int, String, String, String, Int),
) -> Nil

@external(javascript, ".././db.ts", "do_delete_shopping_list")
pub fn do_delete_shopping_list(id: String) -> Nil

@external(javascript, ".././db.ts", "do_subscribe_to_shopping_list_summaries")
pub fn do_subscribe_to_shopping_list_summaries(
  callback: fn(Dynamic) -> Nil,
) -> fn() -> Nil

@external(javascript, ".././db.ts", "do_subscribe_to_one_shoppinglist_by_date")
pub fn do_subscribe_to_one_shoppinglist_by_date(
  date: Int,
  callback: fn(Dynamic) -> Nil,
) -> fn() -> Nil

@external(javascript, ".././db.ts", "do_subscribe_to_one_recipe_by_slug")
pub fn do_subscribe_to_one_recipe_by_slug(
  slug: String,
  callback: fn(Dynamic) -> Nil,
) -> fn() -> Nil

@external(javascript, ".././db.ts", "do_get_tagoptions")
pub fn do_get_tagoptions() -> Promise(Dynamic)

@external(javascript, ".././db.ts", "do_subscribe_to_recipe_summaries")
pub fn do_subscribe_to_recipe_summaries(
  callback: fn(Dynamic) -> Nil,
) -> fn() -> Nil

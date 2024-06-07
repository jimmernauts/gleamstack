import components/ingredient_input.{ingredient_input}
import components/method_step_input.{method_step_input}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre/attribute.{attribute, class, for, href, id, name, type_, value}
import lustre/element.{type Element, fragment, text}
import lustre/element/html.{
  a, button, div, fieldset, form, input, label, legend, nav, textarea,
}
import lustre/event
import types.{type Msg, type Recipe, SaveUpdatedRecipe}

pub fn edit_recipe(recipe: Recipe) {
  form(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr]",
      ),
      id("create_recipe_form"),
      event.on_submit(SaveUpdatedRecipe),
    ],
    [
      div(
        [
          class(
            "mt-4 mb-2 sm:mb-4 mr-2 flex col-start-1 col-span-11 sm:col-start-1 sm:col-span-8",
          ),
        ],
        [
          textarea(
            [
              id("title"),
              name("title"),
              class(
                "placeholder:underline-blue underline-blue min-h-[56px] max-h-[140px] sm:max-h-[170px] overflow-x-hidden px-0 pb-1 input-base w-full input-focus font-transitional resize-none font-bold italic text-ecru-white-950  text-7xl bg-ecru-white-100",
              ),
              attribute("title", "recipe title"),
            ],
            recipe.title,
          ),
        ],
      ),
      fieldset(
        [
          class(
            "mx-2 sm:mx-0 mt-0 sm:mt-4 flex sm:flex-wrap justify-between row-start-2 col-span-full sm:row-start-1 sm:col-span-3 sm:col-start-9",
          ),
        ],
        [
          fieldset([class("flex flex-wrap items-baseline mb-2")], [
            label(
              [class("justify-self-start font-mono italic"), for("prep_time")],
              [text("Prep:")],
            ),
            div([class("justify-self-start")], [
              div([class("after:content-['h'] after:text-xs inline-block")], [
                input([
                  id("prep_time_hrs"),
                  class(
                    "bg-ecru-white-100 input-base input-focus pr-0.5 w-[3ch] text-right text-base",
                  ),
                  type_("number"),
                  name("prep_time_hrs"),
                  attribute("title", "prep time in hours"),
                  value(
                    int.floor_divide(recipe.prep_time, 60)
                    |> result.unwrap(0)
                    |> int.to_string
                    |> string.replace("0", ""),
                  ),
                ]),
              ]),
              div([class("after:content-['m'] after:text-xs inline-block")], [
                input([
                  id("prep_time_mins"),
                  class(
                    "bg-ecru-white-100 input-base input-focus pr-0.5 w-[3ch] text-right text-base",
                  ),
                  type_("number"),
                  name("prep_time_mins"),
                  attribute("title", "prep time in minutes"),
                  value(
                    recipe.prep_time % 60
                    |> int.to_string,
                  ),
                ]),
              ]),
            ]),
          ]),
          fieldset([class("flex flex-wrap items-baseline mb-2")], [
            label(
              [class("justify-self-start font-mono italic"), for("prep_time")],
              [text("Cook:")],
            ),
            div([class("justify-self-start")], [
              div([class("after:content-['h'] after:text-xs inline-block")], [
                input([
                  id("cook_time_hrs"),
                  class(
                    "bg-ecru-white-100 input-base input-focus pr-0.5 w-[3ch] text-right text-base",
                  ),
                  type_("number"),
                  name("cook_time_hrs"),
                  attribute("title", "cook time in hours"),
                  value(
                    int.floor_divide(recipe.cook_time, 60)
                    |> result.unwrap(0)
                    |> int.to_string
                    |> string.replace("0", ""),
                  ),
                ]),
              ]),
              div([class("after:content-['m'] after:text-xs inline-block")], [
                input([
                  id("cook_time_mins"),
                  class(
                    "bg-ecru-white-100 input-base input-focus pr-0.5 w-[3ch] text-right text-base",
                  ),
                  type_("number"),
                  name("cook_time_mins"),
                  attribute("title", "cook time in minutes"),
                  value(
                    recipe.cook_time % 60
                    |> int.to_string,
                  ),
                ]),
              ]),
            ]),
          ]),
          fieldset([class("flex flex-wrap items-baseline mb-2")], [
            label(
              [class("justify-self-start font-mono italic"), for("serves")],
              [text("Serves:")],
            ),
            input([
              id("serves"),
              class(
                "bg-ecru-white-100 justify-self-start col-span-3 input-base input-focus pr-0.5 w-[3ch] text-right text-base",
              ),
              type_("number"),
              name("serves"),
              value(recipe.serves |> int.to_string),
            ]),
          ]),
        ],
      ),
      nav(
        [
          class(
            "flex flex-col justify-start items-middle col-span-1 col-start-12 text-sm sm:text-base md:text-lg my-4 text-center",
          ),
        ],
        [
          a([href("/"), class("text-center")], [text("🏠")]),
          a([href("/recipes." <> recipe.slug), class("text-center")], [
            text("❎"),
          ]),
          button([type_("submit"), class("")], [text("💾")]),
        ],
      ),
      fieldset(
        [
          class(
            "col-span-full my-1 mb-6 pt-1 pb-2 px-1 mr-1 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-6 [box-shadow:1px_1px_0_#9edef1]",
          ),
        ],
        [
          legend([class("mx-2 px-1 font-mono italic")], [text("Ingredients")]),
          recipe.ingredients
            |> option.map(list.map(_, Some(_)))
            |> option.map(list.index_map(_, ingredient_input))
            |> option.map(fragment)
            |> option.unwrap(element.none()),
        ],
      ),
      fieldset(
        [
          class(
            "col-span-full my-1 mb-6 pt-1 pb-2 px-1 mr-1 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-6 [box-shadow:1px_1px_0_#9edef1]",
          ),
        ],
        [
          legend([class("mx-2 px-1 font-mono italic")], [text("Method")]),
          recipe.method_steps
            |> option.map(list.map(_, Some(_)))
            |> option.map(list.index_map(_, method_step_input))
            |> option.map(fragment)
            |> option.unwrap(element.none()),
        ],
      ),
    ],
  )
}

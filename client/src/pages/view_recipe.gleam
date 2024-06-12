import components/page_title.{page_title}
import gleam/dict
import gleam/int.{to_string}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/uri.{type Uri}
import lib/types
import lustre/attribute.{class, for, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element, fragment, none, text}
import lustre/element/html.{
  a, div, fieldset, label, legend, li, nav, ol, section, span,
}

pub fn view_recipe(recipe: types.Recipe) {
  section(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(100px)_fit-content(100px)_1fr]",
      ),
    ],
    [
      page_title(recipe.title, "underline-green"),
      fieldset(
        [
          class(
            "mx-2 sm:mx-0 mt-0 sm:mt-4 flex sm:flex-wrap justify-between row-start-2 col-span-full sm:row-start-1 sm:col-span-3 sm:col-start-9",
          ),
        ],
        [
          fieldset(
            [class("flex flex-wrap sm:justify-between items-baseline mb-2")],
            [
              label(
                [for("prep_time"), class("justify-self-start font-mono italic")],
                [text("Prep:")],
              ),
              div([class("mx-4 justify-self-start")], [
                text(to_string(recipe.prep_time)),
              ]),
            ],
          ),
          fieldset(
            [class("flex flex-wrap sm:justify-between items-baseline mb-2")],
            [
              label(
                [for("cook_time"), class("justify-self-start font-mono italic")],
                [text("Cook:")],
              ),
              div([class("mx-4 justify-self-start")], [
                text(to_string(recipe.cook_time)),
              ]),
            ],
          ),
          fieldset(
            [class("flex flex-wrap sm:justify-between items-baseline mb-2")],
            [
              label(
                [for("cook_time"), class("justify-self-start font-mono italic")],
                [text("Serves:")],
              ),
              div([class("mx-4 justify-self-start")], [
                text(to_string(recipe.serves)),
              ]),
            ],
          ),
        ],
      ),
      nav(
        [
          class(
            "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4",
          ),
        ],
        [
          a([href("/"), class("text-center")], [text("🏠")]),
          a(
            [href("/recipes/" <> recipe.slug <> "/edit"), class("text-center")],
            [text("✏️")],
          ),
        ],
      ),
      fieldset(
        [
          class(
            "flex flex-wrap gap-1 items-baseline mx-1 col-span-full gap-x-3",
          ),
        ],
        case recipe.tags {
          Some(a) -> list.map(a, fn(tag) { view_tag(tag) })
          _ -> [none()]
        },
      ),
      fieldset(
        [
          class(
            "col-span-full my-1 mb-6 pt-1 pb-2 px-2 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-6 [box-shadow:1px_1px_0_#a3d2ab] mr-1",
          ),
        ],
        [
          legend([class("mx-2 px-1 font-mono italic")], [text("Ingredients")]),
          recipe.ingredients
            |> option.map(dict.map_values(_, fn(_i, item) {
              view_ingredient(item)
            }))
            |> option.map(dict.values)
            |> option.map(fragment)
            |> option.unwrap(element.none()),
        ],
      ),
      fieldset(
        [
          class(
            "flex justify-start flex-wrap col-span-full my-1 mb-6 pt-1 pb-2 px-2 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-6 [box-shadow:1px_1px_0_#a3d2ab] mr-1",
          ),
        ],
        [
          legend([class("mx-2 px-1 font-mono italic")], [text("Method")]),
          ol(
            [
              class(
                "list-decimal flex flex-wrap w-full items-baseline col-span-full pr-1 pl-2 ml-1 mb-1",
              ),
            ],
            [
              recipe.method_steps
              |> option.map(list.map(_, view_method_step))
              |> option.unwrap([none()])
              |> fragment,
            ],
          ),
        ],
      ),
    ],
  )
}

fn view_ingredient(ingredient: types.Ingredient) {
  div([class("flex justify-start col-span-6 text-sm items-baseline")], [
    div([class("flex-grow-[2] text-left flex justify-start")], [
      option.unwrap(option.map(ingredient.name, text(_)), none()),
    ]),
    div([class("col-span-1 text-xs")], [
      option.unwrap(option.map(ingredient.quantity, text(_)), none()),
    ]),
    div([class("col-span-1 text-xs")], [
      option.unwrap(option.map(ingredient.units, text(_)), none()),
    ]),
  ])
}

fn view_method_step(method_step: types.MethodStep) {
  li(
    [
      class(
        "marker:text-base w-full justify-self-start list-decimal text-left pl-1 ml-2 leading-snug my-2",
      ),
    ],
    [text(method_step.step_text)],
  )
}

fn view_tag(tag: types.Tag) {
  div([class("flex")], [
    div(
      [
        class(
          "font-mono bg-ecru-white-100 border border-ecru-white-950 px-1 text-xs",
        ),
      ],
      [text(tag.name)],
    ),
    div(
      [
        class(
          "font-mono bg-ecru-white-50 border border-l-0 border-ecru-white-950  px-1 text-xs",
        ),
      ],
      [text(tag.value)],
    ),
  ])
}

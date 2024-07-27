import components/page_title.{page_title}
import gleam/io
import gleam/javascript/promise.{type Promise}
import gleam/result
import lustre/attribute.{attribute, class, href, id, name, type_, value}
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html.{
  a, button, div, fieldset, form, input, legend, nav, section, text,
}
import lustre/event.{on_input}
import session

//-TYPES-------------------------------------------------------------

pub type ImportMsg {
  UserEnteredUrl(String)
  UserSubmittedForm
  ParsedRecipefromUrl(session.Recipe)
}

pub type ImportModel {
  ImportModel(url: String)
}

//-UPDATE-------------------------------------------------------------

pub fn update(
  model: ImportModel,
  msg: ImportMsg,
) -> #(ImportModel, Effect(ImportMsg)) {
  io.debug(msg)
  case msg {
    UserEnteredUrl(url) -> #(ImportModel(url: url), effect.none())
    UserSubmittedForm -> #(model, {
      use dispatch <- effect.from
      do_parse_url(model.url)
      |> promise.map(result.map(_, ParsedRecipefromUrl))
      |> promise.tap(result.map(_, dispatch))
      Nil
    })
    ParsedRecipefromUrl(_) -> #(model, effect.none())
  }
}

@external(javascript, ".././parseRemoteRecipe.ts", "parseUrl")
fn do_parse_url(url: String) -> Promise(Result(session.Recipe, String))

//-VIEWS-------------------------------------------------------------

pub fn view(model: ImportModel) {
  element.fragment([
    section(
      [
        class(
          "grid grid-cols-12 col-start-[main-start] grid-rows-[fit-content(65px)] gap-y-2",
        ),
      ],
      [
        page_title("Import Recipe", "underline-yellow"),
        nav(
          [
            class(
              "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4",
            ),
          ],
          [
            a([href("/"), class("text-center")], [text("🏠")]),
            button(
              [
                type_("submit"),
                class("text-center"),
                attribute("form", "import-recipe-form"),
              ],
              [text("📩")],
            ),
          ],
        ),
        form(
          [
            id("import-recipe-form"),
            class("subgrid-cols grid-rows-[1fr,1fr,5fr] gap-y-2 col-span-full"),
            event.on_submit(UserSubmittedForm),
          ],
          [
            fieldset(
              [
                class(
                  "col-span-full my-1 mb-6 pt-1 pb-2 px-2 mr-1 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-5 [box-shadow:1px_1px_0_#fce68b]",
                ),
              ],
              [
                legend([class("mx-2 px-1 font-mono italic")], [
                  text("URL to import"),
                ]),
                div([class("justify-self-start col-span-4")], [
                  input([
                    name("url"),
                    type_("url"),
                    class(
                      "input-base input-outline input-focus text-base w-full box-border",
                    ),
                    value(model.url),
                    on_input(UserEnteredUrl),
                    id("url"),
                  ]),
                ]),
              ],
            ),
          ],
        ),
      ],
    ),
  ])
}

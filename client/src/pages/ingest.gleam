import components/page_title.{page_title}
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html.{a, nav, section, text}

//-TYPES-------------------------------------------------------------

pub type ImportMsg {
  UserEnteredUrl(String)
}

pub type Model {
  Model
}

//-UPDATE-------------------------------------------------------------

pub fn update(model: Model, msg: ImportMsg) -> #(Model, Effect(ImportMsg)) {
  case msg {
    UserEnteredUrl(_url) -> #(model, effect.none())
  }
}

//-VIEWS-------------------------------------------------------------

pub fn view(_model: Model) {
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
          [a([href("/"), class("text-center")], [text("🏠")])],
        ),
      ],
    ),
  ])
}

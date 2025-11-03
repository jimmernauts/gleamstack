import gleam/string
import lustre/attribute.{class, id}
import lustre/element.{text}
import lustre/element/html.{div, h1}

pub fn page_title(title: String, styles: String) {
  div(
    [
      class("mt-2 flex col-start-1"),
      class(case string.length(title) {
        num if num > 38 -> "text-4xl"
        num if num > 27 -> "text-5xl"
        num if num > 24 -> "text-5.5xl"
        num if num == 18 -> "text-6xl"
        _ -> "text-7xl"
      }),
      class(styles),
    ],
    [
      h1(
        [
          id("title"),
          class(
            "min-h-[56px] max-h-[140px] overflow-hidden px-0 pb-1 mt-3 mr-2 w-full font-transitional font-bold italic text-ecru-white-950",
          ),
        ],
        [text(title)],
      ),
    ],
  )
}

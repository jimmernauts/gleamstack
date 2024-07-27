import gleam/string
import lustre/attribute.{class, id}
import lustre/element.{text}
import lustre/element/html.{div, h1}

pub fn page_title(title: String, styles: String) {
  div([class(styles), class("mt-4 flex col-start-1 col-span-11 text-7xl")], [
    h1(
      [
        id("title"),
        class(
          "min-h-[56px] max-h-[140px] overflow-hidden px-0 pb-1 w-full font-transitional font-bold italic text-ecru-white-950",
        ),
        class(case string.length(title) {
          num if num > 38 -> "text-4xl"
          num if num > 18 -> "text-5.5xl"
          num if num == 18 -> "text-6xl"
          _ -> "text-7xl"
        }),
      ],
      [text(title)],
    ),
  ])
}

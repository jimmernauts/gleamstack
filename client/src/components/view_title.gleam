import lustre/attribute.{class, id}
import lustre/element.{text}
import lustre/element/html.{div, h1}

pub fn view_title(title: String, styles: String) {
  div(
    [
      class(styles),
      class(
        "mt-4 mb-2 sm:mb-4 mx-2 flex col-start-1 col-span-11 sm:col-start-1 sm:col-span-8 text-7xl",
      ),
    ],
    [
      h1(
        [
          id("title"),
          class(
            "min-h-[56px] max-h-[140px] sm:max-h-[170px] overflow-hidden px-0 pb-1 w-full font-transitional font-bold italic text-ecru-white-950",
          ),
        ],
        [text(title)],
      ),
    ],
  )
}

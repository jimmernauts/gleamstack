import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html.{nav}

pub fn nav_footer(children: List(Element(a))) {
  nav(
    [
      class(
        "flex flex-row flex-wrap mb-2 col-span-full justify-around md:justify-start items-middle md:col-span-1 md:col-start-12 text-base md:text-lg md:mt-4",
      ),
    ],
    children,
  )
}

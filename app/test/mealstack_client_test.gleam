import gleam/dict
import gleam/json
import gleam/option.{None, Some}
import lib/utils
import shared/codecs
import shared/types.{Ingredient, MethodStep, Recipe}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  1
  |> expect.to_equal(1)
}

pub fn utils_tests() {
  describe("utils", [
    describe("slugify", [
      it("should strip spaces and convert to lowercase", fn() {
        "Hello World"
        |> utils.slugify
        |> expect.to_equal("hello-world")
      }),
      it("should strip accented characters", fn() {
        "áàäâàãåä ÀÁÂÄ éèëê ÉÈÊË íìïî ÍÌÏÎ óòöô ÓÒÖÔ úùüû ÚÙÜÛ ñÑ"
        |> utils.slugify
        |> expect.to_equal(
          "aaaaaaaa-aaaa-eeee-eeee-iiii-iiii-oooo-oooo-uuuu-uuuu-nn",
        )
      }),
      it("should strip non-alphanumeric characters except space, hyphen", fn() {
        "Hello🎨🔔⚠️🧾📗💾⬅️✔️❎➖🔖❕World"
        |> utils.slugify
        |> expect.to_equal("hello-world")
      }),
      it("should convert common punctuation to hyphens", fn() {
        "Hello&+!@#$%^&*()_+=-~`{}[]:;'<>\",.?/World"
        |> utils.slugify
        |> expect.to_equal("hello-world")
      }),
      it("should collapse multiple spaces into a single hyphen", fn() {
        "Hello   World"
        |> utils.slugify
        |> expect.to_equal("hello-world")
      }),
      it("should collapse multiple hyphens into a single hyphen", fn() {
        "Hello---World"
        |> utils.slugify
        |> expect.to_equal("hello-world")
      }),
      it("should collapse multiple underscores into a single hyphen", fn() {
        "Hello___World"
        |> utils.slugify
        |> expect.to_equal("hello-world")
      }),
    ]),
  ])
}

pub fn production_recipe_json_fields_test() {
  let payload =
    "{\"id\":\"recipe-1\",\"title\":\"Mediterranean potato salad\",\"slug\":\"mediterranean-potato-salad\",\"cook_time\":25,\"prep_time\":10,\"serves\":4,\"ingredients\":\"[\\\"1 tbsp olive oil\\\",\\\"1 small onion\\\"]\",\"method_steps\":\"[{\\\"@type\\\":\\\"HowToStep\\\",\\\"text\\\":\\\"Heat the oil.\\\"}]\"}"

  let expected =
    Recipe(
      id: Some("recipe-1"),
      title: "Mediterranean potato salad",
      slug: "mediterranean-potato-salad",
      cook_time: 25,
      prep_time: 10,
      serves: 4,
      author: None,
      source: None,
      tags: None,
      ingredients: Some(
        dict.from_list([
          #(
            0,
            Ingredient(
              name: Some("1 tbsp olive oil"),
              ismain: Some(False),
              quantity: None,
              units: None,
              category: None,
            ),
          ),
          #(
            1,
            Ingredient(
              name: Some("1 small onion"),
              ismain: Some(False),
              quantity: None,
              units: None,
              category: None,
            ),
          ),
        ]),
      ),
      method_steps: Some(dict.from_list([#(0, MethodStep("Heat the oil."))])),
      shortlisted: None,
    )

  json.parse(payload, codecs.decode_recipe_with_inner_json())
  |> expect.to_equal(Ok(expected))
}

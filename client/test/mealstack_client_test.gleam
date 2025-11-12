import lib/utils
import startest.{describe, it}
import startest/expect
import snapshot/component_snapshot_test.{snapshot_tests}

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

pub fn snapshot_test() {
  snapshot_tests()
}

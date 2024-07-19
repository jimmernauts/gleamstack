import decode
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/result

pub fn stringed_bool(d: Dynamic) -> Result(Bool, dynamic.DecodeErrors) {
  dynamic.string(d)
  |> result.map(fn(a) {
    case a {
      "True" -> True
      "true" -> True
      "1" -> True
      _ -> False
    }
  })
}

pub fn decode_stringed_bool(d: Dynamic) -> Result(Bool, dynamic.DecodeErrors) {
  let decoder = decode.string
  decoder
  |> decode.map(fn(a) {
    case a {
      "True" -> True
      "true" -> True
      "1" -> True
      _ -> False
    }
  })
  |> decode.from(d)
}

pub fn stringed_int(d: Dynamic) -> Result(Int, dynamic.DecodeErrors) {
  let decoder = dynamic.string
  decoder(d)
  |> result.map(int.parse)
  |> result.then(result.map_error(_, fn(_x) {
    [
      dynamic.DecodeError(
        expected: "a stringed int",
        found: "something else",
        path: [""],
      ),
    ]
  }))
}

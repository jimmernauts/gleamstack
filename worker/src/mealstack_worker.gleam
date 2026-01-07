import conversation
import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import glen.{type Request, type Response}
import glen/status

pub fn handle_req(req: Request) -> Promise(Response) {
  // Log all requests and responses
  use <- glen.log(req)
  // Handle potential crashes gracefully
  use <- glen.rescue_crashes

  case glen.path_segments(req) {
    ["api", "scrape_url"] -> {
      let target =
        glen.get_query(req)
        |> list.key_find("target")
      case target {
        Ok(target) -> scrape_url_page(target, req)
        _ -> not_found(req)
      }
    }
    ["api", "parse_recipe_text"] -> handle_parse_recipe_text(req)
    ["api", "parse_recipe_image"] -> handle_parse_recipe_image(req)
    _ -> not_found(req)
  }
}

fn handle_parse_recipe_text(req: Request) -> Promise(Response) {
  use body <- promise.await(glen.read_json_body(req))
  case body {
    Ok(json) -> {
      case decode_text_from_json(json) {
        Ok(text) -> {
          do_parse_recipe_text(text)
          |> promise.map(fn(result) {
            case result {
              Ok(data) -> {
                data
                |> json.to_string
                |> glen.json(status.ok)
                |> glen.set_header("Access-Control-Allow-Origin", "*")
              }
              Error(_error) -> {
                glen.json(
                  json.object([
                    #("error", json.string("Failed to parse recipe")),
                  ])
                    |> json.to_string,
                  status.internal_server_error,
                )
                |> glen.set_header("Access-Control-Allow-Origin", "*")
              }
            }
          })
        }
        Error(_) -> {
          promise.resolve(
            glen.text(
              "Invalid JSON body: missing 'text' field",
              status.bad_request,
            )
            |> glen.set_header("Access-Control-Allow-Origin", "*"),
          )
        }
      }
    }
    Error(_) -> {
      promise.resolve(
        glen.text("Invalid JSON body", status.bad_request)
        |> glen.set_header("Access-Control-Allow-Origin", "*"),
      )
    }
  }
}

fn decode_text_from_json(
  json: dynamic.Dynamic,
) -> Result(String, List(decode.DecodeError)) {
  let decoder = {
    use text <- decode.field("text", decode.string)
    decode.success(text)
  }
  decode.run(json, decoder)
}

fn handle_parse_recipe_image(req: Request) -> Promise(Response) {
  use body <- promise.await(glen.read_json_body(req))
  case body {
    Ok(json) -> {
      case decode_image_from_json(json) {
        Ok(image) -> {
          do_parse_recipe_image(image)
          |> promise.map(fn(result) {
            case result {
              Ok(data) -> {
                data
                |> json.to_string
                |> glen.json(status.ok)
                |> glen.set_header("Access-Control-Allow-Origin", "*")
              }
              Error(_error) -> {
                glen.json(
                  json.object([
                    #("error", json.string("Failed to parse recipe from image")),
                  ])
                    |> json.to_string,
                  status.internal_server_error,
                )
                |> glen.set_header("Access-Control-Allow-Origin", "*")
              }
            }
          })
        }
        Error(_) -> {
          promise.resolve(
            glen.text(
              "Invalid JSON body: missing 'image' field",
              status.bad_request,
            )
            |> glen.set_header("Access-Control-Allow-Origin", "*"),
          )
        }
      }
    }
    Error(_) -> {
      promise.resolve(
        glen.text("Invalid JSON body", status.bad_request)
        |> glen.set_header("Access-Control-Allow-Origin", "*"),
      )
    }
  }
}

fn decode_image_from_json(
  json: dynamic.Dynamic,
) -> Result(String, List(decode.DecodeError)) {
  let decoder = {
    use image <- decode.field("image", decode.string)
    decode.success(image)
  }
  decode.run(json, decoder)
}

pub fn scrape_url_page(target: String, req: Request) -> Promise(Response) {
  echo "Scraping URL: " <> target
  do_fetch_jsonld(target, conversation.to_js_request(req))
  |> promise.map(fn(data) {
    case data {
      Ok(data) -> {
        data
        |> json.to_string
        |> glen.json(status.ok)
        |> glen.set_header("Access-Control-Allow-Origin", "*")
      }
      Error(error) -> {
        error
        |> glen.text(status.internal_server_error)
      }
    }
  })
}

pub fn not_found(_req: Request) -> Promise(Response) {
  "<h1>Oops, are you lost?</h1>
  <p>This page doesn't exist.</p>"
  |> glen.html(status.not_found)
  |> promise.resolve
}

@external(javascript, "./scrape_url.ts", "do_fetch_jsonld")
fn do_fetch_jsonld(
  url: String,
  request: conversation.JsRequest,
) -> Promise(Result(Json, String))

@external(javascript, "./parse_recipe.ts", "do_parse_recipe_text")
fn do_parse_recipe_text(text: String) -> Promise(Result(Json, dynamic.Dynamic))

@external(javascript, "./parse_recipe.ts", "do_parse_recipe_image")
fn do_parse_recipe_image(
  image_data: String,
) -> Promise(Result(Json, dynamic.Dynamic))

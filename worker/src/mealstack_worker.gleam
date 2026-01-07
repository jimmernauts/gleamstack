import conversation
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
    _ -> not_found(req)
  }
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

import components/page_title.{page_title}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/io
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre/attribute.{
  accept, attribute, class, for, href, id, name, src, type_,
}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{a, button, div, form, img, input, label, nav}
import lustre/event.{on, on_click, on_input, on_submit}
import session.{type Recipe}

//--TYPES-------------------------------------------------------------

pub type UploadMsg {
  UserSelectedFile(file_name: String, raw_file_change_event: dynamic.Dynamic)
  BrowserReadFile(file_data: String)
  UserSubmittedFile
  UserUpdatedUrl(url: String)
  UserSubmittedUrlToScrape
  ScrapeUrlResponseReceived(Result(String, ParseToRecipeError))
  ParseRecipeResponseReceived(Result(Recipe, ParseToRecipeError))
}

pub type ParseToRecipeError {
  DecoderError(List(decode.DecodeError))
  InvalidImage
  Unauthorized
  ScrapeUrlFailed(String)
  Other(String)
}

pub type UploadStatus {
  NotStarted
  FileSelected
  ImageProcessing
  ImageSubmitting
  UrlProcessing
  UrlSubmitting
  Finished
}

pub type UploadModel {
  UploadModel(
    status: UploadStatus,
    file_name: Option(String),
    file_data: Option(String),
    raw_file_change_event: Option(dynamic.Dynamic),
    url: Option(String),
  )
}

//--UPDATE-------------------------------------------------------------

pub fn upload_update(
  model: UploadModel,
  msg: UploadMsg,
) -> #(UploadModel, Effect(UploadMsg)) {
  case msg {
    UserSelectedFile(file_name, raw_file_change_event) -> #(
      UploadModel(
        ..model,
        status: FileSelected,
        file_name: Some(file_name),
        raw_file_change_event: Some(raw_file_change_event),
      ),
      {
        use dispatch <- effect.from
        do_read_file_from_event(raw_file_change_event, fn(file_data) {
          let _ =
            file_data
            |> result.map(BrowserReadFile)
            |> result.map_error(io.print_error)
            |> result.map(dispatch)
          Nil
        })
      },
    )
    BrowserReadFile(file_data) -> #(
      UploadModel(
        status: ImageProcessing,
        file_name: model.file_name,
        file_data: Some(file_data),
        raw_file_change_event: None,
        url: None,
      ),
      effect.none(),
    )
    UserSubmittedFile -> {
      case model.file_data {
        None -> #(model, effect.none())
        Some(file_data) -> #(UploadModel(..model, status: ImageSubmitting), {
          use dispatch <- effect.from
          do_submit_file(file_data, fn(response) {
            case response {
              Ok(recipe_data) -> {
                let decoded =
                  recipe_data
                  |> decode.run(session.decode_recipe_no_json())
                case decoded {
                  Ok(recipe) ->
                    dispatch(ParseRecipeResponseReceived(Ok(recipe)))
                  Error(errors) -> {
                    io.debug(errors)
                    dispatch(
                      ParseRecipeResponseReceived(
                        Error(Other("Response could not be decoded")),
                      ),
                    )
                  }
                }
              }
              Error(inner_error) ->
                dispatch(ParseRecipeResponseReceived(Error(inner_error)))
            }
          })
        })
      }
    }
    UserUpdatedUrl(url) -> #(
      UploadModel(..model, url: Some(url)),
      effect.none(),
    )
    UserSubmittedUrlToScrape -> #(UploadModel(..model, status: UrlProcessing), {
      case model.url {
        None -> effect.none()
        Some(url) -> {
          use dispatch <- effect.from
          do_scrape_url(url, fn(response) {
            case response {
              Ok(scraped_json) ->
                dispatch(ScrapeUrlResponseReceived(Ok(scraped_json)))
              Error(error) -> dispatch(ScrapeUrlResponseReceived(Error(error)))
            }
          })
        }
      }
    })
    ScrapeUrlResponseReceived(Ok(scraped_json)) -> {
      #(UploadModel(..model, status: UrlSubmitting), {
        io.debug("ScrapeUrlRepsonseReceived")
        io.debug(scraped_json)
        use dispatch <- effect.from
        do_submit_scraped_json(scraped_json, fn(response) {
          case response {
            Ok(recipe_data) -> {
              let decoded =
                recipe_data
                |> decode.run(session.decode_recipe_no_json())
              case decoded {
                Ok(recipe) -> dispatch(ParseRecipeResponseReceived(Ok(recipe)))
                Error(errors) -> {
                  io.debug(errors)
                  dispatch(
                    ParseRecipeResponseReceived(
                      Error(Other("Response could not be decoded")),
                    ),
                  )
                }
              }
            }
            Error(inner_error) ->
              dispatch(ParseRecipeResponseReceived(Error(inner_error)))
          }
        })
      })
    }
    ScrapeUrlResponseReceived(Error(error)) -> {
      #(model, effect.none())
    }
    ParseRecipeResponseReceived(Ok(_recipe)) -> {
      //actually handled in mealstack_client.gleam
      #(model, effect.none())
    }
    ParseRecipeResponseReceived(Error(error)) -> {
      let error_message = case error {
        DecoderError(_errors) -> "Could not decode the result into a recipe."
        InvalidImage -> "Invalid image format."
        Unauthorized -> "Unauthorized access."
        ScrapeUrlFailed(msg) ->
          "Failed to scrape the URL submitted. Error: " <> msg
        Other(msg) -> "Error: " <> msg
      }
      io.print_error(error_message)
      #(
        UploadModel(
          status: Finished,
          raw_file_change_event: None,
          file_data: None,
          file_name: None,
          url: None,
        ),
        effect.none(),
      )
    }
  }
}

fn handle_file_upload(
  event: dynamic.Dynamic,
) -> Result(UploadMsg, List(dynamic.DecodeError)) {
  let decoder =
    decode.at(
      ["target", "files"],
      decode.at([0], decode.at(["name"], decode.string)),
    )
  decode.run(event, decoder)
  |> result.map(fn(file_name) { UserSelectedFile(file_name, event) })
  |> result.map_error(
    list.map(_, fn(e) { dynamic.DecodeError(e.expected, e.found, e.path) }),
  )
}

@external(javascript, ".././upload.ts", "do_read_file_from_event")
fn do_read_file_from_event(
  event: dynamic.Dynamic,
  cb: fn(Result(String, String)) -> Nil,
) -> Nil

@external(javascript, ".././upload.ts", "do_submit_file")
fn do_submit_file(
  file: String,
  cb: fn(Result(dynamic.Dynamic, ParseToRecipeError)) -> Nil,
) -> Nil

@external(javascript, ".././upload.ts", "do_submit_scraped_json")
fn do_submit_scraped_json(
  file: String,
  cb: fn(Result(dynamic.Dynamic, ParseToRecipeError)) -> Nil,
) -> Nil

@external(javascript, ".././upload.ts", "do_scrape_url")
fn do_scrape_url(
  url: String,
  cb: fn(Result(String, ParseToRecipeError)) -> Nil,
) -> Nil

//--VIEW---------------------------------------------------------------

pub fn view_upload(model: UploadModel) -> Element(UploadMsg) {
  form(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[repeat(4,fit-content(65px))] gap-y-2",
      ),
      on_submit(UserSubmittedFile),
      attribute("enctype", "multipart/form-data"),
      attribute("accept", "image/*"),
    ],
    [
      page_title("Upload a new recipe", "underline-grey"),
      nav(
        [
          class(
            "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4",
          ),
        ],
        [
          a([href("/"), class("text-center")], [text("🏠")]),
          button(
            [
              class(
                "flex flex-row justify-center items-center gap-2 p-2 rounded-md text-base md:text-lg bg-underline-grey hover:bg-underline-hover",
              ),
              name("Upload"),
              type_("submit"),
            ],
            [text("📤")],
          ),
        ],
      ),
      div([class("col-span-11 row-start-2")], [
        label([class("block mb-2 text-base font-medium"), for("recipe-image")], [
          text("Upload Recipe Image"),
        ]),
        input([
          class(
            "block w-full text-base rounded-lg cursor-pointer bg-ecru-white-100",
          ),
          type_("file"),
          id("recipe-image"),
          accept(["image/*"]),
          on("change", handle_file_upload),
        ]),
        case model.status {
          NotStarted -> element.none()
          FileSelected -> element.none()
          ImageProcessing ->
            div([class("mt-2 text-sm text-blue-500")], [
              text("Processing image..."),
            ])
          ImageSubmitting ->
            div([class("mt-2 text-sm text-blue-500")], [
              text("Parsing image with AI..."),
            ])
          UrlProcessing ->
            div([class("mt-2 text-sm text-blue-500")], [
              text("Scraping URL for Recipe content..."),
            ])
          UrlSubmitting ->
            div([class("mt-2 text-sm text-blue-500")], [
              text("Parsing scraped data with AI..."),
            ])
          Finished -> element.none()
        },
        case model.file_data {
          Some(file_data) ->
            div([class("mt-2 text-sm")], [
              text("Selected image: "),
              img([src(file_data), class("w-1/2")]),
            ])
          None -> element.none()
        },
      ]),
      div([class("col-span-11 row-start-3")], [
        label([class("block mb-2 text-base font-medium"), for("recipe-url")], [
          text("Or Enter Recipe URL"),
        ]),
        div([class("flex gap-2")], [
          input([
            class("block w-full text-base rounded-lg bg-ecru-white-100 p-2"),
            type_("url"),
            id("recipe-url"),
            on_input(UserUpdatedUrl),
          ]),
          button(
            [
              class(
                "flex flex-row justify-center items-center gap-2 p-2 rounded-md text-base md:text-lg bg-underline-grey hover:bg-underline-hover",
              ),
              type_("button"),
              on_click(UserSubmittedUrlToScrape),
            ],
            [text("📥")],
          ),
        ]),
      ]),
    ],
  )
}

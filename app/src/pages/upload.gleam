import components/nav_footer.{nav_footer}
import components/page_title.{page_title}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre/attribute.{
  accept, attribute, class, for, href, id, name, src, type_, value,
}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{
  a, button, div, fieldset, form, img, input, label, nav, textarea,
}
import lustre/event.{on, on_input, on_submit}
import shared/codecs
import shared/types

//--TYPES-------------------------------------------------------------

pub type UploadMsg {
  UserSelectedFile(file_name: String, raw_file_change_event: dynamic.Dynamic)
  BrowserReadFile(file_data: String)
  UserSubmittedFile
  UserUpdatedUrl(url: String)
  UserSubmittedUrlToScrape
  ScrapeUrlResponseReceived(Result(String, ParseToRecipeError))
  UserUpdatedText(text: String)
  UserSubmittedText
  ParseRecipeResponseReceived(Result(types.Recipe, ParseToRecipeError))
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
  ImageProcessing
  ImageLoaded
  ImageSubmitting
  UrlProcessing
  UrlSubmitting
  TextSubmitting
  Finished
}

pub type UploadModel {
  UploadModel(
    status: UploadStatus,
    api_key: Option(String),
    file_name: Option(String),
    file_data: Option(String),
    raw_file_change_event: Option(dynamic.Dynamic),
    url: Option(String),
    text: Option(String),
  )
}

//--UPDATE-------------------------------------------------------------

pub fn upload_update(
  model: UploadModel,
  msg: UploadMsg,
) -> #(UploadModel, Effect(UploadMsg)) {
  echo model
  case msg {
    UserSelectedFile(file_name, raw_file_change_event) -> #(
      UploadModel(
        ..model,
        status: ImageProcessing,
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
        status: ImageLoaded,
        api_key: model.api_key,
        file_name: model.file_name,
        file_data: Some(file_data),
        raw_file_change_event: None,
        url: None,
        text: None,
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
                  |> decode.run(codecs.decode_recipe_no_json())
                case decoded {
                  Ok(recipe) ->
                    dispatch(ParseRecipeResponseReceived(Ok(recipe)))
                  Error(errors) -> {
                    echo errors
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
        case model.api_key {
          Some(key) -> {
            use dispatch <- effect.from
            do_submit_text(scraped_json, key, fn(response) {
              case response {
                Ok(recipe_data) -> {
                  let decoded =
                    recipe_data
                    |> decode.run(codecs.decode_recipe_no_json())
                  case decoded {
                    Ok(recipe) ->
                      dispatch(ParseRecipeResponseReceived(Ok(recipe)))
                    Error(errors) -> {
                      echo "Could not decode recipe from scraped content."
                      echo errors
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
          }
          None -> {
            use dispatch <- effect.from
            dispatch(
              ParseRecipeResponseReceived(Error(Other("No API key provided"))),
            )
          }
        }
      })
    }
    ScrapeUrlResponseReceived(Error(error)) -> {
      let error_message = case error {
        DecoderError(_errors) -> "Could not decode the result into a recipe."
        InvalidImage -> "Invalid image format."
        Unauthorized -> "Unauthorized access."
        ScrapeUrlFailed(msg) ->
          "Failed to scrape the URL submitted. Error: " <> msg
        Other(msg) -> "Error: " <> msg
      }
      echo error_message
      #(model, effect.none())
    }
    UserUpdatedText(text) -> #(
      UploadModel(..model, text: Some(text)),
      effect.none(),
    )
    UserSubmittedText -> #(
      UploadModel(..model, status: TextSubmitting),
      case model.text, model.api_key {
        Some(text), Some(api_key) -> {
          use dispatch <- effect.from
          do_submit_text(text, api_key, fn(response) {
            case response {
              Ok(recipe_data) -> {
                let decoded =
                  recipe_data
                  |> decode.run(codecs.decode_recipe_no_json())
                case decoded {
                  Ok(recipe) ->
                    dispatch(ParseRecipeResponseReceived(Ok(recipe)))
                  Error(errors) -> {
                    echo errors
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
        }
        _, _ -> {
          echo "No text or API key provided"
          effect.none()
        }
      },
    )
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
      echo error_message
      #(
        UploadModel(
          status: Finished,
          api_key: model.api_key,
          raw_file_change_event: None,
          file_data: None,
          file_name: None,
          url: None,
          text: None,
        ),
        effect.none(),
      )
    }
  }
}

fn handle_file_upload() -> decode.Decoder(UploadMsg) {
  use evt <- decode.field("event", decode.dynamic)
  use res <- decode.subfield(
    ["target", "files"],
    decode.at([0], decode.at(["name"], decode.string)),
  )
  decode.success(UserSelectedFile(res, evt))
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

@external(javascript, ".././upload.ts", "do_submit_text")
fn do_submit_text(
  text: String,
  api_key: String,
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
        "h-env-screen grid grid-cols-12 col-start-[main-start] grid-rows-[auto_1fr_auto] grid-named-3x12 gap-y-2",
      ),
      on_submit(fn(_x) {
        case model {
          UploadModel(file_data: Some(_file_data), ..) -> UserSubmittedFile
          UploadModel(url: Some(_url), ..) -> UserSubmittedUrlToScrape
          UploadModel(text: Some(_text), ..) -> UserSubmittedText
          _ -> UserSubmittedFile
        }
      }),
    ],
    [
      page_title(
        "Import a new recipe",
        "underline-yellow [grid-area:header] col-span-full md:col-span-[11]",
      ),
      div([class("[grid-area:content]")], [
        case model.status {
          NotStarted -> element.none()
          ImageLoaded -> element.none()
          ImageProcessing ->
            div(
              [
                class(
                  "font-mono col-span-2 py-1 bg-ecru-white-100 border border-ecru-white-950 px-1 text-xs",
                ),
              ],
              [text("Processing image...")],
            )
          ImageSubmitting ->
            div(
              [
                class(
                  "font-mono col-span-2 py-1 bg-ecru-white-100 border border-ecru-white-950 px-1 text-xs",
                ),
              ],
              [text("Parsing image with AI...")],
            )
          UrlProcessing ->
            div(
              [
                class(
                  "font-mono col-span-2 py-1 bg-ecru-white-100 border border-ecru-white-950 px-1 text-xs",
                ),
              ],
              [text("Scraping URL for Recipe content...")],
            )
          UrlSubmitting ->
            div(
              [
                class(
                  "font-mono col-span-2 py-1 bg-ecru-white-100 border border-ecru-white-950 px-1 text-xs",
                ),
              ],
              [text("Parsing scraped data with AI...")],
            )
          TextSubmitting ->
            div(
              [
                class(
                  "font-mono col-span-2 py-1 bg-ecru-white-100 border border-ecru-white-950 px-1 text-xs",
                ),
              ],
              [text("Parsing text with AI...")],
            )
          Finished -> element.none()
        },
        //col-span-full text-base my-1 pt-1 pb-2 px-2 border-ecru-white-950 border-[1px] rounded-[1px] sm:row-span-2 sm:col-span-5 [box-shadow:1px_1px_0_#fce68b] mr-1
        fieldset(
          [
            class(
              "md:col-span-4 flex flex-col gap-y-2 col-span-11 row-start-3 p-2 border-ecru-white-950 border rounded-[1px] [box-shadow:1px_1px_0_#fce68b]",
            ),
          ],
          [
            html.legend([class("mx-2 px-1 text-base")], [text("Image")]),
            label(
              [
                class(
                  "inline-block self-start items-baseline cursor-pointer bg-ecru-white-100 border border-ecru-white-950 px-1",
                ),
                for("recipe-image"),
              ],
              [text("Upload an image")],
            ),
            input([
              class("hidden"),
              type_("file"),
              id("recipe-image"),
              accept(["image/*"]),
              on("change", handle_file_upload()),
            ]),
            case model.file_data {
              Some(file_data) ->
                div([class("")], [img([src(file_data), class("")])])
              None -> element.none()
            },
          ],
        ),
        fieldset(
          [
            class(
              "md:col-span-4 col-span-11 flex  row-start-3 p-2 gap-y-2 border-ecru-white-950 border rounded-[1px] [box-shadow:1px_1px_0_#fce68b]",
            ),
          ],
          [
            html.legend([class("mx-2 px-1 text-base")], [text("Web")]),
            div([class(" gap-x-2")], [
              label([class("inline-block"), for("recipe-url")], [text("URL:")]),
              input([
                class(
                  "inline-block w-[16ch] xxs:w-[23ch] xs:w-[28ch] sm:w-[16ch] md:w-[23ch] lg:w-[28ch] text-base bg-ecru-white-100 ml-1 p-2",
                ),
                type_("url"),
                id("recipe-url"),
                on_input(UserUpdatedUrl),
                value(model.url |> option.unwrap("")),
              ]),
            ]),
          ],
        ),
        fieldset(
          [
            class(
              "md:col-span-4 col-span-11 flex  row-start-3 p-2 gap-y-2 border-ecru-white-950 border rounded-[1px] [box-shadow:1px_1px_0_#fce68b]",
            ),
          ],
          [
            html.legend([class("mx-2 px-1 text-base")], [text("Text")]),
            textarea(
              [
                name("recipe-text-to-import"),
                id("recipe-text-to-import"),
                class(
                  "mx-1 p-2 bg-ecru-white-100 w-full input-focus text-base resize-none field-sizing-content",
                ),
                attribute("rows", "3"),
                on_input(UserUpdatedText),
              ],
              model.text |> option.unwrap(""),
            ),
          ],
        ),
      ]),
      nav_footer([
        a([href("/"), class("text-center")], [text("🏠")]),
        button(
          [
            class(
              "flex flex-row justify-center items-center gap-2 p-2 cursor-pointer text-base md:text-lg bg-underline-grey hover:bg-underline-hover",
            ),
            name("Upload"),
            type_("submit"),
          ],
          [text("📤")],
        ),
      ]),
    ],
  )
}

import components/page_title.{page_title}
import gleam/io
import gleam/option.{type Option, None, Some}
import lustre/attribute.{accept, attribute, class, for, id, name, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, form, input, label, nav}
import lustre/event.{on_input, on_submit}
import pages/settings.{SettingsModel}
import session.{type Recipe}

//--TYPES-------------------------------------------------------------

pub type UploadMsg {
  UserUploadedFile(String)
  UserSubmittedFile
  ResponseReceived(Result(Recipe, ParseImageToRecipeError))
}

pub type ParseImageToRecipeError {
  InvalidImage
  Unauthorized
  Other(String)
}

pub type UploadModel {
  UploadModel(is_loading: Bool, file: Option(String))
}

//--UPDATE-------------------------------------------------------------

pub fn upload_update(
  model: UploadModel,
  msg: UploadMsg,
) -> #(UploadModel, Effect(UploadMsg)) {
  case msg {
    UserUploadedFile(file) -> #(
      UploadModel(is_loading: False, file: Some(file)),
      effect.none(),
    )
    UserSubmittedFile -> {
      case model.file {
        None -> #(model, effect.none())
        Some(file) -> #(UploadModel(..model, is_loading: True), {
          let response = do_submit_file(file)
          use dispatch <- effect.from
          dispatch(ResponseReceived(response))
        })
      }
    }
    ResponseReceived(Ok(_recipe)) -> {
      //actually handled in app.gleam
      #(UploadModel(is_loading: False, file: model.file), effect.none())
    }
    ResponseReceived(Error(error)) -> {
      let error_message = case error {
        InvalidImage -> "Invalid image format"
        Unauthorized -> "Unauthorized access"
        Other(msg) -> "Error: " <> msg
      }
      io.print_error(error_message)
      #(UploadModel(is_loading: False, file: model.file), effect.none())
    }
  }
}

@external(javascript, ".././upload.ts", "do_submit_file")
fn do_submit_file(file: String) -> Result(Recipe, ParseImageToRecipeError)

//--VIEW---------------------------------------------------------------

pub fn view_upload(model: UploadModel) -> Element(UploadMsg) {
  form(
    [
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[repeat(3,fit-content(65px))] gap-y-2",
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
          button(
            [
              class(
                "flex flex-row justify-center items-center gap-2 p-2 rounded-md text-base md:text-lg bg-underline-grey hover:bg-underline-hover",
              ),
              name("Upload"),
              type_("submit"),
            ],
            [text("Upload")],
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
          on_input(fn(value) { UserUploadedFile(value) }),
        ]),
        case model.file {
          Some(file_path) ->
            div([class("mt-2 text-sm")], [text("Selected file: " <> file_path)])
          None -> element.none()
        },
        case model.is_loading {
          True ->
            div([class("mt-2 text-sm text-blue-500")], [
              text("Processing image..."),
            ])
          False -> element.none()
        },
      ]),
    ],
  )
}

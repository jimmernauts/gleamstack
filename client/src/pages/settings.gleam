import components/page_title.{page_title}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre/attribute.{class, href, name, type_, value}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{a, button, form, input, label, nav}
import lustre/event.{on_input}

//-TYPES--------------------------------------------------------------

pub type SettingsMsg {
  UserSavedSettings
  UserRetrievedSettings(api_key: Option(String))
  UserUpdatedApikey(api_key: String)
}

pub type SettingsModel {
  SettingsModel(api_key: Option(String))
}

//-UPDATE-------------------------------------------------------------

pub fn settings_update(
  model: SettingsModel,
  msg: SettingsMsg,
) -> #(SettingsModel, Effect(SettingsMsg)) {
  echo msg
  case msg {
    UserSavedSettings -> {
      case model.api_key {
        Some(api_key) -> do_save_settings(api_key)
        None -> do_save_settings("")
      }
      #(model, effect.none())
    }
    UserRetrievedSettings(api_key) -> #(SettingsModel(api_key), effect.none())
    UserUpdatedApikey(api_key) -> #(SettingsModel(Some(api_key)), effect.none())
  }
}

@external(javascript, ".././db2.ts", "do_save_settings")
fn do_save_settings(api_key: String) -> Nil

pub fn retrieve_settings() -> Effect(SettingsMsg) {
  use dispatch <- effect.from
  do_retrieve_settings()
  |> promise.map(decode.run(_, decode.optional(decode.string)))
  |> promise.map(result.map(_, UserRetrievedSettings))
  |> promise.tap(result.map(_, dispatch))
  Nil
}

@external(javascript, ".././db2.ts", "do_retrieve_settings")
fn do_retrieve_settings() -> Promise(Dynamic)

//-VIEW---------------------------------------------------------------

pub fn view_settings(model: SettingsModel) -> Element(SettingsMsg) {
  form(
    [
      event.on_submit(fn(_x) { UserSavedSettings }),
      class(
        "grid grid-cols-12 col-start-[main-start] grid-rows-[repeat(3,fit-content(65px))] gap-y-2",
      ),
    ],
    [
      page_title("Settings", "underline-grey"),
      nav(
        [
          class(
            "flex flex-col justify-start items-middle col-span-1 col-start-12 text-base md:text-lg mt-4",
          ),
        ],
        [
          a([href("/"), class("text-center")], [text("🏠")]),
          button([type_("submit"), class("cursor-pointer")], [text("💾")]),
        ],
      ),
      label([class("block mb-2")], [text("API Key")]),
      input([
        class(
          "bg-ecru-white-100 input-base input-focus pr-0.5 w-[20ch] text-left text-base",
        ),
        type_("text"),
        name("api_key"),
        on_input(UserUpdatedApikey),
        value(option.unwrap(model.api_key, "")),
      ]),
    ],
  )
}

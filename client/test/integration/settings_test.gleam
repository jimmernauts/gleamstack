import birdie
import gleam/option.{None, Some}
import lustre/dev/simulate
import lustre/element
import mealstack_client.{OnRouteChange, Settings, ViewSettings}
import pages/settings.{UserRetrievedSettings, UserUpdatedApikey}
import startest.{describe, it}
import startest/expect

pub fn settings_integration_tests() {
  describe("Settings Persistence", [
    it("should load settings route", fn() {
      // Arrange
      let initial_route = ViewSettings

      // Act
      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Assert
      let model = simulate.model(simulation)
      case model {
        mealstack_client.Model(current_route: route, ..) -> {
          route
          |> expect.to_equal(ViewSettings)
        }
      }
    }),
    it("should start with no API key", fn() {
      // Arrange
      let initial_route = ViewSettings

      // Act
      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Assert
      let model = simulate.model(simulation)
      case model {
        mealstack_client.Model(settings: settings, ..) -> {
          settings.api_key
          |> expect.to_equal(None)
        }
      }
    }),
    it("should update API key in model", fn() {
      // Arrange
      let initial_route = ViewSettings

      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Act - Update API key
      let final_simulation =
        simulation
        |> simulate.message(Settings(UserUpdatedApikey("test-api-key-123")))

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        mealstack_client.Model(settings: settings, ..) -> {
          settings.api_key
          |> expect.to_equal(Some("test-api-key-123"))
        }
      }
    }),
    it("should retrieve settings from database", fn() {
      // Arrange
      let initial_route = ViewSettings

      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Act - Simulate database retrieval
      let final_simulation =
        simulation
        |> simulate.message(
          Settings(UserRetrievedSettings(Some("retrieved-api-key"))),
        )

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        mealstack_client.Model(settings: settings, ..) -> {
          settings.api_key
          |> expect.to_equal(Some("retrieved-api-key"))
        }
      }
    }),
    it("should propagate API key to upload model", fn() {
      // Arrange
      let initial_route = ViewSettings

      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Act - Retrieve settings with API key
      let final_simulation =
        simulation
        |> simulate.message(Settings(UserRetrievedSettings(Some("test-key"))))

      // Assert - Check that upload model also has the API key
      let final_model = simulate.model(final_simulation)
      case final_model {
        mealstack_client.Model(upload: upload, ..) -> {
          upload.api_key
          |> expect.to_equal(Some("test-key"))
        }
      }
    }),
    it("should handle empty API key retrieval", fn() {
      // Arrange
      let initial_route = ViewSettings

      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Act - Retrieve empty settings
      let final_simulation =
        simulation
        |> simulate.message(Settings(UserRetrievedSettings(None)))

      // Assert
      let final_model = simulate.model(final_simulation)
      case final_model {
        mealstack_client.Model(settings: settings, ..) -> {
          settings.api_key
          |> expect.to_equal(None)
        }
      }
    }),
    it("should snapshot settings view with no API key", fn() {
      // Arrange
      let initial_route = ViewSettings

      // Act
      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))

      // Assert - Snapshot the view
      simulate.view(simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "settings_empty")
    }),
    it("should snapshot settings view with API key", fn() {
      // Arrange
      let initial_route = ViewSettings

      // Act
      let simulation =
        simulate.application(
          init: mealstack_client.public_init,
          update: mealstack_client.public_update,
          view: mealstack_client.public_view,
        )
        |> simulate.start(Nil)
        |> simulate.message(OnRouteChange(initial_route))
        |> simulate.message(
          Settings(UserRetrievedSettings(Some("sk-test-key-123"))),
        )

      // Assert - Snapshot the view
      simulate.view(simulation)
      |> element.to_readable_string
      |> birdie.snap(title: "settings_with_key")
    }),
  ])
}

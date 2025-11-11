import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import lustre/element/html.{div, text}
import lustre/attribute

/// Helper to create a simple test element for snapshot testing
pub fn simple_test_element(content: String) -> Element(String) {
  div([attribute.class("test")], [text(content)])
}

/// Helper to assert option equality for testing
pub fn expect_option_equal(
  actual: Option(a),
  expected: Option(a),
) -> Bool {
  case actual, expected {
    Some(a), Some(b) -> a == b
    None, None -> True
    _, _ -> False
  }
}

/// Helper to create test error results
pub fn test_error(msg: String) -> Result(a, String) {
  Error(msg)
}

/// Helper to create test success results  
pub fn test_success(value: a) -> Result(a, String) {
  Ok(value)
}

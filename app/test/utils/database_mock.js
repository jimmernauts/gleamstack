// Mock database functions for integration testing
export let captured_saves = [];

export function mock_do_save_recipe(recipe) {
  console.log("Mock save_recipe called with:", recipe);
  captured_saves.push(recipe);
  // Don't actually save to database during tests
}

export function mock_do_delete_recipe(id) {
  console.log("Mock delete_recipe called with:", id);
  // Don't actually delete from database during tests
}

export function get_captured_saves() {
  return captured_saves;
}

export function clear_captured_saves() {
  captured_saves.length = 0;
}

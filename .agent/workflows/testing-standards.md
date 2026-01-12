---
description: Gleamstack Testing Standards
---

# Gleamstack Testing Standards

## Running Tests

// turbo
- Run all tests: `just test-app` (from project root)

### Single Test Execution
- **Gleam Tests:** Cannot run individual test files - all Gleam tests run through the main runner in `app/test/mealstack_client_test.gleam`. To test specific functionality, comment/uncomment test groups in the main runner.
- **Birdie Snapshots:** Use `gleam run -m birdie review` for interactive review of specific snapshots.
- **TypeScript Tests:** `bun test <specific-file.test.ts>`

## Test Structure

### File Structure
- [test/unit/](file:///home/ubuntu/projects/gleamstack/app/test/unit) - Unit tests for pure functions and business logic
- [test/snapshot/](file:///home/ubuntu/projects/gleamstack/app/test/snapshot) - Component view snapshots with Birdie
- [test/utils/](file:///home/ubuntu/projects/gleamstack/app/test/utils) - Mock data and test helpers
- [test/integration/](file:///home/ubuntu/projects/gleamstack/app/test/integration) - Integration tests for pages/features

## Test Patterns

### Unit Tests (Startest)
- Test pure functions and business logic
- Use `describe`/`it` structure with `expect` assertions
- Focus on `update` functions, data transformation, validation

### Snapshot Tests (Birdie)
- Only test actual `view` and `update` functions from source code
- Use `birdie.snap(title: "descriptive_name")` for component output
- No string formatting or arbitrary data snapshots
- Use [lustre/dev/simulate](https://hexdocs.pm/lustre/lustre/dev/simulate.html) combined with birdie.snap to simulate user interactions

## Guidelines
- Tests should exercise real application code
- Prefer testing `update`/`view` functions over utilities
- Keep snapshots focused on component rendering and testing interaction flows
- Write snapshot tests for all view functions
- Write unit tests for complex update logic
- Test decoders with various input shapes
- Test edge cases (empty lists, missing data, etc.)
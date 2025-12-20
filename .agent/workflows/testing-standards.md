---
description: Gleamstack Testing Standards
---

# Gleamstack Testing Standards

## Running Tests
// turbo
- Run all tests: `gleam test --target javascript` (must be run in `client/` directory)
// turbo
- Run snapshot tests (Birdie): `gleam run -m birdie` (must be run in `client/` directory)
  - Press `a` to accept a new snapshot
  - Press `r` to reject a new snapshot
  - Press `d` to toggle the diff view

## Test Patterns

### Unit Tests (Startest)
- Test pure functions and business logic
- Use `describe`/`it` structure with `expect` assertions
- Focus on `update` functions, data transformation, validation

### Snapshot Tests (Birdie)
- Only test actual `view` and `update` functions from source code
- Use `birdie.snap(title: "descriptive_name")` for component output
- No string formatting or arbitrary data snapshots

## File Structure
- [test/unit/](file:///home/ubuntu/projects/gleamstack/client/test/unit) - Unit tests for core logic
- [test/snapshot/](file:///home/ubuntu/projects/gleamstack/client/test/snapshot) - Component view snapshots
- [test/utils/](file:///home/ubuntu/projects/gleamstack/client/test/utils) - Mock data and test helpers

## Guidelines
- Tests should exercise real application code
- Prefer testing `update`/`view` functions over utilities
- Keep snapshots focused on component rendering and testing interaction flows
- Use [lustre/dev/simulate](https://hexdocs.pm/lustre/lustre/dev/simulate.html) combined with birdie.snap to simulate user interactions and test component behavior
- Write snapshot tests for all view functions
- Write unit tests for complex update logic
- Test decoders with various input shapes
- Test edge cases (empty lists, missing data, etc.)

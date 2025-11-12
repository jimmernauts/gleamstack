---
trigger: always_on
glob: "**/*_test.gleam"
description: Test patterns for Gleam project
---

# Test Patterns

## Unit Tests (Startest)
- Test pure functions and business logic
- Use `describe`/`it` structure with `expect` assertions
- Focus on `update` functions, data transformation, validation

## Snapshot Tests (Birdie)
- Only test actual `view` and `update` functions from source code
- Use `birdie.snap(title: "descriptive_name")` for component output
- No string formatting or arbitrary data snapshots

## File Structure
- [test/unit/](cci:7://file:///home/ubuntu/projects/gleamstack/client/test/home/ubuntu/projects/gleamstack/client/test/unit:0:0-0:0) - Unit tests for core logic
- [test/snapshot/](cci:7://file:///home/ubuntu/projects/gleamstack/client/test/home/ubuntu/projects/gleamstack/client/test/snapshot:0:0-0:0) - Component view snapshots
- [test/utils/](cci:7://file:///home/ubuntu/projects/gleamstack/client/test/home/ubuntu/projects/gleamstack/client/test/utils:0:0-0:0) - Mock data and test helpers

## Guidelines
- Tests should exercise real application code
- Prefer testing `update`/`view` functions over utilities
- Keep snapshots focused on component rendering and testing interaction flows
- Use [lustre/dev/simulate](https://hexdocs.pm/lustre/lustre/dev/simulate.html) combined with birdie.snap to simulate user interactions and test component behavior
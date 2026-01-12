---
description: How to be an effective agent
---

# How to be an effective agent

## Lint Policy
- **Lint ERRORS:** Must be fixed immediately (type errors, syntax errors, compilation failures)
- **Lint warnings:** Must be ignored until task completion (unused imports, etc.)
- You shouldn't need to run `gleam build`. The LSP reports type errors to the IDE that you should be able to read.

## Useful Behaviours
- When drafting an Implementation Plan, always use your `browser_subagent` for the 'Manual Verification' step
- ALWAYS use `bun` to manage package.json files and JavaScript dependencies, not `npm`
- At the end of each feature implementation, check over all the test cases to see if you should add any new tests for what you have introduced
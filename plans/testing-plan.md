# Testing Plan for Core Workflows

## Overview

This plan outlines testing strategies for the core Mealstack workflows to ensure safe refactoring. We'll use a combination of unit tests (Startest) and snapshot tests (Birdie) to cover different aspects of the functionality.

## Testing Libraries

### Startest (Unit Testing)
- **Purpose**: Traditional unit tests for pure functions and business logic
- **Strengths**: Fast, precise assertions, good for testing specific functions
- **Current Setup**: Already configured in `gleam.toml` with existing test examples
- **Usage**: `import startest.{describe, it}` and `import startest/expect`

### Birdie (Snapshot Testing)
- **Purpose**: Integration-style tests without running the full app
- **Strengths**: Captures complex output (HTML, data structures), great for UI components
- **Setup**: Need to add `gleam add --dev birdie`
- **Usage**: `birdie.snap(title: "unique_snapshot_name")`
- **Review**: Run `gleam run -m birdie` to review snapshots

## Core Workflows to Test

### 1. Create a New Recipe

#### Functions to Test:
- `session.save_recipe()` - Database save operation
- `pages/recipe.detail_update()` - Handle form inputs and validation
- Recipe data validation and transformation

#### Test Strategy:
**Unit Tests (Startest):**
- Recipe data validation functions
- Form input parsing and sanitization
- Error handling for invalid data

**Snapshot Tests (Birdie):**
- Recipe form HTML structure
- Recipe detail view rendering
- Recipe list item rendering

#### Test Files:
- `test/recipe_creation_test.gleam`
- `test/recipe_validation_test.gleam`

### 2. Load Recipe List Page

#### Functions to Test:
- `session.get_recipes()` - Data fetching
- `session.merge_recipe_into_model()` - State updates
- `pages/recipe.list_update()` - Component update logic
- Recipe filtering and grouping logic

#### Test Strategy:
**Unit Tests (Startest):**
- Recipe data transformation functions
- Filtering and grouping algorithms
- State merging logic
- Error handling for fetch failures

**Snapshot Tests (Birdie):**
- Recipe list HTML output
- Grouped recipe list rendering
- Empty state display
- Loading state display

#### Test Files:
- `test/recipe_list_test.gleam`
- `test/recipe_filtering_test.gleam`

### 3. Load Recipe Details Page

#### Functions to Test:
- `session.get_one_recipe_by_slug()` - Individual recipe fetch
- `session.subscribe_to_one_recipe_by_slug()` - Real-time updates
- `pages/recipe.detail_update()` - Detail page logic
- Recipe data parsing and display

#### Test Strategy:
**Unit Tests (Startest):**
- Recipe slug resolution
- Data parsing from database format
- Ingredient and method step processing
- Real-time subscription handling

**Snapshot Tests (Birdie):**
- Recipe detail page HTML structure
- Ingredient list rendering
- Method steps display
- Recipe metadata display

#### Test Files:
- `test/recipe_details_test.gleam`
- `test/recipe_data_processing_test.gleam`

### 4. Load Planner Page

#### Functions to Test:
- `pages/planner.planner_update()` - Planner component logic
- `pages/planner.save_plan()` - Plan persistence
- Date handling and week calculation
- Meal assignment logic

#### Test Strategy:
**Unit Tests (Startest):**
- Date manipulation functions
- Plan data structure validation
- Meal assignment algorithms
- Week boundary calculations

**Snapshot Tests (Birdie):**
- Planner week view HTML
- Individual day rendering
- Meal assignment display
- Empty planner state

#### Test Files:
- `test/planner_test.gleam`
- `test/planner_data_test.gleam`

### 5. Mark Planned Meal as Complete

#### Functions to Test:
- `pages/planner.UserToggledMealComplete()` - Toggle handler
- Plan status update logic
- Real-time synchronization
- State persistence

#### Test Strategy:
**Unit Tests (Startest):**
- Status toggle logic
- Plan data structure updates
- Completion state validation
- Error handling for failed updates

**Snapshot Tests (Birdie):**
- Meal item rendering with completion status
- Planner view after status changes
- Checkbox state display

#### Test Files:
- `test/planner_completion_test.gleam`
- `test/planner_state_test.gleam`

## Implementation Plan

### Phase 1: Setup and Infrastructure
1. Add Birdie dependency: `gleam add --dev birdie`
2. Create test directory structure
3. Set up test utilities and mock data
4. Configure test runner

### Phase 2: Unit Tests (Startest)
1. Test pure utility functions first
2. Test data transformation logic
3. Test business logic functions
4. Test error handling paths

### Phase 3: Snapshot Tests (Birdie)
1. Create mock data generators
2. Test component rendering
3. Test complex data structures
4. Review and approve snapshots

### Phase 4: Integration Tests
1. Test workflow sequences
2. Test error recovery scenarios
3. Test edge cases and boundaries
4. Performance and load testing (if needed)

## Test File Structure

```
test/
├── mealstack_client_test.gleam          # Existing tests
├── utils/
│   ├── mock_data.gleam                  # Test data generators
│   ├── test_helpers.gleam               # Common test utilities
│   └── assertions.gleam                 # Custom assertions
├── unit/
│   ├── recipe_creation_test.gleam       # Recipe creation unit tests
│   ├── recipe_list_test.gleam           # Recipe list unit tests
│   ├── recipe_details_test.gleam        # Recipe details unit tests
│   ├── planner_test.gleam               # Planner unit tests
│   └── planner_completion_test.gleam    # Completion logic unit tests
├── snapshot/
│   ├── recipe_views_test.gleam          # Recipe component snapshots
│   ├── planner_views_test.gleam         # Planner component snapshots
│   └── integration_test.gleam           # Workflow snapshots
└── integration/
    ├── workflows_test.gleam             # End-to-end workflow tests
    └── error_scenarios_test.gleam       # Error handling tests
```

## Mock Data Strategy

### Recipe Test Data
- Valid complete recipe
- Recipe with optional fields missing
- Invalid recipe data
- Large recipe (stress test)

### Planner Test Data
- Empty week plan
- Partially filled week
- Complete week plan
- Overlapping meal assignments

### Common Test Utilities
- Recipe builders/factories
- Date helpers for testing
- Database mock functions
- Effect simulation helpers

## Running Tests

### Unit Tests
```bash
cd client
gleam test
```

### Snapshot Tests
```bash
cd client
gleam test
gleam run -m birdie  # Review snapshots
```

### Specific Test Files
```bash
gleam test --file test/unit/recipe_creation_test.gleam
```

## Success Criteria

1. **Coverage**: All core workflow functions have tests
2. **Reliability**: Tests pass consistently across runs
3. **Maintainability**: Tests are clear and easy to understand
4. **Safety**: Refactoring can be performed with confidence tests will catch regressions
5. **Performance**: Test suite runs quickly (under 30 seconds)

## Next Steps

1. Review and approve this testing plan
2. Add Birdie dependency to project
3. Create test infrastructure and utilities
4. Implement tests phase by phase

## Notes

- External JavaScript functions (database calls) will need mocking
- Real-time subscriptions may need special handling in tests
- Consider test data isolation to prevent test interference
- Plan for test maintenance as the codebase evolves

# Integration Test Plan - Week 1 Safety Net

## Overview

Create 5-10 integration tests covering the critical user flows before starting the domain-driven refactor. These tests serve as regression protection during the migration.

## Testing Philosophy

- **Focus on user journeys**, not implementation details
- **Integration over unit testing** - test the whole flow working together
- **Fast feedback** - tests should run quickly and be easy to debug
- **Regression detection** - catch obvious breaks, not every edge case

## Critical User Flows to Test

### 1. Recipe Management Flow (2 tests)

#### Test 1: Recipe Creation and Persistence
**File**: `test/integration/recipe_creation_test.gleam`
**Flow**: New recipe → Fill form → Save → Verify in database
**Steps**:
1. Navigate to `/recipes/new`
2. Fill in title, author, serves, ingredients, method steps
3. Submit form
4. Verify recipe appears in database with correct data
5. Verify redirect to recipe detail page

**Key Assertions**:
- Recipe data persists correctly
- Slug generation works
- Navigation after save succeeds
- Database subscription updates UI

#### Test 2: Recipe List Loading and Filtering
**File**: `test/integration/recipe_list_test.gleam`
**Flow**: Load recipe list → Apply filters → Verify grouping
**Steps**:
1. Navigate to `/recipes`
2. Verify recipe list loads from database
3. Test tag-based grouping
4. Test author-based grouping
5. Test recipe search/filtering

**Key Assertions**:
- Recipes load from database
- Grouping logic works correctly
- UI updates with filtered results
- Real-time subscriptions work

### 2. Meal Planning Flow (2 tests)

#### Test 3: Weekly Planner Loading and Meal Assignment
**File**: `test/integration/planner_test.gleam`
**Flow**: Load planner → Assign meals → Save → Verify persistence
**Steps**:
1. Navigate to `/planner`
2. Verify week loads with current plan
3. Use typeahead to assign recipe to meal slot
4. Save plan
5. Verify plan persists in database

**Key Assertions**:
- Planner loads current week data
- Typeahead integration works
- Meal assignment updates model correctly
- Plan saves to database
- Real-time updates work

#### Test 4: Meal Completion Toggle
**File**: `test/integration/planner_completion_test.gleam`
**Flow**: Load plan → Mark meal complete → Verify state change
**Steps**:
1. Navigate to `/planner`
2. Mark a meal as complete
3. Verify UI updates
4. Verify state persists

**Key Assertions**:
- Completion state toggles correctly
- UI reflects completion status
- State persists across page refresh

### 3. Settings and Configuration (1 test)

#### Test 5: Settings Persistence
**File**: `test/integration/settings_test.gleam`
**Flow**: Load settings → Update API key → Save → Verify persistence
**Steps**:
1. Navigate to `/settings`
2. Update API key field
3. Save settings
4. Verify settings persist in database
5. Verify API key propagates to other features

**Key Assertions**:
- Settings load from database
- API key saves correctly
- Cross-feature integration works

### 4. Import/Export Flow (2 tests)

#### Test 6: Image Upload and AI Processing
**File**: `test/integration/image_upload_test.gleam`
**Flow**: Upload image → AI processes → Navigate to edit → Verify data
**Steps**:
1. Navigate to `/import`
2. Upload recipe image
3. Wait for AI processing
4. Verify parsed recipe data
5. Navigate to recipe editor
6. Verify form is pre-filled with parsed data

**Key Assertions**:
- File upload works
- AI integration processes correctly
- Parsed data populates form
- Navigation to editor succeeds

#### Test 7: URL Import and Recipe Parsing
**File**: `test/integration/url_import_test.gleam`
**Flow**: Enter URL → Scrape content → Parse recipe → Navigate to edit
**Steps**:
1. Navigate to `/import`
2. Enter recipe URL
3. Wait for scraping and parsing
4. Verify parsed recipe data
5. Navigate to recipe editor
6. Verify form is pre-filled

**Key Assertions**:
- URL scraping works
- Recipe parsing succeeds
- Data flows to editor correctly

### 5. Cross-Domain Integration (1 test)

#### Test 8: Recipe to Planner Integration
**File**: `test/integration/cross_domain_test.gleam`
**Flow**: Create recipe → Add to planner → Verify in planner view
**Steps**:
1. Create new recipe (reuse Test 1 pattern)
2. Navigate to planner
3. Assign newly created recipe to meal
4. Verify recipe appears in planner
5. Verify recipe details are accessible

**Key Assertions**:
- Recipe data flows between domains
- Planner can access recipe list
- Cross-domain data sharing works

## Test Implementation Strategy

### Mock Strategy
- **Database**: Use real InstantDB for integration tests (test environment)
- **External APIs**: Mock AI calls to avoid dependencies and costs
- **File system**: Mock file uploads for image processing tests

### Test Structure Pattern
```gleam
pub fn recipe_creation_workflow_test() {
  // Arrange
  let initial_model = setup_test_model()
  let test_recipe_data = create_test_recipe()
  
  // Act
  let #(result_model, effects) = simulate_recipe_creation(initial_model, test_recipe_data)
  
  // Assert
  result_model.current_recipe
  |> expect.to_equal(Some(test_recipe_data))
  
  // Verify database state
  verify_recipe_in_database(test_recipe_data)
}
```

### Test Data Management
- Create consistent test data fixtures
- Use deterministic IDs and slugs for testing
- Clean up test data after each test
- Use test database namespace to avoid conflicts

## Implementation Timeline (Week 1)

### Day 1-2: Setup and Foundation
- Set up test database environment
- Create test data fixtures and helpers
- Implement Test 1 (Recipe Creation) as baseline

### Day 3-4: Core Flows
- Implement Tests 2-4 (Recipe List, Planner flows)
- Refine test patterns and utilities
- Ensure tests run reliably

### Day 5: Import/Export and Integration
- Implement Tests 5-8 (Settings, Import, Cross-domain)
- Full test suite validation
- Documentation and cleanup

## Success Criteria

1. **All 8 tests pass consistently** in CI environment
2. **Tests run under 30 seconds** total execution time
3. **Tests catch intentional regressions** (verify by temporarily breaking things)
4. **Clear failure messages** that help identify what broke during refactor
5. **Tests can run locally** without complex setup

## Next Steps After Week 1

1. **Run test suite** before any refactor changes
2. **Use as regression guard** during each migration phase
3. **Add domain-specific tests** as you build new architecture
4. **Maintain and update** tests as functionality evolves

This safety net will give you confidence to make large structural changes while ensuring the core user experience remains intact.

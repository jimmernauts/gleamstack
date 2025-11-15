# Domain-Driven Architecture Refactor Plan

## Overview

This document outlines a comprehensive refactoring plan to transition the Mealstack client from a monolithic MVU structure to a domain-driven architecture with clear separation of business logic, improved modularity, and better maintainability.

## Current Architecture Analysis

### Current Structure
```
client/src/
├─ components/          # UI components (nav_footer, page_title, typeahead)
├─ lib/                # Pure utilities (utils.gleam)
├─ pages/              # Page-level MVU bundles
│  ├─ planner.gleam    # Planner logic, model, view, update
│  ├─ recipe.gleam     # Recipe CRUD, forms, lists
│  ├─ settings.gleam   # Settings management
│  ├─ shopping_list.gleam # Shopping list functionality
│  └─ upload.gleam     # Recipe import/upload
├─ session.gleam       # Data persistence, database interactions
└─ mealstack_client.gleam # Main application router and coordinator
```

### Identified Domains
Based on the current codebase, I've identified these core business domains:

1. **Recipe Management** - Recipe CRUD, lists, details, forms
2. **Meal Planning** - Weekly planning, meal assignments, completion tracking
3. **Shopping Lists** - List creation, ingredient aggregation, list management
4. **Settings & Configuration** - API keys, user preferences
5. **Import/Export** - Recipe parsing, file upload

## Proposed Architecture

### New Directory Structure
```
client/src/
├─ components/          # Unchanged - pure UI components
├─ lib/                # Unchanged - pure utilities
├─ recipe_management/   # Recipe domain
│  ├─ recipe_list.gleam     # Entry point, public API
│  ├─ recipe_list_model.gleam # Data types, database calls, encoders/decoders
│  ├─ recipe_list_update.gleam # Business logic, update functions
│  ├─ recipe_list_view.gleam   # View functions
│  ├─ recipe_detail.gleam      # Recipe CRUD entry point
│  ├─ recipe_detail_model.gleam # Recipe data structures, database calls
│  ├─ recipe_detail_update.gleam # Recipe form logic
│  └─ recipe_detail_view.gleam   # Recipe forms and detail views
├─ meal_planning/      # Planner domain
│  ├─ planner.gleam          # Entry point, public API
│  ├─ planner_model.gleam    # Plan data structures, database calls
│  ├─ planner_update.gleam   # Planning logic, meal assignments
│  └─ planner_view.gleam     # Planner views
├─ shopping_lists/     # Shopping list domain
│  ├─ shopping_list.gleam    # Entry point, public API
│  ├─ shopping_list_model.gleam # List data structures, database calls
│  ├─ shopping_list_update.gleam # List management logic
│  └─ shopping_list_view.gleam   # List views
├─ settings/           # Settings domain
│  ├─ settings.gleam          # Entry point, public API
│  ├─ settings_model.gleam    # Settings data structures, database calls
│  ├─ settings_update.gleam   # Settings management logic
│  └─ settings_view.gleam     # Settings views
├─ import_export/      # Import/Export domain
│  ├─ import_export.gleam     # Entry point, public API
│  ├─ import_export_model.gleam # Upload/parse data structures, database calls
│  ├─ import_export_update.gleam # File processing logic
│  └─ import_export_view.gleam   # Upload interface
└─ app.gleam            # Main application (refactored from mealstack_client.gleam)
```

### Domain Module Pattern

Each domain follows this consistent pattern:

#### Entry Point Module (`domain.gleam`)
- Public API that other domains can call
- Type definitions for public messages
- Constructor functions for initialization
- Cross-domain communication helpers

#### Model Module (`domain_model.gleam`)
- All domain-specific data types
- Database operations and subscriptions (direct calls to db.ts FFI)
- JSON encoders/decoders for domain data
- No business logic - pure data operations and persistence

#### Update Module (`domain_update.gleam`)
- All business logic and state transitions
- Message handling functions
- Domain-specific validation and transformation
- Effect generation for side effects

#### View Module (`domain_view.gleam`)
- All view functions for the domain
- Component composition
- Event handler creation
- Pure rendering logic

## Architecture Patterns

### 1. Nested Messages Pattern
Based on Lustre's nested action pattern, domains will have nested message types:

```gleam
// In app.gleam
pub type Msg {
  RecipeManagement(recipe_management.Msg)
  MealPlanning(meal_planning.Msg)
  ShoppingLists(shopping_lists.Msg)
  Settings(settings.Msg)
  ImportExport(import_export.Msg)
}

// In recipe_management.gleam
pub type Msg {
  List(recipe_list.Msg)
  Detail(recipe_detail.Msg)
}
```

### 2. Domain Boundaries
Each domain exposes a controlled public API:

```gleam
// recipe_management/recipe_list.gleam (internal only API, just drives the views and flows within recipe_management)
pub fn init() -> #(Model, Effect(Msg))
pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg))
pub fn view(model: Model) -> Element(Msg)

// Public API (other domains can call this)
pub fn get_recipe_by_id(id: String) -> Option(Recipe)
pub fn search_recipe_by_slug(slug: String) -> Option(Recipe)
etc...
```

### 3. Direct Database Access
Each domain's `_model.gleam` module handles its own database operations directly:
- Database calls are made in domain model modules
- No shared data layer - domains own their data access
- Cross-domain data sharing happens through public API functions

## Migration Strategy

### Phase 1: Foundation (Week 1-2)
1. **Create new directory structure**
   - Set up domain directories
   - Create placeholder files for each domain


2. **Extract database functions from session.gleam**
   - Move database operations to appropriate domain `_model.gleam` files
   - Each domain handles its own subscriptions and data access
   - Remove the shared data layer concept entirely

3. **Create domain boundaries**
   - Define public APIs for each domain
   - Create entry point modules with basic structure

### Phase 2: Recipe Management Domain (Week 3-4)
1. **Extract recipe functionality**
   - Move recipe types to `recipe_management/recipe_list_model.gleam`
   - Extract recipe CRUD logic to `recipe_management/recipe_detail_update.gleam`
   - Move recipe views to appropriate view modules

2. **Create recipe list domain**
   - Extract list management logic
   - Implement proper separation between list and detail concerns

3. **Update main app**
   - Wire recipe domain into main application
   - Test recipe functionality works as before

### Phase 3: Meal Planning Domain (Week 5-6)
1. **Extract planner functionality**
   - Move planning logic to `meal_planning/` domain
   - Separate planning data from recipe data
   - Implement proper domain boundaries

2. **Cross-domain communication**
   - Implement recipe → planner communication
   - Handle meal assignment with proper data flow

### Phase 4: Remaining Domains (Week 7-8)
1. **Shopping Lists domain**
   - Extract shopping list functionality
   - Implement ingredient aggregation logic

2. **Settings domain**
   - Extract settings management
   - Handle cross-domain configuration

3. **Import/Export domain**
   - Extract upload functionality
   - Separate parsing logic from UI

### Phase 5: Integration & Cleanup (Week 9-10)
1. **Remove old files**
   - Delete `pages/` directory
   - Remove old `session.gleam`
   - Clean up imports

2. **Testing & Refinement**
   - Update all tests to work with new structure
   - Performance testing
   - Documentation updates

## Benefits of This Architecture

### 1. **Clear Separation of Concerns**
- Business logic isolated by domain
- UI components remain reusable
- Data operations centralized

### 2. **Improved Testability**
- Domain logic can be tested in isolation
- Mock data layer for business logic tests
- Clear boundaries for unit testing

### 3. **Better Maintainability**
- Changes to one domain don't affect others
- Easier to understand code organization
- Clear ownership of functionality

### 4. **Enhanced Reusability**
- Domains can be reused in different contexts
- Public APIs allow controlled sharing
- Components remain domain-agnostic

### 5. **Scalability**
- New domains can be added easily
- Existing domains can be split further
- Clear patterns for future development

## Potential Challenges & Mitigations

### 1. **Cross-Domain Communication**
**Challenge**: Domains need to share data and coordinate actions
**Mitigation**: 
- Define clear public APIs for each domain (pure functions only)
- Direct module-to-module function calls for low throughput app
- Each domain owns its data and exposes read-only access functions
- Avoid complex message passing between domains


### 3. **Initial Complexity**
**Challenge**: More files and directories initially
**Mitigation**:
- Clear naming conventions: `{domain}_{module}.gleam` pattern
- Consistent 4-file structure across all domains (entry, model, update, view)
- IDE navigation: domain folders group related functionality
- Documentation: each domain has clear public API documentation

### 4. **Performance Concerns**
**Challenge**: Potential for more indirection through module boundaries
**Mitigation**:
- Profile during migration to identify bottlenecks
- Optimize hot paths after structure is established
- Gleam's function call overhead is minimal
- Direct module calls (no message passing between domains)
- Database operations remain unchanged

## Implementation Guidelines

### 1. **Domain Boundaries**
- Each domain should have minimal dependencies on other domains
- Database operations stay within domain `_model.gleam` files
- Public APIs should be stable and well-documented
- Prefer direct function calls over message passing

### 2. **Message Flow**
- Follow parent → child message nesting pattern within domains
- Avoid circular dependencies between domains
- Use effects only for external side effects (database, navigation)

### 3. **Data Ownership**
- Each domain owns its core data structures and database access
- Cross-domain data sharing through public API functions
- Transform data at domain boundaries when needed

### 4. **Testing Strategy**
- Test domain logic in isolation
- Test integration at the app level
- Mock database calls in unit tests using standard testing patterns

## Success Criteria

1. **Functionality**: All existing features work without regression
2. **Performance**: No significant performance degradation
3. **Maintainability**: New features can be added more easily
4. **Testability**: Domain logic can be tested in isolation
5. **Code Organization**: Clear separation of concerns

## Next Steps

1. **Review this plan** with the team and gather feedback
2. **Set up the new directory structure** (Phase 1)
3. **Extract database functions from session.gleam** to appropriate domain models
4. **Choose one domain** (recommend Recipe Management) to start with
5. **Establish patterns** that can be replicated across other domains

This refactoring will provide a solid foundation for scaling the application while maintaining the simplicity and elegance of the MVU pattern.

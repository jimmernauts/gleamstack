---
description: Gleam & Lustre Coding Standards
---

# Gleam & Lustre Coding Standards

## Gleam language paradigms

- You shouldn't need to run `gleam build`. The LSP reports type errors to the IDE that you should be able to read.
- ALWAYS fix lint errors as soon as possible, as Gleam's static typing catches many issues early on

## Gleam & Lustre Patterns

### Architecture
- Follow the Elm/Lustre architecture: Model, Msg, update, view
- Use `lustre.simple()` or `lustre.application()` - avoid `lustre.element()` for interactive features
- All update functions return `#(Model, Effect(Msg))`
- Effects are created with `effect.from`, `effect.map`, `effect.batch`, or `effect.none()`

### Syntax & Style
- Use `use` syntax for monadic operations (decode, effect.from, promise operations)
- Prefer pattern matching with `case` over if/else
- Use pipe operator `|>` for function chaining
- Name messages in subject-verb-object style: `UserClickedButton`, `DbReturnedData`, `ApiFailedRequest`
- Use descriptive variable names, avoid single letters except in lambdas

### Type Safety
- Always use `Option(T)` for nullable values, never rely on empty strings
- Use `Result(Ok, Err)` for operations that can fail
- Define custom types for domain concepts (don't use primitives for everything)
- Use pattern matching exhaustively - let the compiler help you

## Code Organization

### File Structure
- Domain logic goes in `client/src/pages/` (one file per domain: planner, shoppinglist, recipe_list, etc.)
- Shared types in `client/src/shared/types.gleam`
- Shared codecs (encoders/decoders) in `client/src/shared/codecs.gleam`
- Reusable components in `client/src/components/`
- Database functions in `client/src/db.ts` (TypeScript)
- Main app orchestration in `client/src/app.gleam`

### Domain Module Structure
Each domain module should follow this order:
1. Imports
2. Types (Msg, Model, domain-specific types)
3. Update functions
4. Database/Effect functions (with @external declarations)
5. View functions
6. Components (helper view functions)
7. Decoders
8. Encoders

## Database & Persistence

### InstantDB
- Use InstantDB for all persistence
- Store complex nested data as JSON strings (use `json.to_string()`)
- Use rata_die format (Int) for dates in database
- Always handle subscription cleanup in app.gleam's update function
- Database functions go in `db.ts`, exposed via `@external` declarations

### Subscriptions
- Open subscriptions in route change handlers
- Store subscription cleanup functions in `Model.db_subscriptions: Dict(String, fn() -> Nil)`
- Clean up subscriptions when navigating away from a route
- Use date strings or slugs as subscription keys

## UI/UX Patterns

### Views
- Use semantic HTML elements (section, nav, article, etc.)
- Use Tailwind CSS classes for styling
- Use Lustre effects in view functions for effectful operations
- Group related content with clear visual hierarchy
- Use `page_title` component for consistent page headers
- Use `nav_footer` component for bottom navigation

### Forms & Editing
- Prefer inline editing where possible
- Use typeahead component for recipe/item lookups
- Provide immediate visual feedback for user actions
- Use checkboxes for toggleable state

### State Management
- Keep current item in model (e.g., `current_recipe`, `current` shopping list)
- Store lists/collections separately (e.g., `all_lists`, `recipes`)
- Use optimistic updates where appropriate

## Gleam-Specific Guidelines

### Common Patterns
- Use `option.unwrap(value, default)` for safe unwrapping
- Use `result.unwrap(value, default)` for results
- Use `list.map`, `list.filter`, `list.fold` instead of loops
- Use `dict.get`, `dict.upsert`, `dict.update` for dictionary operations
- Use `bool.guard` for early returns in view functions

### Avoid
- Don't use `let assert` in production code (only in tests or main)
- Don't ignore compiler warnings
- Don't use `todo` or `panic` in production code
- Don't mutate data (Gleam is immutable)

## TypeScript Interop

### External Functions
- Define TypeScript functions in `.ts` files
- Expose to Gleam with `@external(javascript, "path", "function_name")`
- Keep external functions simple and focused
- Handle JSON encoding/decoding at the boundary
- Use Dynamic type for complex JS objects, decode immediately

### Type Conversions
- Gleam Date ↔ JS number (rata_die format)
- Gleam Dict ↔ JS object (via JSON)
- Gleam List ↔ JS array
- Gleam Option(T) ↔ JS null/undefined (handle carefully)

## Error Handling

### User-Facing Errors
- Show helpful error messages
- Provide recovery actions when possible
- Log errors to console for debugging
- Don't crash the app on expected errors

### Developer Errors
- Use descriptive error messages in decoders
- Log unexpected states to console
- Use type system to prevent errors at compile time
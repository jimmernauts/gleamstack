# AGENTS.md

This file contains essential information for AI agents working in the Gleamstack codebase.

## Project Overview

This is a monorepo containing a Gleam frontend application and Cloudflare Worker backend.

**Frontend:** Gleam with Lustre framework (Elm-inspired MVU architecture) compiling to JavaScript
**Backend:** Cloudflare Worker with Gleam and TypeScript
**Database:** InstantDB for real-time client-side persistence
**Build Tools:** Vite, TailwindCSS v4 with fluid type scaling
**Package Manager:** Bun (not npm)

## Essential Commands

### Development
```bash
cd /home/ubuntu/projects/gleamstack && just dev                    # Frontend dev server
cd /home/ubuntu/projects/gleamstack && just dev-full               # Full stack development
cd /home/ubuntu/projects/gleamstack/app && just build-app         # Frontend build with watch
```

### Testing
```bash
cd /home/ubuntu/projects/gleamstack && just test-app               # Complete frontend test suite
cd /home/ubuntu/projects/gleamstack && just test-worker           # Backend test suite
cd /home/ubuntu/projects/gleamstack/app && gleam test --target javascript  # Run all Gleam tests
cd /home/ubuntu/projects/gleamstack/app && gleam run -m birdie      # Snapshot tests
cd /home/ubuntu/projects/gleamstack/app && gleam run -m birdie accept # Approve all snapshots
cd /home/ubuntu/projects/gleamstack/app && gleam run -m birdie review # Interactive snapshot review
cd /home/ubuntu/projects/gleamstack/app && bun run test:image       # TypeScript image processing tests
```

### Single Test Execution
**Gleam Tests:** Cannot run individual test files - all Gleam tests run through the main runner in `app/test/mealstack_client_test.gleam`. To test specific functionality, comment/uncomment test groups in the main runner.

**Birdie Snapshots:** Use `gleam run -m birdie review` for interactive review of specific snapshots.

**TypeScript Tests:** `cd /home/ubuntu/projects/gleamstack/app && bun test <specific-file.test.ts>`

### Deployment
```bash
cd /home/ubuntu/projects/gleamstack && just deploy                 # Full deployment (runs both test suites first)
```

## Code Style Guidelines

### Lint Policy
- **Lint ERRORS:** Must be fixed immediately (type errors, syntax errors, compilation failures)
- **Lint warnings:** Must be ignored until task completion (unused imports, etc.)

### Gleam & Lustre Patterns
- Follow Elm/Lustre architecture: Model, Msg, update, view
- Use `lustre.simple()` or `lustre.application()` - avoid `lustre.element()` for interactive features
- All update functions return `#(Model, Effect(Msg))`
- Effects are created with `effect.from`, `effect.map`, `effect.batch`, or `effect.none()`
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

### File Organization
**Domain Module Structure (each domain module follows this order):**
1. Imports
2. Types (Msg, Model, domain-specific types)
3. Update functions
4. Database/Effect functions (with @external declarations)
5. View functions
6. Components (helper view functions)
7. Decoders
8. Encoders

**Directory Structure:**
- Domain logic in `app/src/pages/` (one file per domain: planner, shoppinglist, recipe_list, etc.)
- Shared types in `app/src/shared/types.gleam`
- Shared codecs (encoders/decoders) in `app/src/shared/codecs.gleam`
- Reusable components in `app/src/components/`
- Database functions in `app/src/db.ts` (TypeScript)
- Main app orchestration in `app/src/app.gleam`

### Import Style
- Group imports: standard library → third-party → local modules
- Use explicit imports, avoid `import.*`
- Order alphabetically within groups

### TypeScript Interop
- Define TypeScript functions in `.ts` files
- Expose to Gleam with `@external(javascript, "path", "function_name")`
- Keep external functions simple and focused
- Handle JSON encoding/decoding at the boundary
- Use Dynamic type for complex JS objects, decode immediately

## Testing Standards

### Test Structure (project root relative paths)
- `app/test/unit/` - Unit tests for pure functions and business logic
- `app/test/snapshot/` - Component view snapshots with Birdie
- `app/test/utils/` - Mock data and test helpers
- `app/test/integration/` - Integration tests for pages/features

### Testing Patterns
**Unit Tests (Startest):**
- Test pure functions and business logic
- Use `describe`/`it` structure with `expect` assertions
- Focus on `update` functions, data transformation, validation

**Snapshot Tests (Birdie):**
- Only test actual `view` and `update` functions from source code
- Use `birdie.snap(title: "descriptive_name")` for component output
- No string formatting or arbitrary data snapshots
- Use `lustre/dev/simulate` combined with birdie.snap to simulate user interactions

**Guidelines:**
- Tests should exercise real application code
- Prefer testing `update`/`view` functions over utilities
- Keep snapshots focused on component rendering and testing interaction flows
- Write snapshot tests for all view functions
- Write unit tests for complex update logic
- Test decoders with various input shapes
- Test edge cases (empty lists, missing data, etc.)

## Database & Integration

### InstantDB
- Use InstantDB for all persistence
- Store complex nested data as JSON strings (use `json.to_string()`)
- Use rata_die format (Int) for dates in database
- Always handle subscription cleanup in app.gleam's update function
- Database functions go in `app/src/db.ts`, exposed via `@external` declarations

### Subscriptions
- Open subscriptions in route change handlers
- Store subscription cleanup functions in `Model.db_subscriptions: Dict(String, fn() -> Nil)`
- Clean up subscriptions when navigating away from a route
- Use date strings or slugs as subscription keys

## Error Handling & Best Practices

### Type Safety Requirements
- Never use `let assert` in production code (only in tests or main)
- Don't ignore compiler warnings
- Don't use `todo` or `panic` in production code
- Don't mutate data (Gleam is immutable)

### Common Patterns
- Use `option.unwrap(value, default)` for safe unwrapping
- Use `result.unwrap(value, default)` for results
- Use `list.map`, `list.filter`, `list.fold` instead of loops
- Use `dict.get`, `dict.upsert`, `dict.update` for dictionary operations
- Use `bool.guard` for early returns in view functions

### Error Handling
**User-Facing Errors:**
- Show helpful error messages
- Provide recovery actions when possible
- Log errors to console for debugging
- Don't crash the app on expected errors

**Developer Errors:**
- Use descriptive error messages in decoders
- Log unexpected states to console
- Use type system to prevent errors at compile time

## Key Locations

### Important Directories
- `/app/src/pages/` - Domain logic and page components
- `/app/src/components/` - Reusable UI components
- `/app/src/shared/` - Shared types, codecs, and db functions
- `/app/src/db.ts` - Database functions (TypeScript)
- `/worker/src/` - Backend Cloudflare Worker logic
- `/justfile` - Task runner commands

### Configuration Files
- `/app/gleam.toml` - Frontend Gleam configuration
- `/worker/gleam.toml` - Backend Gleam configuration
- `/app/package.json` - Frontend dependencies
- `/worker/package.json` - Backend dependencies
- `/app/vite.config.ts` - Vite build configuration
- `/biome.jsonc` - JavaScript/TypeScript linting and formatting
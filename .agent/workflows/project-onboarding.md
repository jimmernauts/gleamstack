---
description: Project Overview and Core Commands
---

# Project Overview

This is a monorepo containing a Gleam frontend application and Cloudflare Worker backend.

- **Frontend:** Gleam with Lustre framework (Elm-inspired MVU architecture) compiling to JavaScript
- **Backend:** Cloudflare Worker with Gleam and TypeScript
- **Database:** Turso (libSQL) — browser-local OPFS replica with cloud sync via push/pull
- **Build Tools:** Vite, TailwindCSS v4 with fluid type scaling
- **Package Manager:** Bun (not npm)

## Essential Commands

### Development
// turbo
```bash
just dev                    # Frontend dev server (from project root)
just dev-full               # Full stack development
```

### Testing
// turbo
```bash
just test-app               # Complete frontend test suite
just test-worker            # Backend test suite
```

From `app/` directory:
// turbo
```bash
gleam test                  # Run all Gleam tests
gleam run -m birdie         # Snapshot tests
gleam run -m birdie accept  # Approve all snapshots
gleam run -m birdie review  # Interactive snapshot review
bun run test:image          # TypeScript image processing tests
```

### Single Test Execution
- **Gleam Tests:** Cannot run individual test files - all Gleam tests run through the main runner. To test specific functionality, comment/uncomment test groups in the main runner.
- **Birdie Snapshots:** Use `gleam run -m birdie review` for interactive review.
- **TypeScript Tests:** `bun test <specific-file.test.ts>` (from `app/` directory)

### Deployment
// turbo
```bash
just deploy                 # Full deployment (runs both test suites first)
```

## Key Locations

### Important Directories
- `app/src/pages/` - Domain logic and page components
- `app/src/components/` - Reusable UI components
- `app/src/shared/` - Shared types, codecs, and db functions
- `app/src/db.ts` - Database functions (TypeScript)
- `worker/src/` - Backend Cloudflare Worker logic
- `justfile` - Task runner commands

### Configuration Files
- `app/gleam.toml` - Frontend Gleam configuration
- `worker/gleam.toml` - Backend Gleam configuration
- `app/package.json` - Frontend dependencies
- `worker/package.json` - Backend dependencies
- `app/vite.config.ts` - Vite build configuration
- `biome.jsonc` - JavaScript/TypeScript linting and formatting

## Verification
- Home screen: [http://localhost:5173/](http://localhost:5173/)
- Verify the header says "Mealstack"
- Verify primary navigation: Plan, Shop, List, New, Import

## Routing
- `/recipes` - list view
- `/recipes/new` - create new
- `/recipes/:slug` - detail view
- `/recipes/:slug/edit` - edit view
- `/planner?date=YYYY-MM-DD` - planner with optional date
- `/shopping-list` - list view
- `/shopping-list/:date` - detail view for specific date
- `/import` - import view (corresponds to upload.gleam, `import` is a reserved keyword)
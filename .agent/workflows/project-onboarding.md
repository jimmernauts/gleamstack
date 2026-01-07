---
description: Project Overview and Core Commands
---

# Project Overview

1. This directory is a monorepo containing a few projects as part of a larger application.
2. The client project is written in Gleam, a type-safe language that compiles to either Erlang or JavaScript. Here we use it to compile a client-side Single Page Application using the Lustre framework for Gleam.
3. The server project is a stub only and we do not use it yet.
// turbo
4. The command to run the client project is `bun run vite dev` (executed in the `client/` directory).
5. NEVER fix lint warnings until you are finished with the task at hand.
6. ALWAYS fix lint errors as soon as possible, as Gleam's static typing catches many issues early on.
7. ALWAYS use `bun` to manage package.json files and javascript dependencies, not `npm`.

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
- `/import` - import view (corresponds to the upload.gleam page, because import is a reserved keyword)
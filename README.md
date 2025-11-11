# Mealstack

A recipe management and meal planning application built with Gleam.

## Technology Stack

- **Frontend**: Gleam (compiles to JavaScript) with Lustre framework
- **Database**: InstantDB (real-time database)
- **Styling**: TailwindCSS
- **Build Tool**: Vite
- **Runtime**: Bun
- **Server**: Gleam with Glen framework (recipe scraping service)

## Getting Started

### Prerequisites

- Gleam compiler
- Bun runtime
- Node.js (for some dependencies)

### Installation

```bash
# Clone the repository
git clone github.com/jimmernauts/gleamstack
cd gleamstack

# Install dependencies
bun install

# Setup environment
cp client/.env.example client/.env
# Edit .env with InstantDB credentials
```

### Development

```bash
# Start client development server
bun run vite dev

# Start server (for recipe scraping)
cd server && gleam run
```

## Configuration

InstantDB is configured using the `.env` file and the `src/instant.schema.ts` file in the client directory.

## Project Structure

```
gleamstack/
├── client/          # Gleam frontend application
│   ├── src/         # Source code
│   │   ├── pages/   # Page components
│   │   ├── components/ # Shared components
│   │   └── lib/     # Utility modules
│   ├── gleam.toml   # Gleam configuration
│   └── package.json # Node dependencies
├── server/          # Recipe scraping service
│   ├── gleam.toml   # Server configuration
│   └── src/         # Server source code
├── common/          # Shared code (if any)
└── plans/           # Project plans and documentation
```

## Features

- Recipe management with CRUD operations
- Meal planning with weekly calendar view
- Shopping list generation from meal plans
- Recipe import from URLs via web scraping
- OCR recipe scanning capabilities (WIP)
- Tag-based recipe categorization
- PWA capabilities

## Live Demo

https://gleamstack.pages.dev

## Testing

The project uses Startest for unit testing and Birdie for snapshot testing.

### Running Tests

```bash
# Run all tests (automatically discovers files ending in '_test.gleam')
cd client
gleam test

# Test output shows discovered test files and individual test results
# Example output:
# Running 12 tests
# ✓ utils ❯ slugify ❯ should strip spaces and convert to lowercase
# ✓ Recipe List ❯ merge_recipe_into_model ❯ should merge a new recipe into empty model
# Test Files: 2
#      Tests: 12 passed (12)
```

### Test Structure

- **Unit Tests**: `test/unit/` - Pure function and business logic tests
- **Snapshot Tests**: `test/snapshot/` - Component and integration tests  
- **Test Utilities**: `test/utils/` - Mock data and helper functions
- **Main Test**: `test/mealstack_client_test.gleam` - Core functionality tests

### Test Discovery

Gleam automatically discovers all files ending in `_test.gleam` and runs:
- Functions ending in `_test` (standalone tests)
- Functions containing `describe` blocks (structured tests)

## Build & Deployment

// TODO: Add build and deployment process documentation

## Database Schema

// TODO: Add database schema documentation

# Mealstack

A recipe management and meal planning application built with Gleam.

## Technology Stack

- **Frontend**: [Gleam](https://gleam.run/) (compiles to JavaScript) with [Lustre](https://github.com/lustre-labs/lustre) framework
- **Backend**: Gleam deployed on Cloudflare Workers
- **Database**: [InstantDB](https://instantdb.com/) (real-time, client-side database)
- **Styling**: [TailwindCSS v4](https://tailwindcss.com/)
- **Build Tool**: [Vite](https://vitejs.dev/)
- **Runtime**: [Bun](https://bun.sh/)
- **Task Runner**: [Just](https://github.com/casey/just)

## Features

- **Recipe Management**: Create, edit, and organize recipes with tags.
- **Recipe Import**: Scrape recipes from URLs or parse them from text/images using AI.
- **Meal Planning**: Drag-and-drop weekly meal planner.
- **Shopping List**: Generate shopping lists automatically from your meal plan.
- **PWA Support**: Installable as a Progressive Web App.

## Project Structure

```bash
gleamstack/
├── app/             # Frontend application (Gleam + Lustre + Vite)
├── worker/          # Backend worker (Gleam + Cloudflare Workers)
├── common/          # Shared Gleam code
└── justfile         # Task runner configuration
```

## Getting Started

### Prerequisites

- [Gleam](https://gleam.run/getting-started/installing/)
- [Bun](https://bun.sh/)
- [Just](https://github.com/casey/just) (optional, but recommended)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/jimmernauts/gleamstack.git
   cd gleamstack
   ```

2. Install dependencies:
   ```bash
   bun install
   ```

3. Configure environment variables:
   ```bash
   cp app/.env.example app/.env
   # Edit app/.env with your InstantDB App ID
   ```

### Development

We use `just` to manage development commands.

**Start the specific service:**
```bash
# Start the frontend dev server
just dev
```

**Run the full stack:**
```bash
# Builds app & worker, and serves the worker
just dev-full
```

**Run tests:**
```bash
just test-app    # Run frontend tests
just test-worker # Run backend tests
```

If you don't have `just` installed, you can look at the `justfile` to see the underlying `bun` and `gleam` commands.

## Architecture Highlights

- **InstantDB Integration**: The app uses InstantDB for real-time data sync and offline capabilities.
- **Gleam on the Edge**: The backend worker runs Gleam encoded as JavaScript on Cloudflare Workers, handling scraping and AI tasks.
- **Modern Styling**: TailwindCSS v4 with fluid type scaling.

## Testing

The project uses a combination of Gleam's built-in testing harness, Startest, and Birdie for snapshot testing.

- **Unit Tests**: Business logic and pure functions.
- **Snapshot Tests**: Component rendering and integration.

Run all tests from the root:
```bash
just test-app
just test-worker
```

# Mealstack

A recipe management and meal-planning application built with Gleam.

## Technology Stack

- **Frontend:** [Gleam](https://gleam.run/) with the [Lustre](https://github.com/lustre-labs/lustre) framework, compiled to JavaScript
- **Backend:** Gleam and TypeScript on Cloudflare Workers
- **Database:** Turso Cloud (libSQL), with a browser-local OPFS replica and bidirectional push/pull sync
- **Styling:** Tailwind CSS v4
- **Build tool:** Vite
- **Runtime and package manager:** Bun
- **Task runner:** Just

## Features

- **Recipe management:** Create, edit, delete, and organize recipes with tags.
- **Recipe import:** Scrape recipe pages or parse recipe text and images with Gemini.
- **Meal planning:** Use the drag-and-drop weekly planner.
- **Shopping lists:** Maintain lists associated with planned meals.
- **Offline-first browser storage:** The app keeps a local SQLite replica in OPFS and synchronizes changes with Turso when connectivity is available.
- **PWA support:** Install the app as a Progressive Web App.

## Architecture

The browser talks to a local SQLite replica through the Turso sync WASM client. Reads and writes remain available locally; writes are pushed to Turso and remote changes are pulled into the replica. The Cloudflare Worker provides the database configuration to authenticated clients and handles scraping and Gemini-backed parsing. Production access is protected by Cloudflare Access.

This is currently a private, single-user application. Sync uses last-push-wins semantics; it is not a multi-user collaboration system.

## Project Structure

```text
gleamstack/
├── app/             # Frontend Gleam/Lustre application and Vite build
├── worker/          # Cloudflare Worker and parsing endpoints
├── common/          # Shared TypeScript types and persistence helpers
├── db/              # Turso schema migrations and local migration tests
└── justfile         # Task runner
```

## Getting Started

### Prerequisites

- [Gleam](https://gleam.run/getting-started/installing/)
- [Bun](https://bun.sh/)
- [Just](https://github.com/casey/just/) (recommended)

### Installation

Clone the repository, then install the frontend and Worker dependencies:

```bash
git clone https://github.com/jimmernauts/gleamstack.git
cd gleamstack
(cd app && bun install)
(cd worker && bun install)
```

### Local configuration

Create the ignored file `worker/.dev.vars` for local Worker and integration-test credentials:

```text
TURSO_URL=libsql://your-development-database.turso.io
TURSO_AUTH_TOKEN=your-development-database-token
GEMINI_API_KEY=your-gemini-key
```

Never commit this file or put production credentials in the repository. Production values are configured as Cloudflare Worker secrets.

### Development

Run commands from the repository root:

```bash
just dev       # Frontend development server
just dev-full  # Frontend, Worker, and Wrangler development stack
```

### Testing

```bash
just test-app               # Frontend tests, formatting, and build
just test-worker            # Worker unit tests and Gleam checks
just test-worker-integration # Credentialed UAT tests; requires worker/.dev.vars
```

### Deployment

```bash
just deploy
```

Deployment runs the application and Worker checks before deploying with Wrangler. The production Worker is `mealstack` and serves the built frontend through its assets binding.

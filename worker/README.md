# Mealstack Worker

The backend service for Mealstack. It runs on Cloudflare Workers and provides recipe scraping, Gemini-backed recipe parsing, and the authenticated Turso database configuration used by the browser client.

## Technology Stack

- **Application code:** Gleam with TypeScript FFI
- **Runtime:** Cloudflare Workers
- **Local tooling:** Bun and Wrangler
- **Database client:** `@tursodatabase/serverless`
- **AI client:** `@google/genai`

## API endpoints

### `GET /api/db-config`

Returns the Turso URL and configured client auth token to an authenticated browser client. Production access is protected by Cloudflare Access. The endpoint returns `503` when the Turso Worker secrets are not configured.

### `GET /api/scrape_url?target=<url>`

Fetches a recipe page, extracts structured recipe data, and returns every recipe found on the page. The parser handles JSON-LD first and falls back to page-text parsing when needed.

### `POST /api/parse_recipe_text`

Parses unstructured recipe text into the application recipe shape using Gemini.

Example body:

```json
{
  "text": "1 cup flour, 2 eggs... Mix them together..."
}
```

### `POST /api/parse_recipe_image`

Extracts a recipe from a base64-encoded image data URL using Gemini.

Example body:

```json
{
  "image": "data:image/jpeg;base64,..."
}
```

## Configuration

For local development and credentialed integration tests, create the ignored file `worker/.dev.vars`:

```text
TURSO_URL=libsql://your-development-database.turso.io
TURSO_AUTH_TOKEN=your-development-database-token
GEMINI_API_KEY=your-gemini-key
```

The application schema is owned by the SQL migrations in `db/migrations/`. The Worker reads Turso credentials from its runtime environment; do not hard-code credentials or commit `.dev.vars`.

## Running locally

From the repository root:

```bash
just dev-full
```

To work on the Worker alone:

```bash
cd worker
gleam build
bun run server.ts
```

The local server normally listens on `http://localhost:3000`.

## Testing

Run the standard Worker checks:

```bash
just test-worker
```

This runs the unit tests, Gleam tests, and a Gleam build. The TypeScript unit-test script can also be run directly:

```bash
cd worker
bun run test:unit
```

Credentialed integration tests exercise the local Worker and Gemini/Turso path. They require `worker/.dev.vars` and must never target production:

```bash
cd worker
bun --env-file=.dev.vars run test:integration:uat
```

To target a local Worker on another port, set `MEALSTACK_WORKER_URL`. The test harness rejects the production Worker hostname.

## Deployment

The root `just deploy` command runs the application and Worker checks before deploying with Wrangler. Production Worker secrets are managed through Cloudflare; the required names are `TURSO_URL`, `TURSO_AUTH_TOKEN`, and `GEMINI_API_KEY`.

## Project structure

- `src/mealstack_worker.gleam` — request routing and Worker application logic
- `src/scrape_url.ts` — URL fetching and structured-data extraction
- `src/parse_recipe.ts` — Gemini text/image parsing and Turso tag lookup
- `test/` — unit and integration tests
- `package.json` — Bun dependencies and test commands
- `gleam.toml` — Gleam project configuration

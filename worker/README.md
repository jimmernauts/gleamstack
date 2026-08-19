# mealstack_worker

This is the backend worker service for the Mealstack application. It is primarily responsible for scraping recipe websites and parsing recipe data from various formats (text, images) using AI.

## Technology Stack

- **Language:** [Gleam](https://gleam.run/) (compiles to JavaScript)
- **Runtime:** [Bun](https://bun.sh/)
- **Web Server:** [Glen](https://github.com/glen-framework/glen)
- **Deployment:** Cloudflare Workers (via Wrangler)

## Capabilities

The worker exposes an API to:
1.  **Scrape Recipes:** Extract structured data (JSON-LD) from a recipe website URL.
2.  **Parse Text:** Convert unstructured text (e.g., pasted recipe) into a structured format using AI.
3.  **Parse Images:** Extract and structure recipe information from an image using AI.

## API Endpoints

### `GET /api/scrape_url`

Scrapes valid JSON-LD recipe data from a given URL.

- **Query Parameters:**
    - `target`: The URL of the recipe page to scrape.
- **Response:** JSON object containing the scraped data.

### `POST /api/parse_recipe_text`

Parses a unstructured recipe text into a structured JSON format.

- **Body:** JSON object
  ```json
  {
    "text": "1 cup flour, 2 eggs... Mix them together..."
  }
  ```
- **Response:** Structured recipe JSON.

The parser response includes a `tags` object. It can contain at most one `Cuisine`, `Style`, and `Label` entry, and each value is filtered against the existing `tag_options` values in InstantDB.
### `POST /api/parse_recipe_image`

Parses a recipe from an image (base64 encoded or publicly accessible URL, depending on implementation details not fully exposed here but general usage implies image data).

- **Body:** JSON object
  ```json
  {
    "image": "<base64_image_data_or_url>"
  }
  ```
- **Response:** Structured recipe JSON.

## Development

### Prerequisites

- [Bun](https://bun.sh/)
- [Gleam](https://gleam.run/)

### Running Locally

You can run a local development server using the bundled `server.ts` script. This bypasses Wrangler and runs directly on Bun, which is useful for quick debugging.

```bash
bun run server.ts
```

The server will typically start on `http://localhost:3000` (or the port defined in `server.ts`/environment).

For a more production-like environment (simulating Cloudflare Workers), use Wrangler from the root project or configured scripts.

### UAT integration tests

Credentialed integration tests use the `mealstack-dev` InstantDB app. They reject the production worker URL. Keep `worker/.dev.vars` at mode `600` with the dev app ID and admin token.

Start the local UAT worker in one terminal:

```bash
cd worker
gleam build
bun run server.ts
```

Run the five bookmark checks in another terminal:

```bash
cd worker
MEALSTACK_WORKER_URL=http://127.0.0.1:3000 bun run test:integration:uat
```

The local server loads `worker/.dev.vars` automatically.

If the bookmark tests fail with `Unable to connect` or `ERR_TLS_CERT_ALTNAME_INVALID` while the parse test passes, the local Bun worker cannot reach the source sites. Check the machine's HTTPS proxy and certificate configuration (`env | grep -i proxy`); the request has not reached the scraper/parser in that case.
### One-off favourites importer

`scripts/import_favourites.ts` is a disposable operational importer. It reads the `recipe` folder, processes a bounded batch, calls `/api/scrape_url?all=true`, and appends one JSONL checkpoint record per URL. It is parse-only unless `--write` is supplied.

Run a parse-only batch from the repository root:

```bash
bun worker/scripts/import_favourites.ts \
  --offset 0 \
  --limit 10 \
  --checkpoint plans/favourites_import_batch_000.jsonl
```

After reviewing the checkpoint, write the same successful responses to a selected InstantDB app:

```bash
bun --env-file=worker/.dev.vars worker/scripts/import_favourites.ts \
  --offset 0 \
  --limit 10 \
  --checkpoint plans/favourites_import_batch_000.jsonl \
  --app-id 4304e120-9a5c-45e4-ba7a-4aaa0b7f282a \
  --write
```

Do not put the admin token in source control or shell history; use a protected environment file instead. The importer indexes existing recipes by canonical source/slug identity before writing, reuses a matching entity, and uses a stable source-URL/slug ID when no match exists. It preserves the worker's recipe data and only reshapes ingredient/instruction arrays into the JSON object shape used by the frontend save path.

### Duplicate report and cleanup

`scripts/cleanup_recipe_duplicates.ts` is read-only by default. It reports duplicate groups and writes a reviewable JSON report without deleting anything:

```bash
bun --env-file=/secure/mealstack-production.env \
  worker/scripts/cleanup_recipe_duplicates.ts \
  --app-id eeaf3b82-5b5d-40c4-a29a-b68988377c3c \
  --report plans/favourites_duplicate_report.json
```

After reviewing the report, delete only source-URL duplicates with an explicit confirmation:

```bash
bun --env-file=/secure/mealstack-production.env \
  worker/scripts/cleanup_recipe_duplicates.ts \
  --app-id eeaf3b82-5b5d-40c4-a29a-b68988377c3c \
  --report plans/favourites_duplicate_report.json \
  --delete \
  --confirm DELETE_DUPLICATES
```

Title/slug-only groups are reported but skipped by default; `--include-low-confidence` is required to delete them.
### Existing recipe tag backfill

`scripts/tag_existing_recipes.ts` suggests missing Cuisine, Style, and Label tags for existing recipes. It preserves current tags and is dry-run by default. Export the production `INSTANT_ADMIN_TOKEN` before running; no token is stored in the command or repository.

Generate a reviewable report for all recipes:

```bash
bun worker/scripts/tag_existing_recipes.ts \
  --app-id eeaf3b82-5b5d-40c4-a29a-b68988377c3c \
  --report plans/favourites_tag_backfill.jsonl
```

After reviewing the JSONL, apply the recorded suggestions without re-running Gemini:

```bash
bun worker/scripts/tag_existing_recipes.ts \
  --app-id eeaf3b82-5b5d-40c4-a29a-b68988377c3c \
  --report plans/favourites_tag_backfill.jsonl \
  --write
```

Only the `tags` field is updated. Existing tags are preserved, and suggestions are discarded if they are not exact values from the current `tag_options`.
The prompt is intentionally conservative and leaves uncertain tags blank, especially `Label`. Requests are spaced by 13 seconds by default for the Gemini free-tier limit; 429 responses use Gemini's requested retry delay and exponential fallback retries. Use `--delay-ms` and `--max-retries` only when appropriate for the account's quota.

The prompt version invalidates old planned suggestions. Use a new report path when regenerating an earlier over-eager dry run. Already-written tags are treated as existing and are not removed automatically.
### Testing

Run the Gleam test suite:

```bash
gleam test
```

## Project Structure

- `src/`: Contains the source code.
    - `mealstack_worker.gleam`: The main application entry point and router.
    - `scrape_url.ts`: TypeScript FFI for handling URL scraping logic.
    - `parse_recipe.ts`: TypeScript FFI for interacting with AI services for text/image parsing.
- `gleam.toml`: Gleam project configuration.
- `package.json`: JavaScript dependencies (including AI SDKs and utility libraries).
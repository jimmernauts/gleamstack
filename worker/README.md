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
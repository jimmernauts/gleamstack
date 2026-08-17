# Mealstack Release Stabilization, Bookmark Import, and Post-Release Roadmap

**Status:** Proposed revision for review
**Repository:** `repos/james-personal/gleamstack`
**Application baseline:** `main` at `a99473a`
**Plan revision:** incorporates the review annotations from 2026-08-17
**Purpose:** Make the existing single-user app reliable enough to release, exercise the current parser against the 200-bookmark corpus, fix the issues that corpus exposes, and defer new product features until after release.

## Executive decision

This revision changes the plan in four important ways:

1. **Treat the app as single-user.** Remove the proposed multi-user auth, ownership, and permission redesign from this work. Keep the current single-user InstantDB/settings approach unless a concrete release blocker appears.
2. **Do not assume the SPA routing observation is a production bug.** We saw `/recipes` return 404 in one local Wrangler run, but the existing production experience has not shown that problem. Reproduce it against the actual release path before changing `worker/src/index.mjs`; if it cannot be reproduced, record it and move on.
3. **Prioritize the 200-bookmark import.** The existing import path handles one URL at a time, and the current JSON-LD extraction concatenates multiple script blocks into one invalid JSON string. Build a resumable dev import runner and use the corpus to find parser failures, including pages containing multiple recipes.
4. **Release before shopping-list work.** The shopping-list/planner integration becomes post-release scope. The release gate covers baseline stabilization, parser hardening, the bookmark import run, and the existing product. No new feature work starts until that gate passes.

The recommended first implementation commit remains small: make tests deterministic and make the parser/import code testable. Do not combine that with shopping-list changes.

## Current baseline

| Area | Observed state | Revised implication |
|---|---|---|
| Repository | Clean application code at `a99473a`; the prior plan is committed separately | Preserve the clean baseline and keep this revision limited to planning. |
| Frontend | Gleam + Lustre, Vite, Tailwind, InstantDB client | Existing URL import is a browser flow in `app/src/upload.gleam` and `app/src/upload.ts`. |
| Worker | Gleam + Glen compiled to JavaScript, TypeScript FFI, Wrangler | The parser work crosses `worker/src/mealstack_worker.gleam`, `worker/src/scrape_url.ts`, and `worker/src/parse_recipe.ts`. |
| App build | `bun run vite build` passes | The current frontend can be released once runtime and data preflight are complete. |
| Worker build | `gleam build` passes | Keep the worker build as a release check. |
| App tests | 60/62 pass; two Birdie planner snapshots fail | Fix the wall-clock dependence; do not simply accept August snapshots. |
| Worker tests | 5/17 Bun tests pass | Separate deterministic tests from InstantDB/Gemini and schema.org network behavior. |
| App formatting | `typeahead.gleam` and `typeahead_2.gleam` fail format check | Resolve this existing debt before release verification. |
| Import path | One URL at a time: `/api/scrape_url` fetches a page, extracts JSON-LD, then falls back to AI text parsing | Add a batch runner around the same production parsing path. |
| Multiple recipes | `worker/src/scrape_url.ts` appends every JSON-LD script’s text to one string before `JSON.parse` | Multiple script blocks can invalidate the whole page; this is the first known parser issue to fix. |
| Bookmark tooling | No current bookmark importer exists. `notebooks/post_recipes.ts` is a Triplit-era seeding script, not an InstantDB importer, and contains a legacy credential | Do not reuse it. Build a new worker-side import tool and separately audit/revoke the legacy credential if it is still active. |
| SPA routing | One local Wrangler smoke run returned 404 for `/recipes`; this has not been observed by the user in production | Reproduce on the real release path before touching routing. |
| Credentials | Local environment had no InstantDB admin, Gemini, or Cloudflare credentials | Default tests must remain credential-free; dev/prod import and deployment require explicit local/production configuration. |

## Delivery order

| Milestone | Scope | Exit condition |
|---|---|---|
| 0. Release contract | Confirm single-user scope, import input, dev/prod environments, and release boundary | Decisions are recorded; no auth redesign is in the work. |
| 1. Deterministic baseline | Fix snapshots, worker test isolation, formatting, and local commands | Default checks pass without secrets or external HTTP. |
| 2. Bookmark/parser spike | Build the first import runner and run a representative corpus slice | We know the failure classes and have a stable per-URL result format. |
| 3. Parser and importer hardening | Handle multiple recipes, retries, rate limits, checkpoints, dedupe, and InstantDB writes | The full bookmark folder completes in dev with an auditable report. |
| 4. Release current product | Reproduce/close the routing observation, deploy the existing app, and smoke-test production | Current app is live and basic flows work. |
| 5. Production bookmark import | Run a canary, then the approved full import with resume support | Production data is imported and the report is reviewed. |
| 6. Post-release features | Revisit shopping-list/planner integration and other TODOs | Starts only after Milestone 5 is accepted. |

## Milestone 0 — Release contract

### Scope decisions

- This is a single-user app. Do not add login, user ownership fields, multi-user sharing, or a permissions redesign as part of this plan.
- Keep the existing Settings/API-key flow for now. Do not redesign Gemini key ownership unless it blocks the import or release path.
- The 200-link bookmark run is operational hardening of an existing import capability, not a reason to build a new bookmark-management UI.
- Release the existing product before implementing the shopping-list/planner feature work.
- Default tests must be deterministic and offline. Live parser and production import runs are explicit operations with their own prerequisites.

### Inputs to confirm before implementation

1. What export format will the bookmark folder use: browser HTML, JSON, or a plain URL list? Support browser Netscape bookmark HTML plus a plain URL list in the first version; add other formats only if the real export requires them.
2. Is there a separate InstantDB development app, or should dev writes use a disposable namespace in the current app? Prefer a separate dev app or a backup/export before the first write.
3. For a page with multiple recipes, should the import bring in all recipes or select one? Recommend importing all distinct recipes in the batch tool, while keeping the existing single-URL UI’s first/selection behavior explicit.
4. Should a URL that has no JSON-LD be sent to Gemini as one page-level recipe or as a possible list of recipes? Start by measuring the corpus; do not make the expensive array-AI path mandatory until the sample shows it is needed.
5. What production deployment/account is used for the current app? A real Wrangler login and the existing InstantDB/Gemini configuration will be needed for Milestones 4–5.

## Milestone 1 — Deterministic baseline

This is the only work that should happen before the parser spike. It creates a trustworthy signal for every later parser change.

### 1.1 Freeze planner snapshot dates

**Files:**

- `app/test/integration/planner_test.gleam`
- `app/birdie_snapshots/planner_empty_week.accepted`
- `app/birdie_snapshots/planner_with_meals.accepted`

**Implementation:**

1. Add a test-local fixed Monday matching the committed snapshot date.
2. Use that fixed date only in the two rendered snapshot scenarios. Keep non-snapshot tests that intentionally exercise `date.today()` separate.
3. Run the planner tests and inspect generated `.new` files.
4. Review Birdie metadata changes separately from the date change. Pin or preserve the repository’s intended Birdie version rather than accepting machine-specific output.
5. Remove all `.new` files after the accepted snapshots are correct.

**Acceptance:** planner snapshots pass on different calendar dates, and the accepted files contain no current-clock values.

### 1.2 Isolate worker unit tests from live services

**Files:**

- `worker/src/parse_recipe.ts`
- `worker/test/parse_recipe.test.ts`
- `worker/test/parse_recipe.integration.test.ts` (new)
- `worker/package.json`
- `justfile`

**Implementation:**

1. Extract response normalization/schema validation from `do_parse_recipe_text` and `do_parse_recipe_image` into functions that can consume deterministic fixture responses.
2. Keep the production wrapper responsible for InstantDB settings lookup and Gemini invocation.
3. Make the default unit tests cover empty input, malformed image data, malformed model JSON, valid fixture normalization, and schema fields without credentials.
4. Move the current live text/image calls to an explicit integration test file.
5. Add an explicit integration command that requires the existing `INSTANT_ADMIN_TOKEN` and Gemini configuration. It must fail with a clear prerequisite message when those are absent; it must not turn a missing secret into a false green.
6. Keep the single-user settings lookup unchanged for now. This is test isolation, not an auth redesign.

**Acceptance:** `bun test test/` passes without InstantDB, Gemini, or external HTTP; live coverage remains available through a separate command.

### 1.3 Make JSON-LD tests use local fixtures

**Files:**

- `worker/src/scrape_url.ts`
- `worker/test/scrape_url.test.ts`
- `worker/test/fixtures/` (new)

**Implementation:**

1. Make the JSON-LD document loader injectable, with the current network loader as the production default.
2. Add a minimal local schema.org context fixture for the terms used by the tests.
3. Pass the fixture loader from tests so no test calls schema.org.
4. Keep live document-loader behavior as an explicit integration check only if it is useful for release confidence.

**Acceptance:** all default JSON-LD tests pass with network access disabled.

### 1.4 Resolve formatting and make checks discoverable

**Files:**

- `app/src/components/typeahead.gleam`
- `app/src/components/typeahead_2.gleam`
- `justfile`
- `README.md`
- `worker/README.md`

**Implementation:**

1. Run and review a formatting-only change for the two typeahead modules.
2. Add package-level `check-app` and `check-worker` recipes that run format, tests, and builds in a predictable order.
3. Add a root `check`/`verify` recipe that runs both packages.
4. Document the supported Bun, Gleam, Just, and Wrangler versions and the exact local commands.
5. Pin Wrangler as a worker development dependency instead of resolving an unpinned package through `bunx` at runtime.
6. Document the names and locations of local secrets without committing values.

**Acceptance:** a new checkout can find one default check command; the default path does not require Cloudflare login, InstantDB, Gemini, or external HTTP.

## Milestone 2 — Bookmark/parser spike

The spike should start with a small sample, not all 200 links. Its purpose is to discover the corpus shape before building a production import loop.

### 2.1 Build a standalone bookmark input reader

**New area:** `worker/scripts/` or another worker-local scripts directory.

**Files likely involved:**

- `worker/scripts/import_bookmarks.ts` (new)
- `worker/scripts/bookmark_input.ts` (new, if kept separate)
- `worker/test/bookmark_input.test.ts` (new)
- `worker/package.json`
- `worker/README.md`

**Input contract:**

- Netscape browser bookmark HTML: recursively find `<A HREF="...">` links and retain folder/title metadata when available.
- Plain text URL list: one HTTP(S) URL per non-empty, non-comment line.
- Reject unsupported schemes, blank URLs, and malformed entries before making network calls.
- Normalize obvious URL noise such as fragments and tracking parameters only through an explicit, tested rule; do not rewrite recipe URLs aggressively.

**Output contract:** every input URL gets a stable record with:

- input URL and normalized URL;
- bookmark title/folder, if present;
- attempt count and timestamps;
- status: `success`, `multiple_recipes`, `no_recipe`, `blocked`, `rate_limited`, `parse_error`, or `network_error`;
- recipe count;
- normalized recipe payloads when present;
- warnings and a human-readable error;
- parser version/commit for reproducibility.

### 2.2 Run a representative sample

Select approximately 15–20 links covering likely domains and bookmark folders. Run a **dry-run** that does not write InstantDB records.

Capture:

- domains and HTTP status distribution;
- JSON-LD present/absent;
- one vs. multiple JSON-LD blocks;
- `@graph`, arrays, `ItemList`, and recipe objects embedded in other data;
- blocked pages, bot checks, redirects, timeouts, and rate limits;
- pages with multiple recipes;
- pages whose JSON-LD is malformed but whose visible text might be parseable;
- duplicate URLs and duplicate recipes;
- title/slug/source collisions.

Write the report as JSONL plus a summary table. Do not use the legacy `notebooks/post_recipes.ts`; it targets Triplit and contains an old credential.

**Spike exit condition:** the sample report identifies the first implementation changes and proves that the runner can resume from a result file.

## Milestone 3 — Parser and importer hardening

### 3.1 Extract multiple JSON-LD documents independently

**Primary file:** `worker/src/scrape_url.ts`

The current implementation appends the text from every `application/ld+json` script into one `jsonLdContent` string. Replace that behavior with a collection of independent script payloads.

For each script:

1. Parse independently; one malformed script must not discard valid scripts from the same page.
2. Accept a top-level object or array.
3. Walk `@graph` and common list containers such as `itemListElement`.
4. Select nodes whose `@type` is `Recipe` or an equivalent schema.org URL.
5. Normalize title/name, source URL, yield, durations, ingredients, and instructions using the existing recipe shape.
6. Deduplicate equivalent recipes by canonical source URL plus normalized title, with a stable fallback when source URL is absent.
7. Preserve warnings when a page contains more than one recipe or when fields are incomplete.

Add tests for:

- two separate JSON-LD script blocks;
- one JSON-LD array containing multiple recipes;
- an `@graph` containing recipes and non-recipe nodes;
- one malformed script followed by one valid recipe;
- duplicate recipe nodes;
- a page with no recipe JSON-LD;
- multiple instruction formats (`HowToStep`, strings, and arrays).

### 3.2 Define an explicit multi-recipe response

Do not silently discard additional recipes from the batch path.

Recommended compatibility design:

- Extract a core `ScrapeResult` containing `source_url`, `recipes`, `warnings`, and parser status.
- Add a batch-facing endpoint or worker entry point such as `/api/scrape_url_all` that returns the complete result.
- Keep the existing `/api/scrape_url` response compatible with the current one-recipe upload UI, but make its first-recipe behavior explicit and log when additional recipes were found.
- Update the upload UI later if selecting among multiple recipes becomes necessary; it is not required for the first 200-link import.

If the sample shows that no-JSON-LD pages commonly contain multiple recipes, add a separate multi-recipe Gemini schema and test it explicitly. Otherwise retain the current single-page fallback and mark the limitation in the batch report.

**Files likely involved:**

- `worker/src/scrape_url.ts`
- `worker/src/parse_recipe.ts`
- `worker/src/mealstack_worker.gleam`
- `worker/test/`
- `app/src/upload.ts` only if the existing endpoint contract must change

### 3.3 Make the runner safe to leave running

**Primary file:** `worker/scripts/import_bookmarks.ts`

Implement:

- bounded concurrency, starting at 2–3 requests;
- per-request timeout;
- retry with exponential backoff only for transient network/5xx/429 failures;
- respect `Retry-After` when available;
- no retry for permanent 4xx, invalid URL, or deterministic parse failures;
- checkpoint after every URL, not only at the end;
- `--resume results.jsonl` to retry unfinished/transient records without duplicating successes;
- `--limit N` and `--only-domain example.com` for controlled testing;
- structured logs that never print API keys or full sensitive headers;
- a dry-run mode that writes only result files;
- a write mode that requires an explicit confirmation flag.

### 3.4 Make writes idempotent for the single-user database

Use the existing InstantDB admin configuration for now; do not introduce a multi-user ownership model.

The write path should:

1. preserve the original source URL in the recipe’s `source` field;
2. derive a stable slug from the normalized title, with collision handling;
3. query for an existing matching source/slug before inserting;
4. update only when the import record is explicitly approved to overwrite;
5. write one recipe at a time with a result record containing the Instant transaction ID;
6. continue after an individual failure and record it for resume.

If the existing schema cannot support a reliable source lookup, add the smallest single-user-compatible field/index needed. Do not use the old Triplit schema or seed script as the migration path.

### 3.5 Dev import run

Run in this order:

1. Dry-run the representative sample.
2. Fix parser and runner issues until the sample report is understandable.
3. Run the full 200-link input against the development InstantDB environment with writes enabled.
4. Review successes, multiple-recipe pages, failures, duplicate candidates, and suspicious low-content recipes.
5. Re-run only failed/transient records after corrections.
6. Export an approved result set for the production run.

The dev run is complete only when every input URL has a terminal status and the report explains every non-success.

## Milestone 4 — Release the current product

This milestone happens before shopping-list/planner feature work.

### 4.1 Pre-release checks

Run the default verification command from Milestone 1 and confirm:

- app format, tests, and Vite build pass;
- worker format, deterministic Bun tests, Gleam tests, and build pass;
- no generated `.new` snapshots or local credentials are present;
- the current InstantDB app and worker configuration are available for production;
- the legacy Triplit credential in `notebooks/post_recipes.ts` has been checked and revoked/rotated if it is still valid.

### 4.2 Conditional SPA route check

The local Wrangler run observed a 404 for `/recipes`, but this has not been a known production issue. Do not implement an asset-routing change yet.

Verify the actual release path:

1. Run the built app through the same Wrangler configuration used for release.
2. Test direct navigation to `/`, `/recipes`, `/planner`, `/shopping-list`, `/settings`, and `/import`.
3. If possible, test the current deployed site before changing code.
4. If direct routes work in the real path, close this as a local-only observation.
5. If direct routes fail, make the smallest targeted change in `worker/src/index.mjs` to delegate non-API requests to the configured assets binding, then repeat the route smoke checks.

This check is a release diagnostic, not a new architecture milestone.

### 4.3 Deploy and smoke-test

Deployment requires the user’s existing Cloudflare access; local Wrangler development does not.

After deployment:

- load the home page;
- open recipes, planner, shopping list, settings, and import from the UI;
- create or edit one recipe;
- verify planner load/save;
- verify shopping-list load/save at its current behavior level;
- run one known-good URL import;
- confirm worker logs do not expose secrets;
- confirm the production InstantDB app contains the expected single-user data.

**Release gate:** the current product is live and the known workflows work. Stop here before implementing shopping-list/planner improvements.

## Milestone 5 — Production bookmark import

Run the parser against production only after the current product has been released and the dev run has been reviewed.

1. Use the same input file and parser version recorded in the dev report.
2. Start with a canary of approximately 5–10 URLs, including one known-good page, one multiple-recipe page, and one likely failure.
3. Confirm the production records and source URLs are correct.
4. Run the remaining URLs with bounded concurrency and checkpointing.
5. Monitor rate limits, Gemini usage, worker duration, and InstantDB transaction errors.
6. Stop/review if the failure rate or duplicate rate is materially different from dev.
7. Produce a final report with successes, imported recipe count, duplicate decisions, failures, and URLs requiring manual review.

Production import must be resumable and idempotent. A rerun must not create a second copy of every successful recipe.

## Milestone 6 — Post-release feature backlog

Only after the production release and bookmark import are accepted should we return to product TODOs. The next likely slice is shopping-list ↔ planner integration.

When that work starts, cover:

- plan link persistence;
- multiple meal extraction and recipe deduplication;
- explicit add-ingredients behavior;
- stable `RecipeSlug` resolution;
- missing/name-only recipe handling;
- ingredient provenance and duplicate behavior;
- model tests in `app/test/integration/shopping_list_test.gleam`;
- manual verification against the released app.

Other TODOs—offline support, bookmark UI, ratings/notes, navigation cleanup, and shared layout—remain separate decisions rather than being pulled into the release.

## Final release checklist

### Default verification

- `gleam format --check src test` passes in both packages.
- App Gleam tests pass without date-sensitive snapshot churn.
- Worker Gleam tests pass.
- Worker Bun unit tests pass without credentials or external network.
- Vite production build passes.
- Worker Gleam build passes.
- `git diff --check` passes.

### Import verification

- Bookmark input parser tests pass.
- Representative sample has a terminal per-URL result.
- Multiple JSON-LD scripts and arrays are parsed independently.
- Malformed pages do not abort the whole batch.
- Results are checkpointed and resumable.
- Dev writes are idempotent and reviewed.
- Production canary passes before the full run.

### Runtime verification

- Local Wrangler starts without Cloudflare login.
- The actual release path is checked for direct SPA routes; routing code changes only if reproduced.
- API invalid-input behavior remains correct.
- One known-good production URL import succeeds.
- Existing recipe, planner, shopping-list, settings, and import flows smoke-test successfully.

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---:|---:|---|
| Multiple JSON-LD blocks are concatenated into invalid JSON | High | High | Parse each script independently and add multi-script fixtures first. |
| One page contains multiple recipes but the current UI expects one | High | Medium | Add a complete batch response; keep legacy UI behavior explicit and report discarded/extra recipes. |
| 200 requests trigger bot checks or rate limits | High | High | Low concurrency, timeouts, retry policy, `Retry-After`, checkpointing, and canary runs. |
| AI fallback costs or fails on pages without JSON-LD | Medium | High | Measure the sample first; separate JSON-LD and AI outcomes; cap/retry deliberately. |
| Duplicate slugs or source URLs create duplicate recipes | High | High | Stable source/title identity, idempotent writes, dry-run review, and resume-safe transactions. |
| Dev and production behave differently | Medium | High | Same parser version/input, dev full run, production canary, and per-URL reports. |
| Local Wrangler route behavior is not production behavior | Medium | Medium | Reproduce on the actual release path before changing `index.mjs`. |
| Legacy Triplit credential remains usable | Unknown | High | Audit and revoke/rotate it before release; do not reuse the legacy script. |
| Scope drifts into multi-user/auth work | Low after review | High | Keep single-user assumptions explicit and defer auth/ownership. |

## Decisions no longer required for this plan

The following are intentionally removed from the implementation scope because the app is staying single-user:

- user authentication;
- per-user ownership fields and permission redesign;
- multi-user sharing;
- worker-owned versus BYO Gemini key architecture;
- a global settings migration for multi-user isolation.

The existing single-user configuration still needs to be documented well enough to run dev and production imports, but it is not being redesigned here.

## Out of scope until after release

- Shopping-list/planner feature implementation.
- A bookmark-management UI.
- Offline support or moving away from InstantDB.
- Ratings and cooking notes.
- Navigation/layout refactors.
- Multi-user authentication or sharing.
- General ingredient normalization and unit aggregation.
- Public deployment communication beyond the release smoke test.

## Recommended first implementation commit after approval

Create one focused commit titled something like **`stabilize parser test baseline`** containing only:

- fixed-date planner snapshot tests;
- offline worker fixtures and test seams;
- independent JSON-LD test loading;
- existing formatting fixes;
- default verification commands and setup documentation.

The next commit should be the bookmark input reader and dry-run reporter. Only after the sample report is reviewed should the multiple-recipe parser and production write path be expanded.

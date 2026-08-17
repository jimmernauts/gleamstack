# Mealstack Release First, Then One-Off Bookmark Import

**Status:** Proposed revision for review
**Repository:** `repos/james-personal/gleamstack`
**Application baseline:** `main` at `a99473a`
**Plan revision:** incorporates the 2026-08-17 review annotations
**Purpose:** Release the existing single-user app first, then run the existing worker repeatedly over the supplied recipe bookmarks, fixing only the parser issues needed to complete that one-off import. Shopping-list work starts after the release and import are accepted.

## What changed in this revision

- The provided input is now concrete: `plans/favourites_17_08_2026.html` is a Netscape browser-bookmark export with 344 links total and 230 links inside the `recipe` folder. The runner should select that folder rather than process unrelated favourites such as music, jobs, and development links.
- There is no parser spike or proposed batch-product feature. We will add a thin one-off loop around the worker endpoint that already exists.
- The current product is released before parser/import changes, as requested.
- Multiple recipes from one URL are in scope: the import must retain all distinct recipes.
- If JSON-LD is missing, the worker will extract the page text and ask the LLM to identify every recipe in that text. We will not add a Python-only tool such as Trafilatura before seeing whether the existing JavaScript runtime can produce sufficient text.
- The app remains explicitly single-user. There is no auth, ownership, or multi-user permissions milestone.
- The local `/recipes` routing observation is still only a conditional check. We will not change routing unless it reproduces on the actual release path.

## Current repository facts

| Area | Current state | Plan consequence |
|---|---|---|
| Frontend | Gleam/Lustre + Vite; URL import is wired through `app/src/upload.gleam` and `app/src/upload.ts` | Keep the existing UI contract for ordinary one-recipe imports. |
| Worker | Gleam/Glen + TypeScript FFI under `worker/src/` | Extend the existing scrape endpoint with an explicit all-recipes mode rather than building a new service. |
| Existing scrape flow | `/api/scrape_url` fetches one URL, tries JSON-LD, then falls back to AI text parsing | The one-off runner will call this worker repeatedly. |
| Known multi-recipe bug | `worker/src/scrape_url.ts` concatenates all JSON-LD script text before parsing it as one JSON document | Parse each script independently and collect every recipe node. |
| AI fallback | `worker/src/parse_recipe.ts` asks for one recipe using a single-recipe schema | Add an all-recipes fallback for the batch mode. |
| Bookmark export | 344 links total; 230 under the `recipe` folder; 217 total links are on `theguardian.com` | Filter by bookmark folder and expect a domain-heavy corpus with varied page structures. |
| Tests | App has two date-sensitive snapshot failures; worker tests include live InstantDB/Gemini/schema.org calls | Stabilize the default checks before releasing or changing parser behavior. |
| Local runtime | Vite and Wrangler start; one local Wrangler run returned 404 for `/recipes` | Test actual release routing before changing `worker/src/index.mjs`. |
| Legacy script | `notebooks/post_recipes.ts` is a Triplit-era seeder and contains a legacy credential | Do not reuse it for this import; audit/revoke the old credential separately if it remains valid. |

## Delivery order

| Milestone | Work | Exit condition |
|---|---|---|
| 0. Baseline release preparation | Make the existing checks deterministic and document the release commands | We can verify the current product without false failures. |
| 1. Release current product | Deploy the existing app/worker without bookmark/parser changes | Current production app is live and its existing flows smoke-test successfully. |
| 2. Minimal parser enhancement | Add all-recipes JSON-LD handling and all-recipes text fallback | The production-shaped worker can return every recipe found on one URL. |
| 3. One-off loop runner | Read the supplied bookmark file, call the worker until every URL has a result, and checkpoint progress | A complete result file exists with no unclassified URLs. |
| 4. Development import | Run the result/write process against a separate InstantDB development app | Dev records and failures are reviewed; reruns are safe. |
| 5. Production parser release and import | Deploy the minimal parser change, canary it, then run the approved 230-link import | Production import completes or every failure has a manual disposition. |
| 6. Post-release features | Return to shopping-list/planner integration and the remaining TODOs | Starts only after Milestone 5 is accepted. |

## Milestone 0 — Baseline release preparation

This is test/setup work, not new product functionality.

### 0.1 Make planner snapshots deterministic

**Files:**

- `app/test/integration/planner_test.gleam`
- `app/birdie_snapshots/planner_empty_week.accepted`
- `app/birdie_snapshots/planner_with_meals.accepted`

Use a fixed date in the two snapshot scenarios instead of `date.today()`. Review the generated Birdie output and accept only the intended fixed-date/metadata changes. Do not regenerate snapshots from the current wall clock.

**Acceptance:** the app snapshots pass on different calendar dates and no `.new` files remain.

### 0.2 Separate default tests from live services

**Files:**

- `worker/src/parse_recipe.ts`
- `worker/test/parse_recipe.test.ts`
- `worker/test/parse_recipe.integration.test.ts` (new)
- `worker/src/scrape_url.ts`
- `worker/test/scrape_url.test.ts`
- `worker/test/fixtures/` (new)
- `worker/package.json`
- `justfile`

Make the default worker tests deterministic:

- test recipe response normalization from fixtures rather than calling Gemini;
- test empty/malformed input locally;
- use a local JSON-LD context fixture instead of fetching schema.org;
- keep live InstantDB/Gemini tests in an explicit integration command.

This does not change the single-user runtime design. It only stops the default check from requiring live credentials and external network access.

### 0.3 Resolve existing formatting and command drift

- Format `app/src/components/typeahead.gleam` and `typeahead_2.gleam` as a formatting-only change.
- Add clear package checks to `justfile`.
- Pin/document the Wrangler version used by local development instead of resolving an arbitrary `bunx` version.
- Update `README.md` and `worker/README.md` with the commands that actually work.
- Keep `worker/.dev.vars` and any `.env` files ignored. Never add values to the repository.

**Baseline release check:** app format/tests/build, worker format/unit tests/Gleam tests/build, and `git diff --check` pass.

## Milestone 1 — Release the current product first

No bookmark importer or parser behavior change is included in this release.

### 1.1 Production preflight

Confirm:

- the current InstantDB app and its existing data are available;
- the existing worker has the admin token and Gemini settings it already expects;
- the user can authenticate Wrangler in the sandbox;
- the legacy Triplit credential in `notebooks/post_recipes.ts` has been checked and revoked/rotated if it is still active;
- the current repository builds from a clean checkout.

### 1.2 Conditional SPA route check

A local Wrangler run returned 404 for `/recipes`, but this has not been a known production problem. Treat it as a check, not a planned rewrite.

1. Build and run the current app through the exact Wrangler configuration used for deployment.
2. Test direct navigation to `/`, `/recipes`, `/planner`, `/shopping-list`, `/settings`, and `/import`.
3. If possible, test the current production URL before changing code.
4. If routes work, record the local result as non-blocking and make no routing change.
5. If routes fail in the actual release path, make the smallest targeted asset-delegation fix in `worker/src/index.mjs`, then rerun the checks.

### 1.3 Deploy and smoke-test

Use the existing deployment path after Wrangler authentication:

- deploy the current app and worker;
- load the home page;
- open recipes, planner, shopping list, settings, and import;
- create/edit one recipe;
- verify the existing planner and shopping-list flows load/save;
- run one known-good URL import;
- confirm worker logs do not print credentials.

**Exit condition:** the current product is live and usable. Stop feature work here before beginning the bookmark/parser changes.

## Milestone 2 — Minimal parser enhancement for all recipes

This is the smallest change required to make the one-off import useful. It extends the existing worker; it does not introduce a new batch API product.

### 2.1 Preserve the existing endpoint and add an explicit mode

**Files:**

- `worker/src/mealstack_worker.gleam`
- `worker/src/scrape_url.ts`
- `worker/src/parse_recipe.ts`
- `worker/test/`

Keep the current `/api/scrape_url?target=...` behavior for the existing upload UI. Add an explicit query option such as `all=true` for the one-off runner:

- without `all=true`: preserve the current one-recipe response contract;
- with `all=true`: return a structured result containing all distinct recipes, source URL, warnings, and status.

The runner will call the existing production worker endpoint with this option. There is no need for a new permanent batch endpoint or bookmark UI.

### 2.2 Parse JSON-LD script blocks independently

Replace the current concatenation behavior in `worker/src/scrape_url.ts`:

1. collect each `application/ld+json` script as its own payload;
2. parse each payload independently so one malformed script does not discard valid scripts;
3. accept top-level objects, arrays, `@graph`, and common `itemListElement` containers;
4. retain every node whose type is `Recipe` or a schema.org Recipe URL;
5. normalize the existing recipe fields: title/name, source URL, yield, durations, ingredients, and instructions;
6. deduplicate identical nodes while retaining distinct recipes from the same page;
7. preserve warnings when fields are incomplete or multiple recipes are found.

Add fixtures for:

- two JSON-LD script blocks with two recipes;
- one array with multiple recipes;
- an `@graph` containing recipe and non-recipe nodes;
- one malformed script followed by a valid recipe;
- duplicate recipe nodes;
- multiple instruction formats;
- a page with no usable JSON-LD.

### 2.3 Send page text to the LLM when JSON-LD is absent

For the `all=true` path, if JSON-LD yields no recipes:

1. fetch the page once;
2. extract readable text using the existing JavaScript-compatible stack, preferably `HTMLRewriter`/`linkedom` already present in the worker;
3. remove scripts, styles, navigation, and obvious non-content regions where practical;
4. cap and log the text length so a pathological page cannot create an unbounded request;
5. send the extracted page text to Gemini with a prompt that asks it to return **every recipe found**, not one recipe;
6. validate the response against an array-of-recipes schema;
7. return an empty recipe list plus a clear status if the page contains no recipe.

Do not add Trafilatura first: it is primarily a Python tool and the current worker is TypeScript/Gleam running under Bun/Cloudflare. If the first corpus run shows that the lightweight extraction is too noisy, evaluate a JS readability package as a separate, evidence-based change.

Keep the current single-recipe schema and UI path intact. Add a separate multi-recipe schema/function for `all=true` so the existing import screen does not break unexpectedly.

### 2.4 Tests for the parser change

Default tests must cover:

- all JSON-LD recipes are returned;
- malformed JSON-LD does not erase valid recipes;
- an HTML page with no JSON-LD sends its extracted text to the mocked all-recipes model path;
- the model can return zero, one, or multiple recipes;
- source URL is retained on every result;
- duplicates are removed deterministically;
- one-recipe mode remains compatible with the current UI;
- oversized/empty text produces a controlled result.

## Milestone 3 — One-off runner around the existing worker

### 3.1 Input: the provided favourites export

**Input:** `plans/favourites_17_08_2026.html`

The file is a standard Netscape bookmark export. The one-off runner should:

- parse the folder tree;
- select the `recipe` folder and its links, currently 230 URLs;
- retain bookmark title and folder path for reporting;
- ignore the other 114 links by default;
- reject non-HTTP(S) links and duplicate normalized URLs before network calls.

Do not build generic JSON/plain-text input support unless the actual input changes. This is a one-off operation against the supplied file.

### 3.2 Loop behavior

**New file:** `worker/scripts/import_favourites.ts`

The runner should be intentionally small:

1. read and filter the one input file;
2. call the configured existing worker endpoint for each URL, using `all=true`;
3. write one JSONL result immediately after each URL;
4. continue after individual failures;
5. support `--limit 5` for a smoke run, then run the full recipe folder;
6. support `--resume results.jsonl` so an interrupted run does not repeat completed URLs;
7. record URL, bookmark metadata, HTTP status, recipe count, recipes, warnings, error, and parser/deployment version;
8. use low bounded concurrency, initially 2 requests, with timeout and retry for 429/5xx/transient network failures;
9. honor `Retry-After` where available;
10. never log token values or authorization headers.

This runner is not a new application feature. It is a disposable operational script that invokes the worker already used by the application.

### 3.3 Separate parse results from database writes

The first run must be parse-only. It writes a result file and does not mutate InstantDB. After reviewing the result file, run an explicit write step that:

- targets a selected InstantDB app;
- inserts all recipes returned for each URL;
- preserves the original source URL;
- derives stable slugs and handles collisions;
- skips or updates an existing recipe according to an explicit rule;
- writes a transaction/result record for each recipe;
- can resume without duplicating successful writes.

The write step can live in the same one-off script behind `--write`, or be a second worker-local script. Do not add a production API endpoint solely for this import.

## Milestone 4 — Development database and credentials

### 4.1 Development InstantDB app

There is currently no separate InstantDB development app. Create one before the first database write. The development app is not a multi-user feature; it is a safety boundary so the 230-link run cannot pollute production.

The plan assumes one of these paths:

- the user creates the dev app and supplies its app ID plus admin token through the sandbox secret file; or
- the agent creates it after authenticated InstantDB CLI/API access is available in the sandbox.

The supplied `https://www.instantdb.com/llm-rules/AGENTS.md` returned HTTP 403 from this sandbox, so no InstantDB creation command is being guessed or run from this plan. Once official authenticated instructions are available, use them and record the resulting dev app ID without recording the admin token.

If a separate app cannot be created, stop at parse-only output. Do not write the import into the production app as a substitute.

### 4.2 Safe credential handoff into the sandbox

Do not paste secrets into chat. Put them in an ignored file inside the project, or inject them into the sandbox environment through the host’s secret mechanism.

For this repository, the practical local path is:

`repos/james-personal/gleamstack/worker/.dev.vars`

The root ignore rules already cover `.dev.vars*`. The file should contain only local values, for example:

```text
INSTANT_ADMIN_TOKEN=the-dev-app-admin-token
INSTANT_APP_ID=the-dev-app-id
```

Important current-code detail: `worker/src/parse_recipe.ts` currently hard-codes the Instant app ID and reads `INSTANT_ADMIN_TOKEN` from `process.env`. Before using a second app, make the app ID a runtime configuration value in the one-off script/worker path. Do not assume adding `INSTANT_APP_ID` to the file changes current behavior automatically.

The current worker retrieves the Gemini key from the first InstantDB settings row. Therefore the dev app also needs the required settings record/key, or the import code must be given an explicitly approved environment-based Gemini configuration. Do not put a Gemini key in tracked files or print it in logs.

For Wrangler deployment access, use an authenticated `wrangler login` session inside the sandbox, or inject the Cloudflare API/account credentials through the sandbox’s secret mechanism. Do not commit them or paste them into the conversation. Tell the agent only that the credentials are ready; the agent can check presence without printing values.

### 4.3 Development run

1. Create/configure the separate dev InstantDB app.
2. Put the dev admin token and app ID into the ignored sandbox secret path.
3. Run the parser-only smoke command against five recipe links.
4. Review the JSONL shape and multi-recipe output.
5. Run the complete 230-link recipe folder.
6. Review every non-success, low-content recipe, duplicate candidate, and source URL.
7. Run the explicit write step against dev.
8. Re-run selected failures and confirm resume/idempotency behavior.

## Milestone 5 — Parser release and production import

This is the second release, after the current product has already been released in Milestone 1.

### 5.1 Deploy the minimal parser change

Deploy the worker/app change that adds the explicit all-recipes mode and page-text fallback. Keep the existing single-recipe UI behavior unchanged. Run the normal build/tests and a production worker canary first.

### 5.2 Production canary

Run 5–10 carefully selected recipe-folder URLs:

- a known-good JSON-LD recipe;
- a page with multiple JSON-LD recipes;
- a Guardian page representative of the dominant domain;
- a page with no JSON-LD;
- a likely blocked or malformed page.

Confirm that the production result file contains all recipes, source URLs, warnings, and errors before enabling writes.

### 5.3 Production full run

Run the same one-off runner against the same input file and `recipe` folder:

- use low concurrency;
- checkpoint every URL;
- stop if failure/rate-limit behavior materially differs from dev;
- write only after the parse report is approved;
- preserve a copy of the final result/report outside the application database;
- verify that rerunning completed records does not duplicate recipes.

The production import is complete when every URL has a terminal result and every failure has either been retried successfully or manually classified.

## Milestone 6 — Post-release feature work

Only after the current product release and production bookmark import are accepted should we return to new product features.

The next likely slice is shopping-list ↔ planner integration, covering:

- plan-link persistence;
- all meal extraction and stable recipe references;
- explicit add-ingredients behavior;
- missing/name-only recipe handling;
- ingredient provenance and duplicate behavior;
- model tests in `app/test/integration/shopping_list_test.gleam`.

Offline support, ratings/notes, navigation cleanup, and a bookmark-management UI remain separate follow-up decisions.

## Release and import checklist

### Before current-product release

- app deterministic snapshots pass;
- worker default tests pass without live services;
- app/worker formatting and builds pass;
- current UI flows smoke-test locally;
- actual release-path SPA routes are checked, with no code change unless reproduced;
- current production app/worker configuration is confirmed;
- Wrangler authentication is ready;
- legacy Triplit credential is audited/revoked if still active.

### Before development writes

- separate InstantDB dev app exists;
- dev app ID and admin token are present only in ignored sandbox configuration;
- Gemini settings/configuration is available to the dev worker;
- five-link parser-only smoke run is understandable;
- full 230-link run has terminal per-URL results;
- write mode is explicit and resumable.

### Before production writes

- parser change is deployed;
- production canary has been reviewed;
- result format includes all recipes from multi-recipe pages;
- source URLs and slug collision behavior are acceptable;
- production write credentials are available without being committed;
- final runner command and input file are recorded.

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---:|---:|---|
| Multiple JSON-LD blocks currently become invalid concatenated JSON | High | High | Parse each script independently and return all distinct recipes. |
| LLM receives too much boilerplate or exceeds context | Medium | High | Strip obvious non-content, cap/log text length, and inspect failures before adding heavier extraction. |
| A page contains several recipes but the old UI expects one | High | Medium | Keep default endpoint behavior unchanged; use explicit `all=true` for the runner. |
| Guardian and other domains rate-limit the loop | High | High | Low concurrency, timeout, Retry-After, retries, and checkpointing. |
| Production data is polluted by a bad dev run | High | High | Require a separate dev InstantDB app and parse-only output before writes. |
| Runner is interrupted after partial completion | Medium | Medium | JSONL checkpoint after every URL and resume by normalized URL. |
| Re-running creates duplicates | Medium | High | Stable source/title identity and idempotent write behavior. |
| Local Wrangler route issue is not a production issue | Medium | Low | Reproduce before changing routing; treat the observation as non-blocking if production works. |
| Credentials are exposed in the sandbox or logs | Medium | High | Ignored `.dev.vars`, secret injection, presence-only checks, and redacted logs. |
| InstantDB app creation instructions are inaccessible from the sandbox | Current blocker | Medium | Do not guess commands; user creates the dev app or provides authenticated official CLI/API access. |

## Explicitly out of scope until after import/release

- Multi-user auth, ownership, sharing, or permission redesign.
- A general-purpose bookmark management UI.
- A reusable hosted batch-import product.
- Offline support or moving away from InstantDB.
- Shopping-list/planner feature changes.
- Ratings, cooking notes, navigation/layout refactors.
- General ingredient normalization.

## Recommended implementation commits

1. **`stabilize parser test baseline`**
   - fixed-date app snapshots;
   - offline worker tests/fixtures;
   - formatting fixes;
   - default verification commands.
2. **`release current mealstack product`**
   - deployment/configuration only; no bookmark parser change.
3. **`add all-recipes worker mode`**
   - independent JSON-LD extraction;
   - page-text multi-recipe fallback;
   - tests preserving the existing one-recipe mode.
4. **`add one-off favourites import runner`**
   - parse the supplied Netscape HTML;
   - filter the `recipe` folder;
   - loop/resume/report/write behavior.
5. **`run production favourites import`**
   - operational result/report and data changes, reviewed separately.

Shopping-list work begins only after these are accepted.

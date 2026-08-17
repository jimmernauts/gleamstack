# Mealstack Baseline Stabilization and Hardening

**Status:** Proposed for review  
**Repository:** `repos/james-personal/gleamstack`  
**Baseline:** `main` at `a99473a`  
**Purpose:** Restore a trustworthy local/CI baseline, fix the production-shaped SPA runtime, close the most serious data-access risks, and only then finish the shopping-list integration.

## Executive summary

The project compiles and can be run locally, but its verification signal is currently noisy:

- the app test suite has two date-dependent snapshot failures;
- worker tests call InstantDB, Gemini, and schema.org directly instead of using deterministic fixtures;
- the app format check fails on two existing typeahead modules;
- Wrangler serves `/` but returns 404 for an SPA route such as `/recipes`;
- InstantDB permissions are empty, auth is not implemented, and settings access contains a hard-coded entity ID;
- the shopping-list/planner work is partly implemented but has persistence and recipe-resolution gaps.

The first implementation slice should therefore be **baseline stabilization**, not another product feature. A green, deterministic default test command is the prerequisite for safely changing routing, permissions, and shopping-list behavior.

## Current baseline

| Area | Observed state | Meaning for implementation |
|---|---|---|
| Repository | Clean `main` at `a99473a` | No existing local changes need preserving. |
| Frontend | Gleam + Lustre, Vite, Tailwind, InstantDB client | UI state and routing live in `app/src/app.gleam` and `app/src/pages/`. |
| Worker | Gleam + Glen compiled to JavaScript, TypeScript FFI, Wrangler | API behavior crosses `worker/src/mealstack_worker.gleam`, `worker/src/index.mjs`, and TypeScript FFI. |
| App build | `bun run vite build` passes | Static production output is buildable. |
| Worker build | `gleam build` passes | Worker Gleam compilation is healthy. |
| App tests | 60/62 pass; two Birdie planner snapshots fail | Snapshots encode January 2026 while the runtime clock is August 2026; generated snapshots also show Birdie metadata drift. |
| Worker tests | 5/17 Bun tests pass | Parsing tests require `INSTANT_ADMIN_TOKEN`; JSON-LD tests fetch schema.org and receive 403 through the current proxy. |
| App formatting | Fails for `app/src/components/typeahead.gleam` and `typeahead_2.gleam` | Existing formatting debt blocks a clean check. |
| Worker formatting/tests | Worker format check and Gleam test pass | Keep this as a regression guard while changing the TypeScript test harness. |
| Local runtime | Vite and Wrangler both start; Wrangler root/API smoke checks pass | The full stack is runnable without Cloudflare login. |
| SPA routing | Wrangler `/recipes` returns 404 | `worker/src/index.mjs` handles every request and does not delegate non-API requests to configured assets. |
| Credentials | No `INSTANT_*`, Gemini, Google, or Cloudflare variables; Wrangler is unauthenticated | Local unit tests must not depend on credentials. Deployment and live AI tests need explicit secrets later. |

## Proposed delivery order

| Milestone | Scope | Depends on | Exit condition |
|---|---|---|---|
| 0. Baseline contract | Freeze scope, record commands, decide secret/test policy | Review approval | Decisions below are accepted or explicitly deferred. |
| 1. Deterministic verification | Date-safe snapshots, offline worker unit tests, explicit integration tests | Milestone 0 | Default app/worker checks pass without credentials or external HTTP. |
| 2. Toolchain and formatting | Format existing modules, pin/document Bun/Wrangler usage, improve Just commands | Milestone 1 | A new checkout can discover and run the same checks. |
| 3. SPA runtime | Delegate non-API requests to Cloudflare assets | Milestone 2 | `/`, `/recipes`, `/settings`, and `/import` serve the SPA under Wrangler. |
| 4. Data access and secrets | Define ownership, auth, permissions, and settings/Gemini secret handling | Milestone 3 plus product decisions | Unauthenticated users cannot read or mutate application data; no admin or AI secret reaches the browser. |
| 5. Shopping-list integration | Complete planner linking, persistence, recipe resolution, and ingredient import | Milestone 4 | Shopping-list workflow is covered by model tests and manual runtime verification. |
| 6. Release verification | Full checks, runtime smoke, security review, and handoff | Milestones 1–5 | All required commands pass and remaining limitations are documented. |

## Milestone 0 — Baseline contract

### Goals

1. Preserve the current clean repository state.
2. Treat the existing failures as signals to fix, not as reasons to update snapshots or skip tests blindly.
3. Keep live credentials and external network access out of the default test path.
4. Make one explicit decision about the AI key model before implementing permissions.

### Working rules

- Do not commit `.env`, `.dev.vars`, `INSTANT_ADMIN_TOKEN`, Gemini keys, or Cloudflare credentials.
- Do not accept current-date snapshots merely to make Birdie green.
- Default tests must be deterministic and runnable on a clean machine without InstantDB, Gemini, schema.org, or Cloudflare access.
- Live integration checks must have a separate command and a clear prerequisite/error message.
- Keep each milestone in a focused commit; do not combine test harness, routing, permissions, and product behavior into one change.

### Review decision required: AI key ownership

The current Settings page stores an API key in InstantDB, while the worker reads the first settings row using an admin token. This is not safe as a multi-user design.

**Recommended first implementation:** use a worker-owned `GEMINI_API_KEY` secret for the initial authenticated product, and defer BYO-key support until user identity and per-user secret ownership exist. This keeps the browser and InstantDB client away from the service credential and removes the need for the worker to query a global settings row.

**Alternative:** retain BYO keys, but make the setting user-scoped, pass authenticated user identity to the worker, and ensure the worker never returns the key to another user. This is a larger slice and should be chosen only if BYO is a near-term product requirement.

The remainder of this plan assumes the recommended worker-owned key unless the review changes that decision.

## Milestone 1 — Deterministic verification

### 1.1 Make planner snapshots independent of the wall clock

**Files:**

- `app/test/integration/planner_test.gleam`
- `app/birdie_snapshots/planner_empty_week.accepted`
- `app/birdie_snapshots/planner_with_meals.accepted`

**Implementation:**

1. Add a test-local fixed date helper, for example the Monday represented by the existing January snapshot.
2. Use that fixed date only in the two snapshot scenarios. Keep behavior tests that intentionally validate `date.today()` separate from snapshot rendering tests.
3. Run the planner tests and inspect the `.new` files.
4. Regenerate/accept snapshots only after confirming that the remaining diff is the intended Birdie metadata format and fixed-date output. Do not accept a snapshot containing the current machine date.
5. If Birdie metadata differs because the lockfile or Birdie version changed, pin the version that the repository intends to use and update the snapshots once, rather than allowing every developer’s Birdie version to rewrite them.

**Acceptance criteria:**

- Planner snapshots pass on two different calendar dates.
- No snapshot test calls `date.today()` for the rendered date.
- No `.new` snapshot files remain after the test run.
- Snapshot changes are limited to the intentional fixed date and compatible metadata.

### 1.2 Split worker unit tests from live AI integration tests

**Files:**

- `worker/src/parse_recipe.ts`
- `worker/test/parse_recipe.test.ts`
- `worker/test/parse_recipe.integration.test.ts` (new)
- `worker/package.json`
- `justfile`

**Current problem:** `parse_recipe.test.ts` invokes `do_parse_recipe_text`, which queries InstantDB for a key and calls Gemini. A missing `INSTANT_ADMIN_TOKEN` therefore prevents a unit test from reaching the behavior it claims to test.

**Implementation:**

1. Extract the response-to-recipe logic from `worker/src/parse_recipe.ts` into a testable function that accepts a generated JSON response or a small model-client abstraction.
2. Keep the production wrapper responsible for retrieving configuration and calling Gemini; keep schema validation and result conversion pure.
3. Rewrite the default unit tests around deterministic cases:
   - empty text returns the documented error;
   - empty image returns the documented error;
   - malformed image data URL returns an error without a network call;
   - a valid fixture response produces the expected recipe shape;
   - malformed model JSON produces a controlled error;
   - the response includes the fields required by `recipeSchema`.
4. Move the current real Gemini/InstantDB text test to `parse_recipe.integration.test.ts`. Make the integration command fail clearly when its required variables are absent; do not silently report a skipped pass.
5. Add an explicit worker command such as `bun run test:integration` and a matching Just recipe. The normal `just test-worker` path must run only deterministic unit tests.
6. Document the integration prerequisites in `worker/README.md`: `INSTANT_ADMIN_TOKEN`, a reachable InstantDB settings record if BYO remains selected, and a valid Gemini credential or worker secret.

**Acceptance criteria:**

- `bun test test/` passes with no credentials and no external AI call.
- Live AI coverage remains available through an explicit integration command.
- The unit tests do not depend on module-load environment state.

### 1.3 Make JSON-LD tests independent of schema.org

**Files:**

- `worker/src/scrape_url.ts`
- `worker/test/scrape_url.test.ts`
- `worker/test/fixtures/` (new fixture directory)

**Current problem:** test HTML uses `"@context": "https://schema.org/"`. The JSON-LD library then fetches `https://schema.org/docs/jsonldcontext.json`, which returns 403 through the current proxy.

**Implementation:**

1. Add an injectable document loader to `extractJsonLd`, defaulting to the production loader.
2. Add a local test loader or fixture for the schema.org context used by the test cases. The fixture only needs to define the terms exercised by the tests: `Recipe`, `name`, `title`, `recipeIngredient`, `recipeInstructions`, `recipeYield`, `cookTime`, and `prepTime`.
3. Pass the local loader from `scrape_url.test.ts`, so the test suite never requests schema.org.
4. Keep one optional live document-loader integration test if external compatibility is important; place it outside the default suite and report a clear network prerequisite.
5. Add a regression fixture for a recipe with no title/name and confirm the generated fallback slug remains deterministic enough for the assertion. If the fallback intentionally contains a timestamp, assert the prefix rather than a full timestamp.

**Acceptance criteria:**

- All default JSON-LD tests pass with network disabled.
- The production path still uses the real document loader.
- The test suite can run behind the current proxy without schema.org access.

### 1.4 Establish a single default verification entry point

**Files:**

- `justfile`
- optionally `app/package.json` and `worker/package.json`

**Implementation:**

1. Keep `test-app` and `test-worker` as package-specific commands.
2. Add a `check-app` recipe that runs, in a useful failure order:
   - dependency install using the lockfile;
   - Gleam format check;
   - Gleam tests;
   - Vite production build.
3. Add a `check-worker` recipe that runs:
   - dependency install using the lockfile;
   - TypeScript unit tests;
   - Gleam format check;
   - Gleam tests;
   - Gleam build.
4. Add `check` or `verify` at the root to run both package checks. Keep the live integration checks separate.
5. Ensure commands fail on the first real error and print the command that failed.

**Acceptance criteria:**

- A clean checkout has one documented command for the default verification path.
- Default verification does not need Cloudflare login, InstantDB credentials, Gemini, or external HTTP.
- The live integration command is visibly separate from the default check.

## Milestone 2 — Toolchain, formatting, and setup documentation

### 2.1 Resolve existing formatting debt

**Files:**

- `app/src/components/typeahead.gleam`
- `app/src/components/typeahead_2.gleam`

Run the project formatter and review the diff. This should be a formatting-only commit; do not mix behavior changes into it. Re-run the app format check and app tests afterward.

### 2.2 Pin the tools used by local development

The current Justfile invokes `bunx wrangler`, which resolves a package outside the repository. That makes the runtime tool version dependent on the current registry result.

**Files:**

- `worker/package.json`
- `worker/bun.lock`
- `justfile`
- `README.md`
- `worker/README.md`

**Implementation:**

1. Add Wrangler as a pinned worker development dependency at the version selected during review.
2. Replace `bunx wrangler` in Just recipes with the locally installed package, for example a worker `dev` script invoked via `bun run`.
3. Document the supported Bun, Gleam, Just, and Wrangler versions.
4. Document both local modes:
   - Vite-only frontend development;
   - Wrangler full-stack development using the built app and worker.
5. Add a safe environment example containing variable names only. At minimum document the chosen worker secret names and the optional live-integration prerequisites. Ensure the example is not ignored by the repository’s `.gitignore`.
6. Correct the README’s current instruction that references `app/.env.example` if the implementation uses Wrangler `.dev.vars` or a different configuration path.

**Acceptance criteria:**

- A new checkout does not silently download an unpinned Wrangler version.
- Documentation reflects the commands that actually work.
- No secret value is added to Git.

## Milestone 3 — Fix SPA asset routing under Wrangler

**Files:**

- `worker/src/index.mjs`
- `wrangler.jsonc`
- `worker/src/index.mjs` or a small worker runtime test fixture
- `worker/README.md`

**Current problem:** the configured `assets.not_found_handling = "single-page-application"` does not help when the Worker returns a 404 before the asset handler is consulted.

**Implementation:**

1. Parse the request URL at the JavaScript Worker boundary.
2. Route only `/api/...` requests to the compiled Gleam handler.
3. Delegate every other request to the Cloudflare assets binding, using the binding exposed by the current Wrangler assets configuration.
4. Keep the direct Bun server behavior explicit: it is an API debugging server and does not serve the frontend assets. Update its README wording if necessary.
5. Preserve API behavior and CORS headers while adding the asset path.
6. Add a local smoke script or documented curl checks for:
   - `GET /` → 200 and Mealstack HTML;
   - `GET /recipes` → 200 and the same SPA document;
   - `GET /settings` → 200 and the same SPA document;
   - `GET /assets/...` → 200;
   - `POST /api/parse_recipe_text` with `{}` → the existing 400 response;
   - an unknown `/api/...` route → the existing API 404 response.

**Acceptance criteria:**

- Direct navigation to `/recipes`, `/planner`, `/shopping-list`, `/settings`, and `/import` no longer returns 404 under Wrangler.
- API routes still reach Gleam and do not get swallowed by the asset fallback.
- The runtime smoke checks pass without Cloudflare authentication.

## Milestone 4 — Data ownership, auth, and secret handling

This milestone requires the AI-key decision from Milestone 0. It should be implemented as a security-focused slice before more data features are added.

### 4.1 Define the ownership model

**Files to review/change:**

- `app/src/instant.schema.ts`
- `app/src/instant.perms.ts`
- `app/src/db.ts`
- `app/src/app.gleam`
- `worker/src/index.mjs`
- `worker/src/mealstack_worker.gleam`
- `README.md`

**Implementation direction:**

1. Choose the identity source and document how a signed-in user is represented.
2. Add an owner/user identity to user-owned entities or place data in a user-scoped structure. Recipes, plans, shopping lists, and settings must not remain globally shared by accident.
3. Define InstantDB rules for view/create/update/delete. The minimum invariant is that unauthenticated users cannot read or mutate private data, and a user cannot access another user’s records.
4. Add a small set of permission-focused checks or a documented manual verification against a disposable InstantDB app. Do not test rules only against the production app.
5. Make the Worker validate the authenticated request context before performing scrape/parse operations if those operations are user-scoped or billable.

The exact InstantDB rule syntax and auth API should be confirmed against the version already used by the project during implementation; do not invent a new permission model in the same commit as the shopping-list work.

### 4.2 Remove hard-coded/global settings access

**File:** `app/src/db.ts`

The current `do_save_settings` writes to a fixed entity ID. Replace this with an ownership-aware lookup/upsert strategy. If the recommended worker-owned Gemini secret is selected, remove the API key from browser-readable settings and either remove the settings field or reserve it for non-secret preferences.

Add tests for:

- first-time settings creation;
- updating the current user’s settings;
- no update to another user’s record;
- no secret returned to the browser or included in client logs.

### 4.3 Establish safe local and deployed secret paths

- Local Wrangler: `.dev.vars` or the project’s selected local secret mechanism, never committed.
- Deployed Worker: Wrangler secret storage, not `wrangler.jsonc`.
- CI: repository secret store, with a smoke test that reports missing configuration without printing values.
- Browser: only public configuration such as the Instant app ID; never `INSTANT_ADMIN_TOKEN` or a service Gemini key.

If BYO keys remain a requirement, write a separate design for encryption/ownership and authenticated worker retrieval rather than extending the current global settings row.

**Acceptance criteria:**

- Permission rules are non-empty and tested against a disposable environment.
- No admin token or service Gemini key is present in client bundles.
- The hard-coded settings ID is gone.
- Local unit tests still pass without secrets.

## Milestone 5 — Finish shopping-list ↔ planner integration

**Primary files:**

- `app/src/pages/shoppinglist.gleam`
- `app/src/pages/planner.gleam`
- `app/src/shared/db.gleam`
- `app/src/shared/codecs.gleam`
- `app/src/db.ts`
- `app/test/integration/shopping_list_test.gleam`
- optionally `app/test/integration/planner_test.gleam`

### 5.1 Make the data contract explicit

Use the existing fields consistently:

- `linked_plan_start` and `linked_plan_end` identify the selected planner range;
- `linked_recipes` contains stable `RecipeSlug` references where possible;
- shopping-list items retain a `FromRecipe` source reference;
- ingredient import is explicit and does not happen merely because a plan was linked.

Recommended first-slice semantics:

1. Linking a plan updates and persists the selected date range.
2. The plan preview derives a unique, ordered list of recipe slugs from lunch and dinner entries.
3. Updating the preview persists `linked_recipes` rather than leaving them only in the in-memory model.
4. “Add ingredients” is explicit per recipe, with an optional “add all” action after the single-recipe path is correct.
5. A planner entry represented only by `RecipeName` must either resolve to a recipe deterministically or produce a visible unresolved state; it must not silently convert to an empty slug.
6. Initial implementation should preserve duplicate ingredients unless the product explicitly chooses normalized aggregation. Quantities such as “2 eggs” and “1 egg” cannot be safely merged by string matching alone.

### 5.2 Close the current behavior gaps

`shoppinglist.gleam` already contains parts of the new flow, but the current code shows these gaps:

- `DbRetrievedPlanForLinking` updates the preview and linked recipes in memory; persistence must be verified and added at the correct confirmation point.
- `UserUpdatedLinkedRecipeAtIndex` still carries a TODO about looking up the recipe and adding ingredients.
- `UserAddedIngredientsFromLinkedRecipe` only resolves `RecipeSlug`; a `RecipeName` path currently becomes an empty lookup key.
- Existing model tests cover preview and date fields, but do not assert persistence intent, linked-recipe uniqueness, unresolved recipes, or ingredient provenance.

Implement the smallest coherent message flow:

1. select start/end dates;
2. fetch the plan once both dates are valid;
3. decode and derive linked recipes;
4. update the model and save the complete shopping-list record;
5. render linked recipes with explicit add/remove controls;
6. resolve a recipe by slug and append ingredients with `FromRecipe` provenance;
7. show a user-visible error or unresolved label when the recipe cannot be found;
8. ensure reloading the list reconstructs the same linked plan and recipe references.

### 5.3 Add model-level tests before changing views

Extend `app/test/integration/shopping_list_test.gleam` with deterministic Lustre simulation tests for:

- linking a plan containing lunch and dinner recipes;
- extracting one recipe when the other meal is empty;
- de-duplicating the same recipe appearing on multiple days;
- persisting/reconstructing the linked date range and recipe references;
- adding ingredients from a slug-resolved recipe;
- handling a missing slug without changing the list;
- handling a name-only planned recipe explicitly;
- retaining `FromRecipe` source metadata;
- preventing an add-all action from mutating the list twice when dispatched twice, if idempotency is selected.

Where a test would invoke the JavaScript DB FFI, keep the model transformation pure and test the FFI payload separately. Do not require a live InstantDB app for model tests.

### 5.4 Manual verification

After the model tests pass, run the full local stack and verify:

1. Create a shopping list.
2. Select a planner range containing at least two meals.
3. Confirm the range and reload the page.
4. Confirm the linked recipes survive reload.
5. Add ingredients from one recipe and confirm the item source is the linked recipe.
6. Add the same recipe again and confirm the chosen duplicate/idempotency behavior.
7. Remove a linked recipe and confirm it does not delete already imported ingredients unless that behavior is explicitly chosen.
8. Open `/shopping-list/<date>` directly through Wrangler to verify SPA routing and data loading.

## Final verification and release gate

The implementation is ready for review only when the following are true:

### Static and unit checks

- `gleam format --check src test` passes in both packages.
- App Gleam tests pass with no snapshot churn.
- Worker Gleam tests pass.
- Worker Bun unit tests pass without external credentials or network access.
- Vite production build passes.
- Worker Gleam build passes.
- `git diff --check` passes.

### Runtime checks

- Vite development server starts.
- Wrangler full-stack server starts without Cloudflare login.
- `/`, `/recipes`, `/planner`, `/shopping-list`, `/settings`, and `/import` return the SPA document.
- API invalid-input and not-found behavior remains correct.
- Shopping-list/planner manual workflow passes against a disposable data environment.

### Security checks

- No `INSTANT_ADMIN_TOKEN`, Gemini service key, or Cloudflare credential appears in tracked files or client assets.
- InstantDB permissions are non-empty and verified.
- Settings are scoped to the authenticated owner or removed from the client-facing secret path.
- Logs do not print API keys or admin tokens.

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---:|---:|---|
| Snapshot metadata differs across Birdie versions | Medium | Medium | Pin the version, use fixed dates, review generated diffs before accepting. |
| Tests still call live services indirectly | High | High | Inject loaders/clients and keep integration tests in a separate command. |
| Cloudflare asset binding differs between local and deployed Wrangler | Medium | High | Add `/recipes` smoke coverage locally and in a disposable preview deployment. |
| Permission changes lock out existing data | Medium | High | Use a disposable InstantDB app first, back up/export existing data, then migrate ownership deliberately. |
| BYO key requirement conflicts with worker-owned key design | Medium | Medium | Resolve the AI-key decision before Milestone 4; do not implement both paths opportunistically. |
| Recipe names cannot be mapped reliably to slugs | High | Medium | Prefer stable slugs in planner data and render unresolved references explicitly. |
| Ingredient deduplication loses quantities | Medium | Medium | Preserve duplicates in the first slice; design normalization separately. |
| Bun/Wrangler version drift reappears | Medium | Medium | Pin dependencies and document the supported Bun version. |
| Scope expands into offline support or a full auth redesign | High | High | Keep those items out of this plan unless separately approved. |

## Open questions for review

1. **AI credentials:** Should the first secure implementation use a worker-owned Gemini key, or must it preserve BYO user keys now?
2. **Auth scope:** Is basic authenticated single-user ownership enough for the next release, or is multi-user sharing required immediately?
3. **Existing data:** Is the current InstantDB app disposable for development, or must existing recipes/plans be migrated in place?
4. **Shopping-list duplicates:** Should importing ingredients preserve duplicate lines, or should a later normalization pass merge compatible ingredients?
5. **Wrangler deployment:** Should the plan include a temporary authenticated preview deployment, or only local verification until the code is approved?
6. **Snapshot metadata:** Should the accepted Birdie snapshots be regenerated with the repository’s current Birdie version, or should the dependency be pinned back to the version that produced the committed metadata?

## Out of scope for this implementation

- Moving away from InstantDB for offline support.
- Browser-bookmark import and multi-recipe page import.
- Ratings, cooking notes, and rating-based grouping.
- Navigation icon/layout polish unrelated to runtime correctness.
- A complete visual redesign or shared page-layout refactor.
- Production deployment or public communication before review.
- A generalized ingredient ontology or unit/quantity normalization engine.

## Recommended first commit after approval

Create one focused commit titled something like **`stabilize deterministic test baseline`** containing only:

- fixed-date planner snapshot tests and reviewed snapshots;
- offline worker JSON-LD fixtures/loader;
- extracted worker unit-test seam and deterministic fixtures;
- explicit worker integration-test command;
- updated default verification recipes.

Do not include SPA routing, permissions, secret migration, or shopping-list behavior in that commit. This keeps the first review small and gives every later milestone a reliable green baseline.

# Gleamstack backend architecture redesign

**Review draft — no implementation tasks will be created until this plan is approved.**

## Recommendation

Replace InstantDB with **Turso Cloud plus a browser-local Turso database running in WASM**. This is a good match for Gleamstack’s current single-user design and small data model.

The browser will read and write a local SQL database stored in OPFS. A simple sync loop will push local changes to Turso Cloud and pull changes made on another device. The existing Cloudflare Worker will continue to handle scraping and AI parsing.

The migration will be completed as one coordinated piece of work while the production app is not being used. There will be no InstantDB/Turso dual-write period.

## Assumptions agreed during review

- Gleamstack is a private, single-user application.
- Turso’s last-push-wins behaviour is acceptable for this use case.
- The production app will not be used while the migration is in progress.
- We will perform one complete migration rather than maintain two backends in parallel.
- Implementation tasks will be created only after this document is approved.

## Current Gleamstack data surface

The existing InstantDB integration is fairly compact:

- Five entity groups: recipes, tag options, plan days, settings, and shopping lists.
- No InstantDB links, rooms, or presence features.
- One browser adapter, `app/src/db.ts`, owns most queries, writes, and subscriptions.
- The UI subscribes to recipe summaries and details, plan ranges, and shopping-list summaries and details.
- The worker reads tag options and a Gemini key through the InstantDB Admin SDK.
- Import, duplicate-cleanup, and tag-backfill scripts also use the Admin SDK.
- The app and API are deployed together through a Cloudflare Worker.

The tables translate naturally to SQLite. Most of the migration work is in replacing InstantDB subscriptions, running sync reliably, moving the Gemini secret, and importing the existing records.

## Relevant Turso behaviour

The Turso documentation and Vite example establish the following:

- Use `@tursodatabase/sync-wasm` and its `/vite` export.
- A named database path persists in browser OPFS across reloads.
- Reads and writes happen against the local database.
- The app calls `db.push()` and `db.pull()` explicitly to sync with Turso Cloud.
- The first normal database bootstrap needs a network connection. After that, local reads and writes can continue offline.
- `pull()` reports whether local data changed, allowing the app to refresh the current queries.
- When two devices change the same data, the last push wins.
- Browser use requires WASM, OPFS, `SharedArrayBuffer`, and the documented COOP/COEP response headers.
- The current implementation expects one active tab for a local database.
- A browser needs a Turso token to connect. That token should be supplied at runtime rather than copied into the public Vite bundle.

Turso’s exact package version and browser behaviour will be recorded during the spike. Keeping the verified InstantDB export and routine Turso backups provides a straightforward recovery path.

## Proposed target architecture

```text
Gleam / Lustre screens
          |
          v
Repository in app/src/db.ts
          |
          v
Turso WASM database
stored in browser OPFS
          |
          |  push() / pull()
          v
Turso Cloud

Gleamstack browser
          |
          |  same-origin API calls
          v
Cloudflare Worker
  - scrape and AI endpoints
  - Gemini key stored as a secret
  - owner-only database configuration
```

### Responsibility boundaries

| Concern | Proposed owner |
|---|---|
| Interactive reads and writes | Browser-local Turso database |
| Cross-device sync | A sync loop in `app/src/db.ts` calling `push()` and `pull()` |
| UI updates after data changes | A small in-memory query subscription registry |
| Schema changes | Checked-in, versioned SQL migrations |
| Owner access | Cloudflare Access plus runtime database configuration from the Worker |
| Gemini key | Cloudflare Worker secret |
| Scraping and AI parsing | Existing Cloudflare Worker endpoints |
| Imports, cleanup, and backfills | Server-side Turso client or CLI |
| Recovery | Verified InstantDB export and scheduled Turso exports |

## Key design decisions

### 1. Keep Turso behind the existing database adapter

Keep the Gleam-facing function boundary in `app/src/db.ts`. Replace its InstantDB internals with SQL rather than importing Turso throughout the UI.

The existing functions can retain their current result shapes while recipes, plans, and shopping lists are converted. This keeps the Gleam changes focused and gives migrations, SQL, subscriptions, and sync one clear home.

### 2. Replace InstantDB subscriptions with a small query registry

The app only has a handful of active database subscriptions, so a simple implementation is enough.

Each subscription will store:

- the SQL query to run;
- the callback that sends results back to Gleam;
- an unsubscribe function that removes it from memory.

The flow will be:

```text
subscribe(query, callback):
  run the query immediately
  store the query and callback
  return an unsubscribe function

after a local write:
  rerun all active queries
  schedule db.push()

after db.pull() returns changed = true:
  rerun all active queries
```

For this data size, rerunning all active queries is simpler than tracking table-level dependencies. The current functions such as `do_subscribe_to_recipe_summaries` and `do_subscribe_to_plan` can use this shared helper and continue dispatching the same data shapes to Gleam.

### 3. Keep the database token out of the public build

The browser needs a Turso token in order to sync. If the token is named `VITE_TURSO_AUTH_TOKEN`, Vite copies it into the JavaScript files served to everyone.

For this single-user app, the proposed setup is simpler:

1. Protect the production app with Cloudflare Access so only the owner can open it.
2. Store the Turso token as a Cloudflare Worker secret.
3. Add a same-origin Worker endpoint that returns the database URL and token after Cloudflare Access has admitted the owner.
4. Load that configuration when the app starts, then open the local database.

The owner can still see the token in their own browser tools; that is expected. The important point is that it is not published in the app bundle or returned to an anonymous visitor.

This design assumes one Turso database containing one user’s data. If Gleamstack becomes multi-user later, database access should be redesigned at that point.

### 4. Move the Gemini key to the Worker

The current `settings` entity stores the Gemini key in InstantDB. It should not be copied into the browser database.

The migration will:

- store the Gemini key as a Cloudflare Worker secret;
- update the parser to read that secret from its runtime environment;
- remove or simplify the current API-key settings screen;
- either send the non-secret tag options with parse requests or let the Worker read them from Turso.

### 5. Start with a direct SQLite translation

The first SQL schema should preserve current behaviour rather than redesign the data model at the same time.

| Table | Initial shape |
|---|---|
| `recipes` | Stable UUID, unique slug, `created_at`, `updated_at`, and existing ingredient, method, and tag data stored as JSON text |
| `tag_options` | Stable ID, unique name, options stored as JSON text |
| `plan_days` | Stable ID, unique date, lunch and dinner values |
| `shopping_lists` | Stable ID, unique date, status, items, recipe links, and plan bounds |
| `schema_migrations` | Applied migration ID, checksum, and timestamp |

The current `serverCreatedAt` recipe ordering will become an explicit `created_at` column. Unique date constraints will make plan-day and shopping-list updates predictable.

### 6. Accept last-push-wins for the single-user app

Turso’s default last-push-wins behaviour is acceptable here. The first version does not need conflict screens, merge logic, or application revision tracking.

Add `updated_at` fields for useful ordering and diagnostics. During the spike, make one deliberate conflicting edit from two browser profiles and record the result so the behaviour is understood.

### 7. Use one planned migration

The production app will remain unused during the work. The migration process is therefore:

1. Take and verify a full InstantDB export.
2. Stop making production changes.
3. Build and test the Turso version against a development database.
4. Import the verified export into the production Turso database.
5. Deploy the Turso-backed app and run the acceptance checks.
6. Archive the export and remove the InstantDB integration.

There is no need for dual writes, a delta importer, or a backend feature flag.

## Sequenced migration plan

| Order | Milestone | Work to execute | Ready when |
|---:|---|---|---|
| 0 | Export data and pause production use | Write and run an InstantDB Admin export for all five entity groups; save IDs and available timestamps; produce record counts and hashes; exclude the Gemini key from normal fixtures; restore the export into a disposable SQLite database; agree that production data will not change after the final export | The raw export, validation report, and test restore are complete |
| 1 | Build a Turso browser spike | Create a development Turso database; add `@tursodatabase/sync-wasm` on a spike branch; open a named OPFS database; add the required Vite and Cloudflare headers; prototype owner-only runtime token delivery; add a small test page or script; run the reload, offline, reconnect, second-browser, and one-tab checks listed below | The spike works in the actual deployed environment and its results are recorded |
| 2 | Create the SQL schema and importer | Write the initial SQL migration; add the migration runner and `schema_migrations` table; add unique constraints and timestamps; write an idempotent InstantDB-export importer; add representative fixtures; test both a clean database and an already-migrated database | Schema and importer tests pass and the exported fixture imports with matching counts |
| 3 | Build the local repository and sync loop | Replace the InstantDB initialisation inside `app/src/db.ts`; implement SQL query and write helpers; implement the in-memory subscription registry; push after local writes; run a long-poll or scheduled pull loop; rerun subscriptions after changed pulls; expose simple sync status and retry; add production response headers | A recipe can be read, edited offline, reloaded, pushed, and pulled in a second browser profile |
| 4 | Convert the application features | Convert recipe list/detail/save/delete; convert tag options; convert planner range queries and saves; convert shopping-list summaries/detail/save/delete; preserve the existing Gleam FFI result shapes; update integration fixtures and tests for each slice | All current user journeys pass with InstantDB disabled |
| 5 | Convert the Worker and maintenance tools | Move the Gemini key to a Worker secret; update parse endpoints and tag-option handling; port import, duplicate-cleanup, and tag-backfill scripts to Turso; replace InstantDB credentials in local setup and CI; remove InstantDB packages, schema, and permission files once nothing imports them | Runtime, scripts, tests, and CI no longer reference InstantDB |
| 6 | Rehearse the complete migration | Run the exporter and importer against a non-production Turso database; compare counts, hashes, IDs, JSON fields, and recipe ordering; manually exercise recipes, planner, shopping lists, tags, and parsing; run the browser/sync acceptance checks; correct any mapping or lifecycle issues and repeat the rehearsal | The full export/import and acceptance checklist complete without unexplained differences |
| 7 | Run the production migration | Confirm production has remained unused; take a fresh full export if needed; create and migrate the production Turso database; import the data; run automated comparisons; deploy the Turso-backed build; complete a short production smoke test; archive the InstantDB export; create the first Turso backup; remove and rotate InstantDB credentials | Production journeys and sync checks pass, the export is archived, and both repositories are clean |

## Exact work for the Turso spike

The spike is a short implementation in the real app and deployment path, not a general research exercise.

1. Create a disposable Turso Cloud database and a token.
2. Install `@tursodatabase/sync-wasm` in the Vite app.
3. Connect with a named path such as `gleamstack-spike.db`.
4. Add COOP `same-origin` and COEP `require-corp` to Vite development responses and Cloudflare production responses.
5. Add a minimal spike screen or test harness that can insert, list, edit, and delete rows.
6. Reload the page and restart the browser; confirm the rows remain in OPFS.
7. Complete the first sync, disable the network, make an edit, reconnect, call `push()`, and confirm the edit reaches Turso Cloud.
8. Open a second browser profile, call `pull()`, and confirm the edit appears there.
9. Make different edits to one row in both profiles, push them in sequence, and record the last-push-wins result.
10. Open a second tab and confirm the documented limitation; decide whether the app should show a one-active-tab message.
11. Prototype `/api/db-config` behind Cloudflare Access; confirm an anonymous request is rejected and the owner can initialise the database.
12. Run the deployed spike on the browsers and devices Gleamstack needs to support.
13. Record the package version, browser results, startup time, and any required Vite upgrade.

## Feature conversion order

Convert the app in this order:

1. Recipe list, detail, save, and delete.
2. Tag options.
3. Planner range queries and saves.
4. Shopping-list summaries, detail, save, and delete.
5. Settings removal or redesign.
6. Import, cleanup, and backfill scripts.

Recipes exercise the repository, JSON fields, ordering, writes, and subscriptions. Planner and shopping lists then cover range queries and unique dates.

## Acceptance checks

| Area | Check |
|---|---|
| Export | Counts and hashes match the InstantDB snapshot |
| Import | IDs, recipe ordering, optional fields, and JSON values are preserved |
| Local persistence | Data remains after reload and browser restart |
| Offline use | Existing data can be read and edited after the network is disabled |
| Reconnect | Pending local changes push successfully after reconnecting |
| Pull | A second browser profile receives cloud changes and refreshes its active screen |
| Reactivity | Current recipe, planner, and shopping-list screens update after local writes and changed pulls |
| Access | Anonymous database-configuration requests are rejected; the owner can connect |
| One-tab behaviour | The app handles or clearly explains a second active tab |
| Worker | Scraping and AI parsing work with the Gemini key stored as a Worker secret |
| Migration | All current user journeys work with InstantDB removed |
| Recovery | The archived export and a Turso backup can each be restored into a disposable database |

## Practical considerations

| Topic | Planned handling |
|---|---|
| Browser token | Deliver it at runtime to the authenticated owner; do not embed it in the Vite bundle |
| Explicit sync | Centralise push, pull, retry, and status in `app/src/db.ts` |
| InstantDB subscriptions | Replace them with the small in-memory query registry described above |
| Last-push-wins | Accept it for this single-user app and document the observed two-profile result |
| Multiple tabs | Start with one active tab unless the spike shows a simple supported alternative |
| Browser and deployment support | Test the exact Cloudflare deployment and required devices during the spike |
| Package maturity | Pin the tested Turso version and keep routine exports |
| Gemini key | Store it only as a Worker secret |
| Data recovery | Keep the verified InstantDB export and create regular Turso backups |

## Remaining review questions

1. Is Cloudflare Access the preferred way to keep the production app owner-only?
2. Is one active Gleamstack tab acceptable for the first Turso version?
3. Which browsers and devices should the spike cover?
4. Should the Gemini key become one server-owned Worker secret?
5. How long should the archived InstantDB export be retained?

## Out of scope for this review draft

- Detailed estimates and task assignment.
- Final SQL statements and indexes.
- Data-model normalisation unrelated to the migration.
- New collaborative or multi-user features.
- Application code, infrastructure changes, or credential creation before approval.

## Approval

Choose one:

- **Approve:** use this sequence as the basis for implementation task creation.
- **Approve with revisions:** annotate the document again and regenerate it.
- **Change direction:** keep the InstantDB export work and review another backend approach.

After approval, create tasks for the first authorised milestone rather than pre-creating the full backlog.

## Primary references

- [Turso Sync usage](https://docs.turso.tech/sync/usage)
- [Turso JavaScript database WASM Vite example](https://github.com/tursodatabase/turso/tree/main/examples/javascript/database-wasm-vite)
- [Turso sync conflict resolution](https://docs.turso.tech/sync/conflict-resolution)
- [Turso SDK authorisation](https://docs.turso.tech/sdk/authorization)
- [Turso in the browser](https://turso.tech/blog/introducing-turso-in-the-browser)
- [Turso offline sync public-beta announcement](https://turso.tech/blog/turso-offline-sync-public-beta)

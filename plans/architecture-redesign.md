# Gleamstack backend architecture redesign

**Review draft — no implementation tasks will be created until this plan is approved.**

## Recommendation

Replace InstantDB with **Turso Cloud plus a browser-local Turso database running in WASM**. This remains a reasonable fit for Gleamstack’s private, single-user design and compact data model.

Build the replacement in two stages:

1. Convert each feature as a vertical slice against the browser-local Turso database in OPFS. After a local write, that feature directly updates or re-queries its current screen.
2. Add explicit `push()` and `pull()`, sync status and retry, and a shared refresh for changes received by `pull()`.

The browser never runs schema migrations. It holds a replica bootstrapped from the already-migrated Turso Cloud database, and if its schema version does not match the version the build expects, it discards the local copy and re-bootstraps a fresh one. This keeps feature work separate from distributed-sync behaviour and avoids a general query-subscription layer before remote changes make one useful.

Keep the current free `workers.dev` deployment. Native Cloudflare Workers Access is now configured there, so the app can remain owner-only without buying a custom domain or adding an application authentication library.

The migration will be one coordinated change while the production app is not being used. There will be no InstantDB/Turso dual-write period.

## Assumptions agreed during review

- Gleamstack is a private, single-user application.
- Native Cloudflare Workers Access is working on the existing `workers.dev` hostname; no purchased custom domain is required.
- The deployment will remain within the Cloudflare Workers and Access free tiers and their normal limits.
- Turso’s documented last-push-wins behaviour is acceptable for this use case.
- The production app will not be used while the migration is in progress.
- We will perform one complete migration rather than maintain two backends in parallel.
- Implementation tasks will be created only after this document is approved.

## Current Gleamstack data surface

The existing InstantDB integration is fairly compact:

- Five entity groups: recipes, tag options, plan days, settings, and shopping lists.
- No InstantDB links, rooms, or presence features.
- One browser adapter, `app/src/db.ts`, owns most queries, writes, and subscriptions.
- The UI subscribes to recipe summaries and details, plan ranges, and shopping-list summaries and details.
- The Worker reads tag options and a Gemini key through the InstantDB Admin SDK.
- Import, duplicate-cleanup, and tag-backfill scripts also use the Admin SDK.
- The app and API are deployed together through a Cloudflare Worker.

The tables translate naturally to SQLite. The main work is replacing InstantDB access, preserving UI behaviour, moving the Gemini secret, importing the records, and then adding sync.

## What the official sources establish

### Browser database and sync

The current Turso repository and documentation establish the following:

- The browser package is [`@tursodatabase/sync-wasm`](https://github.com/tursodatabase/turso/tree/main/bindings/javascript/sync/packages/wasm). Its source exposes `connect()` and accepts a local `path`, with remote `url` and `authToken` configuration when cloud sync is enabled.
- A named browser database is persisted through OPFS. The implementation uses `navigator.storage.getDirectory()` and `FileSystemSyncAccessHandle` ([official OPFS implementation](https://github.com/tursodatabase/turso/blob/main/bindings/javascript/packages/wasm-common/index.ts)).
- Reads and writes operate on the local database. Offline writes remain local until the application explicitly synchronises ([Sync usage](https://docs.turso.tech/sync/usage)).
- The application explicitly calls `push()`, `pull()`, or `sync()`. `pull()` resolves to `true` when remote changes were applied and `false` when there were no changes ([sync-wasm source](https://github.com/tursodatabase/turso/blob/main/bindings/javascript/sync/packages/wasm/promise-default.ts)).
- When concurrent changes conflict, the documented rule is last push wins. A pull can roll back and replay unpushed local changes ([Conflict resolution](https://docs.turso.tech/sync/conflict-resolution)).
- The official Vite example configures COOP `same-origin` and COEP `require-corp` so `SharedArrayBuffer` is available ([sync-wasm Vite example](https://github.com/tursodatabase/turso/tree/main/examples/javascript/sync-wasm-vite)).
- Multi-tab sharing remains an open Turso backlog item rather than a supported behaviour Gleamstack should assume ([Turso issue #5679](https://github.com/tursodatabase/turso/issues/5679)). The first release should therefore be tested and designed around one active tab.

At the time of this review, the official package metadata reports a pre-release version and the package README does not consistently describe the same package. The implementation should pin and test the exact release used rather than rely on unversioned example behaviour.

A configured remote URL bootstraps a local database from Turso Cloud, and a normal sync replicates the full database with remote changes arriving as physical pages ([Sync usage](https://docs.turso.tech/sync/usage)). The reviewed material does not clearly document converting an already-populated local-only database into a synced one in place. The plan avoids depending on that: on a schema change it discards the local copy and re-bootstraps from the cloud (below). A short test should still confirm fresh-bootstrap and reset behaviour.

### Schema migrations with dbmate

Use [dbmate](https://github.com/amacneil/dbmate/blob/main/README.md) to write and apply migrations. Its documented format is plain SQL in `[version]_[description].sql` files split by `-- migrate:up` and `-- migrate:down`, applied atomically, with applied versions recorded in a `schema_migrations` table. dbmate connects to ordinary filesystem SQLite through `sqlite:` URLs; its documentation lists no `turso://` or `libsql://` driver and no browser/OPFS entry point, so it does not run in the browser or connect directly to Turso Cloud ([dbmate README](https://github.com/amacneil/dbmate/blob/main/README.md), [Turso authentication URLs](https://docs.turso.tech/sdk/authentication)).

**The cloud owns the schema; the browser never runs migration DDL.** This is the simpler model the review proposed, and it is a good fit. The flow is:

1. Author a migration and apply it to a development Turso database — dbmate against a local SQLite file for authoring and tests, then the same up SQL against the Turso database with the official `turso db shell` or `.read` command ([Turso database shell](https://docs.turso.tech/cli/db/shell), [shell commands](https://docs.turso.tech/sql-reference/cli/shell-commands)).
2. Verify the change, then apply the same up SQL to the production Turso Cloud database.
3. The frontend build carries an expected schema version. On startup the app compares it to the version recorded in the local database. If the local database is missing, older, or otherwise mismatched, the app discards the local OPFS database and re-bootstraps a fresh replica — schema and data — from Turso Cloud.

On a schema change this discards any unsynced local edits. For a single-user app that is acceptable, and it removes the need for a browser-side migration engine.

This rests on documented behaviour:

- A normal sync bootstrap replicates the **full** cloud database, and remote changes arrive as physical pages, so a fresh local replica reflects the current cloud schema ([Sync usage](https://docs.turso.tech/sync/usage)).
- The app reads the schema version from dbmate’s `schema_migrations` table, which lives in the database and syncs to the client like any other data. `PRAGMA user_version` is not used because it is read-only on Turso Cloud ([Cloud limitations](https://docs.turso.tech/cloud/limitations)).
- No documented sync-wasm feature auto-detects an application schema mismatch or resets the local database, so the startup check and reset are **application code** — the piece the review correctly identified as needing to be written.

Two details need a short test rather than assumption: that a fresh bootstrap against a migrated cloud database yields the expected schema locally, and the exact supported way to reset the local database (close the connection, then remove the OPFS entry with `removeEntry`) so a clean re-bootstrap occurs. The reviewed sync docs do not document merging incremental DDL into an already-initialised local database, which is why the plan resets and re-pulls instead of migrating in place.

### Cloudflare Workers Access and browser credentials

Cloudflare’s Workers-specific Access integration can protect a Worker’s `workers.dev` hostname directly and can apply to all traffic associated with that Worker ([Access for Workers](https://developers.cloudflare.com/workers/configuration/cloudflare-access/)). This is different from the generic self-hosted-application flow that begins with an active custom domain. The owner has confirmed that the `workers.dev` Access policy is working, so no domain purchase is part of this plan.

Keep Access configured for **all traffic** and allow only the owner identity. The gate runs before the Worker handles the request, covering the SPA, static assets, and `/api/db-config`; Gleamstack does not need a second login system or an application-owned Access-JWT verifier. If application code later needs the admitted identity for logging, use the validated Access information exposed to the Worker rather than reimplementing authentication.

Cloudflare lists an Access free tier for teams under 50 users, which is sufficient for one owner. This is separate from the Workers Free runtime quotas; both remain subject to their published limits ([Access pricing](https://www.cloudflare.com/sase/products/access/), [Workers limits](https://developers.cloudflare.com/workers/platform/limits/)). No `cloudflare-auth`, Tailflare, Basic Auth middleware, or Tailscale hosting layer is needed for the agreed deployment.

After Access admits the owner, `/api/db-config` returns the Turso URL and token to the page. It is worth being exact about what this does and does not achieve, because with Access covering the whole site the difference is smaller than it first looks:

- **Embedding at build time** (a `VITE_`-prefixed variable) writes the token as a literal string into the compiled JavaScript — the static files in `app/dist` that Vite builds and Cloudflare serves. The token then lives in the build output, deploy history, and any cache of those files, and changing it needs a rebuild and redeploy.
- **Returning it from `/api/db-config`** keeps the token in a Worker secret and hands it to the page at load time. It is not in the build output, and it rotates by changing the secret without rebuilding the front end.

Both end up **equally visible to the authenticated owner’s browser**: once the page holds the token, the owner and any script on the page can read it. Direct browser sync makes that unavoidable, so runtime delivery is not about hiding the token from the owner. Its real value is keeping the credential out of static build artifacts and allowing rotation without a rebuild. Because Access already gates every request, an unauthenticated visitor receives neither the bundle nor the API response, so the confidentiality gap between the two is small; the operational difference is the reason to prefer runtime delivery.

For the first version, provision one database-scoped token, store it as a Worker secret, and return it only from the Access-gated endpoint. Do not put a broader Turso organisation token in the Worker or build an automatic token-minting service unless a need appears. sync-wasm accepts an asynchronous `authToken` provider, so the page can re-fetch configuration after the secret is rotated ([sync-wasm source](https://github.com/tursodatabase/turso/blob/main/bindings/javascript/sync/packages/wasm/promise-default.ts)). Use the narrowest scope and a finite expiry, and document rotation and revocation ([Turso token controls](https://docs.turso.tech/sdk/authorization/tokens), [Token revocation](https://docs.turso.tech/api-reference/tokens/revoke)). A future multi-user app would need a different credential boundary.

## Proposed target architecture

### Stage 1 — local feature slices

```text
Gleam / Lustre screen
        |
        v
Feature functions in db.ts
        |
        v
Turso WASM database
in browser OPFS
        |
        v
direct screen update
or feature re-query
```

In this stage the browser bootstraps its replica once from a development Turso database and then works locally. The Access-gated `/api/db-config` delivery, the ongoing push/pull loop, and refresh-on-pull come in Stage 2.

### Stage 2 — cloud sync and protected configuration

```text
Workers Access
on workers.dev
      |
      v
SPA + static assets
+ /api/db-config
      |
      v
browser receives
scoped DB config

Local OPFS database
      |
 push() / pull()
      |
      v
  Turso Cloud
      |
pull() changed
      |
      v
refresh active queries
```

The existing Worker continues to own scraping and AI parsing, with the Gemini key stored as a Worker secret.

### Responsibility boundaries

| Concern | Proposed owner and timing |
|---|---|
| Interactive reads and writes | Browser-local Turso database from the first feature slice |
| Local UI updates | The converted feature directly updates or re-queries its screen |
| Schema changes | dbmate applies SQL to dev and Turso Cloud; the browser re-bootstraps from the cloud on a version mismatch |
| Cross-device sync | Later sync coordinator in `app/src/db.ts` calling `push()` and `pull()` |
| UI updates after remote pulls | Later refresh/invalidation helper, triggered when `pull()` returns `true` |
| Owner access | Native Workers Access on `workers.dev`, configured for all traffic and the owner identity |
| Browser database configuration | Access-gated same-origin `/api/db-config`; scoped token visible to the owner’s browser |
| Turso browser token | Database-scoped token stored as a Worker secret; finite expiry and documented manual rotation/revocation |
| Gemini key | Cloudflare Worker secret; never copied into the browser database |
| Scraping and AI parsing | Existing Cloudflare Worker endpoints |
| Imports, cleanup, and backfills | Server-side Turso client or CLI |
| Recovery | Verified InstantDB export and regular Turso exports |

## Key design decisions

### 1. Keep Turso behind the existing database adapter

Keep the Gleam-facing boundary in `app/src/db.ts`. Replace its InstantDB internals with SQL rather than importing Turso throughout the UI.

The existing functions should retain their current result shapes while each feature is converted. This gives SQL, migrations, and later sync one clear home without forcing unrelated Gleam changes.

### 2. Convert local-only vertical slices first

Convert one complete user journey at a time: query, render, write, delete where relevant, and tests. During this stage, a successful write will update the returned model or re-run that feature’s query directly.

Turso does not require a subscription registry and the reviewed sync-wasm API does not provide reactive queries. A general registry would add machinery before it has a second source of change to coordinate.

### 3. Add refresh coordination with remote pull

When cloud sync is introduced, centralise active-query invalidation in `app/src/db.ts`:

```text
local write
  -> update or re-query the affected feature
  -> request a push

pull() returns true
  -> refresh active feature queries

pull() returns false
  -> no UI refresh
```

The first implementation may refresh all active feature queries because the data set and number of screens are small. Table-level dependency tracking is unnecessary unless measurement later justifies it.

### 4. Let the cloud own the schema; dbmate applies it

dbmate owns the migration SQL. Author and test each migration with dbmate against a local SQLite file, then apply the same up SQL to the development and production Turso databases with `turso db shell`. The browser never executes migration DDL.

Instead, the frontend build carries an expected schema version. On startup the app reads the version recorded in the local database and, if it is missing or does not match, discards the local OPFS database and re-bootstraps a fresh replica from the already-migrated Turso Cloud database. The cloud is the single source of truth for schema; the browser only ever receives a schema it did not build.

The initial schema should preserve current behaviour rather than combine the backend change with data-model redesign:

| Table | Initial shape |
|---|---|
| `recipes` | Stable UUID, unique slug, `created_at`, `updated_at`, and existing ingredient, method, and tag data as JSON text |
| `tag_options` | Stable ID, unique name, options as JSON text |
| `plan_days` | Stable ID, unique date, lunch and dinner values |
| `shopping_lists` | Stable ID, unique date, status, items, recipe links, and plan bounds |
| `schema_migrations` | dbmate’s applied-version table; syncs to the client, which compares it to the build’s expected version |

The current `serverCreatedAt` ordering becomes an explicit `created_at` column. Unique date constraints make plan-day and shopping-list writes predictable.

### 5. Use native Workers Access for owner-only delivery

Keep Access enabled for all traffic on the existing `workers.dev` Worker and restrict the policy to the owner. This protects assets and API routes without a purchased domain or application authentication code.

Have `/api/db-config` return the Turso URL and a database-scoped, expiring token stored as a Worker secret only after Access admission. Do not put the token in `VITE_` variables or built JavaScript, and do not store a broader organisation token in the Worker merely to mint short-lived credentials. The authenticated owner can inspect the runtime token in browser developer tools, which is expected in this architecture.

### 6. Move the Gemini key to the Worker

Do not copy the current Gemini key from InstantDB settings into the browser database. Store it as a Cloudflare Worker secret, update the parser to read it from runtime configuration, and remove or simplify the API-key settings screen.

Tag options are not secret. They can be sent with parse requests or read by the Worker from Turso, whichever keeps the final parsing flow simpler.

### 7. Accept last-push-wins

The documented last-push-wins behaviour is acceptable for this single-user app. The first version does not need merge screens, application revision tracking, or custom conflict resolution.

Keep `updated_at` values for useful ordering and diagnostics. Deliberately test one conflict from two browser profiles and record the observed result.

### 8. Use one planned migration

The production app will remain unused during the work. The migration procedure is:

1. Take and verify a complete InstantDB export.
2. Stop making production changes.
3. Build and test the Turso version against disposable local and cloud databases.
4. Apply the checked-in dbmate up migrations to the production Turso database through the verified host-side Turso CLI adapter.
5. Import the verified export once.
6. Deploy the Turso-backed app and run the acceptance checks.
7. Archive the export, take the first Turso backup, and remove InstantDB credentials.

There is no need for dual writes, a delta importer, or a backend feature flag.

## Sequenced migration plan

These are review milestones, not implementation tasks. Detailed tasks will be created only after approval.

### 0. Preserve data and pause production use

**Work.** Export all five InstantDB entity groups; retain IDs and available timestamps; produce counts and hashes; exclude the Gemini key from ordinary fixtures; restore the export into disposable SQLite; stop production changes after the final export.

**Ready when.** The export, validation report, and test restore are complete.

### 1. Prove Turso works in the real deployment

**Work.** Add a pinned `@tursodatabase/sync-wasm` to a throwaway page deployed the way the real app is — on `workers.dev`, behind Access, with the COOP/COEP headers — and confirm the essentials listed under *What the spike must prove* below.

**Ready when.** The essentials work on your main browser, and anything that does not is written down with a fallback.

### 2. Establish migrations and repository foundations

**Work.** Add dbmate and write the initial migration; apply it to the development Turso database with `turso db shell`; add the startup schema-version check that discards and re-bootstraps the local database on a mismatch; add SQL query and write helpers behind `app/src/db.ts`; add fixtures and tests; write an idempotent InstantDB-export importer.

**Ready when.** A stale local database is detected and re-bootstrapped to the expected schema, and the exported fixture imports with matching counts.

### 3. Convert recipes locally

**Work.** Convert recipe list, detail, save, and delete as one OPFS-only slice; preserve existing FFI shapes; directly re-query recipe screens after writes; add integration coverage.

**Ready when.** Recipe journeys work from the local replica after reload, with InstantDB removed.

### 4. Convert tags and planner locally

**Work.** Convert tag options, planner range queries, and planner saves; directly refresh affected screens; preserve IDs, ordering, and unique dates.

**Ready when.** Tag and planner journeys work locally with InstantDB disabled.

### 5. Convert shopping lists and settings locally

**Work.** Convert shopping-list summaries, detail, save, and delete; move the Gemini key to a Worker secret; remove or redesign settings; retain local direct-refresh behaviour.

**Ready when.** All interactive journeys and parsing work without InstantDB, and the browser database contains no Gemini key.

### 6. Pass the local-only parity gate

**Work.** Exercise every current user journey offline and after browser restart; finish local test fixtures; confirm the schema-version check runs before any query; confirm there is still no sync-only query registry.

**Ready when.** The app is functionally complete against local OPFS alone.

### 7. Add cloud sync and remote refresh

**Work.** Point the app at the Access-gated `/api/db-config` for its Turso URL and token; connect the local replica; add push, pull, retry, token refresh, and sync status; refresh active queries only when a pull reports changes; test two profiles and reconnect behaviour.

**Ready when.** Local changes reach Turso Cloud, remote changes refresh active screens, and anonymous configuration requests are rejected.

### 8. Convert tools and rehearse the cutover

**Work.** Port import, cleanup, and backfill scripts; remove remaining InstantDB package and CI references; rehearse the complete export, dbmate migration, import, deploy, comparison, browser, sync, Access, Worker, backup, and restore procedure.

**Ready when.** The rehearsal completes without unexplained differences or hidden InstantDB dependencies.

### 9. Run the production migration

**Work.** Confirm production remained unused; take a fresh export if required; migrate and import production Turso once; deploy; run comparisons and smoke checks; archive the InstantDB export; create the first Turso backup; remove and rotate InstantDB credentials.

**Ready when.** Production journeys and sync checks pass, recovery artifacts exist, and the repositories are clean.

## What the spike must prove

The spike is a throwaway page deployed like the real app, not a research exercise. Keep it short — it only needs to answer the questions the documentation leaves open:

- A named OPFS database persists across reload and browser restart, with COOP/COEP set.
- A fresh local database bootstraps its schema and data from a dbmate-migrated Turso Cloud database.
- Discarding the local OPFS database triggers a clean re-bootstrap from the cloud.
- Offline edits stay local, then `push()` sends them and `pull()` brings remote changes down (`true` when something changed, `false` when not).
- The Turso token is delivered from `/api/db-config` behind Access, is absent from the built assets, and rotates by changing the Worker secret without a rebuild.
- One deliberate two-profile conflicting edit shows the last-push-wins result.

Record the pinned `sync-wasm` version, one-tab behaviour, and any required Vite change. Anything the spike cannot make work is written down with a fallback before wider conversion begins.

## Feature conversion order

Convert the application as local-only vertical slices in this order:

1. Recipe list, detail, save, and delete.
2. Tag options.
3. Planner range queries and saves.
4. Shopping-list summaries, detail, save, and delete.
5. Settings removal or redesign and Worker secret handling.
6. Import, cleanup, and backfill scripts.
7. Cloud sync, then refresh after changed pulls.

Recipes exercise the repository, JSON fields, ordering, and writes. Planner and shopping lists then cover range queries and unique dates. Sync comes last so local behaviour can be verified without network state obscuring feature issues.

## Acceptance checks

| Area | Check |
|---|---|
| Export | Counts and hashes match the final InstantDB snapshot |
| Schema | Migrations apply to dev and cloud via dbmate/`turso db shell`; a stale local database is detected and re-bootstrapped from the cloud; the browser runs no migration DDL |
| Import | IDs, recipe ordering, optional fields, and JSON values are preserved |
| Local persistence | Data remains after reload and browser restart |
| Local feature parity | Every screen reads and writes correctly before cloud sync is enabled |
| Offline use | Existing data can be read and edited while the network is disabled |
| Reconnect | Pending local changes push successfully after reconnecting |
| Pull | A second profile receives cloud changes; a changed pull refreshes active screens and an empty pull does not |
| Last-push-wins | The recorded two-profile conflict matches the accepted single-user behaviour |
| Access | All-traffic Workers Access rejects unauthenticated SPA, asset, and configuration requests; the allowed owner reaches each route |
| Browser token | No token is embedded in public assets or unauthenticated responses; owner visibility, expiry, refresh, and revocation are documented |
| One-tab behaviour | The app handles or clearly explains a second active tab |
| Worker | Scraping and AI parsing work with the Gemini key stored as a Worker secret |
| Migration | All current journeys work with InstantDB removed and no dual-write period |
| Recovery | The archived export and a Turso backup can each be restored into a disposable database |

## Practical considerations

| Topic | Planned handling |
|---|---|
| Migration mechanism | dbmate for dev/cloud SQL; cloud owns the schema; the browser re-bootstraps from the cloud on a version mismatch and runs no DDL |
| Local UI updates | Direct feature update or re-query during local-only conversion |
| Remote UI updates | Add a shared refresh helper only with cloud pull |
| Owner authentication | Existing all-traffic Workers Access policy on `workers.dev`; no custom domain or application login layer |
| Browser token | Store one database-scoped token as a Worker secret; deliver after Access admission; use finite expiry and manual rotation; do not embed it in Vite assets or unauthenticated responses |
| Explicit sync | Add later and centralise push, pull, retry, and status in `app/src/db.ts` |
| Last-push-wins | Accept it for this single-user app and record the two-profile result |
| Multiple tabs | Begin with one active tab unless the spike proves a supported alternative |
| Browser support | Test the exact Cloudflare deployment and required devices during the spike |
| Package maturity | Pin the tested sync-wasm release and record any discrepancy between package source and examples |
| Gemini key | Store it only as a Worker secret |
| Recovery | Keep the verified InstantDB export and create regular Turso backups |

## Remaining review questions

1. Is one active Gleamstack tab acceptable for the first Turso version?
2. Which browsers and devices must the spike cover?
3. Should the Gemini key become one server-owned Worker secret?
4. How long should the archived InstantDB export be retained?

## Out of scope for this review draft

- Detailed estimates, task assignment, or task creation before approval.
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

## Primary official references

### dbmate

- [dbmate README](https://github.com/amacneil/dbmate/blob/main/README.md)

### Turso and libSQL

- [sync-wasm package source](https://github.com/tursodatabase/turso/tree/main/bindings/javascript/sync/packages/wasm)
- [sync-wasm Vite example](https://github.com/tursodatabase/turso/tree/main/examples/javascript/sync-wasm-vite)
- [Sync usage](https://docs.turso.tech/sync/usage)
- [Sync conflict resolution](https://docs.turso.tech/sync/conflict-resolution)
- [Turso Cloud limitations](https://docs.turso.tech/cloud/limitations)
- [Turso authentication URLs](https://docs.turso.tech/sdk/authentication)
- [Turso database shell](https://docs.turso.tech/cli/db/shell)
- [Turso shell commands](https://docs.turso.tech/sql-reference/cli/shell-commands)
- [Turso token controls](https://docs.turso.tech/sdk/authorization/tokens)
- [Turso token revocation](https://docs.turso.tech/api-reference/tokens/revoke)
- [Migrate to Turso](https://docs.turso.tech/cloud/migrate-to-turso)
- [SDK authorisation](https://docs.turso.tech/sdk/authorization)

### Cloudflare Workers Access

- [Access for Workers](https://developers.cloudflare.com/workers/configuration/cloudflare-access/)
- [One-click Access for Workers](https://developers.cloudflare.com/changelog/post/2025-10-03-one-click-access-for-workers/)
- [Access pricing](https://www.cloudflare.com/sase/products/access/)
- [Workers limits](https://developers.cloudflare.com/workers/platform/limits/)
- [workers.dev routing](https://developers.cloudflare.com/workers/configuration/routing/workers-dev/)

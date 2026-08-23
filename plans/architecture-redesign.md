# Gleamstack backend architecture redesign

**Review draft — no implementation tasks will be created until this plan is approved.**

## Recommendation

Replace InstantDB with **Turso Cloud plus a browser-local Turso database running in WASM**. This remains a reasonable fit for Gleamstack’s private, single-user design and compact data model.

Build the replacement in two stages:

1. Convert each feature as a complete **local-only vertical slice** backed by the browser database in OPFS. After a local write, that feature will directly update or re-query its current screen.
2. After every feature works locally, add Turso Cloud bootstrap, explicit `push()` and `pull()`, sync status and retry, and a shared refresh mechanism for changes received by `pull()`.

This order keeps SQL and feature-parity work separate from distributed sync behaviour. It also avoids building a general query-subscription layer before remote changes make one useful.

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

A configured remote URL can bootstrap an empty local database from Turso Cloud. The official material reviewed does not clearly document converting an already-populated local-only browser database into a synced database. The spike must test that transition before the staged plan depends on it.

### Schema migrations with dbmate

Use [dbmate](https://github.com/amacneil/dbmate/blob/main/README.md) as the canonical migration workflow. Its documented format is plain SQL in `[version]_[description].sql` files, divided by `-- migrate:up` and `-- migrate:down`. Migrations are atomic by default, and applied numeric versions are recorded in `schema_migrations`.

dbmate directly supports ordinary filesystem SQLite through `sqlite:` and `sqlite3:` URLs. Its official documentation does not list Turso’s `turso://` or libSQL’s `libsql://` protocols, and it does not provide a browser/WASM entry point or OPFS access ([dbmate README](https://github.com/amacneil/dbmate/blob/main/README.md), [Turso authentication URLs](https://docs.turso.tech/sdk/authentication)). The plan should not claim dbmate itself runs inside the browser or connects directly to Turso Cloud.

Use one set of dbmate files and version numbers for every database target:

1. Create migrations with `dbmate new` and review the up and down SQL.
2. Run `dbmate up` or `dbmate migrate` against ordinary local SQLite files used by scripts and tests.
3. In the browser, use a minimal compatibility adapter to read each pending `migrate:up` block, execute it through sync-wasm, and insert the same version into `schema_migrations` before repository queries begin.
4. For Turso Cloud, use a host-side script with the official `turso db shell` or `.read` command to execute the same up SQL and record the same version ([Turso database shell](https://docs.turso.tech/cli/db/shell), [shell commands](https://docs.turso.tech/sql-reference/cli/shell-commands)).
5. Compare local and cloud `schema_migrations` before enabling sync, and fail clearly on an unknown or newer version.

The small OPFS and Turso adapters remain application-owned because dbmate cannot execute in those environments. They implement dbmate compatibility rather than introduce a second migration format. Turso’s guidance to use a metadata table instead of read-only `PRAGMA user_version` is consistent with dbmate’s `schema_migrations` table ([Cloud limitations](https://docs.turso.tech/cloud/limitations)).

Because production will be unused during one coordinated migration, Gleamstack does not need a long-lived mixed-schema rollout. Schema rollout remains an explicit out-of-band step; the reviewed Turso sync documentation does not establish OPFS DDL as the cloud migration mechanism.

### Cloudflare Workers Access and browser credentials

Cloudflare’s Workers-specific Access integration can protect a Worker’s `workers.dev` hostname directly and can apply to all traffic associated with that Worker ([Access for Workers](https://developers.cloudflare.com/workers/configuration/cloudflare-access/)). This is different from the generic self-hosted-application flow that begins with an active custom domain. The owner has confirmed that the `workers.dev` Access policy is working, so no domain purchase is part of this plan.

Keep Access configured for **all traffic** and allow only the owner identity. The gate runs before the Worker handles the request, covering the SPA, static assets, and `/api/db-config`; Gleamstack does not need a second login system or an application-owned Access-JWT verifier. If application code later needs the admitted identity for logging, use the validated Access information exposed to the Worker rather than reimplementing authentication.

Cloudflare lists an Access free tier for teams under 50 users, which is sufficient for one owner. This is separate from the Workers Free runtime quotas; both remain subject to their published limits ([Access pricing](https://www.cloudflare.com/sase/products/access/), [Workers limits](https://developers.cloudflare.com/workers/platform/limits/)). No `cloudflare-auth`, Tailflare, Basic Auth middleware, or Tailscale hosting layer is needed for the agreed deployment.

After Access admits the owner, `/api/db-config` may return the Turso URL and a database-scoped, expiring token to the app. Runtime delivery prevents that token from being copied into public Vite assets or returned to an unauthenticated request. It does **not** make the token secret from the authenticated browser: the owner and JavaScript running in the page can inspect it.

For the first version, provision one database-scoped token, store it as a Worker secret, and return it only from the Access-gated endpoint. Do not place a broader Turso organisation token in the Worker or build an automatic token-minting service unless the spike demonstrates a need. sync-wasm accepts an asynchronous `authToken` provider, so the app can re-fetch runtime configuration after the stored token is rotated ([sync-wasm source](https://github.com/tursodatabase/turso/blob/main/bindings/javascript/sync/packages/wasm/promise-default.ts)).

Use the narrowest token scope and a practical finite expiry compatible with browser sync, and document manual rotation and revocation ([Turso token controls](https://docs.turso.tech/sdk/authorization/tokens), [Token revocation](https://docs.turso.tech/api-reference/tokens/revoke)). This is acceptable for the private, single-user design. A future multi-user application would need a different database credential boundary.

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

There is no cloud connection, browser database token, push/pull loop, or general subscription registry in this stage.

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
| Schema changes | Canonical dbmate SQL; dbmate CLI for filesystem SQLite; compatible adapters for OPFS and Turso Cloud |
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

### 4. Use dbmate as the migration source of truth

Keep ordered dbmate SQL files and the standard `schema_migrations` version table. Use dbmate itself for filesystem SQLite. Keep the browser and Turso adapters deliberately small: select pending dbmate up blocks, execute them transactionally where supported, and record the same numeric versions.

Run migrations before feature queries in every local database. Before cloud sync is enabled, apply the identical dbmate up blocks to Turso Cloud out of band and prove that local and cloud version sets match.

The initial schema should preserve current behaviour rather than combine the backend change with data-model redesign:

| Table | Initial shape |
|---|---|
| `recipes` | Stable UUID, unique slug, `created_at`, `updated_at`, and existing ingredient, method, and tag data as JSON text |
| `tag_options` | Stable ID, unique name, options as JSON text |
| `plan_days` | Stable ID, unique date, lunch and dinner values |
| `shopping_lists` | Stable ID, unique date, status, items, recipe links, and plan bounds |
| `schema_migrations` | dbmate-compatible applied numeric migration versions |

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

### 1. Validate the selected Turso release

**Work.** In a small deployed harness, pin `@tursodatabase/sync-wasm`; prove named OPFS persistence, dbmate-compatible migration startup, CRUD, reload, offline use, required headers, supported browsers, and one-tab behaviour. Separately verify the configured all-traffic Workers Access policy, cloud bootstrap, push/pull, conflict behaviour, runtime token delivery, and the transition from populated local-only data to sync.

**Ready when.** The exact release and both local and sync paths are understood, and any unsupported transition has a documented fallback.

### 2. Establish migrations and repository foundations

**Work.** Add dbmate and write the initial migration; add the minimal dbmate-compatible OPFS and Turso adapters; add SQL query and write helpers behind `app/src/db.ts`; add representative fixtures and migration tests; write an idempotent InstantDB-export importer.

**Ready when.** Clean, already-current, and older disposable databases all reach the expected schema, and fixture import counts match.

### 3. Convert recipes locally

**Work.** Convert recipe list, detail, save, and delete as one OPFS-only slice; preserve existing FFI shapes; directly re-query recipe screens after writes; add integration coverage.

**Ready when.** Recipe journeys work after reload with no InstantDB and no cloud connection.

### 4. Convert tags and planner locally

**Work.** Convert tag options, planner range queries, and planner saves; directly refresh affected screens; preserve IDs, ordering, and unique dates.

**Ready when.** Tag and planner journeys work locally with InstantDB disabled.

### 5. Convert shopping lists and settings locally

**Work.** Convert shopping-list summaries, detail, save, and delete; move the Gemini key to a Worker secret; remove or redesign settings; retain local direct-refresh behaviour.

**Ready when.** All interactive journeys and parsing work without InstantDB, and the browser database contains no Gemini key.

### 6. Pass the local-only parity gate

**Work.** Exercise every current user journey offline and after browser restart; finish local test fixtures; confirm migrations run before all queries; confirm there is still no sync-only query registry.

**Ready when.** The app is functionally complete against local OPFS alone.

### 7. Add cloud sync and remote refresh

**Work.** Apply the same dbmate up migrations to a development Turso database; add runtime configuration behind the existing all-traffic Workers Access gate; connect the local database; add push, pull, retry, token refresh, and sync status; add active-query refresh only when pull reports changes; test two profiles and reconnect behaviour.

**Ready when.** Local changes reach Turso Cloud, remote changes refresh active screens, and anonymous configuration requests are rejected.

### 8. Convert tools and rehearse the cutover

**Work.** Port import, cleanup, and backfill scripts; remove remaining InstantDB package and CI references; rehearse the complete export, dbmate migration, import, deploy, comparison, browser, sync, Access, Worker, backup, and restore procedure.

**Ready when.** The rehearsal completes without unexplained differences or hidden InstantDB dependencies.

### 9. Run the production migration

**Work.** Confirm production remained unused; take a fresh export if required; migrate and import production Turso once; deploy; run comparisons and smoke checks; archive the InstantDB export; create the first Turso backup; remove and rotate InstantDB credentials.

**Ready when.** Production journeys and sync checks pass, recovery artifacts exist, and the repositories are clean.

## Exact work for the Turso spike

The spike is a short validation in the real app and deployment path, not a general research exercise.

### Local database checks

1. Pin the exact `@tursodatabase/sync-wasm` release and record it.
2. Open a named local path such as `gleamstack-spike.db` without cloud configuration.
3. Add the required COOP and COEP headers to Vite development and Cloudflare responses.
4. Create two dbmate migrations, apply their up blocks through the OPFS adapter, and confirm `schema_migrations` on clean, current, and older local databases.
5. Insert, list, edit, and delete rows through the proposed repository boundary.
6. Reload the page and restart the browser; confirm rows remain in OPFS.
7. Disable the network and confirm existing data can still be read and edited.
8. Open a second tab and record the actual behaviour; decide whether to show a one-active-tab message.

### Sync and access checks

1. Create a disposable Turso Cloud database, apply the same dbmate up blocks with the host-side Turso CLI adapter, confirm `schema_migrations`, and create a database-scoped, expiring token.
2. Confirm Workers Access remains configured for all traffic on `workers.dev` and allows only the owner identity.
3. Confirm unauthenticated requests for the SPA, a static asset, and `/api/db-config` are stopped by Access; confirm the admitted owner reaches each route.
4. Confirm no Turso token appears in built assets or unauthenticated responses, then confirm the authenticated browser can inspect the runtime token as expected.
5. Rotate the database-scoped Worker secret, re-fetch `/api/db-config` through the asynchronous token provider, and exercise expiry and revocation without rebuilding the frontend.
6. Reopen the populated local-only database with remote configuration and prove its data can be synchronised. If the selected release does not support that transition safely, document and test a controlled local export/import fallback.
7. Disable the network, edit locally, reconnect, call `push()`, and confirm the edit reaches Turso Cloud.
8. Open a second browser profile, call `pull()`, and confirm the edit appears there.
9. Confirm `pull()` returns `true` for applied changes and `false` when there is nothing new.
10. Make conflicting edits in two profiles, push them in sequence, and record the last-push-wins result.
11. Run the checks on every browser and device Gleamstack needs to support.
12. Record startup time, package behaviour, token lifecycle, Free-plan limits, and any required Vite upgrade.

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
| Schema | dbmate handles filesystem SQLite; OPFS and Turso adapters apply the same up blocks; all targets report the same `schema_migrations` versions before sync |
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
| Migration mechanism | Canonical dbmate files and `schema_migrations`; dbmate CLI for filesystem SQLite; minimal compatible adapters for OPFS and Turso Cloud |
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

# Gleamstack backend architecture redesign

**Review draft — no implementation tasks will be created until this plan is approved.**

## Recommendation

Replace InstantDB with **Turso Cloud plus a browser-local Turso database running in WASM**. This remains a reasonable fit for Gleamstack’s private, single-user design and compact data model.

Build the replacement in two stages:

1. Convert each feature as a complete **local-only vertical slice** backed by the browser database in OPFS. After a local write, that feature will directly update or re-query its current screen.
2. After every feature works locally, add Turso Cloud bootstrap, explicit `push()` and `pull()`, sync status and retry, and a shared refresh mechanism for changes received by `pull()`.

This order keeps SQL and feature-parity work separate from distributed sync behaviour. It also avoids building a general query-subscription layer before remote changes make one useful.

The migration will be one coordinated change while the production app is not being used. There will be no InstantDB/Turso dual-write period.

## Assumptions agreed during review

- Gleamstack is a private, single-user application.
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

### Schema migrations

The official sources do **not** document a migration runner for `@tursodatabase/sync-wasm` or a browser API that discovers and applies SQL migration files.

Related Turso features do not fill that gap:

- Turso documents external migrations through tools such as Drizzle, but that is a separate tool-driven workflow ([Turso Drizzle guide](https://docs.turso.tech/sdk/ts/orm/drizzle)).
- Multi-DB Schemas and their migration jobs concern parent and child cloud databases, are marked deprecated, and do not describe browser sync databases ([Multi-DB Schemas](https://docs.turso.tech/features/multi-db-schemas), [Platform API reference](https://docs.turso.tech/sdk/http/reference)).
- Embedded Replicas are a different client model whose writes normally go to a remote primary ([Embedded Replicas](https://docs.turso.tech/features/embedded-replicas/introduction)).
- Turso Cloud treats SQLite `PRAGMA user_version` as read-only and recommends a `_schema_version` table instead ([Cloud limitations](https://docs.turso.tech/cloud/limitations)).

Gleamstack should therefore own a small migration runner. This is an application design choice, not a Turso-provided framework:

1. Keep ordered, immutable SQL migration files in the repository.
2. Track the applied migration ID, checksum, and timestamp in `_schema_version`.
3. Run pending migrations in order before repository queries begin.
4. Apply each migration in a transaction where SQLite permits it.
5. Apply the same migration set to the Turso Cloud database before enabling sync against it.
6. Fail startup clearly rather than opening a database with an unknown or newer schema.

Because production will be unused during one coordinated migration, Gleamstack does not need a long-lived mixed-schema rollout. The spike still needs to verify how the selected sync-wasm release handles DDL and an existing OPFS database before the production procedure is fixed.

### Cloudflare Access and browser credentials

Cloudflare Access can protect a self-hosted application by public hostname and, where needed, by path. Access policies decide which identities may reach the application ([Self-hosted applications](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/), [Access policies](https://developers.cloudflare.com/cloudflare-one/access-controls/policies/)). Protecting the Gleamstack hostname therefore gates both the SPA and its same-origin `/api/db-config` route.

The Worker should also validate the Access assertion supplied in `Cf-Access-Jwt-Assertion`. Cloudflare’s guidance requires validation of the token signature, issuer, and application audience using the Access certificate endpoint ([Validate Access tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/validating-json/)). This gives the configuration route an explicit origin-side identity check rather than relying only on routing assumptions.

After successful validation, `/api/db-config` may return the Turso URL and a database token to the app. Runtime delivery prevents that token from being copied into the public Vite bundle or returned to an anonymous request. It does **not** make the token secret from the authenticated browser: the owner and any JavaScript running in that page can inspect it. Cloudflare Access protects who receives the credential; it does not turn a browser credential into a server-only secret.

This is acceptable for the agreed private, single-user design, provided the exact token scope and rotation procedure are recorded during the spike. A future multi-user application would need a different database and credential boundary.

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
Cloudflare Access
        |
        v
SPA + /api/db-config
        |
        v
Worker validates Access JWT
        |
        v
browser receives DB config

Local OPFS database
        |
   push() / pull()
        |
        v
    Turso Cloud
        |
pull() changed = true
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
| Schema changes | Gleamstack migration runner plus checked-in SQL and `_schema_version` |
| Cross-device sync | Later sync coordinator in `app/src/db.ts` calling `push()` and `pull()` |
| UI updates after remote pulls | Later refresh/invalidation helper, triggered when `pull()` returns `true` |
| Owner access | Cloudflare Access policy plus JWT validation in the Worker |
| Browser database configuration | Same-origin `/api/db-config`; visible to the authenticated browser |
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

### 4. Own ordered schema migrations

Use `_schema_version`, checked-in SQL, and a small runner rather than assuming sync-wasm supplies migrations. Run migrations before feature queries in every local database. Before cloud sync is enabled, bring the Turso Cloud database to the identical schema and prove that local and cloud schema versions match.

The initial schema should preserve current behaviour rather than combine the backend change with data-model redesign:

| Table | Initial shape |
|---|---|
| `recipes` | Stable UUID, unique slug, `created_at`, `updated_at`, and existing ingredient, method, and tag data as JSON text |
| `tag_options` | Stable ID, unique name, options as JSON text |
| `plan_days` | Stable ID, unique date, lunch and dinner values |
| `shopping_lists` | Stable ID, unique date, status, items, recipe links, and plan bounds |
| `_schema_version` | Applied migration ID, checksum, and timestamp |

The current `serverCreatedAt` ordering becomes an explicit `created_at` column. Unique date constraints make plan-day and shopping-list writes predictable.

### 5. Use Cloudflare Access for owner-only delivery

Protect the production hostname with Cloudflare Access. Have `/api/db-config` validate the Access JWT before returning the Turso URL and token. Do not put a privileged token in `VITE_` variables or built JavaScript.

Describe this as protected runtime delivery, not secret client storage. The authenticated owner can inspect the token in browser developer tools, which is expected in this architecture.

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
4. Apply the checked-in migrations to the production Turso database.
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

**Work.** In a small deployed harness, pin `@tursodatabase/sync-wasm`; prove named OPFS persistence, migration startup, CRUD, reload, offline use, required headers, supported browsers, and one-tab behaviour. Separately prove cloud bootstrap, push/pull, conflict behaviour, Access protection, JWT validation, and the transition from populated local-only data to sync.

**Ready when.** The exact release and both local and sync paths are understood, and any unsupported transition has a documented fallback.

### 2. Establish migrations and repository foundations

**Work.** Write the initial schema migration and `_schema_version` runner; add SQL query and write helpers behind `app/src/db.ts`; add representative fixtures and migration tests; write an idempotent InstantDB-export importer.

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

**Work.** Apply the same migrations to a development Turso database; add Access-protected runtime configuration and Worker JWT validation; connect the local database; add push, pull, retry, and sync status; add active-query refresh only when pull reports changes; test two profiles and reconnect behaviour.

**Ready when.** Local changes reach Turso Cloud, remote changes refresh active screens, and anonymous configuration requests are rejected.

### 8. Convert tools and rehearse the cutover

**Work.** Port import, cleanup, and backfill scripts; remove remaining InstantDB package and CI references; rehearse the complete export, migration, import, deploy, comparison, browser, sync, Access, Worker, backup, and restore procedure.

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
4. Run two ordered migrations and confirm `_schema_version` on clean, current, and older local databases.
5. Insert, list, edit, and delete rows through the proposed repository boundary.
6. Reload the page and restart the browser; confirm rows remain in OPFS.
7. Disable the network and confirm existing data can still be read and edited.
8. Open a second tab and record the actual behaviour; decide whether to show a one-active-tab message.

### Sync and access checks

1. Create a disposable Turso Cloud database, apply the same migration set, and create a database token.
2. Protect the deployed spike and `/api/db-config` with Cloudflare Access.
3. Validate the Access JWT in the Worker; confirm an anonymous request is rejected and an allowed owner request succeeds.
4. Confirm no Turso token appears in built assets, then confirm the authenticated browser can inspect the runtime token as expected.
5. Reopen the populated local-only database with remote configuration and prove its data can be synchronised. If the selected release does not support that transition safely, document and test a controlled local export/import fallback.
6. Disable the network, edit locally, reconnect, call `push()`, and confirm the edit reaches Turso Cloud.
7. Open a second browser profile, call `pull()`, and confirm the edit appears there.
8. Confirm `pull()` returns `true` for applied changes and `false` when there is nothing new.
9. Make conflicting edits in two profiles, push them in sequence, and record the last-push-wins result.
10. Run the checks on every browser and device Gleamstack needs to support.
11. Record startup time, package behaviour, token lifecycle, and any required Vite upgrade.

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
| Schema | Clean, old, and current databases reach the expected `_schema_version`; local and cloud schemas match before sync |
| Import | IDs, recipe ordering, optional fields, and JSON values are preserved |
| Local persistence | Data remains after reload and browser restart |
| Local feature parity | Every screen reads and writes correctly before cloud sync is enabled |
| Offline use | Existing data can be read and edited while the network is disabled |
| Reconnect | Pending local changes push successfully after reconnecting |
| Pull | A second profile receives cloud changes; a changed pull refreshes active screens and an empty pull does not |
| Last-push-wins | The recorded two-profile conflict matches the accepted single-user behaviour |
| Access | Anonymous SPA/configuration requests are rejected and the Worker validates an allowed Access JWT |
| Browser token | No token is embedded in public assets; its visibility to the authenticated owner is documented |
| One-tab behaviour | The app handles or clearly explains a second active tab |
| Worker | Scraping and AI parsing work with the Gemini key stored as a Worker secret |
| Migration | All current journeys work with InstantDB removed and no dual-write period |
| Recovery | The archived export and a Turso backup can each be restored into a disposable database |

## Practical considerations

| Topic | Planned handling |
|---|---|
| Migration mechanism | App-owned ordered SQL plus `_schema_version`; do not assume a sync-wasm migration API |
| Local UI updates | Direct feature update or re-query during local-only conversion |
| Remote UI updates | Add a shared refresh helper only with cloud pull |
| Browser token | Deliver after Access authentication and Worker JWT validation; do not embed it in Vite assets; acknowledge owner visibility |
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
3. Does approval include Cloudflare Access as the owner-access mechanism?
4. Should the Gemini key become one server-owned Worker secret?
5. How long should the archived InstantDB export be retained?

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

### Turso and libSQL

- [sync-wasm package source](https://github.com/tursodatabase/turso/tree/main/bindings/javascript/sync/packages/wasm)
- [sync-wasm Vite example](https://github.com/tursodatabase/turso/tree/main/examples/javascript/sync-wasm-vite)
- [Sync usage](https://docs.turso.tech/sync/usage)
- [Sync conflict resolution](https://docs.turso.tech/sync/conflict-resolution)
- [Turso Cloud limitations](https://docs.turso.tech/cloud/limitations)
- [Turso Drizzle guide](https://docs.turso.tech/sdk/ts/orm/drizzle)
- [Multi-DB Schemas](https://docs.turso.tech/features/multi-db-schemas)
- [Embedded Replicas](https://docs.turso.tech/features/embedded-replicas/introduction)
- [Migrate to Turso](https://docs.turso.tech/cloud/migrate-to-turso)
- [SDK authorisation](https://docs.turso.tech/sdk/authorization)

### Cloudflare Access

- [Self-hosted Access applications](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/)
- [Access policies](https://developers.cloudflare.com/cloudflare-one/access-controls/policies/)
- [Validate Access tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/validating-json/)

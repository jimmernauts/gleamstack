# Gleamstack backend architecture redesign

**Review draft — no implementation tasks should be created until this plan is approved.**

## Executive recommendation

Proceed with **Turso Cloud plus a browser-local Turso database running in WASM** as a conditional replacement for InstantDB. It is a credible fit for Gleamstack’s current small, mostly single-user data model, but it is not a drop-in backend replacement.

The recommended target is:

- `@tursodatabase/sync-wasm` in the Vite app, with a file-backed database persisted in browser OPFS.
- Local SQL reads and writes as the application’s normal data path.
- Explicit `push()` and `pull()` orchestration to exchange changes with Turso Cloud.
- A small application-owned reactive query layer to replace InstantDB subscriptions.
- The existing Cloudflare Worker retained for scraping and AI parsing, secret handling, and—if required—authenticated delivery of short-lived database credentials.
- Versioned SQL migrations, independent backups, explicit conflict rules, and visible sync status.

Approval should initially authorise only two actions: **preserve the InstantDB data immediately** and **run a production-shaped Turso feasibility spike**. The full migration should proceed only if the spike passes its security, durability, browser, deployment, and conflict checkpoints.

## Why this is plausible for Gleamstack

The current InstantDB surface is relatively contained:

- Five entity groups: recipes, tag options, plan days, settings, and shopping lists.
- No InstantDB links, rooms, or presence features.
- The checked-in InstantDB permission rules are empty.
- One browser adapter owns most query, transaction, and subscription calls.
- The UI uses subscriptions for recipe summaries/details, plan ranges, and shopping-list summaries/details.
- The worker reads tag options and a Gemini API key through the InstantDB Admin SDK; maintenance scripts also use the Admin SDK.
- The app and API are already deployed together through a Cloudflare Worker.

This makes the storage model straightforward to translate to SQLite. The hard parts are not the tables: they are credentials, reactive UI behaviour, sync lifecycle, conflict handling, schema rollout, and safe cutover.

## What the Turso documentation establishes

The proposed technology behaves as a local-first database rather than an InstantDB-compatible service:

- The browser package is `@tursodatabase/sync-wasm`; Vite uses its `/vite` export.
- A named database path persists in browser OPFS. `:memory:` does not persist.
- Reads and writes are local by default.
- The app explicitly calls `db.push()` to upload local changes and `db.pull()` to receive cloud changes.
- Offline use is possible after the database has been bootstrapped. The first normal bootstrap requires cloud access.
- A pull can report that local state changed; the application must then rerun affected queries and notify the UI.
- Concurrent sync is last-push-wins, not CRDT or field-level merging. Pulling with pending local work replays that work after applying remote changes.
- Browser operation relies on WASM, a worker, OPFS, and `SharedArrayBuffer`.
- Production responses need cross-origin isolation headers, including COOP `same-origin` and COEP `require-corp`; the Turso endpoint must also work with browser CORS requirements.
- The same local database cannot currently be used safely by multiple tabs.
- A Turso credential embedded as a Vite environment variable is still public client-side code. It is not application authentication or row-level authorisation.
- Turso sync replaces storage and replication, not InstantDB auth, permissions, subscriptions, server functions, presence, or application-level conflict resolution.

The official offline-sync announcement carried public-beta durability warnings. The exact package release selected for Gleamstack must therefore be checked for current production guarantees; cloud sync must not be treated as the only backup.

## Proposed target architecture

```text
┌──────────────────────────────── Gleamstack browser ────────────────────────────────┐
│ Gleam/Lustre UI                                                                    │
│        │                                                                            │
│ Application repository API                                                         │
│        │                         ┌─ local change notifications ─► reactive queries  │
│ Turso WASM database in worker ───┤                                                  │
│        │                         └─ sync state ─► status / retry UI                 │
│ Browser OPFS                                                                         │
└────────┬─────────────────────────────────────────────────────────────────────────────┘
         │ explicit push / pull over authenticated connection
         ▼
┌──────────────────────────── Turso Cloud database ───────────────────────────────────┐
│ Shared replica and recovery source; versioned schema; scheduled independent backup │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────── Cloudflare Worker ──────────────────────────────────────┐
│ Existing scrape / AI endpoints                                                      │
│ Gemini key in Worker secret, not synced browser data                                │
│ Optional authenticated short-lived Turso credential issuance                       │
│ Privileged operational access only where required                                  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Responsibility boundaries

| Concern | Proposed owner |
|---|---|
| Interactive reads and writes | Browser-local Turso database |
| Cross-device replication | Explicit browser `push()` / `pull()` coordinator and Turso Cloud |
| UI reactivity | Application-owned query subscriptions rerun after local commits and successful pulls |
| Schema evolution | Checked-in, versioned SQL migrations |
| User identity and database access | Explicit authentication and credential design; not Turso sync alone |
| Gemini credential | Cloudflare Worker secret or another server-side secret store |
| Scraping and AI parsing | Existing Cloudflare Worker |
| Imports, cleanup, and backfills | Server-side Turso client/CLI with privileged credentials |
| Disaster recovery | Turso Cloud plus scheduled independent logical backups and tested restore |

## Key design decisions to approve

### 1. Keep the local database behind an application repository boundary

Replace `app/src/db.ts` with a stable repository interface rather than exposing Turso throughout the Gleam UI. Initially preserve the existing FFI-facing operations so recipes, plans, and shopping lists can move one vertical slice at a time.

This limits rewrite scope and provides one place for SQL, validation, migrations, notifications, and sync status.

### 2. Rebuild reactivity deliberately

InstantDB subscriptions currently drive several screens. Turso sync does not provide equivalent live queries.

The repository should maintain a small subscription registry:

1. A local transaction commits.
2. Relevant local queries rerun immediately and notify the UI.
3. The sync coordinator schedules a push.
4. A long-poll or periodic pull receives remote work.
5. If `pull()` reports a change, relevant queries rerun and notify the UI.

The UI should expose `local`, `syncing`, `synced`, `offline`, and `sync failed` states. A local save must not be presented as cloud-synced until push succeeds.

### 3. Do not ship a long-lived full-access Turso token in the Vite bundle

Any `VITE_TURSO_AUTH_TOKEN` is extractable by a browser user. Turso database credentials also do not recreate InstantDB row-level permissions.

For the current single-owner app, the preferred direction is a private database plus authenticated, short-lived, revocable access delivered at runtime. The feasibility spike must prove that model end to end. If secure direct-browser credentials cannot be made acceptable, direct whole-database sync is a no-go and the fallback is a Worker-mediated API or a database-per-user design.

A future multi-user application must not sync one shared database to every browser. Turso sync distributes the database boundary, not a permission-filtered row subset.

### 4. Remove the Gemini key from synced application data

The current `settings` entity stores an API key which the worker retrieves with InstantDB Admin access. That key should not be copied into a browser-synced Turso database.

Preferred outcome:

- Store the Gemini key as a Cloudflare Worker secret.
- Remove or redefine the current settings screen.
- Pass non-secret tag options with parse requests, or read them through a narrowly scoped server-side Turso connection.

If each future user must provide their own key, design authenticated server-side per-user secret storage separately; it is not part of the synced SQLite schema.

### 5. Use a conservative first SQL schema

The first schema should mirror current behaviour rather than normalising everything at once.

| Table | Important shape and constraints |
|---|---|
| `recipes` | Stable UUID, unique slug, explicit `created_at` and `updated_at`; existing ingredient, method, and tag payloads retained as validated JSON text initially |
| `tag_options` | Stable ID, unique name, options as validated JSON text initially |
| `plan_days` | Stable ID, unique date, lunch and dinner values |
| `shopping_lists` | Stable ID, unique date, status, item/link payloads, plan bounds |
| `schema_migrations` | Applied migration ID, checksum, and timestamp |

The current InstantDB `serverCreatedAt` recipe ordering must become an explicit column. Unique date constraints should replace query-then-insert assumptions for plans and shopping lists.

### 6. Make conflicts explicit

Turso sync is last-push-wins. That may be acceptable for a single person using a small number of devices, but it can silently discard concurrent edits.

Before release, define conflict expectations per entity:

- Recipes: warn or reject when editing a stale version if concurrent edits matter.
- Plan days: decide whether a whole-day last-write-wins rule is acceptable.
- Shopping lists: test simultaneous checking/editing carefully; this is the highest-risk collaborative shape.
- Tag options: treat as infrequent administrative data.

At minimum, store `updated_at` and an application revision, log overwrite conditions where detectable, and document that this is not merge-based collaboration.

### 7. Avoid a prolonged dual-write period

Writing to InstantDB and Turso simultaneously would introduce two replication systems with different conflict and failure semantics. Prefer:

- Repeatable exports and imports during rehearsal.
- Read-only comparison against Turso before cutover.
- A short maintenance window for the final delta.
- A backend feature flag for rollback, while InstantDB remains available and read-only.

## Sequenced migration plan

| Order | Milestone | Scope | Approval checkpoint |
|---:|---|---|---|
| 0 | Preserve InstantDB now | Export every entity and system field; record counts and hashes; verify a restore copy | **Gate A:** complete, restorable, independently stored snapshot before relying on further InstantDB availability |
| 1 | Production-shaped Turso spike | Prove WASM/OPFS, Cloudflare deployment headers, CORS, bootstrap, local persistence, offline writes, reconnect, push/pull, token delivery, two-device conflicts, multi-tab behaviour, and browser support | **Gate B — go/no-go:** security and reliability are acceptable on the exact package version and deployment path |
| 2 | Architecture contract | Decide single-user versus multi-user horizon, database boundary, identity, credential issuance, conflict rules, supported browsers, backup policy, and fallback architecture | **Gate C:** short decision record approved; no unresolved security or tenancy assumption |
| 3 | Schema and migration foundation | Define SQL schema, constraints, migration runner, schema versioning, fixtures, and Instant-to-SQL mapping | **Gate D:** clean install and upgrade tests pass; exported fixture imports without loss |
| 4 | Local database and sync foundation | Add repository boundary, database lifecycle, reactive query mechanism, sync coordinator, retry/backoff, status UI, and required deployment headers | **Gate E:** one representative recipe slice works across reload, offline edit, reconnect, and second-device pull |
| 5 | Application feature migration | Move recipes, tag options, planner, and shopping lists behind the repository; remove the synced Gemini setting; retain parity tests | **Gate F:** all user journeys pass with InstantDB disabled in a test build |
| 6 | Worker and operational migration | Remove InstantDB Admin SDK from runtime; move secrets; port import, duplicate-cleanup, and tag-backfill tools to privileged Turso access | **Gate G:** runtime, tests, CI, and operational tools have no InstantDB dependency |
| 7 | Migration rehearsal and resilience | Run full import rehearsals; validate counts, hashes, IDs, JSON, ordering, and constraints; test outage, token expiry, pending-write upgrade, storage clearing, conflict, and backup restore scenarios | **Gate H:** release checklist, rollback procedure, and restore drill all pass |
| 8 | Cutover and decommission | Freeze writes briefly, take final export/delta, import, validate, release Turso build, monitor, retain read-only rollback window, then remove InstantDB credentials and code | **Gate I:** stable observation window completed and final backup restore confirmed |

## Milestone detail

### Milestone 0 — preserve and baseline

This is urgent and independent of the architecture choice.

Deliverables:

- Raw export of recipes, tag options, plan days, settings, and shopping lists.
- Instant IDs and available system metadata, including creation ordering.
- Per-entity counts and deterministic content hashes.
- A data-quality report for duplicate slugs/dates, null/optional fields, and JSON represented as strings versus objects.
- At least two protected copies outside the InstantDB service.
- A restore test into a disposable SQLite database.

Do not place the Gemini key in general migration fixtures or source control.

### Milestone 1 — feasibility spike

The spike should run inside the actual Gleamstack Vite and Cloudflare deployment shape, not only a standalone demo.

It must demonstrate:

- A named OPFS database surviving reload and browser restart.
- First bootstrap and recovery after local storage deletion.
- Local reads and writes with the network disabled after bootstrap.
- Failed push retained and successfully retried after reconnect.
- Long-poll or scheduled pull updating another browser instance.
- The last-push-wins result of deliberately conflicting edits.
- Correct behaviour when a token expires or is revoked.
- Required COOP/COEP headers on development and production responses.
- Turso endpoint CORS compatibility under those headers.
- A deliberate one-tab policy or a proven tab-coordination design.
- Supported behaviour in the browsers and devices that matter for Gleamstack.
- Bundle-size, startup-time, and database bootstrap measurements using representative data.

The checked example uses a newer Vite major than Gleamstack’s current Vite 6 dependency, so compatibility must be demonstrated or an upgrade included in later scope.

### Milestones 2–4 — contract, schema, and foundation

These milestones turn the spike into a maintainable application subsystem:

- Record the security and tenancy decision before schema or UI work proliferates.
- Pin package versions and document supported platform features.
- Keep migrations forward-only and versioned.
- Coordinate cloud schema rollout before clients depend on it.
- Avoid destructive DDL while offline clients may still hold pending writes.
- Initialise the database before screens issue queries, with explicit bootstrap/error UI.
- Push promptly after local commits, coalesce bursts, retry with bounded backoff, and also retry on `online` and visibility events.
- Pull continuously or periodically, then rerun subscriptions only when state changes.
- Expose sync statistics and enough diagnostic information to support recovery without logging secrets.
- Schedule independent logical backups and test restoration.

### Milestones 5–6 — feature and backend migration

Recommended feature order:

1. Recipe list, detail, save, and delete.
2. Tag options.
3. Planner range queries and saves.
4. Shopping-list summaries, detail, save, and delete.
5. Settings redesign and worker secret migration.
6. Maintenance and import scripts.

Recipes provide the broadest vertical slice. Planner and shopping lists then exercise uniqueness, range queries, and the most important conflict cases.

### Milestones 7–8 — rehearsal and cutover

Run the complete migration at least twice against a non-production Turso database. The migration must be idempotent, preserve stable IDs where practical, and fail loudly on count or checksum differences.

For cutover:

1. Confirm the latest independent InstantDB snapshot.
2. Enable a short write freeze.
3. Export the final delta or full snapshot.
4. Import into the production Turso database.
5. Run automated count/hash checks and manual feature samples.
6. Release the Turso-backed build.
7. Monitor bootstrap failures, push/pull errors, pending operations, and worker errors.
8. Keep InstantDB read-only for the agreed rollback window, subject to its shutdown date.
9. Remove InstantDB packages, app IDs, admin tokens, CI secrets, scripts, schemas, permissions, and documentation.
10. Rotate all credentials and verify a Turso backup restore before declaring completion.

## Release gates

The migration should stop rather than advance if any gate fails.

| Gate | Evidence required |
|---|---|
| Data preservation | Restorable export, counts/hashes, protected copies |
| Technology fit | Actual deployed spike passes persistence, offline, sync, CORS/headers, browser, and performance checks |
| Security | No long-lived privileged token in built assets; approved identity, tenancy, and credential lifecycle |
| Data integrity | Repeatable migration with no unexplained count/hash differences |
| Behavioural parity | Existing core journeys work with InstantDB unavailable |
| Conflict acceptance | Documented and tested outcomes for two-device recipe, plan, and shopping-list edits |
| Operations | Visible sync failures, retry path, backup schedule, restore drill, and rollback runbook |
| Decommission | Stable observation period and no remaining runtime or CI dependency on InstantDB |

## Principal risks

| Risk | Likelihood | Impact | Mitigation / decision |
|---|---|---:|---|
| Long-lived browser token exposes the whole database | High if copied from the example | Critical | Runtime short-lived credentials after authentication; private or per-user database boundary; no privileged `VITE_` token |
| Sync maturity or durability falls short of production needs | Medium until exact release is validated | Critical | Gate on a production-shaped spike; pin version; retain independent backups; preserve fallback architecture |
| Last-push-wins loses concurrent edits | Medium across multiple devices | High | Entity-specific conflict policy, revisions/timestamps, conflict tests, user feedback where needed |
| InstantDB disappears before migration completes | Medium/unknown | Critical | Complete milestone 0 immediately; retain raw and restorable exports |
| Instant-style subscriptions are incompletely reproduced | Medium | High | Central reactive repository; parity tests for every current subscription path |
| Multi-tab OPFS limitation surprises users | Medium | Medium–high | Explicit one-tab UX for first release or leader-tab coordination proven in spike |
| COOP/COEP or CORS breaks production assets/network calls | Medium | High | Test actual Cloudflare deployment and all cross-origin resources during spike |
| Schema change meets a long-offline client with pending work | Medium | High | Forward-compatible staged migrations, minimum supported client version, non-destructive rollout, recovery test |
| Cloud is mistaken for a backup | Medium | High | Independent scheduled export and verified restore procedure |
| Gemini key remains in synced data | High unless deliberately changed | High | Move to Worker secret or separate authenticated secret service; exclude from export fixtures |
| Whole-database sync blocks a future multi-user model | Medium | High | Decide horizon now; use database-per-user or Worker-mediated access before adding users |

## Open questions for review

1. Is Gleamstack expected to remain a private, single-owner application, or should this architecture support multiple users soon?
2. Which identity mechanism should protect database credential delivery: existing Cloudflare controls, a new application login, or another provider?
3. Is one active browser tab acceptable for the first Turso release?
4. Which browsers and devices are required, especially iOS/Safari and installed PWA use?
5. How often do edits occur from more than one device, and is last-push-wins acceptable for plans and shopping lists?
6. Should the Gemini key become one server-owned Worker secret, or must users continue to supply individual keys?
7. What is the confirmed InstantDB shutdown and read-only timeline?
8. What durability and support status does the exact Turso sync release provide today, beyond the earlier public-beta announcement?
9. What rollback observation window is possible before InstantDB becomes unavailable?
10. What recovery point objective is acceptable for independent backups?

## Explicitly out of scope for this review draft

- Detailed task breakdowns or estimates.
- Final SQL statements and indexes.
- Selection or implementation of an authentication provider.
- UI visual design beyond required sync/error states.
- Data-model normalisation unrelated to the migration.
- New collaborative or multi-user features.
- Application code, infrastructure changes, or credential creation.

## Proposed approval outcome

Choose one:

- **Approve for preservation and spike:** authorise milestones 0 and 1 only; review their evidence before creating full migration tasks.
- **Approve with revisions:** annotate this document with required changes, then regenerate it for approval.
- **Reject Turso direct sync:** retain the InstantDB export work and evaluate a Worker-mediated or alternative local-first backend.

After approval, create implementation tasks only for the authorised milestone. Do not pre-create the entire backlog.

## Primary references

- [Turso Sync usage](https://docs.turso.tech/sync/usage)
- [Turso JavaScript database WASM Vite example](https://github.com/tursodatabase/turso/tree/main/examples/javascript/database-wasm-vite)
- [Turso sync conflict resolution](https://docs.turso.tech/sync/conflict-resolution)
- [Turso SDK authorisation](https://docs.turso.tech/sdk/authorization)
- [Turso in the browser](https://turso.tech/blog/introducing-turso-in-the-browser)
- [Turso offline sync public-beta announcement](https://turso.tech/blog/turso-offline-sync-public-beta)

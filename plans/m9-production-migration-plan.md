# M9: Production Migration Plan

Move production Mealstack from the retired InstantDB backend onto Turso Cloud
(new tursodb engine), deploy the Turso-backed build, and retire InstantDB for good.

Decisions (agreed 2026-08-28):

- **Region:** `eu-west-1`, same as dev.
- **Export freshness:** verify against production InstantDB directly; reuse the
  Aug 24 export if production is confirmed unchanged.
- **InstantDB:** not needed any more — credentials removed and apps deleted the
  same day, no read-only safety window. Recovery artifacts are the archived
  export plus the first Turso backup.

Everything below runs from the sandbox except the two user steps marked **[user]**.

## What M8 + the dev rehearsal already proved

- Schema applies cleanly over `/v3/pipeline` (no turso CLI needed) — done twice now.
- `worker/scripts/import_to_turso.mjs` imports the export into a new-engine cloud DB:
  267/267 records, full-field spot check passes, plan date set identical, idempotent re-run.
- The worker runs on `@tursodatabase/serverless` and reads the imported data (t-8108).
- Unit tests pass; `wrangler deploy --dry-run` produces a clean InstantDB-free bundle (M8).

## Preconditions

| # | What | Who |
|---|---|---|
| P1 | Production Turso DB created: `turso db create <prod-name> --tursodb` in `eu-west-1` (CLI or dashboard — no turso CLI in the sandbox) | **[user]** |
| P2a | Long-lived prod DB token set **directly as Worker secrets** (`TURSO_URL`, `TURSO_AUTH_TOKEN`) via wrangler/dashboard — write-only, never transits the sandbox | **[user]** |
| P2b | Short-lived migration token for Phase 2 + Phase 4 backup (`turso db tokens create <prod-db> --expiration 2d`) + the DB URL (URL is not secret — the app receives it from `/api/db-config`) | **[user]** |
| P3 | Production InstantDB admin token for app `eeaf3b82-5b5d-40c4-a29a-b68988377c3c` (for the unused-check; it was removed from `.dev.vars`) | **[user]** |
| P4 | `CLOUDFLARE_API_TOKEN` usable by wrangler | present in sandbox ✓ |
| P5 | `GEMINI_API_KEY` value for the Worker secret | **[user]** (or confirm already set: `wrangler secret list`) |

## Phase 1 — Confirm production unused (task step s-7982)

The export manifest records 268 rows exported 2026-08-24T14:45Z. Production writes
were paused in M0.

1. Query production InstantDB with the admin SDK (archived script's auth path):
   count per collection + max `updated_at`/`created_at` per collection.
2. Compare against `plans/archive/export/manifest.json` and the per-file record counts
   (recipes 65, tag_options 3, plan 196, settings 1, shopping_lists 3).
3. **Gate:** counts equal and no timestamp newer than the export time → Aug 24 export
   stands. Any drift → run `worker/scripts/archived/export_instantdb.ts` for a fresh
   export into a new dated directory, re-verify with `verify_export_sqlite.ts`, and use
   that export in Phase 2.

## Phase 2 — Migrate and import production Turso (s-7983)

1. Apply schema: POST `db/migrations/001_initial_schema.sql` statement-by-statement to
   `<prod-url>/v3/pipeline` (same procedure as dev, or `scripts/apply-migration-to-turso.mjs`).
2. Import: `TURSO_URL=<prod> TURSO_AUTH_TOKEN=<prod> bun worker/scripts/import_to_turso.mjs`.
3. Verify (same evidence as the rehearsal):
   - live counts ≥ export counts per table (script enforces),
   - full-field spot check of a sample recipe,
   - plan_days date set identical to export,
   - re-run import → counts unchanged (idempotency).
4. **Gate:** all four checks pass. Failure → fix and re-run; nothing here is destructive
   (INSERT OR REPLACE against a DB only we can see).

## Phase 3 — Deploy and smoke-check (s-7984)

1. Confirm Worker secrets exist by name: `wrangler secret list` must show `TURSO_URL`,
   `TURSO_AUTH_TOKEN`, `GEMINI_API_KEY` (user sets the Turso pair directly, P2a; values are
   write-only so presence + working smoke checks are the verification).
2. Build fresh assets: `cd app && rm -rf dist && npx vite build`.
3. `npx wrangler deploy` (worker name `mealstack`).
4. Smoke checks against the deployed URL, per `.agent/workflows/e2e-verification.md`:
   - `/api/db-config` returns url + token,
   - recipe list renders the 65 migrated recipes,
   - SPA fallback works,
   - save → reload → close/reopen persists (round-trip through prod Turso),
   - planner + shopping list screens read migrated rows,
   - direct pipeline query confirms writes landed.
5. **Gate:** all smoke checks pass. Failure → the previous InstantDB-era deployment is
   untouched by anything above; fix and redeploy.

## Phase 4 — Recovery artifacts and InstantDB retirement (s-7985)

Only after Phase 3 passes:

> Amended 2026-08-30: the originally planned "first Turso backup" and repo tag are
> dropped. Turso Cloud does continuous point-in-time recovery automatically (restore
> window depends on plan tier), and the committed `plans/archive/export/` covers
> provider-independent recovery up to cutover. A tag protects nothing the export and
> git history don't already cover.

1. Archive: confirm `plans/archive/export/` is complete and committed.
2. Retire InstantDB **[user]** (dashboard actions):
   - delete/rotate the admin tokens for prod (`eeaf3b82-…`) and dev (`4304e120-…`) apps,
   - delete both apps.
3. Scrub: verify no `INSTANT_*` values remain in `.dev.vars`, CI, or Worker secrets
   (`wrangler secret list`).
4. Close out: mark t-7980 done with evidence links; update `AGENTS.md`/onboarding doc
   if any InstantDB mention survives.

## Rollback posture

- Phases 1–2 touch only the new, empty prod Turso DB — abort at any point costs nothing.
- Phase 3 replaces the deployed Worker; the InstantDB-era build is redeployable from git
  until Phase 4 deletes the InstantDB apps.
- Phase 4 step 2 is the **only irreversible action** and is gated on: smoke checks
  passed and the archived export committed.

## Task-step mapping

| Task step | Covered by |
|---|---|
| s-7981 produce detailed implementation plan | this document |
| s-7982 fresh export / confirm unused | Phase 1 |
| s-7983 migrate and import production | Phase 2 |
| s-7984 deploy and smoke checks | Phase 3 |
| s-7985 archive, backup, rotate credentials | Phase 4 |

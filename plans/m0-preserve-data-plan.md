# M0: Preserve data and pause production use — Implementation plan

## Goal

Export all production InstantDB data, verify the export independently, and confirm nothing will change after the final export. This creates the recovery artifact referenced throughout the architecture redesign.

## Entity groups to export

| # | Collection | Key fields | Notes |
|---|---|---|---|
| 1 | `recipes` | id, slug, title, cook_time, prep_time, serves, author, source, ingredients, method_steps, tags, shortlisted | JSON text in ingredients/method_steps/tags |
| 2 | `tag_options` | id, name, options | options is JSON array |
| 3 | `plan` | id, date, lunch, dinner, planned_meals | date is numeric timestamp |
| 4 | `settings` | id, api_key | **Gemini key — exclude from fixtures** |
| 5 | `shopping_lists` | id, date, status, items, linked_recipes, linked_plan_start, linked_plan_end | items/linked_recipes are JSON |

## Implementation steps

### Step 1: Write the export script

**File:** `worker/scripts/export_instantdb.ts`

**Approach:**
- Use `@instantdb/admin` (already a worker dependency) with `INSTANT_APP_ID` and `INSTANT_ADMIN_TOKEN` from environment.
- Query each of the five collections with `db.query({ collection: {} })`.
- For each record, retain the InstantDB `id` and capture `serverCreatedAt` if available from the record metadata (the admin SDK returns `__metadata` on query results or we use the raw response).
- Write each collection to a separate JSON file under `plans/archive/export/`:
  - `recipes.json`
  - `tag_options.json`
  - `plan.json`
  - `settings.json` (kept separate, marked sensitive)
  - `shopping_lists.json`
- For settings: export separately and explicitly note the Gemini key exclusion in the manifest. The settings file will be gitignored; only its hash appears in the validation report.

**Output format per file:**
```json
{
  "exported_at": "2026-08-24T...",
  "collection": "recipes",
  "count": 42,
  "records": [ { "id": "...", ...fields } ]
}
```

### Step 2: Produce the validation manifest

**File produced:** `plans/archive/export/manifest.json`

**Contents:**
- Record count per collection.
- SHA-256 hash of each exported JSON file.
- Total record count across all collections.
- Explicit note: `settings.json` contains the Gemini key and is gitignored.

**Verification checks:**
- Every record has a non-empty `id`.
- No duplicate IDs within a collection.
- recipes: every record has a non-empty `slug`.
- plan: every record has a numeric `date`.
- shopping_lists: every record has a numeric `date` and a `status` string.
- tag_options: every record has a `name`.

The script prints a summary table to stdout and writes `manifest.json`.

### Step 3: Restore into disposable SQLite and verify

**File:** `worker/scripts/verify_export_sqlite.ts`

**Approach:**
- Use `better-sqlite3` (add as a dev dependency) to create a temporary SQLite database.
- Create tables matching the architecture doc's initial schema:
  - `recipes(id TEXT PRIMARY KEY, slug TEXT UNIQUE, title TEXT, cook_time INTEGER, prep_time INTEGER, serves INTEGER, author TEXT, source TEXT, ingredients TEXT, method_steps TEXT, tags TEXT, shortlisted INTEGER, created_at TEXT, updated_at TEXT)`
  - `tag_options(id TEXT PRIMARY KEY, name TEXT UNIQUE, options TEXT)`
  - `plan_days(id TEXT PRIMARY KEY, date INTEGER UNIQUE, lunch TEXT, dinner TEXT)`
  - `shopping_lists(id TEXT PRIMARY KEY, date INTEGER UNIQUE, status TEXT, items TEXT, linked_recipes TEXT, linked_plan_start INTEGER, linked_plan_end INTEGER)`
  - Settings excluded from the SQLite test restore (Gemini key).
- Insert all records from the export JSON files.
- Verify:
  - Row counts match manifest.
  - All UNIQUE constraints pass (no duplicate slugs/dates/names).
  - A sample recipe round-trips its JSON fields correctly.
- Delete the temporary database file.
- Print PASS/FAIL summary.

### Step 4: Confirm production will not change

After the final export:
1. Record the export timestamp in the manifest.
2. Note in the plan that the production app will not be used going forward (per architecture doc assumption).
3. The export script can be re-run later to produce a fresh export if needed — the manifest hash comparison will detect any drift.

There is no automated mechanism to "pause" InstantDB (no write-disable feature). The confirmation is procedural: the owner agrees not to use the app after the final export, and a re-export before migration (M9) will confirm no changes occurred by comparing hashes.

## File layout

```
plans/archive/export/
  recipes.json
  tag_options.json
  plan.json
  settings.json          ← gitignored (contains Gemini key)
  shopping_lists.json
  manifest.json          ← committed (hashes, counts, no secrets)
worker/scripts/
  export_instantdb.ts    ← the export script
  verify_export_sqlite.ts ← the SQLite verification script
```

## .gitignore additions

```
plans/archive/export/settings.json
```

## Prerequisites

- `INSTANT_APP_ID` set to `eeaf3b82-5b5d-40c4-a29a-b68988377c3c`
- `INSTANT_ADMIN_TOKEN` set to a valid admin token (already used by existing scripts)
- Network access to InstantDB API

## Dependencies

- `@instantdb/admin` — already in `worker/package.json`
- `better-sqlite3` — add as dev dependency for verification only
- `crypto` (Node built-in) — for SHA-256 hashing

## Acceptance criteria (matches task steps)

1. ✅ Export script runs and produces JSON for all five entity groups with IDs and timestamps.
2. ✅ Manifest shows record counts and SHA-256 hashes; settings file is excluded from commit.
3. ✅ SQLite restore inserts all records without constraint violations; counts match.
4. ✅ Owner confirms production will not change; a re-export before migration can verify via hash comparison.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Admin token expired or revoked | Test with a simple query before full export |
| InstantDB `serverCreatedAt` not accessible via admin SDK | Fall back to export without timestamps; document the gap |
| Large JSON fields exceed reasonable file size | Unlikely given single-user app; monitor file sizes |
| Settings file accidentally committed | Gitignore rule + manifest clearly labels it sensitive |

## Estimated scope

Small. The export script is ~100 lines, the verification script ~80 lines. The main dependency (`@instantdb/admin`) is already available. The work is self-contained and produces artifacts needed by every subsequent milestone.

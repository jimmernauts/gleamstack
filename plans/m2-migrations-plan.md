# M2: Establish migrations and repository foundations — Implementation plan

## Goal

Set up the database layer that all later milestones build on: migration files, the schema-version startup check, SQL query helpers behind `app/src/db.ts`, and a tested importer for the InstantDB export.

## M1 findings that inform this plan

| Finding | Impact on M2 |
|---|---|
| API is `prepare().all()` / `.run()` / `.get()` and `exec()` — no `execute()` | Repository helpers wrap `prepare()` directly |
| `pull()` returns `boolean` (true = changes arrived) | Used in bootstrap to confirm fresh data loaded |
| OPFS reset = `close()` then `removeEntry()` on the OPFS directory | Schema-mismatch check uses this exact sequence |
| One-tab exclusive lock | Startup must handle connect failure gracefully |
| Pinned at `@tursodatabase/sync-wasm@0.7.2` | Already in package.json from M1 |
| `_headers` COOP/COEP in `app/public/` | Already in place from M1 |
| No settings table needed | Gemini key lives as Worker secret; skip `settings` entity |

**No structural changes to the M2 task steps are needed.** The plan proceeds as scoped.

## File layout (new paths)

```
db/
  migrations/
    001_initial_schema.sql          -- dbmate format: -- migrate:up / -- migrate:down
  schema.sql                        -- dbmate dump (reference, generated)
app/src/
  turso.ts                          -- connect/bootstrap/schema-check/reset
  db.ts                             -- repository: query and write helpers (replaces InstantDB)
  db.test.ts                        -- unit tests for helpers against better-sqlite3
worker/scripts/
  import_instantdb_export.ts        -- reads plans/archive/export/*.json → SQL inserts
  verify_export_sqlite.ts           -- (exists) validate export into local SQLite
```

## Step-by-step plan

### s-7939: Add dbmate and write initial migration

1. Create `db/migrations/001_initial_schema.sql` using dbmate format:

```sql
-- migrate:up
CREATE TABLE recipes (
  id TEXT PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  cook_time INTEGER,
  prep_time INTEGER,
  serves INTEGER,
  author TEXT,
  source TEXT,
  ingredients TEXT,      -- JSON array
  method_steps TEXT,     -- JSON array
  tags TEXT,             -- JSON array
  shortlisted INTEGER DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE tag_options (
  id TEXT PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  options TEXT           -- JSON array
);

CREATE TABLE plan_days (
  id TEXT PRIMARY KEY,
  date INTEGER UNIQUE NOT NULL,
  lunch TEXT,
  dinner TEXT
);

CREATE TABLE shopping_lists (
  id TEXT PRIMARY KEY,
  date INTEGER UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'Active',
  items TEXT,            -- JSON array
  linked_recipes TEXT,   -- JSON array
  linked_plan_start INTEGER,
  linked_plan_end INTEGER
);

-- migrate:down
DROP TABLE IF EXISTS shopping_lists;
DROP TABLE IF EXISTS plan_days;
DROP TABLE IF EXISTS tag_options;
DROP TABLE IF EXISTS recipes;
```

2. Add a `.dbmaterc` or `DATABASE_URL` convention:
```yaml
# .dbmaterc (project root)
db/migrations
schema-file: db/schema.sql
```
   DATABASE_URL: `sqlite:db/dev.sqlite3` for local authoring (gitignored).

3. Add `db/dev.sqlite3` to `.gitignore`.

4. Test locally: `dbmate up` creates the local SQLite, `dbmate dump` generates `db/schema.sql`.

### s-7940: Apply migration to dev Turso database via turso db shell

This step runs on the host (sandbox cannot reach Turso API). Provide a script:

1. Create `scripts/apply-migration-to-turso.sh`:
   - Reads `db/migrations/001_initial_schema.sql`
   - Extracts the `-- migrate:up` section
   - Pipes it to `turso db shell gleamstack-dev` (or uses `.read`)
   - Also inserts into `schema_migrations`: `INSERT INTO schema_migrations (version) VALUES ('001_initial_schema');`

2. The dev database is `gleamstack-dev` (not the spike one from M1).

### s-7941: Implement startup schema-version check with reset/re-bootstrap

Create `app/src/turso.ts`:

```typescript
// Expected version baked into the build
const EXPECTED_SCHEMA_VERSION = "001_initial_schema";

export async function initDatabase(): Promise<Database> {
  const config = await fetchDbConfig();   // calls /api/db-config
  
  let db = await connect(config);
  
  const version = await getLocalSchemaVersion(db);
  
  if (version !== EXPECTED_SCHEMA_VERSION) {
    // Schema mismatch: discard and re-bootstrap
    await db.close();
    await resetOpfsDatabase(config.path);
    db = await connect(config);
    await db.pull();  // full bootstrap from cloud
    
    // Verify
    const newVersion = await getLocalSchemaVersion(db);
    if (newVersion !== EXPECTED_SCHEMA_VERSION) {
      throw new Error(`Schema bootstrap failed: got ${newVersion}, expected ${EXPECTED_SCHEMA_VERSION}`);
    }
  }
  
  return db;
}

async function getLocalSchemaVersion(db: Database): Promise<string | null> {
  try {
    const stmt = await db.prepare(
      "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1"
    );
    const row = await stmt.get();
    return row?.version ?? null;
  } catch {
    return null;  // table doesn't exist yet
  }
}

async function resetOpfsDatabase(path: string): Promise<void> {
  const root = await navigator.storage.getDirectory();
  // sync-wasm stores files under the path name
  await root.removeEntry(path, { recursive: true });
}
```

Key decisions:
- Version comparison is simple string equality on the latest migration name.
- On mismatch: close → removeEntry → reconnect → pull → verify.
- If verify fails, throw (app shows error state, user must reload).
- One-tab lock failure on `connect()` → show "already open in another tab" message.

### s-7942: Add SQL query and write helpers behind app/src/db.ts

Replace InstantDB calls with SQL equivalents. Keep the same exported function signatures so Gleam FFI doesn't break.

Pattern for each helper:
```typescript
import { getDb } from "./turso";

export async function do_get_recipes() {
  const db = await getDb();
  const stmt = await db.prepare(
    "SELECT * FROM recipes ORDER BY created_at DESC"
  );
  const rows = await stmt.all();
  return rows;
}
```

Key helpers to implement (matching current db.ts exports):
- `do_get_tagoptions()`
- `do_get_recipes()` / `do_get_one_recipe_by_slug(slug)`
- `do_save_recipe(recipe)` / `do_delete_recipe(id)`
- `do_get_plan_days(start, end)` / `do_save_plan_day(day)`
- `do_get_shopping_lists()` / `do_save_shopping_list(list)` / `do_delete_shopping_list(id)`
- Subscription helpers → M3+ (replaced with direct query-after-write)

**Note:** Subscriptions (`do_subscribe_*`) have no direct SQLite equivalent. For M2, stub them or leave them as-is. M3–M5 replaces each subscription as it converts that feature slice.

### s-7943: Add fixtures, migration tests, and InstantDB-export importer

1. **Fixtures**: Create `db/fixtures/` with sample JSON files matching the export format (subset of real data or hand-crafted).

2. **Migration tests** (using `better-sqlite3` in Node/Bun):
   - Apply migration SQL to an in-memory SQLite database
   - Insert fixture data
   - Verify constraints (unique slug, unique date, etc.)
   - Verify `schema_migrations` row exists
   - Run the down migration and confirm tables are gone

3. **Importer** (`worker/scripts/import_instantdb_export.ts`):
   - Reads each `plans/archive/export/*.json`
   - Maps InstantDB records to SQL INSERT OR REPLACE statements
   - Handles JSON serialization for array/object fields
   - Reports counts per table
   - Idempotent (uses INSERT OR REPLACE with stable IDs)
   - Can target local SQLite (for testing) or pipe SQL to stdout for `turso db shell`

4. **Test the importer** against the local dbmate database:
   - Run dbmate up → run importer → query counts → verify.

## Sandbox vs. host boundary

| Action | Where |
|---|---|
| Write migration SQL, helpers, tests, importer | Sandbox |
| `dbmate up` against local SQLite | Sandbox (if dbmate installed) or script |
| `turso db create gleamstack-dev` | Host |
| `turso db shell gleamstack-dev < ...` | Host |
| Run unit tests (better-sqlite3 / bun:sqlite) | Sandbox |
| Deploy | Host |

## Definition of done

- [ ] `db/migrations/001_initial_schema.sql` committed and valid
- [ ] `dbmate up` succeeds against local SQLite (or equivalent test)
- [ ] `scripts/apply-migration-to-turso.sh` ready for host execution
- [ ] `app/src/turso.ts` with `initDatabase()`, schema-version check, and OPFS reset
- [ ] `app/src/db.ts` has SQL-based helpers matching current signatures
- [ ] Migration + fixture tests pass
- [ ] `import_instantdb_export.ts` produces correct SQL from export JSON
- [ ] All new files committed; working tree clean

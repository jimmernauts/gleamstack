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

## Local development approach

Per [Turso's local development docs](https://docs.turso.tech/local-development#local-turso-database):

- Use `@tursodatabase/database` for local dev and testing — in-process, file-based, no server needed, fully SQLite-compatible.
- No dbmate. We keep plain SQL migration files and apply them directly.
- For production: apply the same SQL to Turso Cloud via `turso db shell`.
- For sync testing (M7+): use the local sync server (`tursodb --sync-server`).

## File layout

```
db/
  migrations/
    001_initial_schema.sql          -- plain SQL (up section + schema_migrations insert)
    001_initial_schema.down.sql     -- rollback SQL
app/src/
  turso.ts                          -- connect/bootstrap/schema-check/reset
  db.ts                             -- repository: query and write helpers (replaces InstantDB)
  db.test.ts                        -- tests using @tursodatabase/database
worker/scripts/
  import_instantdb_export.ts        -- reads plans/archive/export/*.json → SQL inserts
  apply_migrations.ts               -- applies migration files to a local or remote database
```

## Step-by-step plan

### s-7939: Write initial migration

1. Create `db/migrations/001_initial_schema.sql`:

```sql
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

CREATE TABLE schema_migrations (
  version TEXT PRIMARY KEY
);

INSERT INTO schema_migrations (version) VALUES ('001_initial_schema');
```

2. Create `db/migrations/001_initial_schema.down.sql`:

```sql
DROP TABLE IF EXISTS schema_migrations;
DROP TABLE IF EXISTS shopping_lists;
DROP TABLE IF EXISTS plan_days;
DROP TABLE IF EXISTS tag_options;
DROP TABLE IF EXISTS recipes;
```

3. Add `db/local.db` to `.gitignore`.

4. Write `scripts/apply_migrations.ts` — a small script that:
   - Opens a local Turso database file (via `@tursodatabase/database`)
   - Reads `schema_migrations` to see what's applied
   - Applies any unapplied `.sql` files in order
   - Works for both local dev and generating SQL for cloud application

### s-7940: Apply migration to dev Turso database via turso db shell

Host-side step (sandbox can't reach Turso API):

1. Create `scripts/apply-migration-to-turso.sh`:
   - Reads `db/migrations/001_initial_schema.sql`
   - Pipes it to `turso db shell gleamstack-dev`

2. The dev database is `gleamstack-dev` (created fresh, not the spike from M1).

### s-7941: Implement startup schema-version check with reset/re-bootstrap

Create `app/src/turso.ts`:

```typescript
import { connect } from "@tursodatabase/sync-wasm";

// Expected version baked into the build
const EXPECTED_SCHEMA_VERSION = "001_initial_schema";

export async function initDatabase() {
  const config = await fetchDbConfig();   // calls /api/db-config
  
  let db = await connect({
    path: config.path,
    url: config.url,
    authToken: config.authToken,
  });
  
  const version = await getLocalSchemaVersion(db);
  
  if (version !== EXPECTED_SCHEMA_VERSION) {
    await db.close();
    await resetOpfsDatabase(config.path);
    db = await connect({
      path: config.path,
      url: config.url,
      authToken: config.authToken,
    });
    await db.pull();  // full bootstrap from cloud
    
    const newVersion = await getLocalSchemaVersion(db);
    if (newVersion !== EXPECTED_SCHEMA_VERSION) {
      throw new Error(`Schema bootstrap failed: got ${newVersion}, expected ${EXPECTED_SCHEMA_VERSION}`);
    }
  }
  
  return db;
}

async function getLocalSchemaVersion(db: any): Promise<string | null> {
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
  await root.removeEntry(path, { recursive: true });
}
```

Key decisions:
- Version comparison: string equality on the latest migration name.
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
  return await stmt.all();
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

1. **Fixtures**: Create `db/fixtures/` with sample JSON matching the export format.

2. **Migration tests** (using `@tursodatabase/database`):
   - Apply migration SQL to a local database
   - Insert fixture data
   - Verify constraints (unique slug, unique date, etc.)
   - Verify `schema_migrations` row exists
   - Apply down migration and confirm tables are gone

3. **Importer** (`worker/scripts/import_instantdb_export.ts`):
   - Reads each `plans/archive/export/*.json`
   - Maps InstantDB records to SQL INSERT OR REPLACE statements
   - Handles JSON serialization for array/object fields
   - Reports counts per table
   - Idempotent (uses INSERT OR REPLACE with stable IDs)
   - Can target local database (for testing) or pipe SQL for `turso db shell`

4. **Test the importer**: apply migrations → run importer → query counts → verify.

## Sandbox vs. host boundary

| Action | Where |
|---|---|
| Write migration SQL, helpers, tests, importer | Sandbox |
| Run `apply_migrations.ts` against local `.db` file | Sandbox |
| `turso db create gleamstack-dev` | Host |
| `turso db shell gleamstack-dev < migration.sql` | Host |
| Run tests (`@tursodatabase/database` in-process) | Sandbox |
| Deploy | Host |

## Definition of done

- [ ] `db/migrations/001_initial_schema.sql` committed and valid
- [ ] Migration applies cleanly to local `@tursodatabase/database`
- [ ] `scripts/apply-migration-to-turso.sh` ready for host execution
- [ ] `app/src/turso.ts` with `initDatabase()`, schema-version check, and OPFS reset
- [ ] `app/src/db.ts` has SQL-based helpers matching current signatures
- [ ] Migration + fixture tests pass
- [ ] `import_instantdb_export.ts` produces correct SQL from export JSON
- [ ] All new files committed; working tree clean

/**
 * Turso database connection, schema-version check, and OPFS reset.
 *
 * This module manages the browser-side OPFS database lifecycle:
 * 1. Fetch cloud config (URL + token) from the Worker
 * 2. Connect to the local OPFS replica
 * 3. Verify the local schema version matches what this build expects
 * 4. On mismatch: discard local, re-bootstrap from cloud
 * 5. Export a singleton for use by repository helpers
 *
 * The browser never runs migration DDL — the cloud owns the schema.
 */

// @ts-ignore - sync-wasm types are incomplete
import { connect as tursoConnect } from "@tursodatabase/sync-wasm";

// Expected schema version — updated when new migrations are applied to cloud
export const EXPECTED_SCHEMA_VERSION = "001_initial_schema";

// OPFS database path (one tab holds this exclusively)
const OPFS_DB_PATH = "gleamstack.db";

// Singleton
let dbInstance: any = null;
let dbReady: Promise<any> | null = null;

export interface DbConfig {
  url: string;
  authToken: string;
}

/**
 * Get the database instance. Initialises on first call.
 * Throws if schema bootstrap fails or if another tab holds the lock.
 */
export function getDb(): Promise<any> {
  if (!dbReady) {
    dbReady = initDatabase();
  }
  return dbReady;
}

/**
 * Initialise the database: connect, check schema version, reset if needed.
 */
async function initDatabase(): Promise<any> {
  const config = await fetchDbConfig();

  let db = await connectToOpfs(config);

  const version = await getLocalSchemaVersion(db);

  if (version !== EXPECTED_SCHEMA_VERSION) {
    console.log(
      `[turso] Schema mismatch: local="${version}", expected="${EXPECTED_SCHEMA_VERSION}". Re-bootstrapping...`
    );
    await db.close();
    await resetOpfsDatabase();
    db = await connectToOpfs(config);
    await db.pull(); // full bootstrap from cloud

    const newVersion = await getLocalSchemaVersion(db);
    if (newVersion !== EXPECTED_SCHEMA_VERSION) {
      throw new Error(
        `[turso] Schema bootstrap failed: got "${newVersion}", expected "${EXPECTED_SCHEMA_VERSION}". ` +
          `Check that the cloud database has been migrated.`
      );
    }
    console.log("[turso] Re-bootstrap complete.");
  }

  dbInstance = db;
  return db;
}

/**
 * Connect to the OPFS database with cloud sync config.
 */
async function connectToOpfs(config: DbConfig): Promise<any> {
  try {
    return await tursoConnect({
      path: OPFS_DB_PATH,
      url: config.url,
      authToken: config.authToken,
    });
  } catch (err: any) {
    // OPFS exclusive lock failure = another tab is using the database
    if (err?.message?.includes("lock") || err?.message?.includes("access")) {
      throw new Error(
        "[turso] Database is already open in another tab. Please close the other tab and reload."
      );
    }
    throw err;
  }
}

/**
 * Read the latest schema version from the local database.
 * Returns null if schema_migrations doesn't exist (fresh/empty DB).
 */
async function getLocalSchemaVersion(db: any): Promise<string | null> {
  try {
    const stmt = await db.prepare(
      "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1"
    );
    const row = await stmt.get();
    return row?.version ?? null;
  } catch {
    return null; // table doesn't exist yet
  }
}

/**
 * Discard the local OPFS database so a fresh bootstrap occurs on next connect.
 */
async function resetOpfsDatabase(): Promise<void> {
  const root = await navigator.storage.getDirectory();
  try {
    await root.removeEntry(OPFS_DB_PATH, { recursive: true });
  } catch (err: any) {
    // Not found is fine — means nothing to remove
    if (err?.name !== "NotFoundError") {
      throw err;
    }
  }
}

/**
 * Fetch the Turso URL and auth token from the Worker.
 * Only accessible after Cloudflare Access admission.
 */
async function fetchDbConfig(): Promise<DbConfig> {
  const res = await fetch("/api/db-config");
  if (!res.ok) {
    throw new Error(`[turso] Failed to fetch database config: ${res.status} ${res.statusText}`);
  }
  const data = await res.json();
  return {
    url: data.url,
    authToken: data.authToken,
  };
}

/**
 * Explicitly push local changes to the cloud.
 * Call after writes that should be synced.
 */
export async function pushToCloud(): Promise<void> {
  const db = await getDb();
  await db.push();
}

/**
 * Pull remote changes from the cloud.
 * Returns true if changes were received.
 */
export async function pullFromCloud(): Promise<boolean> {
  const db = await getDb();
  return await db.pull();
}

/**
 * Close the database connection. Used for cleanup/testing.
 */
export async function closeDb(): Promise<void> {
  if (dbInstance) {
    await dbInstance.close();
    dbInstance = null;
    dbReady = null;
  }
}

/**
 * Override the database singleton for testing.
 * Pass null to reset to normal production behaviour.
 */
export function setDbForTesting(db: any): void {
  if (db) {
    dbInstance = db;
    dbReady = Promise.resolve(db);
  } else {
    dbInstance = null;
    dbReady = null;
  }
}

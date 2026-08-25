/**
 * Thin wrapper around @tursodatabase/sync-wasm for the spike page.
 * Exposes a libsql-style execute() on top of the prepare/run/all API.
 * Built by Vite and served as /spike-assets/turso-client.js
 */

import { connect as tursoConnect } from "@tursodatabase/sync-wasm";

export async function connect({ url, authToken, localPath }) {
  const db = await tursoConnect({
    url,
    authToken,
    path: localPath,
  });

  return {
    /** Pull changes from Turso Cloud */
    pull: () => db.pull(),
    /** Push local changes to Turso Cloud */
    push: () => db.push(),
    /** Close the database */
    close: () => db.close(),

    /**
     * execute(sql) or execute({ sql, args })
     * Returns { rows, columns, rowsAffected }
     */
    async execute(query) {
      const sql = typeof query === 'string' ? query : query.sql;
      const args = typeof query === 'string' ? [] : (query.args || []);

      const stmt = await db.prepare(sql);

      // Determine if this is a read or write statement
      const trimmed = sql.trimStart().toUpperCase();
      const isRead = trimmed.startsWith('SELECT') || trimmed.startsWith('PRAGMA') || trimmed.startsWith('EXPLAIN');

      if (isRead) {
        const rows = await stmt.all(...args);
        return { rows, columns: [], rowsAffected: 0 };
      } else {
        const info = await stmt.run(...args);
        return { rows: [], columns: [], rowsAffected: info.changes };
      }
    },
  };
}

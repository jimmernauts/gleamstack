/**
 * Thin wrapper around @tursodatabase/sync-wasm for the spike page.
 * Built by Vite and served as /spike-assets/turso-client.js
 */

import { connect as tursoConnect } from "@tursodatabase/sync-wasm";

export async function connect({ url, authToken, localPath }) {
  const db = await tursoConnect({
    url,
    authToken,
    localPath,
  });
  return db;
}

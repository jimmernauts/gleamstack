https://jazz.tools/docs/concepts/how-sync-works

Fetched source excerpt:
Jazz uses query subscriptions backed by a local replica. Browser local storage is in OPFS through a dedicated worker, with one tab elected as storage leader. Reads and writes work offline; writes queue row-version updates. Sync is tiered local/edge/global. Concurrent writes to the same field use last-writer-wins, while losing row versions remain in history. Query subscriptions mean the client receives requested rows rather than necessarily a full database.

https://jazz.tools/docs/getting-started/server-setup

Fetched source excerpt:
Jazz provides a hosted sync URL and a self-hosted database server launched with jazz-tools@alpha server, app ID, data directory, and admin secret. The server supports external JWT validation, local-first auth, cookies, edge/upstream mode, and persistent file storage; --in-memory loses data on process exit. Generated unclaimed hosted apps are deleted after 14 days.

https://docs.livestore.dev/reference/syncing/

Fetched source excerpt:
LiveStore is event-sourced: it syncs events through a central backend and materializes them into local SQLite. The backend is the global authority for total event order and must query ordered events by cursor and notify clients or allow polling. Client pending events are rebased after pulling upstream events. The docs explicitly state merge conflict handling and compaction are not implemented yet; encryption is listed as TODO.

https://docs.livestore.dev/misc/state-of-the-project/

Fetched source excerpt:
LiveStore is beta and not ready for all production scenarios. Minor releases may change APIs and persisted client or backend storage formats; there is no specific 1.0 timeline. Reliability, performance, testing, compaction, providers, frameworks, and platforms remain active work.

https://www.evolu.dev/docs/relay

Fetched source excerpt:
Evolu Relay provides sync and backup. Apps can use multiple relays, including self-hosted and cloud relays. The relay is stateless and can run on serverless platforms including Cloudflare Workers. The project recommends a geographically separate secondary relay for resilience. The free relay is for testing; Evolu does not currently offer hosting as its mission.

https://use-fireproof.com/docs/architecture/sync

Fetched source excerpt:
Fireproof uses pluggable gateways for remote synchronization. Fireproof Cloud uses Cloudflare for data hosting and Supabase for metadata. Clients queue ledger updates offline and merge after reconnect. The design uses encrypted, content-addressed immutable files and CRDT-based deterministic merging; custom gateways can target dedicated servers, serverless functions, or other storage.

https://www.npmjs.com/package/cojson

Search result excerpt:
cojson is described as the core protocol implementation of Jazz and is MIT licensed; the result showed version 0.20.19 updated in 2026.

https://github.com/livestorejs/livestore

Search result excerpt:
The GitHub result describes LiveStore as Apache-2.0 licensed and a reactive SQLite/local-first sync engine.

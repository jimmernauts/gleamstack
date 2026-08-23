https://tinybase.org/api/persister-indexed-db/

Fetched source excerpt:
TinyBase has an IndexedDB persister that saves and loads Store data in browser IndexedDB. The docs list many separate persistence and synchronization modules, including browser, SQLite, Durable Object, WebSocket, PartyKit, PowerSync, CR-SQLite WASM, and remote persisters.

https://tinybase.org/api/persister-durable-object-sql-storage/

Fetched source excerpt:
TinyBase can persist Store data to Cloudflare Durable Object SQLite storage. The docs require enabling SQLite storage for the Durable Object with new_sqlite_classes migration configuration and describe Cloudflare's SQLite backend as recommended for new namespaces.

https://automerge.org/docs/reference/library-initialization/

Fetched source excerpt:
Automerge is Rust compiled to WebAssembly. Browser use can combine IndexedDBStorageAdapter with WebSocketClientAdapter; Vite requires WASM and top-level-await plugins, while unbundled use requires explicit WASM initialization.

https://automerge.org/docs/tutorial/network-sync/

Fetched source excerpt:
Automerge Repo treats network peers as pluggable adapters. Its public sync server is for experimentation only and has no reliability/data-safety guarantee; production applications should run their own server. IndexedDB storage lets clients create and modify documents offline, with changes syncing after reconnect.

https://github.com/automerge/automerge-repo/releases

Fetched source excerpt:
The release page shows v2.6.0-alpha.3 in 2026. The alpha release includes fixes for IndexedDB transaction failures, storage shutdown/flush, WebSocket error handling, network readiness, sync state, and bounded fan-out. The repository search result reports MIT licensing.

https://vlcn.io/docs/cr-sqlite/js/wasm

Fetched source excerpt:
Vulcan provides cr-sqlite WASM for browser main thread, WebWorkers, ServiceWorkers, and SharedWorkers. The API exposes SQLite transactions and row update hooks. A database opened without a persistent path is in-memory; browser persistence requires a separate persistence setup.

https://vlcn.io/docs/cr-sqlite/js/first-app

Fetched source excerpt:
The first-app scaffold creates a SPA with a SQLite database, schema, and sync server for multiple devices. This is a technically complete path but involves WASM, schema, sync-server, and browser persistence choices rather than a single integrated hosted backend.

https://github.com/vlcn-io/cr-sqlite

Search result excerpt:
The repository result reports MIT licensing and describes CR-SQLite as a SQLite extension that merges independently written SQLite databases.

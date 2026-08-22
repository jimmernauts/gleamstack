Source URLs:
- https://automerge.org/docs/reference/repositories/storage/
- https://automerge.org/docs/tutorial/network-sync/
- https://docs.yjs.dev/ecosystem/database-provider/y-indexeddb
- https://tinybase.org/guides/synchronization/using-a-synchronizer/
- https://www.evolu.dev/
- https://github.com/garden-co/jazz
- https://github.com/vlcn-io/cr-sqlite
- https://www.github.com/livestorejs/livestore

# Automerge Repo
Automerge Repo has an IndexedDB StorageAdapter and a Node filesystem adapter; without storage it is transient. Storage adapters are designed for concurrent use. Network adapters are peers; a sync server runs Automerge, stores data, and can be self-hosted. The public server is explicitly for prototyping with no reliability/data-safety guarantees. With local IndexedDB, documents can be read/written offline and later converge with remote changes.

# Yjs
The y-indexeddb provider persists Y.Doc updates in browser IndexedDB, loads them on rejoin, reduces transfer, and enables offline editing. Yjs network providers are separate; y-websocket is a simple server distributing awareness and updates, while y-hub and other providers offer alternative backend capabilities. Yjs is a document-level CRDT: application-level record deletion/room lifecycle and tombstone retention still need design; destroying/clearing local persistence is not a replicated delete protocol.

# TinyBase
TinyBase MergeableStore synchronizers include WebSocket, BroadcastChannel, and local synchronizers; custom synchronizers are possible. The WebSocket server can be thin or persist with a Persister, and a Cloudflare Durable Object server implementation exists. The docs warn default WS server implementations do not authenticate/authorize channels; upgrade authentication and per-channel authorization must be added. Server persistence can use a file or database-oriented Persister. BroadcastChannel can bridge UI and service worker stores, but does not provide cloud durability.

# Evolu
Evolu advertises reactive local SQLite, CRDT merging/history, E2E encrypted sync and backup, WebSocket transports, typed SQL, MIT licensing, and a self-hostable Relay server. This is a strong conceptual fit, but the landing page alone does not specify browser storage implementation, Relay protocol, object-storage adapters, or multi-user sharing semantics.

# Search-result status notes
The search also found Jazz (local-first relational database with sync/partial tables), LiveStore (reactive SQLite with built-in sync, Apache-2.0 repository), and vlcn/cr-sqlite (convergent replicated SQLite). Their search snippets establish existence but were not relied on for detailed claims here; each needs deeper package/version and backend/maintenance validation before shortlist selection.

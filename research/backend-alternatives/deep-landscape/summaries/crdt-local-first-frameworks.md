---
cycle: 3
purpose: "Evaluate CRDT/local-first frameworks: Automerge Repo, Yjs, TinyBase mergeable/synchronization stores, Jazz/cojson, LiveStore, Evolu, and maintenance status of vlcn/cr-sqlite; identify where they require a custom relay/backend and their practical fit for flat records and Gleam FFI."
quality: medium
tags: [CRDT, local-first, browser]
sources:
  - url: https://automerge.org/docs/reference/repositories/storage/
    title: "Automerge Repo Storage"
  - url: https://automerge.org/docs/tutorial/network-sync/
    title: "Automerge Network Sync"
  - url: https://docs.yjs.dev/ecosystem/database-provider/y-indexeddb
    title: "Yjs IndexedDB provider"
  - url: https://tinybase.org/guides/synchronization/using-a-synchronizer/
    title: "TinyBase Synchronizers"
  - url: https://www.evolu.dev/
    title: "Evolu"
  - url: https://github.com/garden-co/jazz
    title: "Jazz repository"
  - url: https://github.com/vlcn-io/cr-sqlite
    title: "cr-sqlite repository"
  - url: https://www.github.com/livestorejs/livestore
    title: "LiveStore repository"
---

## Key Claims
- Automerge Repo provides persistent IndexedDB storage, pluggable network adapters, offline edits, and a self-hostable sync-server pattern; its public sync endpoint is explicitly not production-safe (Automerge docs).
- Yjs's IndexedDB provider persists CRDT updates and enables offline editing, but the network provider/server and application-level document lifecycle remain separate concerns (Yjs docs).
- TinyBase offers mergeable stores, WebSocket/BroadcastChannel synchronizers, custom synchronizers, and a Cloudflare Durable Object server; its example WebSocket servers do not authenticate or authorize channels by default (TinyBase docs).
- Evolu advertises local reactive SQLite, CRDT history, E2E-encrypted sync/backup, MIT licensing, and a self-hostable relay (Evolu landing page).
- Search results identify Jazz, LiveStore, and vlcn/cr-sqlite as active-looking local-first/replicated SQLite or relational projects, but the fetched primary material did not establish their exact browser storage, sharing, licensing, or continuity details.

## Technical Detail
Automerge is the most explicit document-CRDT option in this set. `@automerge/automerge-repo-storage-indexeddb` persists documents in the browser and is safe for concurrent Repo use; without an adapter, a Repo is transient. Network adapters are peer connections, and a “sync server” is simply an Automerge process that listens and stores documents. The public server is for experiments only, so production requires running and securing a relay. CRDT convergence reduces bespoke same-record conflict logic, but a Mealstack schema still needs record identity, authorization, snapshot/export policy, and handling of logical deletes/history growth.

Yjs is a lower-level CRDT document/update layer. `y-indexeddb` persists updates locally and loads them on the next session, making offline editing straightforward. `y-websocket` provides a simple server that broadcasts updates and awareness; alternative servers exist. Yjs is a good fit for a single shared document or rich collaborative fields, but using one Y.Doc per recipe/plan means defining room naming, auth, record indexing, garbage collection, and logical deletion. Clearing a local Yjs database is not equivalent to a replicated deletion, so deletes must be represented in the shared data model.

TinyBase is closer to a small structured store: MergeableStore rows/cells can synchronize over a WebSocket, bridge browser tabs/workers through BroadcastChannel, and persist on a server through a Persister. A Durable Object server is documented, but authorization is not automatic; the default server accepts any authorized-upgrade client into valid descendant channels unless the application authenticates upgrades and enforces access. This is promising for a custom Worker architecture, while Automerge/Yjs require more document modeling. Evolu's claimed E2E encryption and self-hosted relay are attractive, but the landing page does not prove its browser persistence and object-storage integration.

## Relevance
For Mealstack's flat records, Automerge Repo or TinyBase can be embedded behind a thin TypeScript adapter and called from Gleam FFI; Yjs is more appropriate for collaborative subdocuments than ordinary CRUD tables. Evolu could be a candidate if its browser/relay details and continuity are verified. These frameworks do not remove the need for a coordinator or relay for cross-device discovery, auth, bootstrap, and durable server-side retention. Multi-user sharing and concurrent editing are not automatically solved at the application authorization/schema layer even when the underlying CRDT converges.

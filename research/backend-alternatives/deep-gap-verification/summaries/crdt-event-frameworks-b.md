---
cycle: 4
purpose: "Assess TinyBase, Automerge Repo, and vlcn/cr-sqlite for a browser CRUD PWA: persistence and transport adapters, E2EE/self-hosting/license, export/backup, current health and stability, and whether each is practical rather than merely technically possible."
quality: medium
tags: [tinybase, automerge, cr-sqlite, browser, wasm, cloudflare]
sources:
  - url: https://tinybase.org/api/persister-indexed-db/
    title: "TinyBase IndexedDB persister"
  - url: https://tinybase.org/api/persister-durable-object-sql-storage/
    title: "TinyBase Durable Object SQLite persister"
  - url: https://automerge.org/docs/reference/library-initialization/
    title: "Automerge library initialization"
  - url: https://automerge.org/docs/tutorial/network-sync/
    title: "Automerge network sync"
  - url: https://github.com/automerge/automerge-repo/releases
    title: "Automerge Repo releases"
  - url: https://vlcn.io/docs/cr-sqlite/js/wasm
    title: "CR-SQLite WASM and browser APIs"
  - url: https://vlcn.io/docs/cr-sqlite/js/first-app
    title: "CR-SQLite first app"
---

## Key Claims
- TinyBase has a browser IndexedDB persister and a broad adapter ecosystem covering SQLite, Durable Object storage, WebSockets, remote storage, PartyKit, PowerSync, CR-SQLite WASM, and other backends ([IndexedDB persister](https://tinybase.org/api/persister-indexed-db/); [persisters](https://tinybase.org/api/persisters/)).
- TinyBase can persist directly to Cloudflare Durable Object SQLite, but the Durable Object class must be configured with `new_sqlite_classes` migration settings ([TinyBase Durable Object SQLite](https://tinybase.org/api/persister-durable-object-sql-storage/)).
- Automerge Repo supports IndexedDB storage, BroadcastChannel and WebSocket network adapters, and self-hosted sync servers. The public sync server is explicitly experimental and has no reliability or data-safety guarantee ([Automerge network sync](https://automerge.org/docs/tutorial/network-sync/)).
- Automerge browser deployment requires WebAssembly loading/configuration. The 2026 release stream includes alpha releases and fixes for IndexedDB transaction failures, storage shutdown/flush, sync state, and network error handling ([initialization](https://automerge.org/docs/reference/library-initialization/); [releases](https://github.com/automerge/automerge-repo/releases)).
- CR-SQLite provides SQLite merging in WASM across browser main threads and workers, with transactions and update hooks. The first-app scaffold includes a SPA, schema, and sync server, but browser persistence and deployment are separate choices ([CR-SQLite WASM](https://vlcn.io/docs/cr-sqlite/js/wasm); [first app](https://vlcn.io/docs/cr-sqlite/js/first-app)).
- Search results identify Automerge Repo and CR-SQLite repositories as MIT licensed. The fetched pages do not establish built-in E2EE, managed backup, or commercial continuity guarantees.

## Technical Detail
TinyBase is best understood as a composable state/persistence toolkit rather than a complete sync authority. It can fit a Cloudflare Durable Object architecture and has IndexedDB local persistence, but the application must select and configure the synchronizer, conflict/merge behavior, authentication, and backup. This makes a small household PWA possible without forcing SQLite WASM, but it also leaves correctness at the integration boundary.

Automerge Repo provides a clean document CRDT and pluggable storage/network model. IndexedDB plus a self-hosted WebSocket server is a credible full-document offline path, and the release history shows active reliability fixes. WASM bundling and server operation add implementation surface. The public server must not be used as continuity infrastructure, and export/restore is not demonstrated by the fetched primary pages.

CR-SQLite offers relational queries and mergeable SQLite databases, which is attractive for CRUD. The browser path adds WASM, persistence/VFS, worker coordination, sync server, and schema management. It may be disproportionate for a single-household dataset unless relational querying and multi-device merge are high-value. Neither the fetched docs nor search evidence proves encrypted replication or a turnkey Cloudflare/R2 deployment.

## Relevance
TinyBase is a practical low-level finalist for a bespoke Durable Object-backed design. Automerge Repo is a practical CRDT document finalist if self-hosting and WASM complexity are accepted. CR-SQLite is a technically strong but higher-complexity option. For all three, POCs must prove cold-start restore, delete/tombstone behavior, concurrent edits, durable export/import, and browser quota failure handling; popularity or stars are not sufficient evidence.

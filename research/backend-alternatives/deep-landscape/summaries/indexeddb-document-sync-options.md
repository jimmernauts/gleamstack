---
cycle: 2
purpose: "Evaluate IndexedDB-first and document-database alternatives: Dexie with bespoke sync or Dexie Cloud, PouchDB+CouchDB, RxDB, and Fireproof, focusing on local authority, browser persistence, replication/conflict semantics, self-hosting, and object-storage backup fit."
quality: high
tags: [IndexedDB, document-database, replication]
sources:
  - url: https://dexie.org/docs/cloud/consistency
    title: "Consistency in Dexie Cloud"
  - url: https://dexie.org/pricing
    title: "Dexie Cloud Pricing"
  - url: https://pouchdb.com/guides/conflicts.html
    title: "PouchDB Conflicts"
  - url: https://rxdb.info/replication.html
    title: "RxDB realtime Sync Engine"
  - url: https://github.com/fireproof-storage/fireproof
    title: "Fireproof repository"
---

## Key Claims
- Dexie Cloud is an IndexedDB-first add-on with server-authoritative sync, transactional conditional operations, access realms, and optional Y.js CRDT integration; same-property concurrent updates use latest operation time, while different property updates can merge (Dexie consistency docs).
- PouchDB/CouchDB deliberately expose conflicts: immediate revision conflicts return 409, while eventual offline conflicts retain revision trees and select a deterministic arbitrary winner until application resolution (PouchDB conflicts guide).
- RxDB is explicitly local-first and can replicate through a custom HTTP/GraphQL endpoint backed by PostgreSQL, MongoDB, or another system; it requires checkpoints and tombstones for reliable incremental sync (RxDB sync docs).
- RxDB's default conflict handler drops the client fork in favor of the server state, but custom client-side conflict handlers are supported (RxDB sync docs).
- Fireproof offers an embedded browser document DB with encrypted live sync, CRDT collaboration, causal/hash-history integrity, and content-addressed encrypted blobs; its repository page advertises Apache-2.0, but package-level licensing must be verified before adoption (Fireproof repository).

## Technical Detail
Dexie Cloud is a relatively complete managed coordinator rather than just a browser database. Its server-authoritative model re-executes declarative operations against the current server snapshot, preserving the intention of conditional modify/delete operations across offline peers. Atomic transactions are all-or-nothing. For flat recipe/planning records, use globally unique IDs and `update()` rather than whole-object `put()` when fields may be edited concurrently; different properties can merge, but same-property writes are last-operation-wins. Frequently edited arrays should instead be normalized into related records. Sharing is modeled through realms; tied realm IDs make offline share/delete operations converge deterministically. The pricing page documents a hosted service and a separate on-prem Gold offering, so “user-controlled storage” is not the default deployment.

PouchDB plus CouchDB is self-hostable and battle-tested for document replication, but conflict handling is intentionally application-facing. A delete is a revision/tombstone that must participate in the revision tree; compaction/retention needs operational care. Revision conflicts can be inspected and resolved, or the data model can use append-only delta documents to make conflicts impossible at the document level. This gives strong portability but requires building auth, authorization, conflict UX, compaction, and backup/restore operations.

RxDB supplies a useful bespoke-sync boundary: local IndexedDB/OPFS authority, push/pull batches, checkpoints, a live stream or periodic RESYNC, client conflict handlers, and retry behavior. The remote must keep deleted documents as tombstones, sort deterministically by checkpoint fields, and tolerate duplicate transmissions because a response can be lost after remote acceptance. RxDB also warns not to block app startup on initial sync; offline use must remain possible. Fireproof is attractive when cryptographic ledger integrity and object-storage-style gateways matter, but its exact storage gateway, package license, and operational continuity need validation before making it a primary architecture.

## Relevance
Dexie Cloud is the least bespoke route for structured flat records and sharing, at the cost of hosted/on-prem commercial boundaries. PouchDB/CouchDB maximizes self-hosting and transparent conflict history but exposes more conflict/ops work. RxDB is a strong fit for Mealstack if a small custom Worker coordinator is acceptable. Fireproof potentially combines local authority, CRDTs, and object storage, but licensing and gateway continuity are material gaps. None of these sources proves browser storage is non-evictable; persistence policy remains a web-platform concern.

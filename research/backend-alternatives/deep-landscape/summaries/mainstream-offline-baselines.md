---
cycle: 5
purpose: "Establish comparison baselines and test whether mainstream stacks meet the user-controlled storage requirement: Firestore and Supabase offline capabilities, persistence constraints, conflict behavior, exports, and vendor/cloud dependence."
quality: high
tags: [Firestore, Supabase, offline-cache]
sources:
  - url: https://firebase.google.com/docs/reference/js/firestore_
    title: "Firestore JavaScript API reference"
  - url: https://github.com/firebase/firebase-js-sdk/blob/main/packages/firestore/src/local/indexeddb_persistence.ts
    title: "Firestore IndexedDB persistence source"
  - url: https://cloud.google.com/firestore/pricing
    title: "Firestore pricing"
  - url: https://supabase.com/pricing
    title: "Supabase pricing"
  - url: https://supabase.com/docs/guides/platform/backups
    title: "Supabase database backups"
---

## Key Claims
- Firestore Web supports IndexedDB persistence, multi-tab coordination, cache reads, latency-compensated offline writes/deletes, queued delivery, and persisted write batches; persistence can fail on an incompatible browser or tab configuration (Firestore API/source).
- Firestore's documented offline behavior is a cache plus cloud backend, not user-controlled storage; billing includes document operations, indexes, storage, bandwidth, and separately billed backup/PITR/restore features (Firestore API/pricing).
- Supabase provides hosted Postgres, auth, storage, realtime, and plan-based backups; free projects are directed to use `supabase db dump` for off-site backups, while paid plans have 7/14/30-day daily retention (Supabase docs/pricing).
- Supabase restore makes the project inaccessible during restoration and may require subscription/replication-slot handling; ordinary Supabase browser/Realtive APIs do not provide the required local-authoritative conflict sync by themselves (Supabase backups; comparison inference).

## Technical Detail
Firestore's Web API lets an application select a persistent IndexedDB cache or use the legacy `enableIndexedDbPersistence`/multi-tab APIs. Reads can explicitly come from cache; writes and deletes update local state immediately and queue until the network returns. Promise resolution still represents remote acknowledgement, so application code must not await an offline write as if it were a local commit. Transactions retry when read documents change; write batches are persisted offline. The SDK source uses a primary lease and multi-tab metadata in IndexedDB/localStorage, and contains Safari 14–16 cleanup workarounds. Persistence is not guaranteed: unsupported browsers and conflicting tab settings can disable it.

Firestore's server-authoritative model is convenient for a PWA and handles standard document conflict/transaction behavior, but the cited API material does not expose a portable operation log, self-hosted server, or user-selected object-storage bootstrap. Firestore exports/backups are Google Cloud features; pricing explicitly makes PITR, backup data, restore, and clone billable. This is cloud-cache architecture, not a local-first/user-controlled cloud architecture.

Supabase is a standard hosted Postgres platform with storage, auth, and realtime. Its backup contract is clearer than its offline contract: Pro/Team/Enterprise receive daily backups for 7/14/30 days, free projects should export via CLI, PITR adds up-to-seconds recovery at extra cost, and restores incur downtime. The cited sources do not document a browser IndexedDB authority or conflict resolver in `supabase-js`; adding PowerSync, RxDB, Dexie, or bespoke sync is a separate architecture. Supabase's “user data ownership” pricing feature should not be confused with user-controlled per-user backup destinations.

## Relevance
Firestore is a good benchmark for “offline-looking cloud cache” but fails the user-controlled storage and vendor-dependence goals. Supabase is a useful canonical Postgres/backup baseline, not a complete offline-first solution. Either can be paired with a separate local-first engine, but then the engine—not the mainstream backend—owns convergence, delete handling, retries, and bootstrap semantics.

Source URLs:
- https://firebase.google.com/docs/reference/js/firestore_
- https://github.com/firebase/firebase-js-sdk/blob/main/packages/firestore/src/local/indexeddb_persistence.ts
- https://cloud.google.com/firestore/pricing
- https://supabase.com/pricing
- https://supabase.com/docs/guides/platform/backups

# Firestore
The current web API supports persistent IndexedDB cache, optional multi-tab persistence, cache reads, latency-compensated local writes, queued writes while offline, and eventual backend delivery. Persistence can fail due to unsupported browser or tab precondition; if enabling persistence fails, the instance remains usable but without offline persistence. The API reference says offline write promises do not resolve until backend acknowledgement. `deleteDoc` is reflected locally immediately and sent later. `runTransaction` retries if read documents change; write batches are persisted offline. Firestore charges reads/writes/deletes, storage, indexes, and bandwidth; PITR, backup, restore, and clone are billed features.

The Firebase SDK source documents a primary lease and multi-tab synchronization through IndexedDB/localStorage, with cleanup/garbage collection and Safari-specific workarounds. The API reference does not establish user-controlled storage or a portable per-user bootstrap artifact.

# Supabase
Supabase pricing lists hosted Postgres, API, auth, storage, realtime, and daily backups by plan; the pricing page includes a user-data-ownership feature but is still a hosted platform. The backup docs say Pro/Team/Enterprise projects get daily backups with 7/14/30-day retention, free projects should use `supabase db dump` and off-site backups, and PITR adds seconds-granularity restore at additional cost. Restores cause project inaccessibility/downtime, and subscriptions/replication slots may need handling. Supabase's normal browser client and Realtime are network-oriented; the search evidence did not show built-in browser-authoritative offline writes or conflict convergence. A separate sync engine such as PowerSync/RxDB is required for that behavior.

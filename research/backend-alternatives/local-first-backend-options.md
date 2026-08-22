# Mealstack local-first backend alternatives

**InstantDB migration research and shortlist — 22 August 2026**

Mealstack does not need a like-for-like replacement for InstantDB. Its current data model is small and flat, and it does not use InstantDB links, rooms, presence, or collaborative features. The meaningful choice is therefore between a managed local-cache-and-sync product and a smaller local database with a deliberately narrow sync and backup protocol.

## Executive summary

1. **There is a firm migration deadline.** Instant Cloud has closed new signups, asks existing users to migrate within 12 months, shuts all cloud apps down on **31 August 2027**, and retains backups until **31 August 2028**. Self-hosted Instant remains available, but it preserves infrastructure and operational complexity that Mealstack does not appear to need.
2. **IndexedDB through Dexie is the proportionate local store for Mealstack's current browser PWA.** It is widely supported, stores the complete recipe collection locally, works offline, and can atomically update a recipe and an outbox entry. SQLite/Wasm over OPFS is viable, including Turso's browser engine, but adds workers, file locking, cross-origin isolation, and iOS/private-mode questions without improving browser storage permanence.
3. **Sync and backup are separate capabilities.** Google Drive, R2, Tigris, and S3 can hold snapshots and immutable operation files. They do not decide how concurrent edits or deletes converge. Mealstack must either select a sync product that supplies those rules or implement a small protocol itself.
4. **The shortlist contains six distinct implementation paths:**
   - plain Dexie plus a Mealstack operation log, with R2/Tigris or Google Drive transport;
   - Dexie Cloud plus a separate user-owned export;
   - RxDB plus a small Cloudflare sync coordinator;
   - self-hosted Triplit plus a separate backup path;
   - PouchDB plus CouchDB and independent backups;
   - Turso Sync plus a separate user-owned export, currently as a higher-risk prototype.
5. **No browser can promise permanent local storage.** IndexedDB and OPFS can be cleared by the user, evicted under storage pressure, or unavailable in private browsing. Every option needs remote recovery, explicit export/import, `navigator.storage.persist()` where available, and foreground retry when the app opens or regains connectivity.

This report does not select one universal winner. The options trade managed convenience, vendor dependence, operating burden, automatic sync, and control over backup storage differently.

## What Mealstack actually needs

### Current migration surface

The current repository has one TypeScript bridge, `app/src/db.ts`, wrapping the browser Instant client. Its schema in `app/src/instant.schema.ts` contains:

- recipes;
- tag options;
- meal-plan days;
- settings;
- shopping lists;
- no links;
- no rooms or presence.

Recipes are flat records with scalar metadata and JSON-shaped ingredients, method steps, and tags. Most worker-side Instant usage is limited to admin/import scripts. This makes an adapter migration materially smaller than replacing a deeply relational or collaborative backend.

The initial scope should remain recipe data. The API key currently stored under settings should not automatically enter a recipe backup; either keep it device-local or encrypt it under a separately managed key.

### Required behavior

| Requirement | Practical interpretation |
|---|---|
| Local data | Every device has a complete recipe collection in IndexedDB or OPFS and can read and edit it without a network. |
| Cross-device sync | Local writes enter a durable outbox, retries are idempotent, deletes replicate as tombstones, and reconnecting devices converge deterministically. |
| Backup | A recoverable, independently stored snapshot plus later changes exists in Google Drive or S3-compatible storage. |
| Bootstrap | A cleared or new device can authenticate, verify a snapshot, replay later changes, and reach the same logical state. |
| PWA operation | Correctness cannot depend on background execution. Sync retries on launch, `online`, `pageshow`/visibility return, and an explicit **Sync now** action. |
| Portability | Recipes can be exported in a documented, versioned format without a vendor SDK. |

### Important definitions

- **Local authority:** local writes commit immediately and are not merely an optimistic view waiting for a cloud database.
- **Cloud authority:** the browser has an offline cache, but the server owns the canonical result and may reject or roll back changes.
- **Sync coordinator:** authenticates devices, orders or validates changes, deduplicates retries, and returns missing changes.
- **Backup store:** retains restorable bytes. It does not inherently merge records, order concurrent writes, or authorize users.

## InstantDB shutdown and continuity option

The [shutdown announcement](https://www.instantdb.com/essays/instant_team_joins_openai) states:

- new signups are closed;
- existing users should migrate within 12 months;
- all cloud apps shut down on **31 August 2027**;
- backups remain available until **31 August 2028**;
- all of Instant is open source.

Instant's [migration guide](https://www.instantdb.com/docs/self-hosting/migrate) describes a controlled cutover: rehearse a restore, pause writes, drain mutations, restore a fresh backup, verify health, and repoint API and WebSocket endpoints. Instant [backups](https://www.instantdb.com/docs/backups) contain schema and permissions, per-table JSONL, users, and file blobs.

Self-hosting keeps current client semantics and is useful as a continuity bridge. It also transfers email, dashboard security, health monitoring, deployment, scaling, and database operations to Mealstack. Instant's own [self-hosting guide](https://www.instantdb.com/docs/self-hosting) describes roughly **$30/month** as a small VPS starting point and roughly **$600/month** for a serious AWS setup. That option is included in the wider landscape below, but not in the end-state shortlist because it retains capabilities and operating surface that the app has not used.

## Shortlist at a glance

| Path | Local/offline model | Sync and conflict model | User-owned backup | Operating burden | Main dependency or uncertainty |
|---|---|---|---|---|---|
| **1. Dexie + Mealstack sync protocol** | Full IndexedDB database; local writes and atomic outbox | Mealstack-defined field merge, tombstones, idempotent operations; optional Durable Object ordering | Native design goal: R2/Tigris/S3 or Google Drive snapshots and operation segments | Medium to high implementation; low database operations | Sync correctness becomes Mealstack product code |
| **2. Dexie Cloud + export** | IndexedDB cache of the permitted dataset; offline writes | Server-authoritative transactions; different-field merge and same-field latest operation | Separate encrypted Drive/R2 export required | Low custom sync; managed service or commercial on-prem | Hosted/commercial dependency and cloud authority |
| **3. RxDB + Cloudflare coordinator** | Full local RxDB using free Dexie storage or paid optimized storage | Documented checkpoint/push protocol, assumed-master state, tombstones, retries; custom field policy | R2/Tigris/Drive snapshots can be designed into backend | Medium | Backend and conflict policy are still custom; premium plugin boundary |
| **4. Self-hosted Triplit + export** | IndexedDB client; complete recipes only if queries cover the full collection | Optimistic outbox, server permissions, property-level/CRDT claims | Separate snapshot/export pipeline required | Medium; Node or Cloudflare server | AGPL review, restore and delete/tombstone details unresolved |
| **5. PouchDB + CouchDB** | Full local document database | Established revision replication; divergent revisions and explicit conflict resolution | CouchDB backup plus encrypted user export | Medium to high database operations | Conflict UX, compaction, auth, and current maintenance verification |
| **6. Turso Sync + export** | Full OPFS SQLite-style database; offline local writes | Explicit push/pull through Turso Cloud; last-push-wins by default, transform hook | Separate browser/server export to Drive/R2 required | Low-to-medium service work; higher browser integration | Sync beta/pre-1.0, OPFS/isolation/one-tab constraints, iOS and deletes need proof |

## 1. Plain Dexie plus a Mealstack sync protocol

### Model

[Dexie](https://github.com/dexie/Dexie.js/) is an Apache-2.0 wrapper around IndexedDB. Version 4.4.4 was released on 16 June 2026. It is local storage, not a sync service.

A single IndexedDB transaction can update a recipe and append its operation to an outbox. This removes the most common local data-loss gap: a recipe cannot commit without its pending sync record, and vice versa. See [Dexie transaction documentation](https://dexie.org/docs/Dexie/Dexie.transaction()).

A proportionate operation shape is:

- globally unique operation ID;
- dataset, device, entity, and entity ID;
- schema version;
- operation kind: create, patch, or delete;
- changed fields and their values;
- base version or field versions;
- hybrid/logical timestamp plus deterministic device tie-break;
- payload checksum.

Start with per-field last-write-wins for independent scalar fields. Treat ingredients and method steps as atomic fields initially. When the same field was changed offline on both devices, either retain a visible conflict copy or apply a documented deterministic winner. Deletes remain tombstones until all supported restore baselines have advanced beyond them.

This is current-state storage plus a transactional change log, not full event sourcing. Full event sourcing adds audit, replay, schema-upcasting, archival, and privacy-deletion complexity that is not proportionate to ordinary recipe CRUD.

### Variant 1A: Cloudflare Worker plus R2 or Tigris

The existing Worker authenticates the user and accepts idempotent operations. It can either:

- write immutable operation objects directly to R2/Tigris; or
- send each user's operations through a Durable Object when a single receipt order or serialized manifest update is desired.

R2 provides strong read-after-write, delete, metadata, and list consistency. It supports conditional requests and checksums, but does not currently expose S3 bucket versioning. Immutable keys are therefore essential. Tigris supports conditional writes and strong consistency in single- and multi-region configurations; its Global and Dual-region modes can be eventually consistent across regions. Tigris snapshot buckets add object-version behavior, but cannot also use lifecycle expiry.

A workable layout is:

- immutable `ops/{device}/{op-id}` objects;
- immutable packed operation segments after a threshold;
- immutable, checksummed `snapshots/{generation}` bundles;
- a small manifest updated with ETag compare-and-swap, or treated only as an advisory pointer;
- lifecycle rules that never remove operations or tombstones before every retained snapshot can restore safely.

R2's current standard pricing is $0.015/GB-month, $4.50/million Class A operations, and $0.36/million Class B operations, with free egress. At Mealstack's size, correctness and object count matter more than storage cost. One object per change is simplest but should eventually compact into immutable segments.

**Pros**

- Complete local authority and offline behavior.
- Backup/bootstrap is part of the design rather than an afterthought.
- Reuses the existing Cloudflare deployment.
- No database server or Postgres cluster.
- Portable JSON operations and snapshots reduce vendor lock-in.
- R2 Worker bindings avoid exposing storage credentials to the PWA.

**Cons**

- Mealstack owns protocol invariants, auth, retries, ordering, conflicts, tombstones, compaction, schema migration, corruption handling, and restore tooling.
- A Durable Object simplifies ordering but becomes a coordinator dependency; omitting it makes deterministic client merge more important.
- Object listings and many small files need compaction and monitoring.
- Multi-user sharing would require explicit membership and authorization semantics.

**Blocking proof**

Demonstrate duplicate-safe upload after an interrupted response, same-field and different-field offline edits in both reconnect orders, delete-versus-update, a compacted restore, and recovery from a corrupted latest snapshot.

Sources: [R2 consistency](https://developers.cloudflare.com/r2/reference/consistency/), [R2 S3 compatibility](https://developers.cloudflare.com/r2/api/s3/api/), [R2 pricing](https://developers.cloudflare.com/r2/pricing/), [Tigris consistency](https://www.tigrisdata.com/docs/concepts/consistency/), [Tigris conditionals](https://www.tigrisdata.com/docs/objects/conditionals/), [Durable Objects](https://developers.cloudflare.com/durable-objects/concepts/what-are-durable-objects/).

### Variant 1B: Google Drive transport

Mealstack can implement low-frequency synchronization over Google Drive even though Drive itself is not a database-sync engine.

Two storage locations have different consequences:

- `appDataFolder` is hidden and app-private, but can disappear when the user uninstalls the app or deletes its app data. It should not be the only backup.
- A visible folder created by Mealstack under `drive.file` is inspectable and recoverable by the user. Mealstack should persist file/folder IDs and offer a Picker-based reconnect flow.

The browser GIS token model supplies short-lived access tokens and intentionally does not give a SPA a long-lived refresh token. Renewal can require user interaction. A backend authorization-code flow is needed for unattended long-lived Drive access. Browser-only Drive sync should therefore be described as **sync when the app is open and authorized**, not guaranteed background sync.

Use immutable operation files with pre-generated Drive IDs so retrying an ambiguous create cannot silently duplicate the operation. Use the changes feed as an efficient notification/index, not as the authoritative operation history. New immutable snapshots avoid relying on Drive revisions, because non-head blob revisions can be purged after 30 days or after enough later revisions.

**Pros**

- The user recognizes and controls the backup location.
- A browser-only personal configuration can avoid running a database or sync server.
- Visible snapshots improve recovery confidence and portability.
- Drive quotas are ample for a small recipe collection.

**Cons**

- Access-token renewal can interrupt automatic sync.
- Drive provides no atomic log append or application-level conflict policy.
- Hidden app data is not a sufficient sole backup; visible files need a reconnect UX.
- File/list API calls, backoff, revoked consent, storage exhaustion, and domain policy become product states.
- This is less suitable if users expect immediate, invisible synchronization.

**Blocking proof**

Run two browser profiles against one Drive account, expire/revoke tokens, repeat ambiguous uploads, reconnect a visible folder, and bootstrap after clearing all site data. Confirm the app explains stale or paused sync rather than implying success.

Sources: [Drive application data](https://developers.google.com/workspace/drive/api/guides/appdata), [Drive OAuth scopes](https://developers.google.com/drive/api/guides/api-specific-auth), [GIS token model](https://developers.google.com/identity/oauth2/web/guides/use-token-model), [Drive changes](https://developers.google.com/workspace/drive/api/guides/manage-changes), [Drive revisions](https://developers.google.com/drive/api/guides/manage-revisions), [Drive limits](https://developers.google.com/drive/api/guides/limits).

## 2. Dexie Cloud plus a separate user-owned export

### Model

Dexie Cloud keeps data in IndexedDB for offline operation and synchronizes the user's permitted subset with its server. The server is authoritative. Transactions are atomic on the server; updates to different properties can merge, while same-property conflicts use latest-operation behavior. Y.js is available for collaborative document fields, though Mealstack does not currently need it.

The hosted service currently offers three production seats, 100 MB storage, and documented request limits in its entry allowance. On-prem is a separate commercial product using Node and Postgres; Cloudflare Workers are not a documented server target. The CLI can export/import a ZIP containing data, schema, roles, members, blobs, and Y.js state.

Mealstack would still need an automated or user-triggered encrypted export to Drive/R2 so Dexie Cloud is not the only recoverable copy.

**Pros**

- Smallest custom synchronization surface in the shortlist.
- IndexedDB and offline mutations are integrated.
- Documented transaction and property-conflict behavior.
- Authentication options and access-control model are included.
- Full export/import reduces, but does not remove, lock-in.

**Cons**

- Cloud authority is not the strict interpretation of local authority.
- Replaces one hosted sync dependency with another.
- User-owned backup is separate work.
- On-prem requires a commercial agreement and Postgres operations.
- Ensure the recipe query/subscription covers the complete collection needed offline.

**Blocking proof**

Verify all recipes remain available after a clean offline restart, concurrent array/scalar changes behave acceptably, a delete converges, and a scheduled export can rebuild a clean test account without private vendor intervention.

Sources: [Dexie Cloud consistency](https://dexie.org/docs/cloud/consistency), [pricing](https://dexie.org/pricing), [limits](https://dexie.org/docs/cloud/limits), [authentication](https://dexie.org/docs/cloud/authentication), [CLI export/import](https://dexie.org/docs/cloud/cli), [on-prem](https://dexie.org/docs/cloud/premium-software).

## 3. RxDB plus a Cloudflare coordinator

### Model

[RxDB](https://rxdb.info/) provides a local-first document database and an explicit backend-neutral replication protocol. Its free core includes replication and Dexie, memory, and LokiJS storage. Optimized IndexedDB, OPFS, SQLite, encryption, and performance plugins are Premium under an annual license.

The replication protocol documents deterministic checkpoints, assumed-master state on push, retry-safe operations, live streams or periodic resync, and tombstones rather than physical deletion. Its default conflict handler accepts master state; Mealstack would implement a field-aware handler where silent whole-record loss is unacceptable.

The Cloudflare Worker/Durable Object side still needs to authenticate users, retain master state and tombstones, apply conditional updates, and publish independent snapshots to R2/Tigris or Drive.

**Pros**

- More replication machinery and protocol guidance than plain Dexie.
- Full local document database and offline writes.
- Backend-neutral; compatible with a small custom Worker API.
- Explicit retry, checkpoint, conflict, and tombstone concepts reduce protocol invention.
- Free Dexie storage may be sufficient for Mealstack's small dataset.

**Cons**

- It does not eliminate the custom authoritative backend.
- Field merge, auth, compaction, repair, and backup remain Mealstack responsibilities.
- Faster browser storage and encryption plugins cross into the Premium boundary.
- Larger API and runtime surface than plain Dexie.

**Blocking proof**

Benchmark the free Dexie storage, implement the smallest pull/push endpoints, then test retry after committed-but-unacknowledged writes, stale assumed-master conflicts, tombstone retention, and restore from R2 without the live coordinator.

Sources: [RxDB replication](https://rxdb.info/replication.html), [RxDB Premium](https://rxdb.info/premium/), [IndexedDB storage](https://rxdb.info/rx-storage-indexeddb.html).

## 4. Self-hosted Triplit plus a separate export

### Model

Triplit is an integrated TypeScript local-first client and sync server. The client uses IndexedDB, optimistic writes, an outbox/double buffer, WebSockets, reconnect, and query-based incremental synchronization. A complete local recipe set therefore depends on fetching/subscribing to queries that cover the collection.

The project documents Node and Cloudflare server packages and had active releases through July 2026. The repository is AGPL-3.0. A modified network server can trigger source-offer obligations under AGPL section 13; the exact effect on Mealstack needs license review rather than assumption.

Triplit advertises property-level conflict handling and CRDT collaboration. The researched documentation did not establish a decision-grade delete-versus-update rule, tombstone retention/GC contract, or complete restore/import path. A full server database download endpoint exists, but restore remains an explicit proof item.

**Pros**

- Integrated local client, sync server, authorization, queries, and optimistic UX.
- Cloudflare deployment path fits the existing stack.
- Less custom replication code than plain Dexie or RxDB.
- Active project and self-hosting option.

**Cons**

- AGPL obligations require review.
- Full-local behavior is query-dependent rather than an automatic full mirror.
- Delete/tombstone and restore behavior need verification.
- Hosted price, limits, and continuity were not established from current first-party material.
- Adds a substantial TypeScript server framework around a small data model.

**Blocking proof**

Subscribe to the complete recipe set, cold-start offline, test delete-versus-update, inspect retained history/tombstones, deploy the server to Cloudflare, and rebuild a clean deployment from an exported database.

Sources: [Triplit repository and license](https://github.com/aspen-cloud/triplit), [client](https://github.com/aspen-cloud/triplit/blob/main/packages/client/README.md), [Cloudflare release guide](https://www.triplit.dev/blog/release-notes-2024-11-22), [database download release note](https://www.triplit.dev/blog/release-notes-2024-12-06), [releases](https://github.com/aspen-cloud/triplit/releases).

## 5. PouchDB plus CouchDB

### Model

PouchDB stores documents locally in the browser and speaks CouchDB's established replication protocol. CouchDB keeps revision trees. Immediate stale writes can return 409; disconnected edits can produce divergent revision leaves. Normal reads expose a deterministic winner, but the application must inspect, merge, and remove losing leaves. Deletes are revision tombstones, and compaction removes old bodies while preserving revision metadata needed for replication.

CouchDB becomes the reachable synchronization service. Mealstack would operate it, secure CORS and authentication, design per-user/database authorization, monitor compaction, and create independent backups or user exports.

**Pros**

- Long-established, transparent document replication model.
- Complete local dataset and offline writes.
- Self-hostable with no proprietary sync server.
- Conflicts are retained rather than silently overwritten.
- Existing ecosystem and documented replication semantics.

**Cons**

- Operating CouchDB is more infrastructure than the current dataset warrants.
- Revision conflicts require application UX and cleanup.
- Compaction, tombstone retention, CORS, and per-user authorization need care.
- Cloudflare Workers/R2 cannot directly substitute for CouchDB.
- Current release/maintenance health should be verified before commitment.

**Blocking proof**

Deploy a secured test CouchDB, replicate a complete recipe set on two devices, create divergent revisions and delete conflicts, exercise compaction, and restore both CouchDB and a user-owned export.

Sources: [PouchDB conflicts](https://pouchdb.com/guides/conflicts.html), [CouchDB replication conflicts](https://docs.couchdb.org/en/latest/replication/conflicts.html).

## 6. Turso Sync plus a separate user-owned export

### What the supplied sources establish

The official [`database-wasm-vite` example](https://github.com/tursodatabase/turso/tree/main/examples/javascript/database-wasm-vite) is a real persistent local browser database, but **it is not Turso Sync**. It imports `@tursodatabase/database-wasm/vite`, opens `local.db`, and stores the database and WAL in OPFS. It has no cloud URL, token, `push()`, or `pull()`.

Turso Sync is a separate stack using `@tursodatabase/sync` and, in the browser, `@tursodatabase/sync-wasm`. The [Sync usage guide](https://docs.turso.tech/sync/usage) documents:

- a persistent local database;
- offline local writes;
- first-connect bootstrap from Turso Cloud by default;
- explicit `push()`, `pull()`, `checkpoint()`, and `stats()`;
- replay of unpushed local changes after a pull;
- last-push-wins conflict behavior by default, with a transform hook for custom row merges.

The official browser examples require a Web Worker, OPFS, shared Wasm memory, and COOP/COEP headers for `SharedArrayBuffer`. The current example does not provide a cross-tab protocol; the researched docs effectively constrain one open tab per database. The sync example includes a public bundled token as a demonstration and warns about it. Production Mealstack should obtain a narrowly scoped token through its Worker rather than embed a durable credential.

Turso Sync launched in October 2025 and remains Beta/pre-1.0 despite active 2026 releases. Turso Cloud remains the remote source of truth. Native user-selected Google Drive, R2, Tigris, or S3 backup is not documented; Mealstack must add export and restore separately.

**Pros**

- Actual local SQL database in the browser, not merely an API cache.
- Demonstrated OPFS persistence and offline local writes.
- Built-in cloud bootstrap and explicit push/pull.
- Familiar SQL data model and active development.
- Existing Worker can issue tokens or orchestrate independent backup.

**Cons**

- Sync beta/pre-1.0 and potential storage/protocol changes.
- COOP/COEP, Wasm worker, OPFS, and one-tab coordination complicate the PWA.
- iOS installed-PWA behavior is not first-party-qualified.
- Same-row conflict default is last push, and delete/tombstone behavior needs proof.
- Turso Cloud is canonical; user-owned backup remains custom.
- The local-only Vite example proves persistence but does not solve cross-device sync.

**Blocking proof**

Run `sync-wasm` on real installed iOS and desktop PWAs; open competing tabs; edit the same row and different rows offline; test delete-versus-update; expire a scoped token; clear site data and bootstrap; and restore a new Turso database plus local client from a user-owned snapshot. Verify the documented bootstrap option against the current WASM package because the inspected source and generic usage documentation are not perfectly aligned.

Sources: [Sync usage](https://docs.turso.tech/sync/usage), [conflict resolution](https://docs.turso.tech/sync/conflict-resolution), [local browser Vite example](https://github.com/tursodatabase/turso/tree/main/examples/javascript/database-wasm-vite), [sync browser Vite example](https://github.com/tursodatabase/turso/tree/main/examples/javascript/sync-wasm-vite), [Turso 0.7.0](https://github.com/tursodatabase/turso/releases/tag/v0.7.0), [pricing](https://turso.tech/pricing), [durability](https://docs.turso.tech/cloud/durability).

## Comparison by decision preference

| If the priority is… | Paths to examine | Accepted trade-off |
|---|---|---|
| User-visible storage and no always-on database | Dexie + Google Drive | Foreground/user-authorized sync and custom merge logic |
| Existing Cloudflare footprint and maximum control | Dexie + Worker/R2, or RxDB + Worker/R2 | Mealstack owns sync correctness and restore tooling |
| Minimum custom sync code | Dexie Cloud | Hosted authority and a separate backup/export process |
| Integrated open-source client and server | Triplit | AGPL review plus unresolved restore/delete details |
| Established replication protocol and visible conflicts | PouchDB/CouchDB | CouchDB operations and conflict UX |
| Local browser SQL with an integrated cloud path | Turso Sync | Beta/pre-1.0 browser and protocol risk plus custom user backup |

## Browser/PWA constraints shared by every option

IndexedDB is the conservative baseline. OPFS is supported by modern WebKit, but its synchronous access path is worker-only and it is unavailable in Safari Private Browsing. Both IndexedDB and OPFS are origin storage, not permanent device storage.

Required behavior for every implementation:

- call `navigator.storage.persist()` and record the actual Boolean result;
- handle `QuotaExceededError`, storage disappearance, and corrupt local state;
- show local, pending, synced, paused, and error status accurately;
- retry the outbox on app launch, `online`, `pageshow`, and visibility return;
- include an explicit **Sync now** action;
- never depend on one-shot or periodic Background Sync on Safari/iOS;
- close IndexedDB connections on `versionchange` and test schema upgrades across tabs;
- detect private browsing/storage failures and explain that data is not durable;
- provide versioned export and verified import even when automated sync exists.

WebKit gives installed Home Screen apps larger browser-sized quota, and iOS 17+ supports the StorageManager persistence APIs. Evidence about a universal exemption from Safari's seven-day inactive-data policy is version-dependent, so real-device inactivity testing remains necessary.

Sources: [WebKit storage policy](https://webkit.org/blog/14403/updates-to-storage-policy/), [WebKit OPFS](https://webkit.org/blog/12257/the-file-system-access-api-with-origin-private-file-system/), [MDN storage quotas and eviction](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria), [MDN persistent storage](https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist), [MDN Background Sync](https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API).

## Baseline backup and restore format

Whichever sync path is selected, define an independent Mealstack archive format before migration.

### Snapshot bundle

- format and schema version;
- dataset and generation IDs;
- creation time and producing app version;
- normalized recipes;
- tombstones retained at the snapshot cut-line;
- last included operation/checkpoint per device or server sequence;
- per-file and manifest checksums;
- optional encryption algorithm, key ID, and nonce metadata;
- no API keys or admin credentials.

### Incremental changes

- immutable operation IDs;
- idempotent reapplication;
- deterministic ordering/tie-break rules;
- retained delete tombstones;
- compatible decoder for older schema versions;
- signed or checksummed segments.

### Restore sequence

1. Authenticate and discover candidate snapshot generations.
2. Download a complete immutable generation.
3. Verify manifest, sizes, checksums, schema version, and optional encryption before touching live local data.
4. Import into a temporary local database.
5. Replay later operations and validate record counts/invariants.
6. Atomically switch the active local generation.
7. Keep the previous known-good generation until the new one has opened and synced successfully.
8. Record and surface the restore result.

A backup is not complete until this process has been exercised on a clean device.

## Options not in the initial shortlist

| Option | Why it is not in the initial six |
|---|---|
| **Self-hosted InstantDB** | Strong migration bridge, but retains a larger operational stack and unused Instant capabilities. |
| **PowerSync** | Credible local SQLite/upload queue, but still requires a source database, sync service, auth, custom upload backend, and backup. Hosted production starts at $49/month; this appears disproportionate until Mealstack wants a canonical database. |
| **Evolu** | Promising E2E-encrypted SQLite/CRDT model and stateless Cloudflare-compatible relay; independent browser persistence and export/restore still need decision-grade proof. |
| **Fireproof** | Encrypted immutable ledger and CRDT gateway architecture are relevant, but metadata/gateway continuity and an independent restore runbook were not established. |
| **TinyBase** | Active MIT toolkit with IndexedDB and Durable Object adapters; it remains a building block whose auth, authority, merge, and backup must be designed, overlapping the plain-Dexie path. |
| **Automerge Repo** | Complete document CRDT and IndexedDB adapters, but the current repo line is alpha and its public sync server is explicitly experimental. More document-collaboration machinery than flat recipe CRUD needs. |
| **Jazz/cojson** | Offline OPFS and sync are promising, but query-subscription behavior does not itself prove a complete local replica, and stability/export boundaries need proof. |
| **LiveStore** | Project states beta; conflict handling, compaction, and encryption are not implemented in the researched sync layer. |
| **vlcn/cr-sqlite** | Technically mergeable SQLite/Wasm, but persistence, worker coordination, server integration, and schema management are a larger integration surface than current requirements justify. |
| **Yjs** | Excellent collaborative data primitive, but networking, persistence, auth, indexing, and replicated lifecycle remain application concerns. |
| **Electric/PGlite sync** | Documented plugin is alpha and one-way; it does not upload offline local writes or resolve conflicts. |
| **Zero** | GA and supported, but its own guidance says offline writes are not supported and the server is authoritative. |
| **Replicache** | Still supports offline mutations and BYOB push/pull, but is explicitly in maintenance mode and its old repository is archived; Zero is the advised direction. |
| **Firestore** | Useful offline cache around a cloud-authoritative database, not user-owned local authority or backup storage. |
| **Supabase alone** | Good canonical Postgres backend and backups, but no built-in browser-local authority or conflict replication in `supabase-js`. |
| **Raw SQLite-Wasm/OPFS** | Viable basis for a custom protocol, but Dexie is simpler for the current flat dataset and avoids extra Wasm/worker/locking/isolation constraints. Turso is the more concrete SQL prototype in this report. |

These are scope decisions, not claims that the products are generally poor. Multi-user collaboration, large relational datasets, or server-side analytics would change several of them.

## Proof-of-concept plan

### Stage 1: common contract and fixtures

Define one JavaScript/TypeScript adapter that the Gleam UI calls:

- open local store;
- list/get/save/delete recipes;
- subscribe to local changes;
- return sync state and last successful sync;
- trigger sync;
- export and import an archive.

Create deterministic fixtures covering empty optional values, ingredients/method arrays, tags, Unicode, large images if images enter scope, and preserved Instant IDs.

### Stage 2: contrasting spikes

Prototype at least one path from each preferred operating model:

- **controlled/serverless:** Dexie + Worker/R2 or RxDB + Worker/R2;
- **user-storage/no database:** Dexie + Google Drive;
- **integrated/managed or SQL:** Dexie Cloud, Triplit, or Turso Sync.

The owner can select which three based on the decision preferences above; there is no need to prototype all six before eliminating obvious operating models.

### Stage 3: destructive test matrix

For every spike:

1. Bootstrap two clean devices and verify complete recipe counts and hashes.
2. Edit different fields of one recipe offline on both devices.
3. Edit the same field offline on both devices.
4. Delete on one device and update on the other.
5. Interrupt a push after remote commit but before acknowledgement; retry it.
6. Leave one device offline through snapshot compaction, then reconnect it.
7. Corrupt or truncate the newest remote snapshot.
8. Revoke/expire credentials and verify local writes remain safe and visibly pending.
9. Clear site data and restore from backup alone.
10. Test Safari tab, installed iOS PWA, Chrome, Firefox, private browsing, two tabs, device reboot, and foreground resumption.
11. Destroy the live sync service and rebuild it from the independently stored archive.

Record convergence outcome, code size, bundle/startup cost, request count, recovery steps, unresolved conflicts, and operational tasks.

## Migration outline

1. Request and retain an Instant backup well before the 2027 shutdown.
2. Parse table JSONL into the versioned Mealstack archive format, preserving IDs and raw source values.
3. Normalize recipe JSON fields only through a tested migration; avoid combining backend replacement with broad recipe-model cleanup.
4. Import into the selected local store and verify counts, IDs, slugs, and content hashes.
5. Bootstrap the remote sync/backup location from the same archive.
6. Run a read-only comparison or a short controlled dual-read period.
7. Pause writes, drain pending Instant mutations, make a final export, import the delta, and switch the adapter.
8. Keep the original Instant backup and migration tool until restore drills pass and the 2028 backup window is no longer needed.

## Questions that materially change the choice

1. Is Mealstack strictly one person, one Google/cloud account, or a shared household with separate identities?
2. Is sync on app open plus an explicit button acceptable, or must it happen without interaction?
3. Should Google Drive be the primary user experience, or is an app-operated R2/Tigris bucket acceptable?
4. Must the cloud operator be unable to read recipes, requiring end-to-end encryption?
5. Is the first migration recipes only, or plans, shopping lists, tag options, and settings too?
6. For concurrent same-field edits, is deterministic last-write-wins acceptable, or must the app show a conflict?
7. Is operating Postgres/CouchDB acceptable, or should the solution remain serverless?
8. What monthly managed-service budget and vendor-continuity tolerance are acceptable?
9. Are installed iOS/iPadOS PWAs a release requirement or a later target?

## Research caveats

The study used two deep research-server cycles and focused first-party follow-ups. One gap cycle encountered provider rate limits on five branches; later direct-source runs filled the principal Dexie, Triplit, cloud transport, PWA, framework-status, and Turso gaps. Remaining uncertainties are called out rather than inferred, especially:

- Triplit delete/tombstone and restore guarantees;
- PouchDB's current long-term maintenance signal;
- Turso Sync browser/iOS qualification and delete behavior;
- installed-iOS storage retention across current OS configurations;
- end-to-end restore demonstrations for most vendor products.

Pricing, product status, and limits are volatile and should be rechecked immediately before implementation.

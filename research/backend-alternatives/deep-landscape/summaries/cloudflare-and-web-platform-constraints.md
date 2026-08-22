---
cycle: 8
purpose: "Assess a bespoke Cloudflare Worker coordination architecture using Durable Objects and/or D1 with R2/Tigris snapshots, and independently verify web-platform durability/sync limitations affecting every shortlist option: storage persistence/eviction, IndexedDB/OPFS compatibility, Background Sync, and foreground fallback."
quality: high
tags: [Cloudflare, Durable-Objects, web-platform]
sources:
  - url: https://developers.cloudflare.com/durable-objects/best-practices/websockets/
    title: "Durable Objects WebSockets"
  - url: https://developers.cloudflare.com/durable-objects/concepts/what-are-durable-objects/
    title: "What are Durable Objects"
  - url: https://developers.cloudflare.com/durable-objects/platform/limits/
    title: "Durable Objects Limits"
  - url: https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria
    title: "MDN storage quotas and eviction"
  - url: https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist
    title: "MDN StorageManager.persist"
  - url: https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API
    title: "MDN Background Synchronization API"
---

## Key Claims
- Durable Objects provide globally named, single-threaded actors with private transactional strongly consistent storage, making them a natural per-user/room sync coordinator; WebSockets support long-lived multi-client coordination (Cloudflare docs).
- Hibernation keeps WebSocket clients connected while in-memory state is reset, so durable storage or serialized attachments must restore state; per-connection attachments are capped at 16,384 bytes (Cloudflare WebSocket docs).
- SQLite-backed Durable Objects have a 10 GB per-object limit, 2 MB key/value limit, 32 MiB received-message limit, default 30-second CPU/message limit, and a soft 1,000 requests/sec/object limit; overload errors and Cloudflare plan dependence remain operational concerns (Cloudflare limits).
- Browser IndexedDB/OPFS data is best-effort by default; `navigator.storage.persist()` may obtain stronger eviction protection but approval varies, and Safari may proactively evict inactive script-created data after seven days (MDN).
- Background Sync is a secure-context service-worker optimization with incomplete browser support, so foreground retry on launch/visibility/online is mandatory (MDN; compatibility search result).

## Technical Detail
A Cloudflare architecture can route authenticated upgrade requests through a Worker to a Durable Object named by user/account or logical dataset. The DO serializes operations, persists the accepted oplog/materialized state in SQLite storage, broadcasts batches over a hibernating WebSocket, and uses alarms for compaction or snapshot publication. Immutable snapshots/oplog segments can be placed in R2/Tigris through a Worker-signed or server-generated presigned URL; D1 is better for shared relational indexes/control-plane data than for per-user actor serialization. This division is an inference assembled from the documented DO actor/storage/WebSocket properties and object-storage findings.

Hibernation is important: DO in-memory maps vanish on idle reinitialization, so connection identity/room metadata must be in durable storage or serialized attachments. Authentication must happen in the Worker before forwarding the upgrade, and channel/user authorization must be enforced in the DO. Batch small logical operations because each WebSocket message incurs overhead. Use per-entity or per-user DO names to avoid a single hot object; monitor soft throughput and 10 GB limits, and make compaction/delete policies explicit.

On the client, call `navigator.storage.persist()` and show the result, but still offer encrypted export/backup and recovery. Catch `QuotaExceededError`, detect OPFS/IndexedDB availability, and keep a compact repairable local log. Safari's inactivity eviction and private browsing behavior mean “full durable local data” cannot be guaranteed by the web platform alone. Service-worker Background Sync can opportunistically drain an outbox, but unsupported browsers—especially Safari in the cited compatibility data—require retry when the app opens, becomes visible, or receives `online`.

## Relevance
Durable Objects plus R2/Tigris is a credible bespoke coordinator architecture: strong per-user serialization, WebSocket fanout, and independent user-controlled object backups, with no VM/database fleet. Its main costs are Cloudflare dependency, platform limits, and custom protocol/security/repair work. It solves coordination, not local durability: every shortlist option must combine it with browser persistence detection, export/bootstrap, tombstones, idempotency, and foreground retry. Google Drive backup can be added as an alternate user-controlled destination.

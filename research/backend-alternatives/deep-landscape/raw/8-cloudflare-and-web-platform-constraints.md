Source URLs:
- https://developers.cloudflare.com/durable-objects/best-practices/websockets/
- https://developers.cloudflare.com/durable-objects/concepts/what-are-durable-objects/
- https://developers.cloudflare.com/durable-objects/platform/limits/
- https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria
- https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist
- https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API

# Durable Objects
Durable Objects combine Worker compute with a globally named instance, private durable transactional strongly consistent storage, single-threaded execution, WebSockets, and alarms. They are suitable for per-user/room coordination. WebSocket Hibernation keeps clients connected while the object leaves memory, resets in-memory state, and requires durable storage or serialized attachments to restore state. Attachments max at 16,384 bytes. WebSockets can connect thousands of clients per instance, but messages have processing overhead and should be batched. The Worker should authenticate upgrades before forwarding to the DO.

Limits include 10 GB per SQLite-backed object, 2 MB combined key/value, 32 MiB received WebSocket messages, default 30 seconds CPU per invocation/message, and a soft 1,000 requests/sec per object; overloaded objects can return errors. SQLite-backed DO storage is private per object; object naming partitions coordination. Cloudflare pricing/limits and platform continuity remain dependencies.

# Browser storage
MDN says IndexedDB/OPFS and Cache data are best-effort by default. `navigator.storage.persist()` can request persistent storage, but browser approval differs; persistent data is only evicted by user action, while best-effort can be evicted under storage pressure. Safari proactively evicts script-created data for origins without user interaction in the last seven days under tracking prevention. Quotas vary by browser and platform, and quota excess throws QuotaExceededError. Private browsing changes quotas and usually deletes data when the session ends. `persist()` resolves true/false and can fail.

# Background Sync
The Background Synchronization API can defer service-worker work until network availability in secure contexts, but compatibility is not universal and the search results show it is unsupported in Safari. It must be an optimization; foreground-on-launch/visibility/online retry is required for reliable PWA sync.

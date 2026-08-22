---
cycle: 7
purpose: "Assess user-controlled cloud stores as backup/bootstrap and as possible sync substrates: Google Drive appDataFolder and OAuth/changes/revisions; S3/Tigris/R2 consistency, versioning, lifecycle, CORS and presigned access; distinguish native adapters from custom coordination and establish browser credential safety."
quality: high
tags: [object-storage, Google-Drive, presigned-URLs]
sources:
  - url: https://developers.google.com/workspace/drive/api/guides/appdata
    title: "Google Drive application data folder"
  - url: https://developers.google.com/workspace/drive/api/guides/manage-changes
    title: "Google Drive retrieve changes"
  - url: https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html
    title: "Amazon S3 presigned URLs"
  - url: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html
    title: "Amazon S3 Versioning"
  - url: https://developers.cloudflare.com/r2/api/s3/presigned-urls/
    title: "Cloudflare R2 presigned URLs"
  - url: https://www.tigrisdata.com/docs/objects/presigned/
    title: "Tigris presigned URLs"
---

## Key Claims
- Drive `appDataFolder` is app-private hidden storage requiring the `drive.appdata` scope, but uninstalling the app or manual deletion can remove it; files cannot be shared, moved, or trashed (Google Drive docs).
- Drive's changes API provides page-token-based chronological change detection and watch notifications, but notifications only say that changes exist; the app must fetch the change feed (Google Drive docs).
- S3 presigned URLs provide temporary browser GET/PUT access without exposing credentials, but are bearer tokens; S3 Versioning preserves whole-object versions and delete markers, with lifecycle needed for noncurrent versions (AWS docs).
- R2 supports S3-style presigned GET/PUT/HEAD/DELETE with 1-second–7-day expiry and browser CORS, while Tigris documents up-to-90-day presigned URLs; neither is itself a logical sync coordinator (R2/Tigris docs).
- Object storage supplies blobs, versions, and sometimes change/list primitives; it does not provide record-level conflict resolution, authenticated per-operation ordering, or convergence by itself (inference from cited storage APIs).

## Technical Detail
Drive can host a user-owned bootstrap bundle behind OAuth: store a manifest/snapshot/oplog file in `appDataFolder`, list the folder, download by file ID, and use `changes.getStartPageToken` plus paginated `changes.list` to detect updates. The change feed can include removed items and watch channels can reduce polling, but a watch notification carries no details. The folder is app-specific and hidden, and its deletion semantics are unsuitable as the sole backup unless the app warns users and supports export to ordinary Drive. OAuth scope and refresh-token handling must be designed for a browser PWA; never put service-account or S3 signing secrets in client code.

For S3/R2/Tigris, the safe pattern is a coordinator that authenticates the user and returns a short-lived presigned URL scoped to a generated object key, method, content type, and checksum. The browser then uploads/downloads the immutable bundle directly. S3 Versioning can recover accidental overwrite/delete via complete object versions and delete markers, but every version costs full-object storage and lifecycle must clean noncurrent versions. R2's presigned URLs cannot use custom domains, and Tigris warns about active-content/XSS risks when upload presigned URLs are exposed on a custom domain. CORS must be narrowly configured.

A “latest.json” pointer plus immutable generation objects can implement backup/bootstrap, but concurrent pointer updates need conditional writes or a coordinator; listing/versioning is not enough to define a total order. The sync layer still needs device identity, operation IDs, authz, idempotent append, tombstone retention, merge policy, compaction watermarks, and integrity manifests. These are application inferences, not native S3/R2/Tigris guarantees.

## Relevance
Google Drive is a plausible user-controlled backup target for a single user's encrypted bundle and can provide a coarse change signal. S3/R2/Tigris are more programmable, cheaper/object-native substrates for immutable snapshots and logs, especially when the app already has a Worker signer. None should be selected as the sole sync engine. Use them as backup/bootstrap or as the durable log behind a separate coordinator; keep credentials server-side and make bundles encrypted, checksummed, versioned, and explicitly restorable.

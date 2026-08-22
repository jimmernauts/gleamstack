Source URLs:
- https://developers.google.com/workspace/drive/api/guides/appdata
- https://developers.google.com/workspace/drive/api/guides/manage-changes
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html
- https://developers.cloudflare.com/r2/api/s3/presigned-urls/
- https://www.tigrisdata.com/docs/objects/presigned/

# Google Drive
Drive appDataFolder is a hidden, app-only folder requiring the drive.appdata OAuth scope. It is suitable for config/backup files but is deleted if the user uninstalls the app and can be manually deleted. It cannot be shared, moved between spaces, or trashed. Drive changes API uses a start page token, chronological changes.list pagination, next/new start tokens, optional removed items, and watch notifications that only signal that changes are available; the app must poll for details. This is a storage/change-feed substrate, not a conflict-resolving record sync engine. Browser OAuth/token storage and refresh must be handled securely.

# Amazon S3
S3 presigned URLs grant time-limited GET/PUT/etc. without exposing credentials; they are bearer tokens, and uploads can include checksums. URLs signed with temporary credentials expire with those credentials. S3 Versioning preserves complete object versions and creates delete markers, but versioning is off by default, cannot be fully disabled after enablement (only suspended), and every version is billed as a full object. Lifecycle rules are needed for noncurrent versions. CORS is needed for browser cross-origin requests. Object storage does not coordinate concurrent logical operations or resolve application records.

# Cloudflare R2
R2 supports S3-compatible presigned GET/PUT/HEAD/DELETE URLs, 1-second-to-7-day expiry, browser use with CORS, and treats URLs as bearer tokens. Credentials/signing must stay server-side; custom domains cannot use presigned URLs. R2 is an object store, not a sync coordinator.

# Tigris
Tigris presigned URLs support browser/program uploads/downloads, overwrite the same key, and have up to 90-day expiry. Custom-domain uploads raise XSS concerns. The fetched material did not establish native versioning/change-feed/conditional-write semantics equivalent to a sync protocol.

---
cycle: 3
purpose: "Assess newer CRDT/event frameworks Jazz/cojson, LiveStore, Evolu, and Fireproof using primary production/stability statements, releases, licensing, browser persistence, relay/self-hosting/E2EE, export, and storage/deployment adapters—not popularity signals."
quality: high
tags: [jazz, livestore, evolu, fireproof, crdt, event-sourcing]
sources:
  - url: https://jazz.tools/docs/concepts/how-sync-works
    title: "How Jazz sync works"
  - url: https://jazz.tools/docs/getting-started/server-setup
    title: "Jazz server setup"
  - url: https://docs.livestore.dev/reference/syncing/
    title: "LiveStore Syncing"
  - url: https://docs.livestore.dev/misc/state-of-the-project/
    title: "LiveStore State of the project"
  - url: https://www.evolu.dev/docs/relay
    title: "Evolu Relay"
  - url: https://use-fireproof.com/docs/architecture/sync
    title: "Fireproof Sync"
  - url: https://www.npmjs.com/package/cojson
    title: "cojson package"
  - url: https://github.com/livestorejs/livestore
    title: "LiveStore GitHub repository"
---

## Key Claims
- Jazz browser persistence uses OPFS through a dedicated worker and a tab-leader model. Reads and writes continue offline; sync is query-subscription based, so the local replica is not necessarily a full database. Concurrent same-field writes use last-writer-wins and losing row versions remain in history ([Jazz sync](https://jazz.tools/docs/concepts/how-sync-works)).
- Jazz has a documented self-hosted server command with persistent file storage, auth modes, upstream edge mode, and an explicit in-memory mode that loses data on process exit. Hosted generated apps are deleted after 14 days if unclaimed ([Jazz server setup](https://jazz.tools/docs/getting-started/server-setup)).
- LiveStore is event-sourced and uses a central sync backend as global authority for total event ordering. The backend needs ordered cursor reads and notification or polling. The documentation explicitly says merge conflict handling and compaction are not implemented, and encryption remains TODO ([LiveStore Syncing](https://docs.livestore.dev/reference/syncing/)).
- LiveStore states it is beta, not ready for all production scenarios, and may change client/backend storage formats in minor releases; no specific 1.0 timeline is given ([State of the project](https://docs.livestore.dev/misc/state-of-the-project/)).
- Evolu Relay is stateless, supports multiple cloud and self-hosted relays, and can run on Cloudflare Workers. The project recommends a geographically separate secondary relay for resilience; its free relay is for testing, not a hosting commitment ([Evolu Relay](https://www.evolu.dev/docs/relay)).
- Fireproof uses encrypted, immutable, content-addressed ledger files, offline queues, and CRDT merging behind pluggable gateways. Fireproof Cloud uses Cloudflare for data and Supabase for metadata; custom gateways can target other servers or serverless functions ([Fireproof Sync](https://use-fireproof.com/docs/architecture/sync)).
- Search results identify cojson as MIT licensed and LiveStore as Apache-2.0 licensed, but the fetched technical pages do not establish complete commercial support or continuity terms ([cojson](https://www.npmjs.com/package/cojson); [LiveStore repository](https://github.com/livestorejs/livestore)).

## Technical Detail
Jazz is integrated and production-shaped, but its query-subscription model conflicts with a strict “full dataset locally” requirement unless the app subscribes to every required row and proves query replay/recovery behavior. Its documented local OPFS worker and self-hosted server reduce bespoke work, while LWW same-field conflict semantics are straightforward for household CRUD. The main POC questions are full-dataset subscription, export/restore, server data format portability, and whether the alpha server command is a continuity risk.

LiveStore maps closely to an immutable operations design: events are ordered, pulled, pushed, rebased, and materialized into local SQLite. However, the primary docs explicitly leave conflict handling, compaction, and encryption incomplete and label the project beta. Cloudflare support exists in the docs ecosystem, but those missing production behaviors are direct exclusions for a decision-grade backend unless a narrow single-writer proof makes them irrelevant.

Evolu is unusually aligned with multi-relay continuity and E2EE/self-hosting. A stateless relay on Workers is operationally attractive, but relay redundancy does not itself prove export/restore or browser persistence durability. Fireproof is similarly aligned with immutable encrypted files and pluggable object-like gateways; its metadata endpoint and gateway protocol are additional moving pieces, and the source material does not provide a complete independent backup/restore runbook.

## Relevance
Evolu and Fireproof merit POCs as integrated encrypted/immutable finalists; Jazz merits a POC only if query-subscription completeness is acceptable. LiveStore should be treated as an experimental event-log candidate, not assumed production-ready. Required falsifiable tests: full local dataset after cold start, offline edits and deletes, concurrent merge, relay/object-store loss, export/import, and browser/iOS recovery.

---
cycle: 8
purpose: "Close browser and PWA constraints with primary WebKit/MDN/standards compatibility evidence: iOS installed-PWA IndexedDB/OPFS durability and eviction, persistent storage, background/service-worker limitations, cross-tab behavior, foreground recovery, and IndexedDB versus SQLite-Wasm/OPFS proportionality for this dataset."
quality: junk
tags: [ios, pwa, indexeddb, opfs, webkit, unavailable]
sources: []
---

## Key Claims
- NOT FOUND — all planned search providers were unavailable or rate-limited before any source URLs were returned.

## Technical Detail
The required web_search calls failed with Exa HTTP 429 free-MCP rate-limit errors. Retry attempts using Gemini failed because no API key/browser login was configured; Perplexity failed because no API key was configured. No fetching was performed because the search-before-fetch rule could not be satisfied.

## Relevance
The browser/iOS durability, eviction, background execution, tab coordination, and SQLite-WASM proportionality questions remain unverified. Any shortlist must carry these as explicit risks until a successful primary-source cycle and device POC are completed.

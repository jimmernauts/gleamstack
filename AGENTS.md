# Agent guide — Gleamstack (Mealstack)

Recipe app: Gleam/Lustre SPA (`app/`) + Cloudflare Worker (`worker/`) + Turso Cloud (SQLite).
Browser keeps a local OPFS replica synced via `@tursodatabase/sync-wasm`; the Worker queries
Turso Cloud via `@tursodatabase/serverless`.

## Detailed guides

Read the guide that matches your task before starting:

| Guide | When |
|---|---|
| [.agent/workflows/project-onboarding.md](.agent/workflows/project-onboarding.md) | First session on this repo — architecture, layout, key decisions |
| [.agent/workflows/coding-standards.md](.agent/workflows/coding-standards.md) | Writing or reviewing Gleam/TS code |
| [.agent/workflows/testing-standards.md](.agent/workflows/testing-standards.md) | Adding or changing tests |
| [.agent/workflows/e2e-verification.md](.agent/workflows/e2e-verification.md) | Verifying the app end-to-end with wrangler dev + agent-browser |
| [.agent/workflows/agent-best-practices.md](.agent/workflows/agent-best-practices.md) | General working habits for this repo |

## Quick facts

- Secrets live in `.dev.vars` (repo root): `TURSO_URL`, `TURSO_AUTH_TOKEN`. Never hardcode the DB URL — the region can change.
- Schema is owned by the cloud: `db/migrations/001_initial_schema.sql`.
- Unit tests: `cd worker && bun test:unit`. Integration tests need `.dev.vars` plus `GEMINI_API_KEY`.
- Build app: `cd app && npx vite build`. Dev server: `npx wrangler dev --port 8787`.

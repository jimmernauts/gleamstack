[working-directory: './app']
build-app:
    bun run vite build --watch

[working-directory: './app']
dev:
    bun run vite dev

[working-directory: './app']
test-app:
    bun install
    gleam test
    gleam format --check src test
    bun run vite build

[working-directory: './worker']
build-worker:
    watchexec --restart --verbose --wrap-process=session --stop-signal SIGTERM --exts gleam,ts,mjs --debounce 500ms --watch src/ -- "gleam build"

serve-worker:
    bunx wrangler dev --port 5173 --log-level log

[working-directory: './worker']
test-worker:
    bun install
    bun test test/
    gleam test
    gleam build

[parallel]
dev-full: build-app build-worker serve-worker 

deploy: test-app test-worker
    bunx wrangler deploy
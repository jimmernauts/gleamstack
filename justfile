[working-directory: './app']
build-app:
    bun run vite build --watch

[working-directory: './app']
test-app:
    bun install
    gleam test
    gleam format --check src test
    bun run vite build

[working-directory: './worker']
test-worker:
    bun install
    gleam test
    gleam build

deploy: test-app test-worker
    bunx wrangler deploy

[working-directory: './app']
dev:
    bun run vite dev

dev-full: build-app
    bunx wrangler dev
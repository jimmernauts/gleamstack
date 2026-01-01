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
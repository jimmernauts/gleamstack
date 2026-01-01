#!/bin/bash

cd app
bun install
gleam test
gleam format --check src test
bun run build

cd ..
cd worker
bun install
gleam test
gleam build

cd ..
bunx wrangler deploy
---
trigger: always_on
---

1. this directory is a monorepo containing a few projects as part of a larger application.
2. the client project is written in Gleam, a type-safe language that compiles to either Erlang or JavaScript. Here we use it to compile a client-side Single Page Application using the Lustre framework for Gleam.
3. the server project is a stub only and we do not use it yet.
4. the command to run the client project is `bun run vite dev`

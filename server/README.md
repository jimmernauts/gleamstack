# mealstack_server

## What is this?

- This is the server component of the mealstack app.
- It's a simple server that scrapes a recipe page given a URL and returns either the recipe data or the JSON-LD data.
- It's written in Gleam, a language that compiles to JS, using the Glen web server package.
- It's called by the frontend upload page, in upload.ts/do_scrape_url the server address is hardcode to localhost:8000
- TODO: can I move it to the frontend somehow?
- TODO: can I deploy it to a serverless function?

TODO

[-] SHOPPING LIST
[] add ingredients from linked recipe
[] fix up nav icons in both small and large views
[] write proper readme
[] make planner entry edit into a popover card
[] replace typeahead with typeahead_2 in planner
[] add group by to recipe selector in typeahead
[] BUG: noticed double plan entry when editing an existing plan entry
[] BUG: save recipe slow
[] copy recipes from browser bookmarks
[] Add bunch of recipes
[] Add cooking notes and ratings to recipes, group by rating
[] PWA
[] work out process to correct side-by-side
[] extract nav, page layout to shared view functions
[] Build auth
[] deploy server to cloudflare as serverless function
[] deploy server to fly as erlang server (switch from glen to wisp)
[] Decide if stay SPA only or move to SSR / other. Maybe just classic SPA + Backend API - make scraping API endpoint more permanent. Or go other way and make scraping endpoint into a serverless function. Maybe the scraping endpoint could still be done browser-side in WASM somehow

WIP

DONE

[X] switch to Instant DB instead of triplit
[X] reseed all the data from triplit
[X] BUG: tag labels repeated on recipe list page
[X] BUG: loading recipe edit from importer only allows save, editing the fields doesn't work
[X] BUG: + and - buttons in edit recipe view don't show pointer on hover
[x] ~add optional field to recipe schema for source URL to link back to~ - OR make the existing source field display as a link if it is a URL
[x] BUG: text wrapping on title field in view recipe details (sometimes)
[x] BUG: text wrapping on title in edit recipe details (always)
[x] BUG: 'serves' field misaligned in edit recipe details
[x] BUG: delete button misaligned at mobile size in edit recipe details
[x] BUG: background color doesn't fill whole screen (esp. on mobile)
[x] BUG: strange plan behaviour around 29/9/2025. Outside of that date seems fine.
[x] improve layout of recipe list view. consider putting the HR after the recipe title at mobile size. also don't like the grouping headings being smaller than the recipe title. try using mono font at larger size instead.
[x] move page nav to bottom footer. working for planner, can't understand why not on the other pages

[X] Build OCR scanner (BYO AI API key?)

TODO

[-] SHOPPING LIST
[-] Planner refactor: WIP
    [x] Typeahead puts focus to end of input when typing each letter
    [x] add link to planner recipe card when recipe is of type recipe-slug
    [x] Planner card shows slug, not title, when recipe is selected from list
    [] Popover styling
    [x] Typeahead doesn't accept ctrl+a
    [x] Try and make the modal pop with the typeahead input as close as possible to the current cursor position when we hit the edit button
    [] DRAG N DROP ON MOBILE
    [] make it so planner day save only impacts 1 day not the whole week
[] add ingredients from linked recipe
[] fix up nav icons in both small and large views
[] add group by to recipe selector in typeahead
[] BUG: save recipe slow
[] copy recipes from browser bookmarks
[] Add bunch of recipes
[] Add cooking notes and ratings to recipes, group by rating
[] work out process to correct side-by-side
[] extract nav, page layout to shared view functions
[] Build auth
[] Import from URL to handle multiple recipes on a page (both JsonLD + HTML scraping) 


DONE
[x] PWA
[x] deploy server to cloudflare as serverless function
[x] write proper readme
[x] Popover background is too blurred
[x] Edit button on card only shows on hover, hidden on mobile. Make it just any click on the card itself loads the edit modal
[x] BUG: noticed double plan entry when editing an existing plan entry
[X] make planner entry edit into a popover card
[X] replace typeahead with typeahead_2 in planner
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

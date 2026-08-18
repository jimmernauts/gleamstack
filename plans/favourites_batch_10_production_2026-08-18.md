# First ten recipe-folder production scrape

- **Run time:** 2026-08-18 19:22:59–19:23:19 UTC
- **Source:** `plans/favourites_17_08_2026.html`, first ten distinct links under the `recipe` folder
- **Endpoint:** `https://mealstack.jimmernauts.workers.dev/api/scrape_url`
- **Request mode:** `all=true`, one sequential request per bookmark
- **Write behavior:** scrape-only; no recipe or settings writes were requested

## Summary

- Requests: 10
- HTTP 200: 7
- HTTP 500: 3
- Recipes returned: 10
- Multiple-recipe responses: 1
- AI fallback successes: 1

## Results

| # | Bookmark | HTTP | Worker status | Recipes | Result / issue |
|---:|---|---:|---|---:|---|
| 1 | BBC Good Food — Mediterranean potato salad | 200 | `ok` | 1 | JSON-LD: Mediterranean potato salad |
| 2 | EatingWell — Skillet Chicken with Orzo & Tomatoes | 500 | — | 0 | Upstream page returned HTTP 403; worker returned a text `URL Error` |
| 3 | EatingWell — Charred Shrimp, Pesto & Quinoa Bowls | 500 | — | 0 | Upstream page returned HTTP 403; worker returned a text `URL Error` |
| 4 | RecipeTin Eats — Pearl Barley Soup | 200 | `ok` | 1 | JSON-LD: Pearl Barley Soup |
| 5 | EatingWell — Eggplant Parmesan | 500 | — | 0 | Upstream page returned HTTP 403; worker returned a text `URL Error` |
| 6 | Guardian — Rukmini Iyer’s budget recipes with tinned beans | 200 | `ok` | 1 | JSON-LD: Orange, butter bean, spinach and olive salad |
| 7 | Guardian — four garlic recipes | 200 | `multiple_recipes` | 4 | JSON-LD: Roasted garlic herb butter; Cheesy roasted garlic bread; Garlic confit; Garlic confit potato mash bake |
| 8 | Recipe Girl — Pickled Cauliflower | 200 | `ok` | 1 | JSON-LD: Pickled Cauliflower |
| 9 | Broadsheet — Vegemite and cheese biscuits | 200 | `ok` | 1 | No JSON-LD; Gemini page-text fallback succeeded: Vegemite and cheese biscuits |
| 10 | Guardian — Sabzi polo | 200 | `ok` | 1 | JSON-LD: Herbed rice with saffron and pistachios |

## Issues

The three EatingWell URLs were reachable by the worker but returned upstream HTTP 403 responses. The production worker converted those into HTTP 500 text responses rather than structured scrape results. They need a separate retry/anti-bot decision before importing them.

The Broadsheet page exercised the no-JSON-LD Gemini fallback successfully. The Guardian garlic page exercised multi-recipe JSON-LD extraction successfully.

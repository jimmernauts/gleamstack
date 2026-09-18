# Migration export archive

This directory contains the final, validated production data export captured before the Mealstack migration to Turso. It is retained as a provider-independent recovery artifact and is not used by the running application.

## Status

- Captured: 2026-08-24
- Validation errors: none
- Records: 65 recipes, 3 tag-option groups, 196 plan days, and 3 shopping lists
- The settings record is intentionally not committed because it contained a secret that is now configured as a Worker secret.
- The legacy source applications and their credentials have been retired. Do not attempt to re-export or write back to them.

## Files

| File | Committed | Content |
|------|-----------|---------|
| `recipes.json` | Yes | Recipe records and JSON fields |
| `tag_options.json` | Yes | Tag category definitions |
| `plan.json` | Yes | Meal-plan day records |
| `settings.json` | No | Sensitive settings; gitignored |
| `shopping_lists.json` | Yes | Shopping-list records |
| `manifest.json` | Yes | Counts, hashes, and validation result |

Turso Cloud point-in-time recovery is the live recovery mechanism. This export remains the independent cutover snapshot; keep it protected because it contains production data.

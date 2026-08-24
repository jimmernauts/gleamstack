# InstantDB Export Archive

This directory holds the production InstantDB export for the Gleamstack architecture migration.

## Status

**Pending production export.** The scripts are tested against the dev instance. The production export needs:

1. Production credentials: `INSTANT_APP_ID=eeaf3b82-5b5d-40c4-a29a-b68988377c3c` and a valid `INSTANT_ADMIN_TOKEN` for the production app.
2. Run: `set -a && source worker/.dev.vars && set +a && npx tsx worker/scripts/export_instantdb.ts`
3. Verify: `npx tsx worker/scripts/verify_export_sqlite.ts`

## Production change confirmation

After the final export:
- The production app must not be used (no new recipes, plan changes, or shopping lists).
- Before migration (M9), re-run the export and compare `manifest.json` hashes to confirm no drift.
- If hashes differ, take a fresh export as the new baseline.

InstantDB has no server-side write-disable mechanism. This confirmation is procedural — the owner agrees not to use the app after the final export.

## Files

| File | Committed | Content |
|------|-----------|---------|
| `recipes.json` | Yes | All recipes with IDs, JSON fields |
| `tag_options.json` | Yes | Tag category definitions |
| `plan.json` | Yes | Meal plan day records |
| `settings.json` | **No** (gitignored) | Contains Gemini API key |
| `shopping_lists.json` | Yes | Shopping list records |
| `manifest.json` | Yes | Counts, SHA-256 hashes, validation |

## Re-export to verify no changes

```bash
cd /path/to/gleamstack
# Save old manifest for comparison
cp plans/archive/export/manifest.json plans/archive/export/manifest-previous.json

# Re-export
set -a && source worker/.dev.vars && set +a
npx tsx worker/scripts/export_instantdb.ts

# Compare hashes
diff plans/archive/export/manifest-previous.json plans/archive/export/manifest.json
```

If hashes match (ignoring `exported_at`), production data has not changed.

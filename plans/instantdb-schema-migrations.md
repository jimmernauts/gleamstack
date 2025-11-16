# InstantDB Schema Migrations

## Overview

InstantDB uses a schema-as-code approach where you define your data model in `instant.schema.ts` and use the CLI to push changes to production. Unlike traditional ORMs, InstantDB does not have explicit migration scripts - instead, it handles schema changes declaratively.

## Schema Definition

Schemas are defined in `instant.schema.ts` with three core building blocks:

- **Entities**: Equivalent to tables/collections (e.g., `posts`, `users`, `comments`)
- **Attributes**: Properties/fields on entities (e.g., `title`, `body`, `createdAt`)
- **Links**: Relationships between entities (e.g., `postAuthor`, `commentPost`)

## Adding New Entities and Attributes

### Method 1: CLI Push (Recommended for Production)

```bash
npx instant-cli push schema
```

**How it works:**

1. CLI compares your local `instant.schema.ts` with production schema
2. Shows a diff of changes (ADD ENTITY, ADD ATTR, ADD LINK)
3. Asks for confirmation
4. Applies changes automatically
5. **No data loss** - only adds new columns/tables

**Example output:**

```
The following changes will be applied to your production schema:
ADD ENTITY profiles.id
ADD ENTITY posts.id
ADD ATTR profiles.nickname :: unique=false, indexed=false
ADD ATTR posts.title :: unique=false, indexed=false
ADD LINK posts.author <=> profiles.authoredPosts
? OK to proceed? yes
Schema updated!
```

### Method 2: Automatic Creation (Development Only)

- If no schema is defined, InstantDB automatically creates entities/attributes when you call `transact()`
- Useful for rapid prototyping
- **Not recommended for production** - disable by setting appropriate permissions

## Renaming or Deleting Attributes

**Important Limitation:**
The CLI command `npx instant-cli push schema` **does NOT support** renaming or deleting attributes yet.

### Must Use Dashboard Explorer Instead:

1. Go to [Dashboard](https://instantdb.com/dash)
2. Click "Explorer"
3. Click on your entity (e.g., "posts")
4. Click "Edit Schema"
5. Click the attribute you want to modify
6. Use the modal to:
   - Rename the attribute (preserves data)
   - Index the attribute
   - Delete the attribute (data is lost)

### Syncing Local Files After Dashboard Changes:

```bash
npx instant-cli pull
```

This updates your local `instant.schema.ts` and `instant.perms.ts` files to match production.

## Data Migration Strategies

InstantDB does not have explicit data migration scripts. Handle data transformations at the application level.

### Adding New Fields

- New attributes are added to schema
- Existing records will have `null`/`undefined` for new fields until updated
- No migration code needed - just add the field and push

### Changing Field Types

Since direct type changes aren't supported:

1. Add new field with new type
2. Write application code to copy/transform data from old field to new field
3. Once migration is complete, delete old field via dashboard

### Renaming Fields

- Use Dashboard Explorer to rename (preserves all data)
- Update local schema with `npx instant-cli pull`
- Update application code to use new field name

### Deleting Fields

- Use Dashboard Explorer to delete
- **Warning:** Data is permanently lost
- Update local schema with `npx instant-cli pull`

## Migration Pattern for Complex Type Changes

When changing from one type structure to another (e.g., `title: String` to `recipe: PlannedRecipe`):

### Option 1: Dual-Field Migration (Safest)

1. **Add new field** alongside existing field (don't remove old field yet)

   ```typescript
   // instant.schema.ts
   posts: i.entity({
     title: i.string(), // old field
     recipe: i.json(), // new field
   });
   ```

2. **Push schema** with CLI

   ```bash
   npx instant-cli push schema
   ```

3. **Write migration code** in your application:

   ```gleam
   // On read, check if new field exists, otherwise migrate from old field
   fn migrate_plan_day(plan_day: PlanDay) -> PlanDay {
     PlanDay(
       ..plan_day,
       planned_meals: list.map(plan_day.planned_meals, fn(meal) {
         case meal.recipe, meal.title {
           Some(_), _ -> meal  // Already migrated
           None, Some(title) ->
             PlannedMealWithStatus(
               ..meal,
               recipe: Some(PlannedRecipe.RecipeName(title))
             )
           None, None -> meal
         }
       })
     )
   }
   ```

4. **Lazy migration**: Migrate data as it's read and saved

   - Users naturally migrate their own data as they use the app
   - No downtime required
   - Gradual rollout

5. **After migration is complete**, delete old field via Dashboard Explorer

### Option 2: Schema-Flexible Approach (Simpler)

Since InstantDB is schema-flexible and Gleam compiles to JavaScript:

- Change your Gleam types immediately
- Old data with `title` still exists in DB
- Decoder handles both cases:
  ```gleam
  fn planned_meal_decoder() -> Decoder(PlannedMealWithStatus) {
    use for <- decode.field("for", meal_decoder())
    // Try new field first
    use recipe_result <- decode.try(
      decode.optional_field("recipe", None, decode.optional(planned_recipe_decoder()))
    )
    // Fall back to old field if new field doesn't exist
    use title <- decode.optional_field("title", None, decode.optional(decode.string))

    let recipe = case recipe_result, title {
      Some(r), _ -> Some(r)
      None, Some(t) -> Some(PlannedRecipe.RecipeName(t))
      None, None -> None
    }

    decode.success(PlannedMealWithStatus(for: for, recipe: recipe, complete: None))
  }
  ```
- Old data gets overwritten as users edit their plans
- No explicit migration needed

## Workflow Summary

### Development Workflow

1. Make changes to `instant.schema.ts`
2. Run `npx instant-cli push schema`
3. Test changes locally
4. Commit schema file to version control

### For Renames/Deletes

1. Make changes in Dashboard Explorer
2. Run `npx instant-cli pull` to sync local files
3. Update application code
4. Commit updated schema file

### Going to Production

- Restrict creating new attributes automatically (set in permissions)
- Consider separate apps for development and production
- Always test schema changes in development first

## CLI Commands Reference

```bash
# Login to Instant
npx instant-cli login

# Initialize schema and permissions files
npx instant-cli init

# Push schema changes to production
npx instant-cli push schema

# Push permission changes to production
npx instant-cli push perms

# Pull latest schema and permissions from production
npx instant-cli pull

# Logout
npx instant-cli logout
```

## Environment Variables

The CLI looks for app ID in these environment variables (in order):

- `INSTANT_APP_ID`
- `NEXT_PUBLIC_INSTANT_APP_ID` (Next.js)
- `PUBLIC_INSTANT_APP_ID` (Svelte)
- `VITE_INSTANT_APP_ID` (Vite)
- `NUXT_PUBLIC_INSTANT_APP_ID` (Nuxt)
- `EXPO_PUBLIC_INSTANT_APP_ID` (Expo)

Schema file location (defaults to `./`, `./src`, or `./app`):

- `INSTANT_SCHEMA_FILE_PATH` - custom location for `instant.schema.ts`
- `INSTANT_PERMS_FILE_PATH` - custom location for `instant.perms.ts`

## Key Takeaways

✅ **Adding is easy**: Use `npx instant-cli push schema`  
❌ **Deleting/renaming**: Must use Dashboard Explorer  
⚠️ **Data transformations**: Write application-level migration code  
📝 **No migration scripts**: InstantDB is schema-flexible, handle migrations in app logic  
🔄 **Sync local files**: Use `npx instant-cli pull` after dashboard changes  
🎯 **Type safety**: Pass schema to `init()` for full TypeScript/type checking support

## Best Practices

1. **Always test schema changes in development first**
2. **Use version control** for `instant.schema.ts` and `instant.perms.ts`
3. **For breaking changes**, use dual-field migration pattern
4. **Document migrations** in your codebase
5. **Consider lazy migration** to avoid downtime
6. **Handle both old and new data formats** in decoders during transition periods
7. **Clean up old fields** only after confirming migration is complete

## Resources

- [InstantDB Modeling Data Docs](https://www.instantdb.com/docs/modeling-data)
- [InstantDB CLI Docs](https://www.instantdb.com/docs/cli)
- [InstantDB Workflow Docs](https://www.instantdb.com/docs/workflow)
- [InstantDB Dashboard](https://instantdb.com/dash)

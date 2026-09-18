# Gleamstack product backlog

The Turso migration, production cutover, and retired-backend cleanup are complete. Restore Bun test execution first through workspace task `t-9859`; after that, work through the confirmed backlog below in order.

## Confirmed next work

1. **Verify offline sync behavior** — `t-9886`
   - Check startup pulls, offline writes, reconnect/push behavior, remote refresh, schema reset, and OPFS lock handling.
   - This is a product/runtime verification task, separate from restoring Bun-based tests.

2. **Import recipes from browser bookmarks** — `t-9889`
   - Decide which remaining bookmark corpus is wanted.
   - Build or restore a Turso-era parse/import workflow; the retired InstantDB importer is gone.

3. **Polish navigation icons** — `t-9888`
   - Audit the mobile and desktop navigation affordances and replace inconsistent or unclear icons.

4. **Define and implement recipe-selector grouping** — `t-9887`
   - Choose the grouping dimension, such as tags or another recipe category, then group planner typeahead results accordingly.

5. **Complete shopping-list recipe and planner linking** — `t-9885`
   - Finish the linked-recipe picker flow.
   - Add recipe ingredients with clear provenance and duplicate behavior.
   - Persist plan-linked recipes and cover the plan/list navigation workflow.

6. **Add recipe notes and ratings** — `t-9884`
   - Define the schema, editing UI, display behavior, persistence, and rating-based filtering.

## Deferred or removed

- **Application auth / multi-user accounts:** deferred. The app is intentionally private and single-user behind Cloudflare Access.
- **Side-by-side correction workflow:** removed until there is a concrete use case and acceptance criteria.
- **Bulk recipe additions:** folded into the bookmark-import task rather than kept as a vague duplicate.
- **Multiple recipes from one URL:** implemented in the Worker scraper and covered by the existing collection tests.
- **Shared navigation and page-layout extraction:** already represented by the `nav_footer` and `page_title` components.

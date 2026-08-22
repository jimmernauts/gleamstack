## Summary

The announcement says Instant Cloud is being wound down for existing users: new signups are closed, existing users are told to migrate off Instant Cloud “within the next 12 months,” and “all cloud apps will shut down” on August 31, 2027. Backups remain available for one additional year, until August 31, 2028. The page does not describe a continued hosted service after that date.

The stated replacement is self-hosted Instant. The announcement links to self-hosting and migration guidance and says, “All of Instant is open source,” presenting migration as intended to be as seamless as possible. For Mealstack, an existing app using Instant’s client and admin packages should therefore be treated as dependent on a hosted Instant Cloud app if its app/backend endpoints are in Instant Cloud; the announcement itself does not specify the code/configuration changes required to move that app.

## Key Findings

- **New signups:** “New signups are closed.” ([announcement](https://www.instantdb.com/essays/instant_team_joins_openai))
- **Existing-user deadline:** Existing Instant Cloud users “should migrate off of Instant Cloud within the next 12 months.” The page does not state the calendar date from which that 12-month period is measured. ([announcement](https://www.instantdb.com/essays/instant_team_joins_openai))
- **Refunds:** “Any subscriptions that were started after July 31st, 2026 will be fully refunded.” The announcement gives no refund process, timing, or clarification of whether this applies automatically to every such subscription. ([announcement](https://www.instantdb.com/essays/instant_team_joins_openai))
- **Shutdown:** “On August 31st, 2027, all cloud apps will shut down.” ([announcement](https://www.instantdb.com/essays/instant_team_joins_openai))
- **Backups:** “Backups will stay available for 12 more months, until August 31st, 2028.” The page does not define which backup operations remain available or how backups can be retrieved. ([announcement](https://www.instantdb.com/essays/instant_team_joins_openai))
- **Open-source availability:** “All of Instant is open source.” The announcement does not identify the repository, license, release/version, support policy, or whether every hosted-service component is operationally equivalent when self-hosted. ([announcement](https://www.instantdb.com/essays/instant_team_joins_openai))
- **Migration/hosting guidance:** Users are directed to a “guide to help you self-host Instant and migrate your apps.” The page gives no hosting provider, infrastructure requirements, cost, operational burden, migration steps, export format, downtime expectation, or data-integrity procedure. ([announcement](https://www.instantdb.com/essays/instant_team_joins_openai))
- **Important for Mealstack:** The page does not mention `@instantdb/core`, `@instantdb/admin`, SDK compatibility, API endpoints, auth, files, realtime behavior, schema/permissions, or admin tokens. It also does not explicitly say whether an app can remain on Instant Cloud until August 31, 2027, only recommending migration within the next 12 months.

## Sources

- [The Instant team joins OpenAI](https://www.instantdb.com/essays/instant_team_joins_openai) — exact announcement analyzed; all substantive claims above are limited to this page.

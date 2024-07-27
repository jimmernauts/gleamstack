import { type ClientSchema, Schema as S } from "@triplit/client";
/**
 * Define your schema here. After:
 * - Pass your schema to your Triplit client
 * - Push your schema to your Triplit server with 'triplit schema push'
 *
 * For more information about schemas, see the docs: https://www.triplit.dev/docs/schemas
 */

export const schema = {
    recipes: {
      schema: S.Schema({
        id: S.Id(),
        slug: S.String(),
        title: S.String(),
        cook_time: S.Number(),
        prep_time: S.Number(),
        serves: S.Number(),
        author: S.Optional(S.String()),
        source: S.Optional(S.String()),
        ingredients: S.Optional(S.String()),
        method_steps: S.Optional(S.String()),
        tags: S.Optional(S.String()), 
        shortlisted: S.Optional(S.Boolean()),
      }),
    },
    tag_options: {
      schema: S.Schema({
        id: S.Id(),
        name: S.Optional(S.String()),
        options: S.Optional(S.String())
      }),
    },
    plan: {
      schema: S.Schema({
        id: S.Id(),
        date: S.Number(),
        planned_meals: S.Optional(S.String())
      }),
    },
} satisfies ClientSchema;

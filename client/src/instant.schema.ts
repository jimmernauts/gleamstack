// Docs: https://www.instantdb.com/docs/modeling-data

import { i } from "@instantdb/core";

  // recipes: {
  //     schema: S.Schema({
  //       id: S.Id(),
  //       slug: S.String(),
  //       title: S.String(),
  //       cook_time: S.Number(),
  //       prep_time: S.Number(),
  //       serves: S.Number(),
  //       author: S.Optional(S.String()),
  //       source: S.Optional(S.String()),
  //       ingredients: S.Optional(S.String()),
  //       method_steps: S.Optional(S.String()),
  //       tags: S.Optional(S.String()), 
  //       shortlisted: S.Optional(S.Boolean()),
  //     }),
  //   },
  //   ,
  //   plan: {
  //     schema: S.Schema({
  //       id: S.Id(),
  //       date: S.Number(),
  //       planned_meals: S.Optional(S.String())
  //     }),
  //   },
  //   settings: {
  //     schema: S.Schema({
  //       id: S.Id(),
  //       api_key: S.Optional(S.String()),
  //     })
  //   }




const _schema = i.schema({
  entities: {
    recipes: i.entity({
      slug: i.string(),
      title: i.string(),
      cook_time: i.number(),
      prep_time: i.number(),
      serves: i.number(),
      author: i.string().optional(),
      source: i.string().optional(),
      ingredients: i.json().optional(),
      method_steps: i.json().optional(),
      tags: i.json().optional(), 
      shortlisted: i.boolean().optional(),
    }),
    tag_options: i.entity({
      name: i.string().optional(),
      options: i.json().optional(),
    }),
    plan: i.entity({
      date: i.number(),
      planned_meals: i.json().optional(),
    }),
    settings: i.entity({
      api_key: i.string().optional(),
    }),
  },
  links: {},
  rooms: {},
});

// This helps Typescript display nicer intellisense
type _AppSchema = typeof _schema;
interface AppSchema extends _AppSchema {}
const schema: AppSchema = _schema;

export type { AppSchema };
export default schema;

import {createSchema, createTableSchema} from '@rocicorp/zero';

const recipesSchema = createTableSchema({
  tableName: 'recipes',
  columns: {
    id: 'string',
    slug: 'string',
    title: 'string',
    cook_time: 'number',
    prep_time: 'number',
    serves: 'number',
    author: { type: 'string', optional:true},
    source: { type: 'string', optional:true},
    ingredients: { type: 'json', optional:true},
    method_steps: { type: 'json', optional:true},
    tags: { type: 'json', optional:true},
    shortlisted: { type: 'boolean', optional:true},
  },
  primaryKey: 'id',
});

const tagOptionsSchema = createTableSchema({
  tableName: 'tag_options',
  columns: {
    id: 'string',
    name: { type: 'string', optional:true},
    options: { type: 'json', optional:true},
  },
  primaryKey: 'id',
});

const plansSchema = createTableSchema({
  tableName: 'plans',
  columns: {
    id: 'string',
    date: 'number',
    planned_meals: { type: 'json', optional:true},
  },
  primaryKey: 'id',
});

export default createSchema({
  version: 1,
  tables: {recipes: recipesSchema,
  tag_options: tagOptionsSchema,
  plans: plansSchema,
  }
});
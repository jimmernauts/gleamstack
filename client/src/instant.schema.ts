// Docs: https://www.instantdb.com/docs/modeling-data

import { i } from "@instantdb/core";

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
			date: i.number().indexed(),
			planned_meals: i.json().optional(),
		}),
		settings: i.entity({
			api_key: i.string().optional(),
		}),
		shopping_lists: i.entity({
			items: i.json().optional(),
			status: i.string(),
			date: i.number().indexed(),
			linked_recipes: i.json().optional(),
			linked_plan: i.number().optional(),
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

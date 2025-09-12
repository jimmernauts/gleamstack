import type { Recipe, PlanDay } from "../../common/types.ts";
import { init, id } from "@instantdb/core";
import schema from "./instant.schema.ts";

const db = init({
	appId: "eeaf3b82-5b5d-40c4-a29a-b68988377c3c",
	schema,
});

// TAG OPTIONS

export async function do_get_tagoptions() {
	const query = { tag_options: {} };
	const result = await db.queryOnce(query);
	return result.data.tag_options;
}

// RECIPES

export async function do_get_recipes() {
	const query = { recipes: {} };
	const result = await db.queryOnce(query);
	return result.data.recipes;
}

export function do_subscribe_to_recipe_summaries(
	dispatch: (result: unknown) => void,
): () => void {
	const query = {
		recipes: {
			$: {
				fields: [
					"slug",
					"title",
					"cook_time",
					"prep_time",
					"serves",
					"author",
					"source",
					"tags",
					"shortlisted",
				],
			},
		},
	};
	const result = db.subscribeQuery(query, dispatch);
	console.log(result);
	return result;
}

export function do_subscribe_to_one_recipe_by_slug(
	slug: string,
	dispatch: (result: unknown) => void,
): () => void {
	const query = {
		recipes: {
			$: {
				where: {
					slug: slug,
				},
			},
		},
	};
	const result = db.subscribeQuery(query, dispatch);
	return result;
}

export async function do_get_one_recipe_by_slug(slug: string) {
	const query = {
		recipes: {
			$: {
				where: {
					slug: slug,
				},
			},
		},
	};
	const result = await db.queryOnce(query);
	return result.data.recipes;
}

export async function do_save_recipe(recipe: Recipe) {
	// upsert
	//https://stackoverflow.com/questions/11704267/in-javascript-how-to-conditionally-add-a-member-to-an-object
	const obj: Recipe = {
		...(recipe.id !== "" ? { id: recipe.id } : {}),
		slug: recipe.slug,
		title: recipe.title,
		cook_time: recipe.cook_time,
		prep_time: recipe.prep_time,
		serves: recipe.serves,
		...(recipe.author !== "" ? { author: recipe.author } : {}),
		...(recipe.source !== "" ? { source: recipe.source } : {}),
		...(recipe.tags !== "null" && recipe.tags !== "{}"
			? { tags: recipe.tags }
			: {}),
		...(recipe.ingredients !== "null" && recipe.ingredients !== "{}"
			? { ingredients: recipe.ingredients }
			: {}),
		...(recipe.method_steps !== "null" && recipe.method_steps !== "{}"
			? { method_steps: recipe.method_steps }
			: {}),
		...(recipe.shortlisted !== false
			? { shortlisted: recipe.shortlisted }
			: {}),
	};
	const id_to_use = recipe.id || id();
	console.log("do_save_recipe upsert: ", obj);
	const result = await db.transact(
		db.tx.recipes[id_to_use].update({
			slug: obj.slug,
			title: obj.title,
			cook_time: obj.cook_time,
			prep_time: obj.prep_time,
			serves: obj.serves,
			author: obj.author,
			source: obj.source,
			tags: obj.tags,
			ingredients: obj.ingredients,
			method_steps: obj.method_steps,
			shortlisted: obj.shortlisted,
		}),
	);
	return result;
}

export async function do_delete_recipe(id: string) {
	const result = await db.transact(db.tx.recipes[id].delete());
	return result;
}

// PLAN

export async function do_get_plan(
	startDate: number,
	endDate: number,
): Promise<
	{
		id: string;
		date: number;
		planned_meals?: string | undefined;
	}[]
> {
	const query = {
		plan: {
			$: {
				where: {
					and: [{ date: { $gte: startDate } }, { date: { $lte: endDate } }],
				},
			},
		},
	};
	const result = await db.queryOnce(query);
	return result.data.plan;
}

export function do_subscribe_to_plan(
	dispatch: (result: unknown) => void,
	startDate: number,
	endDate: number,
): () => void {
	const query = {
		plan: {
			$: {
				where: {
					and: [{ date: { $gte: startDate } }, { date: { $lte: endDate } }],
				},
			},
		},
	};
	const result = db.subscribeQuery(query, dispatch);
	return result;
}

export async function do_save_plan(plan: PlanDay[]): Promise<PlanDay[]> {
	for (const day of plan) {
		const plan_day_to_update = await do_get_plan(day.date, day.date);
		const id_to_update =
			plan_day_to_update.length > 0 ? plan_day_to_update[0].id : id();
		await db.transact(
			db.tx.plan[id_to_update].update({
				date: day.date,
				planned_meals: JSON.stringify(day.planned_meals),
			}),
		);
	}

	return plan;
}

export async function do_retrieve_settings() {
	const query = {
		settings: {
			$: {
				limit: 1,
			},
		},
	};
	const result = await db.queryOnce(query);
	return result.data.settings;
}

export async function do_save_settings(api_key: string) {
	console.log("saving settings...", api_key);
	// TODO: make this dynamic
	const result = await db.transact(
		db.tx.settings["59b9c881-bd5a-494d-97cc-7f7c50ccb362"].update({
			api_key: api_key,
		}),
	);
	console.log(result);
	return result;
}

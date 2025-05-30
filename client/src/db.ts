import { schema } from "./schema.ts";
import { TriplitClient } from "@triplit/client";
import type { Recipe, PlanDay } from "../../common/types.ts";

export const client = new TriplitClient({
	storage: "indexeddb",
	schema,
	serverUrl: "https://912d44e1-48a6-46b7-b6b9-7bc0fcd59a81.triplit.io",
	token:
		"eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ4LXRyaXBsaXQtdG9rZW4tdHlwZSI6ImFub24iLCJ4LXRyaXBsaXQtcHJvamVjdC1pZCI6IjkxMmQ0NGUxLTQ4YTYtNDZiNy1iNmI5LTdiYzBmY2Q1OWE4MSIsImlhdCI6MTcyMTU2ODg2OX0.mLTejtnhczt5RxdYK1cnnNbeQ7vevO5z7oQD23MJA6AIfiyYS9S5F1il5PcCyLwJyObGomOJE9qIJbfwoHsBzs1QQEg3HOjgMBJAIRhbaWhOJn1BZZ8h2eaZWKpwBQuUpHi37-T0uTnABP7WUTZEFshHWEv5JlUYczehBvUFA8AulNjZDJJrJuEqHNgL3e0OaUZbstWArftiJpoR0htiZ7_HzFRHm5nivgsVO5zSBVeURM5Eygf67N6y6krLxK7jNHIjP0EbFu2DvC2nB9wrfjebChf-x6FRDFZpnMsrMuGn9-gWoyTapMjm-q4br1Sns7oIFbKKhJI1-9LzqifwYaflWrwLEroXvkoG9fJwJConmEPE9HWR20s_75wH7B7-g3ihgHP9I820qQ1WpWuVCF6xIIG3_RwDgt-T_b08HPMAQdo5H5fHxcxSeY-pSua1TUKFeDZjKNdtZhexWfHxAGJP9gKdS2sTY4pz43dRKvIahUGRsoQ5jOMv0jONsT2z8iMnXPsmOiyLZd36Ba6FKaltJBgpoM22GkdsMFd8OIYAa-ROjgKkF1ku2WX78V53AkdAEika26-zdNv3LAK1b40tebvt58imnmR2H2PPx62wAWgsXTTuMSVhm4dMDb1zeKGXOsQCHkNUw-DsgY-3bvj0-TMG8WPU3GPpvBIj_l8",
});

export async function do_get_recipes() {
	const query = client.query("recipes").build();
	const result = await client.fetch(query);
	console.log("do_get_recipes result: ", result);
	return result;
}

export async function do_get_tagoptions() {
	const query = client.query("tag_options").build();
	const result = await client.fetch(query);
	return result;
}

export async function do_save_recipe(recipe: Recipe) {
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
	if (recipe.id) {
		console.log("do_save_recipe update: ", obj);
		const result = await client.update("recipes", recipe.id, async (e) => {
			e.slug = obj.slug;
			e.title = obj.title;
			e.cook_time = obj.cook_time;
			e.prep_time = obj.prep_time;
			e.serves = obj.serves;
			e.author = obj.author;
			e.source = obj.source;
			e.tags = obj.tags;
			e.ingredients = obj.ingredients;
			e.method_steps = obj.method_steps;
			e.shortlisted = obj.shortlisted;
		});
		return result;
	}

	console.log("do_save_recipe insert: ", obj);
	const result = await client.insert("recipes", obj);
	return result;
}

export async function do_save_plan(plan: PlanDay[]) {
	await client.transact(async (tx) => {
		for (const day of plan) {
			const result = await tx.insert("plan", {
				id: day.date.toString(),
				date: day.date,
				planned_meals: JSON.stringify(day.planned_meals),
			});
		}
	});
	return plan;
}

export async function do_get_plan(startDate: number, endDate: number) {
	const query = client
		.query("plan")
		.where([
			["date", ">=", startDate],
			["date", "<=", endDate],
		])
		.build();
	const result = await client.fetch(query);
	return result;
}

export function do_subscribe_to_plan(
	dispatch: (result: unknown) => void,
	startDate: number,
	endDate: number,
) {
	console.log("do_subscribe_to_plan", startDate, endDate, dispatch);
	const query = client
		.query("plan")
		.where([
			["date", ">=", startDate],
			["date", "<=", endDate],
		])
		.build();
	const result = client.subscribe(query, dispatch, () => {});
	return result;
}

export function do_subscribe_to_recipe_summaries(
	dispatch: (result: unknown) => void,
) {
	const query = client
		.query("recipes")
		.select([
			"id",
			"title",
			"slug",
			"cook_time",
			"prep_time",
			"serves",
			"author",
			"source",
			"tags",
		])
		.build();
	const result = client.subscribe(query, dispatch, () => {});
	return result;
}

export function do_subscribe_to_one_recipe_by_slug(
	slug: string,
	dispatch: (result: unknown) => void,
) {
	const query = client
		.query("recipes")
		.select([
			"id",
			"title",
			"slug",
			"cook_time",
			"prep_time",
			"serves",
			"author",
			"source",
			"tags",
			"ingredients",
			"method_steps",
			"shortlisted",
		])
		.where([["slug", "=", slug]])
		.limit(1)
		.build();
	const result = client.subscribe(query, dispatch, () => {});
	return result;
}

export async function do_get_one_recipe_by_slug(slug: string) {
	const query = client
		.query("recipes")
		.where([["slug", "=", slug]])
		.build();
	const result = await client.fetchOne(query);
	return result;
}

export async function do_retrieve_settings() {
	const query = client.query("settings").limit(1).build();
	const result = await client.fetchOne(query);
	return result?.api_key;
}

export async function do_save_settings(api_key: string) {
	console.log("saving settings...", api_key);
	const result = await client.insert("settings", {
		id: "james",
		api_key: api_key,
	});
	console.log(result);
	return result;
}

export async function do_delete_recipe(id: string) {
	console.log("deleting recipe: ", id);
	const result = await client.delete("recipes", id);
	return result;
}

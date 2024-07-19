import { Ok, Error } from "./gleam.mjs";
import Dexie from 'dexie';
import { dexieCloud, type DexieCloudTable } from 'dexie-cloud-addon' 
import type { Recipe, TagOption, PlanDay } from './types.ts';
import { RecipeSeed, TagOptionSeed } from './seed.ts';


const db = new Dexie('db',{addons:[dexieCloud]}) as Dexie & {
    recipes: DexieCloudTable<Recipe>
    tag_options: DexieCloudTable<TagOption>
    plan: DexieCloudTable<PlanDay>
}

db.version(1).stores({
  recipes: '@id, slug, title, cook_time, prep_time, serves, ingredients, method_steps, tags, shortlisted',
  tag_options: '@id, name, options',
  plan: 'date, planned_meals'
});

db.cloud.configure({
    databaseUrl: 'https://zfq8bs6bi.dexie.cloud',
    requireAuth: true
})

export async function do_get_recipes() {    
	const result = await db.recipes.toArray().catch((e) => {
		console.log("do_get_recipes error: ", e);
		return new Error(e);
	});
	console.log("do_get_recipes result: ", result);
	return new Ok(result);
}

export async function do_get_tagoptions() {
	const result = await db.tag_options.toArray().catch((e) => {
		console.log("do_tag_options error: ", e);
		return new Error(e);
	});
	console.log("do_get_tag_options result: ", result);
	return new Ok(result);
}

export async function do_save_recipe(recipe: Recipe) {
	const result = await db.recipes.put(recipe).catch((e) => {
		console.log("do_save_recipe error: ", e);
		return new Error(e);
	});
	console.log("do_save_recipe result: ", result);
	return new Ok(result);
}

export async function do_get_plan(startDate: number, endDate: number) {
	const result = await db.plan.where("date").between(startDate, endDate).toArray().catch((e) => {
		console.log("do_get_plan error: ", e);
		return new Error(e);
	});
	console.log("do_get_plan result: ", result);
	return new Ok(result);
}

export async function do_save_plan(plan: PlanDay[]) {
	console.log("do_save_plan: ", plan);
		const result = await db.plan.bulkPut(plan).catch((e) => {
			console.log("do_save_plan error: ", e);
			return new Error(e);
		});
	return new Ok(result);
}
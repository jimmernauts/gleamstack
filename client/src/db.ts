import { Ok, Error } from "./gleam.mjs";
import { nanoid } from "nanoid";
import type { Recipe, TagOption } from "./types.ts";
import { seedDb } from "./seed.ts";

const sqliteWasm = await import("https://esm.sh/@vlcn.io/crsqlite-wasm@0.16.0");
const sqlite = await sqliteWasm.default(
	() => "https://esm.sh/@vlcn.io/crsqlite-wasm@0.16.0/dist/crsqlite.wasm",
);
const db = await sqlite.open("mealstack.db");

function replacer(key, value) {
	if(value instanceof Map) {
	  return {
		dataType: 'Map',
		value: Array.from(value.entries()), // or with spread: value: [...value]
	  };
	}
	  return value;
  }
  function reviver(key, value) {
	if(typeof value === 'object' && value !== null) {
	  if (value.dataType === 'Map') {
		return new Map(value.value);
	  }
	}
	return value;
  }


export async function prepareTables() {
	const findTagOptionsTable = await db.execA(
		"SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE `type`='table' AND `name`='tag_options')",
	);
	const tagOptionsTableExists = findTagOptionsTable[0][0];
	console.log(tagOptionsTableExists);
	if (!tagOptionsTableExists) {
		console.log("creating tag_options table...");
		await db.execA(
			"CREATE TABLE `tag_options` ( \
			`id` text PRIMARY KEY NOT NULL, \
			`name` text NOT NULL, \
			`options` text NOT NULL \
		)",
		);
	}
	const findRecipesTable = await db.execA(
		"SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE `type`='table' AND `name`='recipes')",
	);
	const recipesTableExists = findRecipesTable[0][0];
	console.log(recipesTableExists);
	if (!recipesTableExists) {
		console.log("creating recipes table...");
		await db.execA(
			"CREATE TABLE `recipes` ( \
			`id` text PRIMARY KEY NOT NULL, \
			`slug` text, \
			`title` text, \
			`cook_time` integer, \
			`prep_time` integer, \
			`serves` integer, \
			`ingredients` text, \
			`method_steps` text, \
			`tags` text, \
			`shortlisted` integer \
		)",
		);
	}
}

export async function listTagOptions() {
	console.log("listTagOptions");
	const findRows = await db.execO("SELECT EXISTS(SELECT 1 FROM tag_options)");
	const exists = findRows[0];
	if (!exists) {
		return new Ok([]);
	}
	const result = await db.execO("SELECT * FROM tag_options");
	const mapped = result.map(x => {
		x.options = JSON.parse(x.options)
		return x
	})
	console.log("tagoptions mapped: ",mapped)
	return mapped;
}

export async function addTagOption(tagOption: TagOption) {
	console.log("addTagOption: ", tagOption);
	const result = await db.execA(
		`INSERT INTO tag_options (id, name, options) VALUES (
			'${nanoid()}'
			,'${tagOption.name}'
			,'${JSON.stringify(tagOption.options)}'
		)`);
	console.log(result);
	return result ? new Ok(result) : new Error(undefined);
}

export async function listRecipes() {
	console.log("listRecipes");
	const findRows = await db.execO("SELECT EXISTS(SELECT 1 FROM recipes)");
	const exists = findRows[0];
	if (!exists) {
		return new Ok([]);
	}
	const result = await db.execO("SELECT id, title, slug, prep_time, cook_time, serves, tags, ingredients, method_steps FROM recipes")
	const mapped = result.map(recipe=>{
		recipe.tags = JSON.parse(recipe.tags,reviver)
		recipe.ingredients = JSON.parse(recipe.ingredients,reviver)
		recipe.method_steps = JSON.parse(recipe.method_steps, reviver)
		return recipe
	})		
	console.log("recipes mapped: ",mapped)
	return mapped
}



export async function addOrUpdateRecipe(recipe: Recipe) {
	console.log("addOrUpdateRecipe: ",recipe);
	const query = ` \
		INSERT INTO recipes \
		(id, slug, title, cook_time, prep_time, serves, ingredients, method_steps, tags, shortlisted) \
		 VALUES ('${recipe.id ? recipe.id : nanoid()}', '${recipe.slug}', '${recipe.title}', '${recipe.cook_time}',
			'${recipe.prep_time}', '${recipe.serves}', '${JSON.stringify(recipe.ingredients,replacer)}',
			'${JSON.stringify(recipe.method_steps,replacer)}', '${JSON.stringify(recipe.tags,replacer)}', '${recipe.shortlisted}') \
		 ON CONFLICT(id) DO UPDATE SET\
		 slug=excluded.slug, \
		 title=excluded.title, \
		 cook_time=excluded.cook_time, \
		 prep_time=excluded.prep_time, \
		 serves=excluded.serves, \
		 ingredients=excluded.ingredients, \
		 method_steps=excluded.method_steps, \
		 tags=excluded.tags, \
		 shortlisted=excluded.shortlisted;`
	const result = await db.execA(query
		);
	return new Ok();
}

export async function do_get_recipes() {
	const _seed = await seedDb();
	const result = await listRecipes();
	console.log("recipe result from ffi: ",result)
	return result;
}

export async function do_get_tagoptions() {
	const result = await listTagOptions();
	console.log("tagoption result from ffi: ",result)
	return result
}
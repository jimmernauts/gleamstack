import { Ok, Error } from "./gleam.mjs";
import { nanoid } from 'nanoid'
import type { Recipe, TagOption } from "./types.ts"
import { seedDb } from "./seed.ts";


const sqliteWasm = await import("https://esm.sh/@vlcn.io/crsqlite-wasm@0.16.0")
const sqlite = await sqliteWasm.default(
	() => "https://esm.sh/@vlcn.io/crsqlite-wasm@0.16.0/dist/crsqlite.wasm"
  )
const db =  await sqlite.open("mealstack.db")

export async function prepareTables() {
	const tagOptionsTableExists = await db.execO("SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE `type`='table' AND `name`='tag_options')")
	console.log(tagOptionsTableExists)
	if (!tagOptionsTableExists) {
		console.log("creating tag_options table...")
		await db.execA("CREATE TABLE `tag_options` ( \
			`id` text PRIMARY KEY NOT NULL, \
			`name` text NOT NULL, \
			`options` text NOT NULL \
		)")
	}//TODO: FIX THE EXISTENCE CHECKS HERE
	const recipesTableExists = await db.execO("SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE `type`='table' AND `name`='recipes')")
	console.log(recipesTableExists)
	if (!recipesTableExists) {
		console.log("creating recipes table...")
		await db.execA('CREATE TABLE `recipes` ( \
			`id` integer PRIMARY KEY NOT NULL, \
			`slug` text, \
			`title` text, \
			`cook_time` integer, \
			`prep_time` integer, \
			`serves` integer, \
			`ingredients` text, \
			`method_steps` text, \
			`tags` text, \
			`shortlisted` integer \
		)')
	} 
}	



export async function listTagOptions() {
	const result = await db.execA("SELECT * FROM tag_options");
	return result ? new Ok(result) : new Error(undefined);
}

export async function addTagOption(tagOption: TagOption) {
	const stmt = await db.prepare("INSERT INTO tag_options (id, name, options) VALUES (?, ?, ?)");
	const result = await stmt.run(null,[nanoid(),tagOption.name,tagOption.options])
	return result ? new Ok(result) : new Error(undefined);
}

export async function listRecipes() {
	const result = await db.execA("SELECT * FROM recipes");
	return result;
}

export async function addOrUpdateRecipe(recipe: Recipe) {
	const stmt = await db.prepare(" \
		INSERT INTO recipes \
		(id, slug, title, cook_time, prep_time, serves, ingredients, method_steps, tags, shortlisted) \
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) \
		 ON CONFLICT(id) DO UPDATE SET\
		 slug=excluded.slug, \
		 title=excluded.title, \
		 cook_time=excluded.cook_time, \
		 prep_time=excluded.prep_time, \
		 serves=excluded.serves, \
		 ingredients=excluded.ingredients, \
		 method_steps=excluded.method_steps, \
		 tags=excluded.tags, \
		 shortlisted=excluded.shortlisted, \
		");
		const result = await stmt.run(null,[
			recipe.id ? recipe.id : nanoid()
			,recipe.slug
			,recipe.title
			,recipe.cook_time
			,recipe.prep_time
			,recipe.serves
			,recipe.ingredients
			,recipe.method_steps
			,recipe.tags
			,recipe.shortlisted
		])
		return result ? new Ok(result) : new Error(undefined);
}

export async function do_get_recipes() {
	const _seed = await seedDb()
	const result = await listRecipes()
	return result
}
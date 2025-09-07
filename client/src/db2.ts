import type { Recipe, PlanDay } from "../../common/types.ts";
import { init, i, id, type InstaQLEntity } from "@instantdb/core";
import schema from './instant.schema.ts';

const db = init({
    appId: process.env.INSTANT_APP_ID!,
    schema,
    
})

export async function do_get_recipes() {
    const query = { recipes: {} };
    const result = await db.queryOnce(query);
    return result.data.recipes;
}

export async function do_get_tagoptions() {
    const query = { tag_options: {} };
    const result = await db.queryOnce(query);
    return result.data.tag_options;
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
    const result = await db.tx.recipes[id_to_use].update({
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
        });
        return result;
    }

export async function do_save_plan(plan: PlanDay[]): Promise<PlanDay[]> {
    
}

export async function do_get_plan(startDate: number, endDate: number): Promise<{
    id: string;
    date: number;
    planned_meals: string | undefined;
}[]> {

}

export function do_subscribe_to_plan(
    dispatch: (result: unknown) => void,
    startDate: number,
    endDate: number,
): () => void {
    
}

export function do_subscribe_to_recipe_summaries(
    dispatch: (result: unknown) => void,
): () => void {
    
}

export function do_subscribe_to_one_recipe_by_slug(
    slug: string,
    dispatch: (result: unknown) => void,
): () => void {
    
}

export async function do_get_one_recipe_by_slug(slug: string): Promise<{
    Recipe | null}> {

}

export async function do_retrieve_settings(): Promise<string | undefined> {
}

export async function do_save_settings(api_key: string): Promise<TransactionResult<{
    id: string;
    api_key: string | undefined;
}>> {
   
}

export async function do_delete_recipe(id: string): Promise<TransactionResult<void>> {

}
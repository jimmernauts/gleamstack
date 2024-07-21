import { Ok, Error } from "./gleam.mjs";
import { schema } from './schema.ts';
import { TriplitClient } from "@triplit/client";
import type { Recipe, PlanDay } from "./types.ts";
 
export const client = new TriplitClient({
    storage: 'indexeddb',
    schema,
    serverUrl: "http://localhost:6543",
    token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ4LXRyaXBsaXQtdG9rZW4tdHlwZSI6ImFub24iLCJ4LXRyaXBsaXQtcHJvamVjdC1pZCI6ImxvY2FsLXByb2plY3QtaWQifQ.JzN7Erur8Y-MlFdCaZtovQwxN_m_fSyOIWNzYQ3uVcc",
    logLevel: 'debug'
});

if (typeof window !== 'undefined') window.client = client;

export async function do_get_recipes() {
    const query = client.query('recipes').build(); 
    const result = await client.fetch(query)
	console.log("do_get_recipes result: ", result);
	return result;
}

export async function do_get_tagoptions() {
    const query = client.query('tag_options').build(); 
    const result = await client.fetch(query)
	console.log("do_get_tag_options result: ", result);
	return result;
}

export async function do_save_recipe(recipe: Recipe) {
    //https://stackoverflow.com/questions/11704267/in-javascript-how-to-conditionally-add-a-member-to-an-object
    const obj: Recipe = {
        ...((recipe.id !== "" )? {id: recipe.id} : {}),
        slug: recipe.slug,
        title:recipe.title,
        cook_time: recipe.cook_time,
        prep_time: recipe.prep_time,
        serves: recipe.serves,
        tags: recipe.tags,
        ingredients: recipe.ingredients,
        method_steps: recipe.method_steps
     }
     console.log("do_save_recipe obj: ", obj);
    const result = await client.insert('recipes', obj)
    return result;
}

export async function do_get_plan(startDate: number, endDate: number) {
    console.log(client)
    const query = client.query('plan').where([['date','>=',startDate],['date','<=',endDate]]).build(); 
    const result = await client.fetch(query)
	console.log("do_get_plan result: ", result);
	return result
}

export async function do_save_plan(plan: PlanDay[]) {
    await client.transact(async (tx) => {
    for (const day of plan) {
        console.log("do_save_plan day: ", { id: day.date.toString(), ...day });
        const result = await tx.insert('plan', { id: day.date.toString(), ...day })
        console.log("do_save_plan result: ", result);
    }
})
    return plan
}
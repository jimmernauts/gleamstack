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
    const result = await client.insert('recipes', recipe)
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
    for (const day of plan) {
        console.log("do_save_plan day: ", { id: day.date.toString(), ...day });
        const result = await client.insert('plan', { id: day.date.toString(), ...day })
        console.log("do_save_plan result: ", result);
    }
    return plan
}
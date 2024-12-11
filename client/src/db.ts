import { Ok, Error } from "./gleam.mjs";
import { schema } from './schema.ts';
import { TriplitClient } from "@triplit/client";
import type { Recipe, PlanDay } from "./types.ts";
 
export const client = new TriplitClient({
    storage: 'indexeddb',
    schema,
    serverUrl: "https://912d44e1-48a6-46b7-b6b9-7bc0fcd59a81.triplit.io",
    token: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ4LXRyaXBsaXQtdG9rZW4tdHlwZSI6ImFub24iLCJ4LXRyaXBsaXQtcHJvamVjdC1pZCI6IjkxMmQ0NGUxLTQ4YTYtNDZiNy1iNmI5LTdiYzBmY2Q1OWE4MSIsImlhdCI6MTcyMTU2ODg2OX0.mLTejtnhczt5RxdYK1cnnNbeQ7vevO5z7oQD23MJA6AIfiyYS9S5F1il5PcCyLwJyObGomOJE9qIJbfwoHsBzs1QQEg3HOjgMBJAIRhbaWhOJn1BZZ8h2eaZWKpwBQuUpHi37-T0uTnABP7WUTZEFshHWEv5JlUYczehBvUFA8AulNjZDJJrJuEqHNgL3e0OaUZbstWArftiJpoR0htiZ7_HzFRHm5nivgsVO5zSBVeURM5Eygf67N6y6krLxK7jNHIjP0EbFu2DvC2nB9wrfjebChf-x6FRDFZpnMsrMuGn9-gWoyTapMjm-q4br1Sns7oIFbKKhJI1-9LzqifwYaflWrwLEroXvkoG9fJwJConmEPE9HWR20s_75wH7B7-g3ihgHP9I820qQ1WpWuVCF6xIIG3_RwDgt-T_b08HPMAQdo5H5fHxcxSeY-pSua1TUKFeDZjKNdtZhexWfHxAGJP9gKdS2sTY4pz43dRKvIahUGRsoQ5jOMv0jONsT2z8iMnXPsmOiyLZd36Ba6FKaltJBgpoM22GkdsMFd8OIYAa-ROjgKkF1ku2WX78V53AkdAEika26-zdNv3LAK1b40tebvt58imnmR2H2PPx62wAWgsXTTuMSVhm4dMDb1zeKGXOsQCHkNUw-DsgY-3bvj0-TMG8WPU3GPpvBIj_l8",
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
	console.log("do_get_tagoptions result: ", result);
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
        ...((Object.hasOwn(recipe,"author") )? {author: recipe.author} : {}),
        ...((Object.hasOwn(recipe,"source") )? {source: recipe.source} : {}),
        ...((Object.hasOwn(recipe,"tags") )? {tags: recipe.tags} : {}),
        ...((Object.hasOwn(recipe,"ingredients") )? {ingredients: recipe.ingredients} : {}),
        ...((Object.hasOwn(recipe,"method_steps") )? {method_steps: recipe.method_steps} : {}),
        ...((Object.hasOwn(recipe,"shortlisted") )? {shortlisted: recipe.shortlisted} : {}),
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


export async function do_subscribe_to_recipe_summaries(dispatch: any) {
    const query = client.query('recipes').select(['id','title','slug','cook_time','prep_time','serves','author','source','tags']).build();
    const result = await client.subscribe(query, dispatch,() => {})
    return result;
}

export async function do_get_one_recipe_by_slug(slug: string) {
    const query = client.query('recipes').where([['slug','=',slug]]).build();
    const result = await client.fetchOne(query)
    console.log("do_get_one_recipe_by_slug result: ", result);
    return result;
}
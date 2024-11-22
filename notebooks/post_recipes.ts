import { TriplitClient } from '@triplit/client';
import { schema } from '../client/src/schema.ts';
import type {Ingredient, MethodStep} from '../client/src/types.ts'
import { readdir } from "node:fs/promises";
import { kebab_case } from "../client/build/dev/javascript/justin/justin.mjs";

const client = new TriplitClient({
    serverUrl: "https://912d44e1-48a6-46b7-b6b9-7bc0fcd59a81.triplit.io",
    token: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ4LXRyaXBsaXQtdG9rZW4tdHlwZSI6ImFub24iLCJ4LXRyaXBsaXQtcHJvamVjdC1pZCI6IjkxMmQ0NGUxLTQ4YTYtNDZiNy1iNmI5LTdiYzBmY2Q1OWE4MSIsImlhdCI6MTcyMTU2ODg2OX0.mLTejtnhczt5RxdYK1cnnNbeQ7vevO5z7oQD23MJA6AIfiyYS9S5F1il5PcCyLwJyObGomOJE9qIJbfwoHsBzs1QQEg3HOjgMBJAIRhbaWhOJn1BZZ8h2eaZWKpwBQuUpHi37-T0uTnABP7WUTZEFshHWEv5JlUYczehBvUFA8AulNjZDJJrJuEqHNgL3e0OaUZbstWArftiJpoR0htiZ7_HzFRHm5nivgsVO5zSBVeURM5Eygf67N6y6krLxK7jNHIjP0EbFu2DvC2nB9wrfjebChf-x6FRDFZpnMsrMuGn9-gWoyTapMjm-q4br1Sns7oIFbKKhJI1-9LzqifwYaflWrwLEroXvkoG9fJwJConmEPE9HWR20s_75wH7B7-g3ihgHP9I820qQ1WpWuVCF6xIIG3_RwDgt-T_b08HPMAQdo5H5fHxcxSeY-pSua1TUKFeDZjKNdtZhexWfHxAGJP9gKdS2sTY4pz43dRKvIahUGRsoQ5jOMv0jONsT2z8iMnXPsmOiyLZd36Ba6FKaltJBgpoM22GkdsMFd8OIYAa-ROjgKkF1ku2WX78V53AkdAEika26-zdNv3LAK1b40tebvt58imnmR2H2PPx62wAWgsXTTuMSVhm4dMDb1zeKGXOsQCHkNUw-DsgY-3bvj0-TMG8WPU3GPpvBIj_l8",
    schema
  });
  
type ManualRecipe = {
    title: string,
    slug: string,
    prep_time: number,
    cook_time: number,
    serves: number,
    ingredients: Ingredient[] | string,
    method_steps: MethodStep[] | string,
}
async function fmt_and_submit(recipe: ManualRecipe) {
    console.log(recipe)
    const new_ingredients = {}
    for (const [index, ingredient] of recipe.ingredients.entries()) {
        new_ingredients[index] = ingredient
    }
    
    const new_method_steps = {}
    for (const [index, method_step] of recipe.method_steps.entries()) {
        new_method_steps[index] = method_step
    }
    recipe.ingredients = JSON.stringify(new_ingredients)
    recipe.method_steps = JSON.stringify(new_method_steps)
    recipe.slug = kebab_case(recipe.title)
    const { txId, output } = await client.http.insert('recipes', recipe);
    console.log(txId,output)
}


const path = './output/checked'
const files = await readdir(path)
for (const f of files) {
    const item = await Bun.file(path+'/'+f).json()
    await fmt_and_submit(item)
}
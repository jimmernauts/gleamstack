import { TriplitClient } from "@triplit/client";
import { schema as triplit_schema } from "../schema.ts";
import { do_save_recipe } from "../db2.ts";
import type {
	Recipe,
	PlanDay,
	Ingredient,
	MethodStep,
} from "../../../common/types.ts";
import { init, id } from "@instantdb/core";
import schema from "../instant.schema.ts";

const db = init({
	appId: "eeaf3b82-5b5d-40c4-a29a-b68988377c3c",
	schema,
});

const triplit_client = new TriplitClient({
	serverUrl: "https://912d44e1-48a6-46b7-b6b9-7bc0fcd59a81.triplit.io",
	token:
		"eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ4LXRyaXBsaXQtdG9rZW4tdHlwZSI6ImFub24iLCJ4LXRyaXBsaXQtcHJvamVjdC1pZCI6IjkxMmQ0NGUxLTQ4YTYtNDZiNy1iNmI5LTdiYzBmY2Q1OWE4MSIsImlhdCI6MTcyMTU2ODg2OX0.mLTejtnhczt5RxdYK1cnnNbeQ7vevO5z7oQD23MJA6AIfiyYS9S5F1il5PcCyLwJyObGomOJE9qIJbfwoHsBzs1QQEg3HOjgMBJAIRhbaWhOJn1BZZ8h2eaZWKpwBQuUpHi37-T0uTnABP7WUTZEFshHWEv5JlUYczehBvUFA8AulNjZDJJrJuEqHNgL3e0OaUZbstWArftiJpoR0htiZ7_HzFRHm5nivgsVO5zSBVeURM5Eygf67N6y6krLxK7jNHIjP0EbFu2DvC2nB9wrfjebChf-x6FRDFZpnMsrMuGn9-gWoyTapMjm-q4br1Sns7oIFbKKhJI1-9LzqifwYaflWrwLEroXvkoG9fJwJConmEPE9HWR20s_75wH7B7-g3ihgHP9I820qQ1WpWuVCF6xIIG3_RwDgt-T_b08HPMAQdo5H5fHxcxSeY-pSua1TUKFeDZjKNdtZhexWfHxAGJP9gKdS2sTY4pz43dRKvIahUGRsoQ5jOMv0jONsT2z8iMnXPsmOiyLZd36Ba6FKaltJBgpoM22GkdsMFd8OIYAa-ROjgKkF1ku2WX78V53AkdAEika26-zdNv3LAK1b40tebvt58imnmR2H2PPx62wAWgsXTTuMSVhm4dMDb1zeKGXOsQCHkNUw-DsgY-3bvj0-TMG8WPU3GPpvBIj_l8",
	schema: triplit_schema,
});

type ManualRecipe = {
	title: string;
	slug: string;
	prep_time: number;
	cook_time: number;
	serves: number;
	ingredients: Ingredient[] | string;
	method_steps: MethodStep[] | string;
};

async function extract_and_submit_data() {
	const recipes = await triplit_client.http.fetch({
		collectionName: "recipes",
	});
	for (const recipe of recipes) {
		const { id, ...new_recipe } = recipe;
		fmt_and_submit(new_recipe as ManualRecipe);
	}
	console.log("done");
}

async function fmt_and_submit(recipe: ManualRecipe) {
	console.log("trying to submit recipe: ", recipe);
	const res = await do_save_recipe(recipe);
	console.log(JSON.stringify(res));
}

extract_and_submit_data();

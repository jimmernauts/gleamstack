import { Ok, Error } from "./gleam.mjs";
import type { Recipe, Ingredient, MethodStep } from "./types";
import api from "jsonld";
import { kebabCase } from "change-case";
import { parse as durationParse, toSeconds } from "iso8601-duration";
import { parseHTML } from "linkedom/worker"

export async function parseUrl(url: string) {
    const pageContents = await fetch(url).then((res) => res.text());
		const { document } = parseHTML(pageContents);
		const recipe = await parseDocumentForRecipe(document);
		if (!recipe) {
			return Error("Could not parse recipe");
		}
        return Ok(recipe);
}


async function parseDocumentForRecipe(
	document: Document,
): Promise<Recipe | undefined> {
	const target = document.querySelector('script[type="application/ld+json"]');
	if (target) {
		const json = target.innerHTML;
		const frameObject = {
			"@context": "https://schema.org/",
			"@type": "Recipe",
			"@explicit": true,
			cookTime: {},
			prepTime: {},
			recipeYield: {},
			cookingMethod: {},
			datePublished: {},
			author: {},
			description: {},
			name: {},
			title: {},
			recipeIngredient: {},
			recipeCategory: {},
			recipeCuisine: {},
			recipeInstructions: {},
			url: { "@explicit": true, id: {} },
		};
		const { frame } = api;
		const parsed = await frame(JSON.parse(json), frameObject);
		const parsedIngredients = parsed?.recipeIngredient
			? (parsed.recipeIngredient as Ingredient[])
			: ([] as Ingredient[]);
		const parsedMethodSteps = parsed?.recipeInstructions
			? (parsed.recipeInstructions as MethodStep[])
			: ([] as MethodStep[]);
		const dateString = new Date().toISOString();
		const parsedTitle: string = (() => {
			switch (true) {
				case Object.hasOwn(parsed, "name"):
					return parsed.name as string;
				case Object.hasOwn(parsed, "title"):
					return parsed.title as string;
				default:
					return `Imported Recipe-${dateString}`;
			}
		})();
		const recipeForImport: Recipe = {
			slug: kebabCase(parsedTitle),
			title: parsedTitle,
			cook_time: parsed?.cookTime
				? toSeconds(durationParse(parsed?.cookTime as string)) / 60
				: null,
			prep_time: parsed?.prepTime
				? toSeconds(durationParse(parsed?.prepTime as string)) / 60
				: null,
			serves: parsed?.recipeYield ? parsed.recipeYield[0] : 0,
			ingredients: parsedIngredients.map((i: any) => {
				return {
					name: i,
				};
			}),
			method_steps: parsedMethodSteps.map((i: any) => {
				return {
					stepText: i.text,
				};
			}),
		};
		return recipeForImport;
	}
}
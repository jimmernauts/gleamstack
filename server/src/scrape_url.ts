import { type Result, Ok, Error as GError } from "./gleam.mjs";
import type { Ingredient, MethodStep, Recipe } from "../../common/types.ts";
import api from "jsonld";
import { kebabCase } from "change-case";
import durationParse from "iso8601-duration";

export async function do_fetch_jsonld(
	url: string,
): Promise<Result<Recipe, string>> {
	// Fetch URL content
	const response = await fetch(url);
	const html = await response.text();
	// Extract JSON-LD data
	const jsonLd = await extractJsonLd(html);
	console.log(jsonLd);
	if (jsonLd) {
		return new Ok(jsonLd);
	}
	return new GError("URL Error: No recipe data found on the page");
}

async function extractJsonLd(html: string): Promise<Recipe | null> {
	let jsonLdContent = "";

	const content = await new HTMLRewriter()
		.on('script[type="application/ld+json"]', {
			async text(text) {
				if (text.text) {
					jsonLdContent += text.text;
				}
			},
		})
		.transform(new Response(html))
		.text();

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
	const parsed = await frame(JSON.parse(jsonLdContent), frameObject);
	console.log(parsed);
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
			? durationParse.toSeconds(
					durationParse.parse(parsed?.cookTime as string),
				) / 60
			: 0,
		prep_time: parsed?.prepTime
			? durationParse.toSeconds(
					durationParse.parse(parsed?.prepTime as string),
				) / 60
			: 0,
		serves: parsed?.recipeYield ? parsed.recipeYield[0] : 0,
		ingredients: JSON.stringify(parsedIngredients),
		method_steps: JSON.stringify(parsedMethodSteps),
	};
	return recipeForImport;
}

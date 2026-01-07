import { type Result, Ok, Error as GError } from "./gleam.mjs";
import type { Ingredient, MethodStep, Recipe } from "../../common/types.ts";
import api, { type NodeObject } from "jsonld";
import { kebabCase } from "change-case";
import durationParse from "iso8601-duration";
import { do_parse_recipe_text } from "./parse_recipe.ts";

export async function do_fetch_jsonld(
	url: string,
	request: Request,
): Promise<Result<Recipe, string>> {
	// Fetch URL content
	const logs: string[] = [];
	const log = (msg: string) => {
		console.log(msg);
		logs.push(msg);
	};

	try {
        log(`Fetching ${url}`);
		const response = await fetch(url, request);
		log(`Response status: ${response.status}`);
		const html = await response.text();
        log(`HTML length: ${html.length}`);
		// Extract JSON-LD data
		const jsonLd = await extractJsonLd(html, log);
		if (jsonLd) {
			return new Ok(jsonLd);
		}
		log("No JSON-LD found, trying to parse recipe text...");
		const recipe = await do_parse_recipe_text(html, log);
		if (recipe) {
			return new Ok(recipe);
		}
		return new GError(`URL Error: No recipe data found on the page. Logs: ${logs.join("; ")}`);
	} catch (e: any) {
		return new GError(`Exception during scrape: ${e.message}. Logs: ${logs.join("; ")}`);
	}
}

const documentLoader = async (url: string) => {
	// schema.org/ often returns HTML even with correct headers, so we explicitly fetch the JSON context
	if (url === "https://schema.org/" || url === "http://schema.org/" || url === "https://schema.org" || url === "http://schema.org") {
		url = "https://schema.org/docs/jsonldcontext.json";
	}

	try {
		const response = await fetch(url, {
			headers: {
				Accept: "application/ld+json, application/json",
			},
		});

		if (!response.ok) {
			throw new Error(`Failed to fetch ${url}: ${response.statusText}`);
		}

		const data = await response.json();

		return {
			contextUrl: null,
			document: data,
			documentUrl: url,
		};
	} catch (error) {
		console.error(`Error loading document ${url}:`, error);
		throw error;
	}
};

export async function extractJsonLd(
	html: string,
    log: (msg: string) => void = console.log,
): Promise<Recipe | NodeObject | null> {
	let jsonLdContent = "";

	await new HTMLRewriter()
		.on('script[type="application/ld+json"]', {
			async text(text) {
				if (text.text) {
					jsonLdContent += text.text;
				}
			},
		})
		.transform(new Response(html))
		.text();

	if (!jsonLdContent) {
        log("No jsonLdContent found via HTMLRewriter");
		return null;
	}
	log(`Found JSON-LD content length: ${jsonLdContent.length}`);
	
	let parsed: NodeObject | null = null;
	
	try {
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
        log("Starting JSON-LD frame");
		parsed = await frame(JSON.parse(jsonLdContent), frameObject, {
			documentLoader: documentLoader,
		} as any) as unknown as NodeObject;
		log("JSON-LD frame completed");
        // log(`Parsed: ${JSON.stringify(parsed)}`);
	} catch (error: any) {
		log(`Failed to parse JSON-LD: ${error.message}`);
		return null;
	}

	if (!parsed) {
        log("Parsed object is null");
		return null;
	}
	const parsedIngredients = parsed?.recipeIngredient
		? (parsed.recipeIngredient as Ingredient[])
		: ([] as Ingredient[]);
	const parsedMethodSteps = parsed?.recipeInstructions
		? (parsed.recipeInstructions as MethodStep[])
		: ([] as MethodStep[]);
	const dateString = new Date().toISOString().replace(":", "").replace("-", "");
	const parsedTitle: string = (() => {
		return (
			(parsed?.name as string) ??
			(parsed?.title as string) ??
			`Imported Recipe-${dateString}`
		);
	})();
	console.log(`${parsed.name} ${parsed.title}`);
	const recipeForImport: Recipe = {
		slug: kebabCase(parsedTitle || ""),
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
		serves: (() => {
			if (Array.isArray(parsed?.recipeYield)) {
				return Number(parsed.recipeYield[0]) || 0;
			}
			if (typeof parsed?.recipeYield === "number") {
				return parsed.recipeYield;
			}
			if (typeof parsed?.recipeYield === "string") {
				return Number(parsed.recipeYield) || 0;
			}
			return 0;
		})(),
		ingredients: JSON.stringify(parsedIngredients),
		method_steps: JSON.stringify(parsedMethodSteps),
	};
	if (
		recipeForImport.ingredients === "[]" &&
		recipeForImport.method_steps === "[]"
	) {
		console.log(
			"There was JSON-LD, and we parsed it, but we couldn't get a recipe with ingrdients and method. Returning the raw parsed JSON-LD",
		);
		return parsed;
	}
	return recipeForImport;
}

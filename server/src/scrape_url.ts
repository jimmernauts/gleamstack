import { type Result, Ok, Error as GError } from "./gleam.mjs";
import type { Recipe } from "../../common/types.ts";

export async function do_fetch_jsonld(
	url: string,
): Promise<Result<Recipe, string>> {
	// Fetch URL content
	const response = await fetch(url);
	const html = await response.text();
	console.log(html);
	// Extract JSON-LD data
	const jsonLd = extractJsonLd(html);
	if (jsonLd) {
		return new Ok(jsonLd);
	}
	return new GError("URL Error: No recipe data found on the page");
}

function extractJsonLd(html: string): Recipe | null {
	const jsonLdRegex = /<script type="application\/ld\+json">(.*?)<\/script>/gs;
	const matches = [...html.matchAll(jsonLdRegex)];

	for (const match of matches) {
		try {
			const data = JSON.parse(match[1]);
			if (data["@type"] === "Recipe") {
				return data;
			}
		} catch (e) {
			console.error("Failed to parse JSON-LD:", e);
		}
	}
	return null;
}

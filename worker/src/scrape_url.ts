import { type Result, Ok, Error as GError } from "./gleam.mjs";
import type { Recipe } from "../../common/types.ts";
import { parseHTML } from "linkedom";
import { kebabCase } from "change-case";
import durationParse from "iso8601-duration";
import { do_parse_recipe_texts } from "./parse_recipe.ts";

type JsonObject = Record<string, any>;

export type ScrapeRecipe = Omit<Recipe, "ingredients" | "method_steps"> & {
  ingredients: unknown[];
  method_steps: { step_text: string }[];
};

export type ScrapeResult = {
  source_url: string;
  recipes: ScrapeRecipe[];
  warnings: string[];
  status: "ok" | "multiple_recipes" | "no_recipe";
};

export async function do_fetch_recipes(
  url: string,
  request: Request,
): Promise<Result<ScrapeResult, string>> {
  const logs: string[] = [];
  const log = (msg: string) => {
    console.log(msg);
    logs.push(msg);
  };

  try {
    log(`Fetching ${url}`);
    const outboundHeaders = new Headers({
      Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language":
        request.headers.get("accept-language") ?? "en-US,en;q=0.9",
      "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/131.0 Safari/537.36",
    });
    const response = await fetch(url, {
      headers: outboundHeaders,
      redirect: "follow",
    });
    log(`Response status: ${response.status}`);
    const html = await response.text();
    log(`HTML length: ${html.length}`);

    if (!response.ok) {
      return new GError(
        `URL Error: ${response.status} while fetching ${url}. Logs: ${logs.join("; ")}`,
      );
    }

    const jsonLdRecipes = extractJsonLdRecipes(html, log, url);
    if (jsonLdRecipes.length > 0) {
      return new Ok(makeScrapeResult(url, jsonLdRecipes, logs));
    }

    log("No usable JSON-LD found, extracting page text for multi-recipe parsing...");
    const pageText = extractPageText(html);
    const parsed = await do_parse_recipe_texts(pageText, log);

    if (parsed instanceof Ok) {
      const recipes = normalizeAiRecipes(parsed[0], url);
      return new Ok(makeScrapeResult(url, recipes, logs));
    }

    return new GError(
      `URL Error: No recipe data found on the page. Logs: ${logs.join("; ")}`,
    );
  } catch (error: any) {
    return new GError(
      `Exception during scrape: ${error.message}. Logs: ${logs.join("; ")}`,
    );
  }
}

function makeScrapeResult(
  sourceUrl: string,
  recipes: ScrapeRecipe[],
  warnings: string[] = [],
): ScrapeResult {
  return {
    source_url: sourceUrl,
    recipes,
    warnings,
    status:
      recipes.length > 1
        ? "multiple_recipes"
        : recipes.length === 1
          ? "ok"
          : "no_recipe",
  };
}

export function extractJsonLdRecipes(
  html: string,
  log: (msg: string) => void = console.log,
  sourceUrl = "",
): ScrapeRecipe[] {
  const { document } = parseHTML(html);
  const scripts = Array.from(
    document.querySelectorAll('script[type="application/ld+json"]'),
  );
  const recipes: ScrapeRecipe[] = [];

  for (const [index, script] of scripts.entries()) {
    const content = script.textContent?.trim() ?? "";
    if (!content) continue;

    try {
      const parsed = JSON.parse(content);
      const nodes = collectRecipeNodes(parsed);
      for (const node of nodes) {
        const recipe = normalizeJsonLdRecipe(node, sourceUrl);
        if (recipe) recipes.push(recipe);
      }
    } catch (error: any) {
      log(`Failed to parse JSON-LD script ${index + 1}: ${error.message}`);
    }
  }

  const uniqueRecipes = dedupeRecipes(recipes);
  log(`Found ${uniqueRecipes.length} recipe(s) in JSON-LD`);
  return uniqueRecipes;
}

function collectRecipeNodes(
  value: unknown,
  results: JsonObject[] = [],
  visited = new Set<object>(),
): JsonObject[] {
  if (Array.isArray(value)) {
    for (const item of value) collectRecipeNodes(item, results, visited);
    return results;
  }

  if (!value || typeof value !== "object") return results;

  const object = value as JsonObject;
  if (visited.has(object)) return results;
  visited.add(object);

  if (isRecipeType(object["@type"])) results.push(object);

  for (const child of Object.values(object)) {
    collectRecipeNodes(child, results, visited);
  }

  return results;
}

function isRecipeType(type: unknown): boolean {
  const types = Array.isArray(type) ? type : [type];
  return types.some(
    (value) =>
      typeof value === "string" &&
      (value === "Recipe" || value.endsWith("/Recipe") || value.endsWith("#Recipe")),
  );
}

function normalizeJsonLdRecipe(
  node: JsonObject,
  sourceUrl: string,
): ScrapeRecipe | null {
  const title =
    stringValue(node.name) ??
    stringValue(node.title) ??
    `Imported Recipe-${new Date().toISOString().replace(/[:.]/g, "")}`;

  const methodSteps = toArray(node.recipeInstructions)
    .map((step) => {
      const stepText = stringValue(step);
      return stepText ? { step_text: stepText } : null;
    })
    .filter((step): step is { step_text: string } => step !== null);

  return {
    slug: kebabCase(title),
    title,
    cook_time: durationMinutes(node.cookTime),
    prep_time: durationMinutes(node.prepTime),
    serves: parseServes(node.recipeYield),
    author: stringValue(node.author),
    source: stringValue(node.url) ?? sourceUrl,
    ingredients: toArray(node.recipeIngredient),
    method_steps: methodSteps,
  };
}

function normalizeAiRecipes(value: unknown, sourceUrl: string): ScrapeRecipe[] {
  if (!Array.isArray(value)) return [];

  const recipes = value.flatMap((item) => {
    if (!item || typeof item !== "object") return [];
    const object = item as JsonObject;
    const title = stringValue(object.title) ?? stringValue(object.name);
    if (!title) return [];

    return [
      {
        slug: stringValue(object.slug) ?? kebabCase(title),
        title,
        cook_time: numberValue(object.cook_time),
        prep_time: numberValue(object.prep_time),
        serves: numberValue(object.serves),
        author: stringValue(object.author),
        source: stringValue(object.source) ?? sourceUrl,
        ingredients: toArrayValue(object.ingredients),
        method_steps: normalizeMethodSteps(object.method_steps),
      } satisfies ScrapeRecipe,
    ];
  });

  return dedupeRecipes(recipes);
}

function dedupeRecipes(recipes: ScrapeRecipe[]): ScrapeRecipe[] {
  const seen = new Set<string>();
  return recipes.filter((recipe) => {
    const key = `${recipe.slug}|${recipe.source ?? ""}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function extractPageText(html: string): string {
  const { document } = parseHTML(html);
  for (const selector of ["script", "style", "noscript", "nav", "header", "footer", "svg"]) {
    for (const element of Array.from(document.querySelectorAll(selector))) {
      element.remove();
    }
  }

  return (document.body?.textContent ?? "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 120_000);
}

function toArray(value: unknown): unknown[] {
  if (value === undefined || value === null) return [];
  return Array.isArray(value) ? value : [value];
}

function toArrayValue(value: unknown): unknown[] {
  if (typeof value !== "string") return toArray(value);
  try {
    return toArray(JSON.parse(value));
  } catch {
    return [value];
  }
}

function normalizeMethodSteps(value: unknown): { step_text: string }[] {
  return toArrayValue(value)
    .map((step) => {
      const text = stringValue(step);
      return text ? { step_text: text } : null;
    })
    .filter((step): step is { step_text: string } => step !== null);
}

function stringValue(value: unknown): string | undefined {
  if (typeof value === "string") return value.trim() || undefined;
  if (typeof value === "number") return String(value);
  if (Array.isArray(value)) return stringValue(value[0]);
  if (!value || typeof value !== "object") return undefined;

  const object = value as JsonObject;
  return (
    stringValue(object.name) ??
    stringValue(object.text) ??
    stringValue(object["@value"]) ??
    stringValue(object["@id"]) ??
    stringValue(object.url)
  );
}

function numberValue(value: unknown): number {
  const number = Number(Array.isArray(value) ? value[0] : value);
  return Number.isFinite(number) ? number : 0;
}

function parseServes(value: unknown): number {
  if (typeof value === "number") return value;
  const text = stringValue(value);
  if (!text) return 0;
  const match = text.match(/\d+(?:\.\d+)?/);
  return match ? Number(match[0]) : 0;
}

function durationMinutes(value: unknown): number {
  if (typeof value === "number") return value;
  const text = stringValue(value);
  if (!text) return 0;

  try {
    return durationParse.toSeconds(durationParse.parse(text)) / 60;
  } catch {
    const match = text.match(/^PT(?:(\d+)H)?(?:(\d+)M)?/i);
    if (!match) return 0;
    return Number(match[1] ?? 0) * 60 + Number(match[2] ?? 0);
  }
}

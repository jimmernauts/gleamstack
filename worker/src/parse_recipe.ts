import { GoogleGenAI, ThinkingLevel } from "@google/genai";
import { init } from "@instantdb/admin";
import { type Result, Ok, Error as GError } from "./gleam.mjs";

const APP_ID =
  process.env.INSTANT_APP_ID || "eeaf3b82-5b5d-40c4-a29a-b68988377c3c";

// Initialize Instant DB Admin
const db = init({
  appId: APP_ID,
  adminToken: process.env.INSTANT_ADMIN_TOKEN || "",
});

console.log(`Initialized DB with Admin Token: ${!!process.env.INSTANT_ADMIN_TOKEN}`);

const TAG_NAMES = ["Cuisine", "Style", "Label"] as const;
type TagName = (typeof TAG_NAMES)[number];
export type AllowedTagOptions = Record<TagName, string[]>;
type TagOptionRecord = { name?: unknown; options?: unknown };
type ParsedTag = { name?: unknown; value?: unknown };

function emptyTagOptions(): AllowedTagOptions {
  return { Cuisine: [], Style: [], Label: [] };
}

function parseTagValues(value: unknown): string[] {
  const parsed = (() => {
    if (Array.isArray(value)) return value;
    if (typeof value !== "string") return [];
    try {
      return JSON.parse(value);
    } catch {
      return [];
    }
  })();
  return Array.isArray(parsed)
    ? parsed.filter((item): item is string => typeof item === "string")
    : [];
}

async function getAvailableTagOptions(
  log: (msg: string) => void,
 ): Promise<AllowedTagOptions> {
  log("Retrieving existing tag options from Instant DB...");
  const options = emptyTagOptions();
  try {
    const result = await db.query({ tag_options: {} });
    for (const record of (result.tag_options ?? []) as TagOptionRecord[]) {
      const rawName = typeof record.name === "string" ? record.name.trim() : "";
      const name = TAG_NAMES.find(
        (candidate) => candidate.toLowerCase() === rawName.toLowerCase(),
      );
      if (!name) continue;
      options[name] = [
        ...new Set(
          parseTagValues(record.options)
            .map((value) => value.trim())
            .filter(Boolean),
        ),
      ];
    }
  } catch (error) {
    log(`Unable to load existing tag options: ${error instanceof Error ? error.message : String(error)}`);
  }
  return options;
}

export function buildTagInstructions(options: AllowedTagOptions): string {
  return [
    "Metadata tags: suggest at most one value for each of Cuisine, Style, and Label.",
    "Use only an exact value from the existing options below. Never invent, paraphrase, or normalize a value.",
    ...TAG_NAMES.map((name) =>
      `- ${name}: ${options[name].length > 0 ? options[name].join(", ") : "(no existing values; return no tag)"}`,
    ),
  ].join("\n");
}

export function normalizeTags(
  value: unknown,
  options: AllowedTagOptions,
 ): Record<string, { name: TagName; value: string }> {
  const candidates = Array.isArray(value)
    ? value
    : value && typeof value === "object"
      ? Object.values(value)
      : [];
  const tags: Record<string, { name: TagName; value: string }> = {};
  const seenNames = new Set<TagName>();
  for (const candidate of candidates as ParsedTag[]) {
    if (!candidate || typeof candidate !== "object") continue;
    const rawName = typeof candidate.name === "string" ? candidate.name.trim() : "";
    const name = TAG_NAMES.find(
      (tagName) => tagName.toLowerCase() === rawName.toLowerCase(),
    );
    if (!name || seenNames.has(name)) continue;
    const rawValue = typeof candidate.value === "string" ? candidate.value.trim() : "";
    const value = options[name].find(
      (allowed) => allowed.toLowerCase() === rawValue.toLowerCase(),
    );
    if (!value) continue;
    tags[String(Object.keys(tags).length)] = { name, value };
    seenNames.add(name);
  }
  return tags;
}

function normalizeParsedRecipe(
  value: unknown,
  options: AllowedTagOptions,
 ): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Gemini returned an invalid recipe object.");
  }
  const recipe = value as Record<string, unknown>;
  return { ...recipe, tags: normalizeTags(recipe.tags, options) };
}

async function getGeminiClient(
  log: (msg: string) => void,
): Promise<GoogleGenAI> {
  log("Retrieving settings from Instant DB...");
  const settingsHelper = await db.query({ settings: { $: { limit: 1 } } });
  const settings = settingsHelper.settings?.[0];

  const apiKey = settings?.api_key;
  if (!apiKey) {
    throw new Error("No valid Gemini API key available");
  }

  log("Initializing Gemini...");
  return new GoogleGenAI({ apiKey });
}

export async function do_parse_recipe_text(
  text: string,
  log: (msg: string) => void = console.log,
): Promise<Result<any, any>> {
  if (!text.trim()) {
    return new GError({
      Other: { message: "Recipe text is empty." },
    });
  }

  log("Parsing recipe text...");

  try {
    const ai = await getGeminiClient(log);
    const tagOptions = await getAvailableTagOptions(log);
    const prompt = `Extract the recipe from this data.\n\n${buildTagInstructions(tagOptions)}\n\nRecipe data:\n${text}`;
    log("Sending request to Gemini...");
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview",
      contents: prompt,
      config: {
        thinkingConfig: {
          thinkingLevel: ThinkingLevel.LOW,
        },
        responseMimeType: "application/json",
        responseSchema: recipeSchema,
      },
    });

    const responseText = response.text;
    if (!responseText) {
      throw new Error("No response text received.");
    }

    return new Ok(normalizeParsedRecipe(JSON.parse(responseText), tagOptions));
  } catch (error: any) {
    log(`Error parsing recipe: ${error}`);
    return new GError({
      Other: {
        message: `Failed to parse recipe: ${error.message}`,
      },
    });
  }
}

export async function do_parse_recipe_texts(
  text: string,
  log: (msg: string) => void = console.log,
): Promise<Result<any[], any>> {
  if (!text.trim()) {
    return new GError({
      Other: { message: "Recipe text is empty." },
    });
  }

  log("Parsing all recipes from page text...");

  try {
    const ai = await getGeminiClient(log);
    const tagOptions = await getAvailableTagOptions(log);
    const prompt = `Extract every distinct recipe in this page text. Return an empty array when there are no recipes. Do not omit recipes just because the page contains several recipes. Return only structured recipe data.\n\n${buildTagInstructions(tagOptions)}\n\nPage text:\n${text}`;
    log("Sending multi-recipe request to Gemini...");
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview",
      contents: prompt,
      config: {
        thinkingConfig: {
          thinkingLevel: ThinkingLevel.LOW,
        },
        responseMimeType: "application/json",
        responseSchema: recipesSchema,
      },
    });

    const responseText = response.text;
    if (!responseText) {
      throw new Error("No response text received.");
    }

    const parsed = JSON.parse(responseText);
    const recipes = Array.isArray(parsed) ? parsed : parsed?.recipes;
    if (!Array.isArray(recipes)) {
      throw new Error("Gemini returned a non-array recipe response.");
    }

    return new Ok(recipes.map((recipe) => normalizeParsedRecipe(recipe, tagOptions)));
  } catch (error: any) {
    log(`Error parsing recipes: ${error}`);
    return new GError({
      Other: {
        message: `Failed to parse recipes: ${error.message}`,
      },
    });
  }
}

export async function do_parse_recipe_image(
  imageDataUrl: string,
  log: (msg: string) => void = console.log,
): Promise<Result<any, any>> {
  if (!imageDataUrl.trim()) {
    return new GError({
      Other: { message: "Image data is empty." },
    });
  }

  log("Parsing recipe image...");

  try {
    const ai = await getGeminiClient(log);
    const tagOptions = await getAvailableTagOptions(log);
    const matches = imageDataUrl.match(
      /^data:([a-zA-Z0-9]+\/[a-zA-Z0-9-.+]+);base64,(.+)$/,
    );

    if (!matches || matches.length !== 3) {
      return new GError({
        Other: { message: "Invalid image data URL format." },
      });
    }

    const mimeType = matches[1];
    const base64Data = matches[2];
    log("Sending request to Gemini with image...");
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview",
      contents: [
        {
          role: "user",
          parts: [
            {
              text: `Extract the recipe from this image.\n\n${buildTagInstructions(tagOptions)}`,
            },
            {
              inlineData: {
                mimeType,
                data: base64Data,
              },
            },
          ],
        },
      ],
      config: {
        responseMimeType: "application/json",
        responseSchema: recipeSchema,
      },
    });

    const responseText = response.text;
    if (!responseText) {
      throw new Error("No response text received.");
    }

    return new Ok(normalizeParsedRecipe(JSON.parse(responseText), tagOptions));
  } catch (error: any) {
    log(`Error parsing recipe image: ${error}`);
    return new GError({
      Other: {
        message: `Failed to parse recipe image: ${error.message}`,
      },
    });
  }
}

export const recipeSchema = {
  description: "Recipe data extraction schema",
  type: "OBJECT",
  properties: {
    slug: { type: "STRING", description: "A unique slug for the recipe" },
    title: { type: "STRING", description: "The recipe title" },
    cook_time: { type: "NUMBER", description: "Cooking time in minutes" },
    prep_time: { type: "NUMBER", description: "Preparation time in minutes" },
    serves: { type: "NUMBER", description: "Number of servings" },
    author: { type: "STRING", description: "Recipe author" },
    source: { type: "STRING", description: "Recipe source URL or name" },
    ingredients: {
      type: "ARRAY",
      description: "List of ingredients",
      items: {
        type: "OBJECT",
        properties: {
          name: { type: "STRING", description: "The ingredient name" },
          quantity: { type: "STRING", description: "Quantity" },
          units: { type: "STRING", description: "Units" },
          ismain: {
            type: "STRING",
            description: "'true' or 'false'",
          },
        },
        required: ["name", "quantity", "units", "ismain"],
      },
    },
    method_steps: {
      type: "ARRAY",
      description: "Cooking instructions",
      items: {
        type: "OBJECT",
        properties: {
          step_text: { type: "STRING", description: "Instruction text" },
        },
        required: ["step_text"],
      },
    },
    tags: {
      type: "ARRAY",
      description: "At most one tag for each category, using only existing options",
      items: {
        type: "OBJECT",
        properties: {
          name: { type: "STRING" },
          value: { type: "STRING" },
        },
        required: ["name", "value"],
      },
    },
  },
  required: [
    "title",
    "cook_time",
    "prep_time",
    "serves",
    "ingredients",
    "method_steps",
    "tags",
  ],
};

export const recipesSchema = {
  description: "All recipe data found on a page",
  type: "ARRAY",
  items: recipeSchema,
};

import { GoogleGenAI, ThinkingLevel } from "@google/genai";
import { createClient } from "@libsql/client/web";
import { type Result, Ok, Error as GError } from "./gleam.mjs";

// Worker env is exposed by index.mjs via globalThis.__workerEnv
declare const globalThis: { __workerEnv?: Record<string, string> };

function getWorkerEnv(): Record<string, string> {
  const env = globalThis.__workerEnv;
  if (!env) throw new Error("Worker env not available (globalThis.__workerEnv not set)");
  return env;
}

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

export async function getAvailableTagOptions(
  log: (msg: string) => void,
 ): Promise<AllowedTagOptions> {
  log("Retrieving existing tag options from Turso...");
  const options = emptyTagOptions();
  try {
    const env = getWorkerEnv();
    const client = createClient({
      url: env.TURSO_URL,
      authToken: env.TURSO_AUTH_TOKEN,
    });
    const result = await client.execute("SELECT name, options FROM tag_options");
    for (const row of result.rows) {
      const rawName = typeof row.name === "string" ? row.name.trim() : "";
      const name = TAG_NAMES.find(
        (candidate) => candidate.toLowerCase() === rawName.toLowerCase(),
      );
      if (!name) continue;
      options[name] = [
        ...new Set(
          parseTagValues(row.options)
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
    "Only assign a tag when the recipe provides clear, direct evidence for it.",
    "If uncertain, leave the tag blank; an empty tag result is better than a weak guess.",
    "Cuisine and Style must be clearly supported by the title, ingredients, or method.",
    "Label is especially subjective: assign it only when the recipe itself makes the use case unmistakable, never based on how someone might personally use it.",
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
  const parsedValue = (() => {
    if (typeof value !== "string") return value;
    try {
      return JSON.parse(value);
    } catch {
      return value;
    }
  })();
  const candidates = Array.isArray(parsedValue)
    ? parsedValue
    : parsedValue && typeof parsedValue === "object"
      ? Object.values(parsedValue)
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

export async function getGeminiClient(
  log: (msg: string) => void,
): Promise<GoogleGenAI> {
  log("Retrieving Gemini API key from Worker env...");
  const env = getWorkerEnv();
  const apiKey = env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error("No GEMINI_API_KEY configured in Worker secrets");
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

export const tagSuggestionsSchema = {
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
};

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
    tags: tagSuggestionsSchema,
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

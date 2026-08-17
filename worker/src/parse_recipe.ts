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
    const prompt = `Extract the recipe from this data: ${text}`;
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

    return new Ok(JSON.parse(responseText));
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
    const prompt = `Extract every distinct recipe in this page text. Return an empty array when there are no recipes. Do not omit recipes just because the page contains several recipes. Return only structured recipe data.\n\n${text}`;
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

    return new Ok(recipes);
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
            { text: "Extract the recipe from this image." },
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

    return new Ok(JSON.parse(responseText));
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
  },
  required: [
    "title",
    "cook_time",
    "prep_time",
    "serves",
    "ingredients",
    "method_steps",
  ],
};

export const recipesSchema = {
  description: "All recipe data found on a page",
  type: "ARRAY",
  items: recipeSchema,
};

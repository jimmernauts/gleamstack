import { GoogleGenAI } from "@google/genai";
import { init } from "@instantdb/admin";
import { type Result, Ok, Error as GError } from "./gleam.mjs";

const APP_ID = "eeaf3b82-5b5d-40c4-a29a-b68988377c3c";

// Initialize Instant DB Admin
const db = init({
  appId: APP_ID,
  adminToken: process.env.INSTANT_ADMIN_TOKEN || "",
});

console.log(`Initialized DB with Admin Token: ${!!(process.env.INSTANT_ADMIN_TOKEN )}`);



export async function do_parse_recipe_text(text: string): Promise<Result<any, any>> {
  if (!text.trim()) {
    return new GError({
      Other: { message: "Recipe text is empty." },
    });
  }

  console.log("Parsing recipe text...");

  try {
    // 1. Retrieve API Key from Instant DB
    console.log("Retrieving settings from Instant DB...");
    const settingsHelper = await db.query({ settings: { $: { limit: 1 } } });
    const settings = settingsHelper.settings?.[0];
    
    // Check for explicit Gemini key or fallback
    // We ignore 'sk-' keys as they are likely OpenAI
    let apiKey = settings?.api_key;
    if (apiKey && apiKey.startsWith("sk-")) {
        console.warn("Found OpenAI API key in settings, ignoring for Gemini usage.");
        apiKey = undefined;
    }
    apiKey = apiKey || process.env.GEMINI_API_KEY;

    console.log(`Using API Key: ${apiKey ? apiKey.substring(0, 5) + "..." : "undefined"}`);

    if (!apiKey) {
        return new GError({ Other: { message: "No valid Gemini API key available (DB has OpenAI key, env var missing)." } });
    }

    console.log("Initializing Gemini...");
    // 2. Initialize Gemini
    const ai = new GoogleGenAI({ apiKey: apiKey });

    

    // 3. Generate Content
    const prompt = `Extract the recipe from this data: ${text}`;
    console.log("Sending request to Gemini...");
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview", 
      contents: prompt,
      config: {
        responseMimeType: "application/json",
        responseSchema: recipeSchema,
      },
    });
    
    // 4. Parse Response
    const responseText = response.text; 
    console.log("Raw response text:", responseText); // Debugging
    
    if (!responseText) {
        throw new Error("No response text received.");
    }
    const recipeData = JSON.parse(responseText);

    return new Ok(recipeData);

  } catch (error: any) {
    console.error("Error parsing recipe:", error);
    return new GError({
        Other: {
            message: `Failed to parse recipe: ${error.message}`,
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
          name: { type: "STRING", description: "Ingredient name" },
          quantity: { type: "STRING", description: "Quantity" },
          units: { type: "STRING", description: "Units" },
          ismain: { type: "STRING", description: "'true' or 'false'" },
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
  required: ["title", "cook_time", "prep_time", "serves", "ingredients", "method_steps"],
};
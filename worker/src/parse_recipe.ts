import { GoogleGenAI, ThinkingLevel } from "@google/genai";
import { init } from "@instantdb/admin";
import { type Result, Ok, Error as GError } from "./gleam.mjs";

const APP_ID = "eeaf3b82-5b5d-40c4-a29a-b68988377c3c";

// Initialize Instant DB Admin
const db = init({
  appId: APP_ID,
  adminToken: process.env.INSTANT_ADMIN_TOKEN || "",
});

console.log(`Initialized DB with Admin Token: ${!!(process.env.INSTANT_ADMIN_TOKEN )}`);




async function getGeminiClient(log: (msg: string) => void): Promise<GoogleGenAI> {
    log("Retrieving settings from Instant DB...");
    const settingsHelper = await db.query({ settings: { $: { limit: 1 } } });
    const settings = settingsHelper.settings?.[0];
    
    // Check for explicit Gemini key or fallback
    let apiKey = settings?.api_key;
  
    if (!apiKey) {
        throw new Error("No valid Gemini API key available");
    }

    log("Initializing Gemini...");
    return new GoogleGenAI({ apiKey: apiKey }); 
}

export async function do_parse_recipe_text(text: string, log: (msg: string) => void = console.log): Promise<Result<any, any>> {
  if (!text.trim()) {
    return new GError({
      Other: { message: "Recipe text is empty." },
    });
  }

  log("Parsing recipe text...");

  try {
    // 1-2. Retrieve Key and Initialize Gemini
    const ai = await getGeminiClient(log);
 
    // 3. Generate Content
    const prompt = `Extract the recipe from this data: ${text}`;
    log("Sending request to Gemini...");
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview", 
      contents: prompt,
      config: {
        thinkingConfig: {
          thinkingLevel: ThinkingLevel.LOW
        },
        responseMimeType: "application/json",
        responseSchema: recipeSchema,
      },
    });
    
    // 4. Parse Response
    const responseText = response.text; 
    log("Raw response text:" + responseText); // Debugging
    
    if (!responseText) {
        throw new Error("No response text received.");
    }
    const recipeData = JSON.parse(responseText);

    return new Ok(recipeData);

  } catch (error: any) {
    log("Error parsing recipe: " + error);
    return new GError({
        Other: {
            message: `Failed to parse recipe: ${error.message}`,
        },
    });
  }
}


export async function do_parse_recipe_image(imageDataUrl: string, log: (msg: string) => void = console.log): Promise<Result<any, any>> {
    if (!imageDataUrl.trim()) {
        return new GError({
            Other: { message: "Image data is empty." },
        });
    }

    log("Parsing recipe image...");

    try {
        // 1-2. Retrieve Key and Initialize Gemini
        const ai = await getGeminiClient(log);

        // 3. Prepare Image Part
        const matches = imageDataUrl.match(/^data:([a-zA-Z0-9]+\/[a-zA-Z0-9-.+]+);base64,(.+)$/);
        
        if (!matches || matches.length !== 3) {
             return new GError({ Other: { message: "Invalid image data URL format." } });
        }
        
        const mimeType = matches[1];
        const base64Data = matches[2];

        // 4. Generate Content
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
                                mimeType: mimeType,
                                data: base64Data
                            }
                        }
                    ]
                }
            ],
            config: {
                responseMimeType: "application/json",
                responseSchema: recipeSchema,
            },
        });

         // 5. Parse Response
        const responseText = response.text;
        log("Raw response text:" + responseText);

        if (!responseText) {
            throw new Error("No response text received.");
        }
        const recipeData = JSON.parse(responseText);

        return new Ok(recipeData);

    } catch (error: any) {
        log("Error parsing recipe image: " + error);
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
import Anthropic from '@anthropic-ai/sdk';
import { Jimp } from 'jimp';
import { Ok, Error } from '../build/dev/javascript/prelude.mjs'

// read a file from an event
export async function do_read_file_from_event(event: Event) {
    const target = event.target as HTMLInputElement
    const file = target?.files?.[0] as File
    
    const reader = new FileReader()
    reader.onload = function(e) {
        const contents = e?.target?.result
        // process here
        return new Ok(contents)
    }

    reader.onerror = function(e) {
        return new Error("Failed to read file: "+e?.target?.error)
    }
    reader.readAsDataURL(file)

}

// Maximum file size (5MB)
const MAX_FILE_SIZE = 5 * 1024 * 1024;
function getFileSizeFromDataUrl(dataUrl: string): number {
    // Extract the base64 data portion from the Data URL
    const base64Data = dataUrl.split(',')[1];
    
    // Calculate the size in bytes
    // Base64 represents 6 bits per character, so 4 characters = 3 bytes
    // We need to account for padding characters ('=') which don't contribute to the size
    const paddingCount = (base64Data.match(/=/g) || []).length;
    const sizeInBytes = Math.floor((base64Data.length - paddingCount) * 3 / 4);
    
    return sizeInBytes;
  }


const tools: Anthropic.Tool[] = [
    {
        name: "recipe_formatter",
        description: "Reads a recipe document and formats it for display in a recipe reader application",
        input_schema: {
            type: "object",
            properties: {
                title: {
                    type: "string",
                    description: "The recipe title",
                },
                cook_time: {
                    type: "integer",
                    description: "How long it takes to cook the recipe, in minutes",
                },
                prep_time: {
                    type: "integer",
                    description: "How long it takes to prepare the recipe, in minutes",
                },
                serves: {
                    type: "integer",
                    description: "How many servings the recipe makes",
                },
                ingredients: {
                    type: "array",
                    description: "The ingredient list for the recipe",
                    items: {
                        type: "object",
                        properties: {
                            name: {
                                type: "string",
                                description: "The ingredient name",
                            },
                            ismain: {
                                type: "string",
                                description: "Denotes whether this is a main ingredient of the recipe. Must be either 'true' or 'false'.",
                            },
                            quantity: {
                                type: "string",
                                description: "The quantity of this ingredient specified by the recipe",
                            },
                            units: {
                                type: "string",
                                description: "The units used for the quantity of this ingredient",
                            },
                        },
                    },
                },
                method_steps: {
                    type: "array",
                    description: "The steps required to prepare and cook the recipe",
                    items: {
                        type: "object",
                        properties: {
                            step_text: {
                                type: "string",
                                description: "The text describing this step in the recipe method",
                            }
                        },
                    },
                },
            },
            required: ["title", "cook_time", "prep_time", "serves"],
        },
    }
]

/**
 * Processes an image using Jimp
 * - Resizes the image if it's over 5MB
 * - Converts it to base64 for API submission
 */
export async function processImage(fileDataUrl: string): Promise<string> {

    const sizeInBytes = getFileSizeFromDataUrl(fileDataUrl);
    const mimetype = fileDataUrl.substring(fileDataUrl.indexOf(":")+1, fileDataUrl.indexOf(";")) as "image/jpeg" | "image/png"
    // Check if the image is already under the maximum size
    if (sizeInBytes < MAX_FILE_SIZE) {
    console.log('Image is already under 5MB, no processing needed');
    return fileDataUrl;
    }
    
    console.log(`Original image size: ${(sizeInBytes / 1024 / 1024).toFixed(2)}MB`);
    
    // Process the image with Jimp
    const image = await Jimp.read(Buffer.from(fileDataUrl.split(',')[1], 'base64'));
    const startingWidth = image.width
    const startingHeight = image.height
    const resizedBase64 = await image.resize({w: startingWidth*.75,h: startingHeight*.75}).getBase64(mimetype);
    if (getFileSizeFromDataUrl(resizedBase64) < MAX_FILE_SIZE) {
        return resizedBase64;
    } else {
        // If still too large, recursively process it again
        // Be careful with recursion - you might want to add a maximum recursion depth
        return processImage(resizedBase64);
}}

export async function do_submit_file(file: string, api_key: string) {
    console.log("Processing file...");
        // Process the image (resize if needed and convert to base64)
        const processedImage = await processImage(file);
        
        // Initialize Anthropic with the provided API key
        const client = new Anthropic({ apiKey: api_key });
        
        console.log("Sending to Anthropic API...");
        const response = await client.messages.create({
            model: "claude-3-7-sonnet-20250219",
            max_tokens: 2000,
            temperature: 0,
            thinking: {type: "disabled"},
            system: "You are a helpful assistant that extracts recipe information from images. Extract all recipe details including title, ingredients, preparation steps, cooking time, and serving size.",
            messages: [
                {
                    role: "user",
                    content: [
                        {
                            type: "image",
                            source: {
                                type: "base64",
                                media_type: processedImage.substring(processedImage.indexOf(":")+1, processedImage.indexOf(";")) as "image/gif" | "image/jpeg" | "image/png" | "image/webp",
                                data: processedImage.split(',')[1]
                            }
                        },
                        {
                            type: "text",
                            text: "Extract the recipe from this image and format it using the recipe_formatter tool."
                        }
                    ]
                }
            ],
            tools: tools
        });
        
        console.log("Received response from Anthropic");
        
        // Parse the tool calls from the response
        const toolCalls = response.content.filter(item => 
            item.type === 'tool_use' && item.name === 'recipe_formatter'
        );
        
        if (toolCalls.length > 0) {
            // @ts-ignore - Anthropic types might not fully match our usage
            const recipeData = JSON.parse(toolCalls[0].input);
            
            // Convert to the format expected by the Gleam app
            const recipe = {
                id: null,
                title: recipeData.title,
                slug: recipeData.title.toLowerCase().replace(/\s+/g, '-'),
                cook_time: recipeData.cook_time,
                prep_time: recipeData.prep_time,
                serves: recipeData.serves,
                author: null,
                source: null,
                tags: null,
                ingredients: recipeData.ingredients ? 
                    Object.fromEntries(recipeData.ingredients.map((ing: any, i: number) => [
                        i, {
                            name: ing.name,
                            quantity: ing.quantity || null,
                            units: ing.units || null,
                            is_main: ing.ismain === 'true'
                        }
                    ])) : null,
                method_steps: recipeData.method_steps ? 
                    Object.fromEntries(recipeData.method_steps.map((step: any, i: number) => [
                        i, { text: step.step_text }
                    ])) : null,
                shortlisted: null
            };
            
            return new Ok(recipe);
        } else {
            return new Error({ Other: "Failed to extract recipe data" });
        }
}
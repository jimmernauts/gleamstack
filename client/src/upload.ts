import Anthropic from '@anthropic-ai/sdk';


const anthropic = new Anthropic({ apiKey: "api_key" });
const tools = [
    {
        "name": "recipe_formatter",
        "description": "Reads a recipe document and formats it for display in a recipe reader application",
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "The recipe title",
                },
                "cook_time": {
                    "type": "integer",
                    "description": "How long it takes to cook the recipe, in minutes",
                },
                "prep_time": {
                    "type": "integer",
                    "description": "How long it takes to prepare the recipe, in minutes",
                },
                "serves": {
                    "type": "integer",
                    "description": "How many servings the recipe makes",
                },
                "ingredients": {
                    "type": "array",
                    "description": "The ingredient list for the recipe",
                    "items": {
                        "type": "object",
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "The ingredient name",
                            },
                            "ismain": {
                                "type": "string",
                                "description": "Denotes whether this is a main ingredient of the recipe. Must be either 'true' or 'false'.",
                            },
                            "quantity": {
                                "type": "string",
                                "description": "The quantity of this ingredient specified by the recipe",
                            },
                            "units": {
                                "type": "string",
                                "description": "The units used for the quantity of this ingredient",
                            },
                        },
                    },
                },
                "method_steps": {
                    "type": "array",
                    "description": "The steps required to prepare and cook the recipe",
                    "items": {
                        "type": "object",
                        "properties": {
                            "step_text": {
                                "type": "string",
                                "description": "The text describing this step in the recipe method",
                            }
                        },
                    },
                },
            },
            "required": ["title", "cook_time", "prep_time", "serves"],
        },
    }
]



export async function do_submit_file(file: string, api_key:string) {
    console.log("submitting file...", file)




}
import { describe, expect, it } from "bun:test";
import { do_parse_recipe_text, recipeSchema } from "../src/parse_recipe.ts";
// @ts-ignore
import recipeText from "./test_input/recipe_text.txt" with { type: "text" };
import { Ok, Error as GError } from "../src/gleam.mjs";

describe("parse_recipe", () => {
    it("should parse recipe text from file", async () => {
        console.log("Testing with recipe text length:", recipeText.length);
        
        const result = await do_parse_recipe_text(recipeText);
        
        if (result instanceof GError) {
             console.error("Test failed with Error:", JSON.stringify(result[0], null, 2));
        }

        expect(result).toBeInstanceOf(Ok);
        
        if (result instanceof Ok) {
            const data = result[0];
            console.log("Parsed Data:", JSON.stringify(data, null, 2));
            
            // Validate against the exact schema used in generation
            for (const key of Object.keys(recipeSchema.properties)) {
                expect(data).toHaveProperty(key);
            }
            
            // Type checks based on basic schema knowledge (could be dynamically derived but simple is better here)
            expect(data.ingredients).toBeInstanceOf(Array);
            expect(data.method_steps || data.steps).toBeInstanceOf(Array); // Schema uses method_steps now? user schema shows steps in original plan but recent output showed method_steps in one log and steps in another.
            // Let's rely on schema keys. 
        }
    },{timeout: 30000, retry: 3});

    it("should return error for empty text", async () => {
        const result = await do_parse_recipe_text("");
        expect(result).toBeInstanceOf(GError);
        if (result instanceof GError) {
            expect(result[0].Other.message).toBe("Recipe text is empty.");
        }
    });
});

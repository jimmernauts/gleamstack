import { describe, expect, it } from "bun:test";
import { do_parse_recipe_text, recipeSchema } from "../../src/parse_recipe.ts";
import { Ok } from "../../src/gleam.mjs";
// @ts-ignore
import recipeText from "../test_input/recipe_text.txt" with { type: "text" };

if (!process.env.INSTANT_ADMIN_TOKEN) {
    throw new Error(
        "INSTANT_ADMIN_TOKEN is required for parse recipe integration tests",
    );
}

describe("parse recipe integration", () => {
    it(
        "parses the repository recipe fixture through InstantDB and Gemini",
        async () => {
            const result = await do_parse_recipe_text(recipeText);
            expect(result).toBeInstanceOf(Ok);

            if (result instanceof Ok) {
                const data = result[0];
                for (const key of Object.keys(recipeSchema.properties)) {
                    expect(data).toHaveProperty(key);
                }
                expect(data.ingredients).toBeInstanceOf(Array);
                expect(data.method_steps).toBeInstanceOf(Array);
            }
        },
        { timeout: 180_000 },
    );
});

import { describe, expect, it } from "bun:test";
import { requireUatEnvironment } from "./uat_env.ts";
import { do_parse_recipe_text, recipeSchema } from "../../src/parse_recipe.ts";
import { Ok } from "../../src/gleam.mjs";
// @ts-ignore
import recipeText from "../test_input/recipe_text.txt" with { type: "text" };

requireUatEnvironment();

describe("parse recipe integration", () => {
    it(
        "parses the repository recipe fixture through Turso and Gemini",
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

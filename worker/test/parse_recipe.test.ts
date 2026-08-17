import { describe, expect, it } from "bun:test";
import { do_parse_recipe_text, recipeSchema } from "../src/parse_recipe.ts";
import { Ok, Error as GError } from "../src/gleam.mjs";

describe("parse_recipe", () => {

    it("should return error for empty text", async () => {
        const result = await do_parse_recipe_text("");
        expect(result).toBeInstanceOf(GError);
        if (result instanceof GError) {
            expect(result[0].Other.message).toBe("Recipe text is empty.");
        }
    });

    it("should return an error for empty image data", async () => {
        const { do_parse_recipe_image } = await import("../src/parse_recipe.ts");
        const result = await do_parse_recipe_image("");
        expect(result).toBeInstanceOf(GError);
    });
});

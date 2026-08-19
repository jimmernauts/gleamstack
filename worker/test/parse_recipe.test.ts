import { describe, expect, it } from "bun:test";
import {
    buildTagInstructions,
    do_parse_recipe_text,
    normalizeTags,
    recipeSchema,
} from "../src/parse_recipe.ts";
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
    it("builds metadata instructions from existing options only", () => {
        const instructions = buildTagInstructions({
            Cuisine: ["Italian"],
            Style: ["Salad"],
            Label: ["Light"],
        });
        expect(instructions).toContain("Cuisine: Italian");
        expect(instructions).toContain("Style: Salad");
        expect(instructions).toContain("Label: Light");
        expect(instructions).toContain("Use only an exact value");
    });

    it("filters metadata to exact existing values and emits frontend tag objects", () => {
        const tags = normalizeTags(
            [
                { name: "Cuisine", value: "italian" },
                { name: "Style", value: "Pasta" },
                { name: "Label", value: "Light" },
                { name: "Cuisine", value: "French" },
            ],
            {
                Cuisine: ["Italian", "French"],
                Style: ["Salad"],
                Label: ["Light"],
            },
        );
        expect(tags).toEqual({
            "0": { name: "Cuisine", value: "Italian" },
            "1": { name: "Label", value: "Light" },
        });
    });

    it("requires tags in the Gemini response schema", () => {
        expect(recipeSchema.properties).toHaveProperty("tags");
        expect(recipeSchema.required).toContain("tags");
    });

});

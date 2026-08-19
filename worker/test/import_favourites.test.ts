import { describe, expect, it } from "bun:test";
import {
    extractRecipeBookmarks,
    formatAdminError,
    scrapeRecipeToFrontendRecipe,
    selectExistingRecipe,
    stableRecipeId,
} from "../scripts/import_favourites.ts";
import { findDuplicateGroups } from "../scripts/cleanup_recipe_duplicates.ts";
import type { ScrapeRecipe } from "../src/scrape_url.ts";
// @ts-ignore
import bookmarks from "../../plans/favourites_17_08_2026.html" with { type: "text" };

describe("favourites importer", () => {
    it("selects the distinct links in the recipe folder", () => {
        const selected = extractRecipeBookmarks(bookmarks);

        expect(selected).toHaveLength(230);
        expect(selected[0]).toEqual({
            index: 0,
            title: "Mediterranean potato salad recipe | BBC Good Food",
            url: "https://www.bbcgoodfood.com/recipes/mediterranean-potato-salad-0",
        });
        expect(selected[9].url).toBe(
            "https://www.theguardian.com/food/2023/sep/02/vegan-sabzi-polo-herbed-rice-saffron-pistachios-recipe-meera-sodha",
        );
    });

    it("includes status and response body in Admin API errors", () => {
        const error = JSON.parse(
            formatAdminError({
                status: 403,
                message: "Forbidden",
                body: { type: "unauthorized", message: "Invalid token" },
            }),
        );
        expect(error).toEqual({
            status: 403,
            message: "Forbidden",
            body: { type: "unauthorized", message: "Invalid token" },
        });
    });

    it("maps scraper arrays into the frontend's persisted JSON shape", () => {
        const scrapeRecipe: ScrapeRecipe = {
            title: "Test Recipe",
            slug: "test-recipe",
            cook_time: 20,
            prep_time: 10,
            serves: 4,
            source: "https://example.com/recipe",
            tags: JSON.stringify({
                "0": { name: "Cuisine", value: "Italian" },
            }),
            ingredients: [
                "1 cup flour",
                { name: "Egg", quantity: "2", units: "", isMain: true },
            ],
            method_steps: [{ step_text: "Mix everything" }],
        };

        const recipe = scrapeRecipeToFrontendRecipe(
            scrapeRecipe,
            "https://example.com/recipe",
        );

        expect(JSON.parse(recipe.ingredients ?? "{}")).toEqual({
            "0": {
                name: "1 cup flour",
                quantity: "",
                units: "",
                ismain: "false",
                category: { name: "" },
            },
            "1": {
                name: "Egg",
                quantity: "2",
                units: "",
                ismain: "true",
                category: { name: "" },
            },
        });
        expect(JSON.parse(recipe.method_steps ?? "{}")).toEqual({
            "0": { step_text: "Mix everything" },
        });
        expect(JSON.parse(recipe.tags ?? "{}")).toEqual({
            "0": { name: "Cuisine", value: "Italian" },
        });

    });

    it("derives a stable entity ID for resume-safe upserts", () => {
        const first = stableRecipeId("https://example.com/recipe", "test-recipe");
        expect(first).toBe(
            stableRecipeId("https://example.com/recipe", "test-recipe"),
        );
        expect(first).not.toBe(
            stableRecipeId("https://example.com/other", "test-recipe"),
        );
        expect(first).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    });

    it("prefers the existing stable entity when matching duplicates", () => {
        const stableId = stableRecipeId(
            "https://example.com/recipe",
            "test-recipe",
        );
        const selected = selectExistingRecipe(
            "https://example.com/recipe",
            {
                slug: "test-recipe",
                title: "Test Recipe",
                cook_time: 0,
                prep_time: 0,
                serves: 0,
            },
            [{ id: "random-id" }, { id: stableId }],
        );
        expect(selected?.id).toBe(stableId);
    });

    it("groups duplicate source URLs after removing tracking parameters", () => {
        const groups = findDuplicateGroups([
            {
                id: "old-id",
                slug: "test-recipe",
                title: "Test Recipe",
                source: "https://example.com/recipe/?utm_source=newsletter",
                ingredients: "{}",
                method_steps: "{}",
            },
            {
                id: "new-id",
                slug: "test-recipe",
                title: "Test Recipe",
                source: "https://example.com/recipe",
                ingredients: '{"0":{"name":"flour"}}',
                method_steps: '{"0":{"step_text":"Mix"}}',
            },
        ]);
        expect(groups).toHaveLength(1);
        expect(groups[0].confidence).toBe("source");
        expect(groups[0].delete_ids).toHaveLength(1);
    });

});

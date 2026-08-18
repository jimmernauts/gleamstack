import { describe, expect, it } from "bun:test";
import { requireUatEnvironment } from "./uat_env.ts";

type BookmarkCase = {
    name: string;
    url: string;
    minimumRecipes: number;
    exactRecipes?: number;
};

type ScrapePayload = {
    source_url?: string;
    recipes?: unknown[];
    warnings?: string[];
    status?: string;
};

const workerBaseUrl = requireUatEnvironment();

const bookmarks: BookmarkCase[] = [
    {
        name: "RecipeTinEats single recipe",
        url: "https://www.recipetineats.com/pearl-barley-soup/",
        minimumRecipes: 1,
    },
    {
        name: "EatingWell single recipe",
        url: "https://www.eatingwell.com/recipe/7884929/skillet-chicken-with-orzo-tomatoes/",
        minimumRecipes: 1,
    },
    {
        name: "Guardian garlic collection",
        url: "https://www.theguardian.com/food/2023/aug/24/the-bulb-and-the-beautiful-four-show-stealing-recipes-with-lots-of-garlic",
        minimumRecipes: 2,
    },
    {
        name: "Guardian recipe hacks collection",
        url: "https://www.theguardian.com/food/2025/jan/26/ultimate-custard-perfectly-timed-pasta-espresso-fuelled-stews-37-brilliant-recipe-hacks",
        minimumRecipes: 2,
    },
    {
        name: "Guardian non-recipe article",
        url: "https://www.theguardian.com/food/article/2024/jul/10/the-best-kitchen-knives-for-every-job-chosen-by-chefs",
        minimumRecipes: 0,
        exactRecipes: 0,
    },
];

async function scrapeAll(
    url: string,
 ): Promise<{ response: Response; payload: ScrapePayload }> {
    const endpoint = new URL("/api/scrape_url", workerBaseUrl);
    endpoint.searchParams.set("target", url);
    const response = await fetch(endpoint);
    const body = await response.text();

    let payload: ScrapePayload;
    try {
        payload = JSON.parse(body) as ScrapePayload;
    } catch {
        throw new Error(
            `UAT worker returned non-JSON (${response.status}): ${body.slice(0, 500)}`,
        );
    }

    return { response, payload };
}

describe("bookmark worker integration", () => {
    for (const bookmark of bookmarks) {
        it(
            `returns all recipes for ${bookmark.name}`,
            async () => {
                const { response, payload } = await scrapeAll(bookmark.url);
                const recipes = payload.recipes ?? [];

                expect(response.status).toBe(200);
                expect(payload.source_url).toBe(bookmark.url);
                expect(Array.isArray(payload.recipes)).toBe(true);
                expect(recipes.length).toBeGreaterThanOrEqual(bookmark.minimumRecipes);

                if (bookmark.exactRecipes !== undefined) {
                    expect(recipes).toHaveLength(bookmark.exactRecipes);
                }
            },
            { timeout: 180_000 },
        );
    }
});

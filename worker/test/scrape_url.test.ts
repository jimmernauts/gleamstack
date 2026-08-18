import { describe, expect, it } from "bun:test";
import { do_fetch_recipes, extractJsonLdRecipes } from "../src/scrape_url";
import type { Recipe } from "../../common/types.ts";
import { Ok } from "../src/gleam.mjs";

const extractJsonLd = async (html: string) =>
	((await extractJsonLdRecipes(html))[0] ?? null) as Recipe | null;

describe("extractJsonLd", () => {
	describe("serves parsing", () => {
		it("should parse numeric recipeYield", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeIngredient": ["test"],
            "recipeYield": 4
          }
        </script>
      `;

			const result = await extractJsonLd(html);
			expect(result?.serves).toBe(4);
		});

		it("should parse string recipeYield", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeIngredient": ["test"],
            "recipeYield": "6"
          }
        </script>
      `;

			const result = await extractJsonLd(html);
			expect(result?.serves).toBe(6);
		});

		it("should parse array recipeYield", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeIngredient": ["test"],
            "recipeYield": ["8", "8 servings"]
          }
        </script>
      `;

			const result = await extractJsonLd(html);
			expect(result?.serves).toBe(8);
		});

		it("should return 0 for invalid recipeYield", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeIngredient": ["test"],
            "recipeYield": "invalid"
          }
        </script>
      `;

			const result = await extractJsonLd(html);
			expect(result?.serves).toBe(0);
		});
	});

	describe("time parsing", () => {
		it("should parse ISO duration for cook time", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeIngredient": ["test"],
            "cookTime": "PT1H30M"
          }
        </script>
      `;

			const result = await extractJsonLd(html);
			expect(result?.cook_time).toBe(90); // 1h30m = 90 minutes
		});

		it("should parse ISO duration for prep time", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeIngredient": ["test"],
            "prepTime": "PT45M"
          }
        </script>
      `;

			const result = await extractJsonLd(html);
			expect(result?.prep_time).toBe(45);
		});
	});

	describe("title and slug parsing", () => {
		it("should use name as title when available", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "name": "Chocolate Cake",
            "recipeIngredient": ["test"]
          }
        </script>
      `;

			const result = await extractJsonLd(html);
			expect(result?.title).toBe("Chocolate Cake");
			expect(result?.slug).toBe("chocolate-cake");
		});

		it("should fallback to title field when name is not available", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "title": "Chocolate Cake",
            "recipeIngredient": ["test"]
          }
        </script>
      `;

			const result = await extractJsonLd(html);
			console.log(result);
			expect(result?.title).toBe("Chocolate Cake");
			expect(result?.slug).toBe("chocolate-cake");
		});
	});

	describe("ingredients and method steps", () => {
		it("should parse ingredients array", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeIngredient": ["200g flour", "2 eggs", "100g sugar"]
          }
        </script>
      `;

			const result = await extractJsonLd(html);
			expect(result?.ingredients).toEqual(["200g flour", "2 eggs", "100g sugar"]);
		});

		it("should parse method steps array", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeInstructions": ["Mix dry ingredients", "Add wet ingredients", "Bake"]
          }
        </script>
      `;

			const result = await extractJsonLd(html);
			expect(result?.method_steps).toEqual([
				{ step_text: "Mix dry ingredients" },
				{ step_text: "Add wet ingredients" },
				{ step_text: "Bake" },
			]);
		});
	});

	describe("error handling", () => {
		it("should handle empty HTML", async () => {
			const result = await extractJsonLd("");
			expect(result).toBeNull();
		});

		it("should handle invalid JSON-LD", async () => {
			const html = `
        <script type="application/ld+json">
          invalid json
        </script>
      `;
			const result = await extractJsonLd(html);
			expect(result).toBeNull();
		});

		it("should handle missing JSON-LD script tag", async () => {
			const html = "<html><body>No recipe here</body></html>";
			const result = await extractJsonLd(html);
			expect(result).toBeNull();
		});

		it("should handle empty title with fallback", async () => {
			const html = `
        <script type="application/ld+json">
          {
            "@context": "https://schema.org/",
            "@type": "Recipe",
            "recipeIngredient": ["test"]
          }
        </script>
      `;
			const result = await extractJsonLd(html);
			expect(result).not.toBeNull();
			expect(result?.title).toMatch(/^Imported Recipe-/);
			expect(result?.slug).toMatch(/^imported-recipe-/);
		});
	});

describe("fetching pages", () => {
    it("does not forward inbound local headers to the source page", async () => {
        const originalFetch = globalThis.fetch;
        let capturedInit: RequestInit | undefined;
        const html = `
            <script type="application/ld+json">
                {"@type":"Recipe","name":"Test Recipe"}
            </script>
        `;

        globalThis.fetch = (async (_input, init) => {
            capturedInit = init;
            return new Response(html, {
                status: 200,
                headers: { "content-type": "text/html" },
            });
        }) as typeof fetch;

        try {
            const request = new Request(
                "http://127.0.0.1:3000/api/scrape_url?target=source",
                {
                    headers: {
                        "accept-language": "fr-FR",
                        "x-forwarded-host": "127.0.0.1:3000",
                    },
                },
            );
            const result = await do_fetch_recipes(
                "https://example.com/recipe",
                request,
            );

            expect(result).toBeInstanceOf(Ok);
            const headers = new Headers(capturedInit?.headers);
            expect(headers.get("accept-language")).toBe("fr-FR");
            expect(headers.get("x-forwarded-host")).toBeNull();
            expect(headers.get("host")).toBeNull();
            expect(headers.get("user-agent")).toContain("Mozilla");
        } finally {
            globalThis.fetch = originalFetch;
        }
    });
});
});

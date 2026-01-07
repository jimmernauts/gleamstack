import { describe, expect, it } from "bun:test";
import { extractJsonLd } from "../src/scrape_url";

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
			const ingredients = JSON.parse(result?.ingredients || "[]");
			expect(ingredients).toEqual(["200g flour", "2 eggs", "100g sugar"]);
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
			const steps = JSON.parse(result?.method_steps || "[]");
			expect(steps).toEqual([
				"Mix dry ingredients",
				"Add wet ingredients",
				"Bake",
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
});

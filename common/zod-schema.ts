import { z } from "zod";

export const recipeSchema = z.object({
	id: z.string().optional(),
	slug: z.string(),
	title: z.string().describe("The recipe title"),
	cook_time: z
		.number()
		.describe("How long it takes to cook the recipe, in minutes"),
	prep_time: z
		.number()
		.describe("How long it takes to prepare the recipe, in minutes"),
	serves: z.number().describe("How many servings the recipe makes"),
	author: z.string().optional().describe("The recipe author"),
	source: z.string().optional().describe("The recipe source"),
	ingredients: z
		.array(
			z.object({
				name: z.string().describe("The ingredient name"),
				quantity: z
					.string()
					.describe("The quantity of this ingredient specified by the recipe"),
				units: z
					.string()
					.describe("The units used for the quantity of this ingredient"),
				ismain: z
					.string()
					.describe(
						"Denotes whether this is a main ingredient of the recipe. Must be either 'true' or 'false'.",
					),
			}),
		)
		.optional()
		.describe("The ingredient list for the recipe"),
	method_steps: z
		.array(
			z.object({
				step_text: z
					.string()
					.describe("The text describing this step in the recipe method"),
			}),
		)
		.optional()
		.describe("The steps required to prepare and cook the recipe"),
	tags: z.array(z.string()).optional(),
	shortlisted: z.boolean().optional(),
});

export const importedRecipeSchema = recipeSchema.omit({
	id: true,
	slug: true,
	shortlisted: true,
	tags: true,
});

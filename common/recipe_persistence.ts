import type { Recipe } from "./types.ts";

export type RecipePersistenceFields = Pick<
    Recipe,
    "slug" | "title" | "cook_time" | "prep_time" | "serves"
> &
    Partial<
        Pick<
            Recipe,
            | "author"
            | "source"
            | "tags"
            | "ingredients"
            | "method_steps"
            | "shortlisted"
        >
    >;

/**
 * Keep the fields and omission rules used by the frontend recipe save path.
 * This is deliberately a pure mapper so the one-off admin importer can use
 * the same persistence shape without importing the browser InstantDB client.
 */
export function toRecipePersistenceFields(
    recipe: Recipe,
): RecipePersistenceFields {
    return {
        slug: recipe.slug,
        title: recipe.title,
        cook_time: recipe.cook_time,
        prep_time: recipe.prep_time,
        serves: recipe.serves,
        ...(recipe.author !== undefined && recipe.author !== ""
            ? { author: recipe.author }
            : {}),
        ...(recipe.source !== undefined && recipe.source !== ""
            ? { source: recipe.source }
            : {}),
        ...(recipe.tags !== undefined &&
        recipe.tags !== "null" &&
        recipe.tags !== "{}"
            ? { tags: recipe.tags }
            : {}),
        ...(recipe.ingredients !== undefined &&
        recipe.ingredients !== "null" &&
        recipe.ingredients !== "{}"
            ? { ingredients: recipe.ingredients }
            : {}),
        ...(recipe.method_steps !== undefined &&
        recipe.method_steps !== "null" &&
        recipe.method_steps !== "{}"
            ? { method_steps: recipe.method_steps }
            : {}),
        ...(recipe.shortlisted === true ? { shortlisted: true } : {}),
    };
}

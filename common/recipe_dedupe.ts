import { createHash } from "node:crypto";

export type RecipeIdentityInput = {
    source?: unknown;
    slug?: unknown;
    title?: unknown;
};

export type RecipeIdentity = {
    key: string;
    confidence: "source" | "title" | "slug";
    source: string;
    slug: string;
    title: string;
};

const TRACKING_QUERY_PARAMETERS = new Set([
    "fbclid",
    "gclid",
    "mc_cid",
    "mc_eid",
]);

function asText(value: unknown): string {
    return typeof value === "string" ? value.trim() : "";
}

function isEmptyValue(value: string): boolean {
    return value === "" || value === "null" || value === "{}";
}

export function normalizeRecipeSlug(value: unknown): string {
    return asText(value).replace(/^\/+|\/+$/g, "").toLowerCase();
}

export function normalizeRecipeTitle(value: unknown): string {
    return asText(value)
        .normalize("NFKD")
        .replace(/\p{Mark}/gu, "")
        .toLowerCase()
        .replace(/[^\p{Letter}\p{Number}]+/gu, "-")
        .replace(/^-+|-+$/g, "");
}

export function normalizeRecipeSource(value: unknown): string {
    const source = asText(value);
    if (isEmptyValue(source)) return "";

    try {
        const url = new URL(source);
        url.hash = "";
        for (const parameter of [...url.searchParams.keys()]) {
            if (
                parameter.toLowerCase().startsWith("utm_") ||
                TRACKING_QUERY_PARAMETERS.has(parameter.toLowerCase())
            ) {
                url.searchParams.delete(parameter);
            }
        }
        url.searchParams.sort();
        if (url.pathname.length > 1) {
            url.pathname = url.pathname.replace(/\/+$/, "");
        }
        return url.toString();
    } catch {
        return source.replace(/\/+$/, "").toLowerCase();
    }
}

export function recipeIdentity(
    input: RecipeIdentityInput,
    fallbackSource?: unknown,
): RecipeIdentity | undefined {
    const slug = normalizeRecipeSlug(input.slug);
    if (!slug) return undefined;

    const source = normalizeRecipeSource(input.source || fallbackSource);
    const title = normalizeRecipeTitle(input.title);
    if (source) {
        return {
            key: `source:${source}#${slug}`,
            confidence: "source",
            source,
            slug,
            title,
        };
    }

    if (title) {
        return {
            key: `title:${title}#${slug}`,
            confidence: "title",
            source: "",
            slug,
            title,
        };
    }

    return {
        key: `slug:${slug}`,
        confidence: "slug",
        source: "",
        slug,
        title,
    };
}

export function recipeIdentityAliases(
    input: RecipeIdentityInput,
    fallbackSource?: unknown,
 ): RecipeIdentity[] {
    const primary = recipeIdentity(input, fallbackSource);
    if (!primary) return [];
    const aliases = [primary];
    if (primary.confidence === "source") {
        const sourceLess = recipeIdentity({
            slug: input.slug,
            title: input.title,
        });
        if (sourceLess && sourceLess.key !== primary.key) aliases.push(sourceLess);
    }
    return aliases;
}

export function stableRecipeId(sourceUrl: string, slug: string): string {
    const hex = createHash("sha256")
        .update(`${sourceUrl}\n${slug}`)
        .digest("hex")
        .slice(0, 32);
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-5${hex.slice(13, 16)}-${(8 | Number.parseInt(hex[16], 16) % 4).toString(16)}${hex.slice(17, 20)}-${hex.slice(20)}`;
}

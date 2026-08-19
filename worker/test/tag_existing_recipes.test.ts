import { describe, expect, it } from "bun:test";
import {
    isRateLimitError,
    retryDelayMs,
} from "../scripts/tag_existing_recipes.ts";

describe("existing recipe tag backfill rate limits", () => {
    it("recognizes Gemini quota errors and honors retryDelay", () => {
        const error = {
            error: {
                code: 429,
                status: "RESOURCE_EXHAUSTED",
                details: [{ "@type": "RetryInfo", retryDelay: "48s" }],
            },
        };

        expect(isRateLimitError(error)).toBe(true);
        expect(retryDelayMs(error, 0)).toBe(48_000);
    });

    it("uses exponential fallback delay when Gemini gives no retry delay", () => {
        const error = new Error("429 too many requests");

        expect(isRateLimitError(error)).toBe(true);
        expect(retryDelayMs(error, 1)).toBe(10_000);
    });

    it("does not retry unrelated failures", () => {
        expect(isRateLimitError(new Error("invalid response"))).toBe(false);
    });
});

import Anthropic from "@anthropic-ai/sdk";
import { Ok, Error as GError } from "./gleam.mjs";

type dispatchFunction = (
  result:
    | Ok<string, never>
    | GError<never, { UrlError: { message: string } }>
    | GError<never, { Other: { message: string } }>,
) => void;

export async function do_fetch_url_data(url: string, dispatch: dispatchFunction): Promise<void> {
  try {
    // Fetch URL content
    const response = await fetch(url);
    const html = await response.text();
    
    // Extract JSON-LD data
    const jsonLd = extractJsonLd(html);
    if (jsonLd) {
      dispatch(new Ok(JSON.stringify(jsonLd)));
    } else {
      // If no JSON-LD, send the whole HTML
      dispatch(new Ok(html));
    }
  } catch (error) {
    dispatch(
      new GError({
        UrlError: { message: `Failed to fetch URL: ${error.message}` },
      }),
    );
  }
}

function extractJsonLd(html: string): any {
  const jsonLdRegex = /<script type="application\/ld\+json">(.*?)<\/script>/gs;
  const matches = [...html.matchAll(jsonLdRegex)];
  
  for (const match of matches) {
    try {
      const data = JSON.parse(match[1]);
      if (data["@type"] === "Recipe") {
        return data;
      }
    } catch (e) {
      console.error("Failed to parse JSON-LD:", e);
    }
  }
  return null;
}

export async function do_submit_url_data(
  data: string,
  dispatch: dispatchFunction,
): Promise<void> {
  const apiKey = await do_retrieve_settings();
  const client = new Anthropic({
    apiKey: apiKey,
    dangerouslyAllowBrowser: true,
  });

  try {
    const response = await client.messages.create({
      model: "claude-3-5-haiku-20241022",
      max_tokens: 2000,
      temperature: 0,
      thinking: { type: "disabled" },
      system: "You are a helpful assistant that extracts recipe information from HTML or JSON-LD data. Extract all recipe details including title, ingredients, preparation steps, cooking time, and serving size.",
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text: `Extract the recipe from this data and format it using the recipe_formatter tool: ${data}`,
            },
          ],
        },
      ],
      tools: tools, // Use the same tools array from upload.ts
      tool_choice: {
        type: "tool",
        name: "recipe_formatter",
      },
    });

    const toolCalls = response.content.filter(
      (item) => item.type === "tool_use" && item.name === "recipe_formatter",
    );

    if (toolCalls.length > 0) {
      dispatch(new Ok(toolCalls[0].input));
    } else {
      dispatch(
        new GError({ Other: { message: "Failed to extract recipe data" } }),
      );
    }
  } catch (error) {
    dispatch(
      new GError({ Other: { message: `API error: ${error.message}` } }),
    );
  }
}
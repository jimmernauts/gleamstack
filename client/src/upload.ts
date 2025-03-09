import Anthropic from "@anthropic-ai/sdk";
import { Jimp } from "jimp";
import { Ok, Error as GError } from "./gleam.mjs";
import { do_retrieve_settings } from "./db.ts";

type dispatchFunction = (
	result:
		| Ok<string, never>
		| GError<never, { FileReadError: { message: string } }>
		| GError<never, { Other: { message: string } }>,
) => void;

// read a file from an event
export async function do_read_file_from_event(
	event: Event,
	dispatch: dispatchFunction,
): Promise<void> {
	console.log("do_read_file_from_event");
	console.log(event);
	const target = event.target as HTMLInputElement;
	const file = target?.files?.[0] as File;

	if (!file) {
		dispatch(new GError({ FileReadError: { message: "No file selected" } }));
		return;
	}

	const reader = new FileReader();

	reader.onload = async (e) => {
		const contents = e?.target?.result as string;

		try {
			let processedDataUrl = contents;
			if (file.size > MAX_FILE_SIZE) {
				processedDataUrl = await processImageAsBase64(contents);
			}

			dispatch(new Ok(processedDataUrl));
		} catch (error) {
			console.error("Error processing image:", error);
			dispatch(
				new GError({
					FileReadError: {
						message: `Failed to process image. File contents: ${contents}`,
					},
				}),
			);
		}
	};
	reader.onerror = (e) => {
		console.error("Error reading file:", e?.target?.error);
		dispatch(
			new GError({
				FileReadError: { message: `Failed to read file: ${e?.target?.error}` },
			}),
		);
	};

	// Start reading the file
	reader.readAsDataURL(file);
}

// Maximum file size (3 MB)
const MAX_FILE_SIZE = 3 * 1024 * 1024;

const tools: Anthropic.Tool[] = [
	{
		name: "recipe_formatter",
		description:
			"Reads a recipe document and formats it for display in a recipe reader application",
		input_schema: {
			type: "object",
			properties: {
				title: {
					type: "string",
					description: "The recipe title",
				},
				cook_time: {
					type: "integer",
					description: "How long it takes to cook the recipe, in minutes",
				},
				prep_time: {
					type: "integer",
					description: "How long it takes to prepare the recipe, in minutes",
				},
				serves: {
					type: "integer",
					description: "How many servings the recipe makes",
				},
				ingredients: {
					type: "array",
					description: "The ingredient list for the recipe",
					items: {
						type: "object",
						properties: {
							name: {
								type: "string",
								description: "The ingredient name",
							},
							ismain: {
								type: "string",
								description:
									"Denotes whether this is a main ingredient of the recipe. Must be either 'true' or 'false'.",
							},
							quantity: {
								type: "string",
								description:
									"The quantity of this ingredient specified by the recipe",
							},
							units: {
								type: "string",
								description:
									"The units used for the quantity of this ingredient",
							},
						},
					},
				},
				method_steps: {
					type: "array",
					description: "The steps required to prepare and cook the recipe",
					items: {
						type: "object",
						properties: {
							step_text: {
								type: "string",
								description:
									"The text describing this step in the recipe method",
							},
						},
					},
				},
			},
			required: ["title", "cook_time", "prep_time", "serves"],
		},
	},
];

/**
 * Processes an image using Jimp
 * - Resizes the image if it's over 5MB
 * - Converts it to base64 for API submission
 */
export async function processImageAsBase64(dataUrl: string): Promise<string> {
	const image = await Jimp.read(dataUrl);

	// Check if the image is already under the maximum size
	const sizeInBytes = (dataUrl.length * 3) / 4; // Base64 uses 4 chars to represent 3 bytes
	if (sizeInBytes < MAX_FILE_SIZE) {
		console.log("Image is already under 3MB, no processing needed");
		return dataUrl;
	}

	console.log(
		`Image size: ${(image.bitmap.data.length / 1024 / 1024).toFixed(2)}MB`,
	);

	// Process the image with Jimp
	const startingWidth = image.width;
	const startingHeight = image.height;
	const resizedImage = image.resize({
		w: startingWidth * 0.75,
		h: startingHeight * 0.75,
	});
	// Convert back to base64
	const mimeType = dataUrl.substring(
		dataUrl.indexOf(":") + 1,
		dataUrl.indexOf(";"),
	) as "image/jpeg" | "image/png";
	const processedBase64 = await resizedImage.getBase64(mimeType);

	// Check if we need to process again
	const processedSizeInBytes = (processedBase64.length * 3) / 4; // Base64 uses 4 chars to represent 3 bytes
	if (processedSizeInBytes < MAX_FILE_SIZE) {
		return processedBase64;
	}
	// If still too large, recursively process it again
	return processImageAsBase64(processedBase64);
}

export async function do_submit_file(
	file_data: string,
	dispatch: dispatchFunction,
): Promise<void> {
	console.log("Submitting file...");
	const apiKey = await do_retrieve_settings();

	// Initialize Anthropic with the provided API key
	const client = new Anthropic({
		apiKey: apiKey,
		dangerouslyAllowBrowser: true,
	});

	console.log("Sending to Anthropic API...");
	const response = await client.messages.create({
		model: "claude-3-5-haiku-20241022",
		max_tokens: 2000,
		temperature: 0,
		thinking: { type: "disabled" },
		system:
			"You are a helpful assistant that extracts recipe information from images. Extract all recipe details including title, ingredients, preparation steps, cooking time, and serving size.",
		messages: [
			{
				role: "user",
				content: [
					{
						type: "image",
						source: {
							type: "base64",
							media_type: file_data.substring(
								file_data.indexOf(":") + 1,
								file_data.indexOf(";"),
							) as "image/gif" | "image/jpeg" | "image/png" | "image/webp",
							data: file_data.split(",")[1],
						},
					},
					{
						type: "text",
						text: "Extract the recipe from this image and format it using the recipe_formatter tool.",
					},
				],
			},
		],
		tools: tools,
		tool_choice: {
			type: "tool",
			name: "recipe_formatter",
		},
	});
	// Parse the tool calls from the response
	const toolCalls = response.content.filter(
		(item) => item.type === "tool_use" && item.name === "recipe_formatter",
	);

	if (toolCalls.length > 0) {
		// @ts-ignore - Anthropic types might not fully match our usage
		const recipeData = toolCalls[0].input;
		dispatch(new Ok(recipeData));
	} else {
		dispatch(
			new GError({ Other: { message: "Failed to extract recipe data" } }),
		);
	}
}

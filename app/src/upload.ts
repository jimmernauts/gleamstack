import { Jimp } from "jimp";
import { Ok, Error as GError } from "./gleam.mjs";


type dispatchFunction = (
    result:
        | Ok<string, never>
        | GError<never, { UrlError: { message: string } }>
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
        dispatch(
            new GError({ FileReadError: { message: "No file selected" } }),
        );
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
                FileReadError: {
                    message: `Failed to read file: ${e?.target?.error}`,
                },
            }),
        );
    };

    // Start reading the file
    reader.readAsDataURL(file);
}

// Maximum file size (3 MB)
const MAX_FILE_SIZE = 3 * 1024 * 1024;


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
    console.log("Submitting file to worker...");
    
    try {
        const response = await fetch("/api/parse_recipe_image", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ image: file_data }),
        });

        if (!response.ok) {
            throw new Error(`Worker returned ${response.status}: ${await response.text()}`);
        }

        const result = await response.json();
        dispatch(new Ok(result));

    } catch (error) {
        console.error("Error submitting file to worker:", error);
        dispatch(
            new GError({
                Other: {
                    message: `API error: ${
                        error instanceof Error ? error.message : String(error)
                    }`,
                },
            }),
        );
    }
}

export async function do_submit_text(
    data: string,
    dispatch: dispatchFunction,
): Promise<void> {
    try {
        const response = await fetch("/api/parse_recipe_text", {
             method: "POST",
             headers: {
                 "Content-Type": "application/json",
             },
             body: JSON.stringify({ text: data }),
        });

        if (!response.ok) {
            throw new Error(`Worker returned ${response.status}: ${await response.text()}`);
        }

        const result = await response.json();

        dispatch(new Ok(result));

    } catch (error) {
        console.error("Error submitting text to worker:", error);
        dispatch(
            new GError({
                Other: {
                    message: `API error: ${
                        error instanceof Error ? error.message : String(error)
                    }`,
                },
            }),
        );
    }
}

export async function do_scrape_url(
    url: string,
    cb: dispatchFunction,
): Promise<void> {
    const response = await fetch(
        `./api/scrape_url?target=${url}`,
    );
    const body = await response.text();
    try {
        cb(new Ok(body));
    } catch (error) {
        cb(
            new GError({
                Other: {
                    message: `Failed to scrape the URL ${url}. Error: ${
                        error instanceof Error ? error.message : String(error)
                    }`,
                },
            }),
        );
    }
}
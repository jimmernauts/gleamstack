import marimo

__generated_with = "0.9.15"
app = marimo.App(width="medium")


@app.cell
def __():
    import dotenv
    from anthropic import Anthropic
    import base64
    import json
    import os
    from PIL import Image

    path = dotenv.find_dotenv(usecwd=True)
    dotenv.load_dotenv(path)
    client = Anthropic()

    def ocr_all_images(path):
        tools = [
            {
                "name": "recipe_formatter",
                "description": "Reads a recipe document and formats it for display in a recipe reader application",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "title": {"type": "string", "description": "The recipe title"},
                        "cook_time": {
                            "type": "integer",
                            "description": "How long it takes to cook the recipe, in minutes",
                        },
                        "prep_time": {
                            "type": "integer",
                            "description": "How long it takes to prepare the recipe, in minutes",
                        },
                        "serves": {
                            "type": "integer",
                            "description": "How many servings the recipe makes",
                        },
                        "ingredients": {
                            "type": "array",
                            "description": "The ingredient list for the recipe",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "name": {
                                        "type": "string",
                                        "description": "The ingredient name",
                                    },
                                    "ismain": {
                                        "type": "boolean",
                                        "description": "Denotes whether this is a main ingredient of the recipe",
                                    },
                                    "quantity": {
                                        "type": "string",
                                        "description": "The quantity of this ingredient specified by the recipe",
                                    },
                                    "units": {
                                        "type": "string",
                                        "description": "The units used for the quantity of this ingredient",
                                    },
                                },
                            },
                        },
                        "method_steps": {
                            "type": "array",
                            "description": "The steps required to prepare and cook the recipe",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "step_text": {
                                        "type": "string",
                                        "description": "The text describing this step in the recipe method",
                                    }
                                },
                            },
                        },
                    },
                    "required": ["title", "cook_time", "prep_time", "serves"],
                },
            }
        ]
        tool_choice = {"type": "tool", "name": "recipe_formatter"}

        directory = os.fsencode(path)

        for file in os.listdir(directory):
            filename = os.fsdecode(file)
            if filename.endswith(".jpg") or filename.endswith(".jpeg"):
                # first check if larger than 5mb, if so, optimize
                size = os.stat(path+filename).st_size / (1024 * 1024)
                if size > 5:
                    Image.open(path+filename).save(path+filename, optimize=True, quality=95)
                # opens the image file in "read binary" mode
                with open(path+filename, "rb") as image_file:
                    # reads the contents of the image as a bytes object
                    binary_data = image_file.read()
                    # encodes the binary data using Base64 encoding
                    base_64_encoded_data = base64.b64encode(binary_data)
                    # decodes base_64_encoded_data from bytes to a string
                    base64_string = base_64_encoded_data.decode("utf-8")

                messages = [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image",
                                "source": {
                                    "type": "base64",
                                    "media_type": "image/jpeg",
                                    "data": base64_string,
                                },
                            },
                            {"type": "text", "text": "use the recipe_formatter tool"},
                        ],
                    },
                ]


                response = client.messages.create(
                    model="claude-3-sonnet-20240229",
                    max_tokens=2000,
                    tools=tools,
                    tool_choice={"type": "tool", "name": "recipe_formatter"},
                    messages=messages,
                    system="You are a recipe assistant, in charge of keeping a home cook's recipes and meal plans organized and accurate.",
                )

                formatted_recipe = None
                for content in response.content:
                    if content.type == "tool_use" and content.name == "recipe_formatter":
                        formatted_recipe = content.input
                        break
                if formatted_recipe:
                    print(formatted_recipe)
                    with open(formatted_recipe["title"] + ".json", "w") as outfile:
                        json.dump(formatted_recipe, outfile, indent=4)
                else:
                    print("No recipe found in the response.")
            else:
                continue
    return (
        Anthropic,
        Image,
        base64,
        client,
        dotenv,
        json,
        ocr_all_images,
        os,
        path,
    )


@app.cell
def __():
    #ocr_all_images("./prompting_images/")
    return


if __name__ == "__main__":
    app.run()

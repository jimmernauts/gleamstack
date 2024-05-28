import { addOrUpdateRecipe, listRecipes, addTagOption, listTagOptions, prepareTables } from "./db.ts";

const TagOptionSeed = [
  {
    name: "Cuisine",
    options: [
      "Mediterranean",
      "French",
      "Italian",
      "Chinese",
      "Thai",
      "Australian",
      "Japanese",
      "International",
    ],
  },
  {
    name: "Style",
    options: [
      "Veggie",
      "Meat & Sides",
      "Soups / Noodles / Stir Fry",
      "Salad",
      "Slow Cooker",
      "Oven Bake",
      "BBQ",
      "Bakery"
    ],
  },
  {
    name: "Label",
    options: [
      "Go-to",
      "Weeknight",
      "Fancy",
      "Light",
      "Substantial",
    ],
  },
];
const RecipeSeed = [{
  title: "Pink potato salad",
  slug: 'pink-potato-salad',
  cook_time: 10,
  prep_time: 10,
  serves: 4,
  shortlisted: false,
  ingredients: [
    { units: "g", quantity: "600", name: "Baby potato" },
    { units: "pc", quantity: "1 / 2", name: "Red Cabbage" },
    { units: "g", quantity: "200", name: "Pomegranate seeds" },
    { units: "tin", quantity: "1", name: "Butter Beans" },
    { units: "g", quantity: "100", name: "Mayonnaise" },
    { units: "g", quantity: "50", name: "Yoghurt" },
    { units: "tbsp", quantity: "3", name: "Extra Virgin Olive Oil" },
    { units: "pc", quantity: "1 / 2", name: "Lemon juice" },
    { units: "g", quantity: "15", name: "Flat - leaf parsley" },
  ],
  method_steps: [{
    stepText:
      "Boil the potatoes in salted water for 10 minutes, until they are just cooked through, then drain and rinse under running cold water to cool.",
  }, {
    stepText:
      "While the potatoes are cooking, shred the cabbage, deseed the pomegranate (or open the packet), and drain and rinse the beans.",
  }, {
    stepText:
      "In a bowl, mix the mayonnaise, yoghurt, lemon juice, oil, a teaspoon of flaky sea salt and plenty of pepper, then taste and adjust the seasoning accordingly.",
  }, {
    stepText:
      "Put the cooled, drained potatoes, red cabbage, pomegranate, beans and the dressing in a large bowl, then taste and adjust the seasoning if necessary. Arrange on a large plate, scatter over the parsley and serve at room temperature.",
  }],
  tags: [{ name: "Cuisine", value: "Australian" }, {
    name: "Style",
    value: "Salad",
  }, { name: "Label", value: "Light" }],
}];

export async function seedDb() {
  console.log("beginning seedDb")
  const preparetables = await prepareTables();
	const tagoptions = await listTagOptions();
  console.log(tagoptions[0])
	const recipes = await listRecipes();
  console.log(recipes[0])
  console.log("tagoptions.length: ",tagoptions[0].length)
	if (tagoptions[0].length === 0) {
		for (const item of TagOptionSeed) {
			const res = await addTagOption(item);
		}
	}
  console.log("recipes.length: ",recipes[0].length)
	if (recipes[0].length === 0) {
		for (const item of RecipeSeed) {
			await addOrUpdateRecipe(item);
		}
	}
  console.log("finishing seedDb")
}

export async function forceSeedTags() {
  for (const item of TagOptionSeed)
  {const res = await addTagOption(item) }
}
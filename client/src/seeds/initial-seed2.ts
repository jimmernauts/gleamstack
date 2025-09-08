import { init, id } from "@instantdb/admin";
import schema from "../instant.schema.ts";
// ID for app: mealstack
const APP_ID = "eeaf3b82-5b5d-40c4-a29a-b68988377c3c";
const db = init({
	appId: APP_ID,
	adminToken: process.env.INSTANT_ADMIN_TOKEN!,
	schema,
});

const recipes_to_insert = [
	{
		title: "Pink potato salad",
		slug: "pink-potato-salad",
		cook_time: 10,
		prep_time: 10,
		serves: 4,
		shortlisted: false,
		ingredients: JSON.stringify({
			"0": { units: "g", quantity: "600", name: "Baby potato" },
			"1": { units: "pc", quantity: "1 / 2", name: "Red Cabbage" },
			"2": { units: "g", quantity: "200", name: "Pomegranate seeds" },
			"3": { units: "tin", quantity: "1", name: "Butter Beans" },
			"4": { units: "g", quantity: "100", name: "Mayonnaise" },
			"5": { units: "g", quantity: "50", name: "Yoghurt" },
			"6": { units: "tbsp", quantity: "3", name: "Extra Virgin Olive Oil" },
			"7": { units: "pc", quantity: "1 / 2", name: "Lemon juice" },
			"8": { units: "g", quantity: "15", name: "Flat - leaf parsley" },
		}),
		method_steps: JSON.stringify({
			"0": {
				step_text:
					"Boil the potatoes in salted water for 10 minutes, until they are just cooked through, then drain and rinse under running cold water to cool.",
			},
			"1": {
				step_text:
					"While the potatoes are cooking, shred the cabbage, deseed the pomegranate (or open the packet), and drain and rinse the beans.",
			},
			"2": {
				step_text:
					"In a bowl, mix the mayonnaise, yoghurt, lemon juice, oil, a teaspoon of flaky sea salt and plenty of pepper, then taste and adjust the seasoning accordingly.",
			},
			"3": {
				step_text:
					"Put the cooled, drained potatoes, red cabbage, pomegranate, beans and the dressing in a large bowl, then taste and adjust the seasoning if necessary. Arrange on a large plate, scatter over the parsley and serve at room temperature.",
			},
		}),
		tags: JSON.stringify({
			"0": { name: "Cuisine", value: "Australian" },
			"1": {
				name: "Style",
				value: "Salad",
			},
			"2": { name: "Label", value: "Light" },
		}),
	},
];

const tags_to_insert = [
	{
		name: "Cuisine",
		options: JSON.stringify([
			"Mediterranean",
			"French",
			"Italian",
			"Chinese",
			"Thai",
			"Australian",
			"Japanese",
			"International",
		]),
	},
	{
		name: "Style",
		options: JSON.stringify([
			"Veggie",
			"Meat & Sides",
			"Soups / Noodles / Stir Fry",
			"Salad",
			"Slow Cooker",
			"Oven Bake",
			"BBQ",
			"Bakery",
		]),
	},
	{
		name: "Label",
		options: JSON.stringify([
			"Go-to",
			"Weeknight",
			"Fancy",
			"Light",
			"Substantial",
		]),
	},
];

for (const recipe of recipes_to_insert) {
	const res = await db.transact([db.tx.recipes[id()].update(recipe)]);
	console.log("Seeded recipe:", res["tx-id"]);
}

for (const tag of tags_to_insert) {
	const res = await db.transact([db.tx.tag_options[id()].update(tag)]);
	console.log("Seeded tag:", res["tx-id"]);
}

export type Recipe = {
	id?: string;
	title: string;
	slug: string;
	cook_time: number;
	prep_time: number;
	serves: number;
	ingredients?: Map<string,Ingredient>;
	method_steps?: Map<string,MethodStep>;
	tags?: Map<string,Tag>;
	shortlisted?: boolean;
};

export type RecipeSummary = Pick<Recipe, "id" | "title" | "slug" | "cook_time" | "prep_time" | "serves" | "tags" | "shortlisted">;

export type Tag = {
	name?: string;
	value?: string;
};

export type TagOption = {
	id?: string;
	name: string;
	options: string[];
};

export type Ingredient = {
	name?: string;
	isMain?: string;
	quantity?: string;
	units?: string;
};

export type MethodStep = {
	step_text?: string;
};

export type PlanDay = {
	date: string;
	planned_meals: {
		lunch: MealWithStatus;
		dinner: MealWithStatus;
	};
}

export type MealWithStatus = {
	title: string;
	complete?: string;
};
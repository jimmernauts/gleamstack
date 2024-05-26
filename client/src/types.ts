export type Recipe = {
	id?: number;
	title: string;
	slug: string;
	cook_time: number;
	prep_time: number;
	serves: number;
	ingredients?: Ingredient[];
	method_steps?: MethodStep[];
	tags?: Tag[];
	shortlisted?: boolean;
};

export type RecipeSummary = Pick<Recipe, "id" | "title" | "slug" | "cook_time" | "prep_time" | "serves" | "tags" | "shortlisted">;

export type Tag = {
	name?: string;
	value?: string;
};

export type TagOption = {
	id?: number;
	name: string;
	options: string[];
};

export type Ingredient = {
	name?: string;
	isMain?: boolean;
	quantity?: string;
	units?: string;
};

export type MethodStep = {
	stepText?: string;
};

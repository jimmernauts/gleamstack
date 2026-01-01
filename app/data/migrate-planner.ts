import { init, id } from "@instantdb/admin";
import schema from "../src/instant.schema.ts";

// ID for app   : mealstack
const APP_ID = "eeaf3b82-5b5d-40c4-a29a-b68988377c3c";
const db = init({
	appId: APP_ID,
	adminToken: process.env.INSTANT_ADMIN_TOKEN!,
	schema,
});

const DRY_RUN = !Bun.argv.includes("--commit");

async function migrate() {
    if (DRY_RUN) {
        console.log("--- DRY RUN MODE --- (Use --commit to apply changes)");
    }
    console.log("Fetching plan records...");
    const result = await db.query({ plan: {} });
    const plans = result.plan;

    console.log(`Found ${plans.length} plan records.`);

    let migrationCount = 0;

    for (const plan of plans) {
        if (!plan.planned_meals) {
            continue;
        }

        let oldMeals: any[];
        try {
            // It might be double-stringified or a parsed object depending on how InstantDB handled it
            oldMeals = typeof plan.planned_meals === 'string' ? JSON.parse(plan.planned_meals) : plan.planned_meals;
            // Sometimes it's stringified twice in the earlier versions
            if (typeof oldMeals === 'string') {
                oldMeals = JSON.parse(oldMeals);
            }
        } catch (e) {
            console.error(`Failed to parse planned_meals for date ${plan.date}:`, plan.planned_meals);
            continue;
        }

        if (!Array.isArray(oldMeals)) {
            continue;
        }

        let lunch: any = null;
        let dinner: any = null;

        for (const meal of oldMeals) {
            if (!meal) continue;

            const isComplete = meal.complete === "true" || meal.complete === true;
            
            // Map old recipe format to new PlannedRecipe format
            let recipe: any = null;
            if (meal.recipe_name || meal.title) {
                recipe = { recipe_name: meal.recipe_name || meal.title };
            } else if (meal.recipe_slug || meal.recipe_id) {
                recipe = { recipe_slug: meal.recipe_slug || meal.recipe_id };
            } else if (meal.recipe && typeof meal.recipe === 'object') {
                // If it's already in the new format but in the old list
                recipe = meal.recipe;
            }

            if (!recipe) continue;

            const newMeal = {
                recipe: recipe,
                complete: isComplete
            };

            if (meal.for === "lunch") {
                lunch = newMeal;
            } else if (meal.for === "dinner") {
                dinner = newMeal;
            }
        }

        const updates: any = {};
        if (lunch) updates.lunch = JSON.stringify(lunch);
        if (dinner) updates.dinner = JSON.stringify(dinner);
        
        if (Object.keys(updates).length > 0) {
            migrationCount++;
            if (DRY_RUN) {
                console.log(`[DRY RUN] Date ${plan.date} would update:`);
                if (lunch) console.log(`  Lunch: ${updates.lunch}`);
                if (dinner) console.log(`  Dinner: ${updates.dinner}`);
            } else {
                console.log(`Migrating date ${plan.date}: lunch=${!!lunch}, dinner=${!!dinner}`);
                await db.transact([
                    db.tx.plan[plan.id].update({
                        ...updates,
                    })
                ]);
            }
        }
    }

    console.log(`\nMigration ${DRY_RUN ? 'would affect' : 'affected'} ${migrationCount} records.`);
    console.log("Done!");
}

migrate().catch(console.error);

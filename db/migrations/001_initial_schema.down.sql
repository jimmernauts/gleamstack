-- Rollback for 001_initial_schema
DROP TABLE IF EXISTS schema_migrations;
DROP TABLE IF EXISTS shopping_lists;
DROP TABLE IF EXISTS plan_days;
DROP TABLE IF EXISTS tag_options;
DROP TABLE IF EXISTS recipes;

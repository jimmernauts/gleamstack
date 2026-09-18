-- Initial schema for Gleamstack (Turso/SQLite)
-- Application data groups: recipes, tag_options, plan, shopping_lists
-- No settings table — Gemini key lives as a Worker secret

CREATE TABLE IF NOT EXISTS recipes (
  id TEXT PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  cook_time INTEGER,
  prep_time INTEGER,
  serves INTEGER,
  author TEXT,
  source TEXT,
  ingredients TEXT,
  method_steps TEXT,
  tags TEXT,
  shortlisted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS tag_options (
  id TEXT PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  options TEXT
);

CREATE TABLE IF NOT EXISTS plan_days (
  id TEXT PRIMARY KEY,
  date INTEGER UNIQUE NOT NULL,
  lunch TEXT,
  dinner TEXT
);

CREATE TABLE IF NOT EXISTS shopping_lists (
  id TEXT PRIMARY KEY,
  date INTEGER UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'Active',
  items TEXT,
  linked_recipes TEXT,
  linked_plan_start INTEGER,
  linked_plan_end INTEGER
);

CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY
);

INSERT OR IGNORE INTO schema_migrations (version) VALUES ('001_initial_schema');

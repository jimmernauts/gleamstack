#!/bin/bash
# Apply migration SQL to a Turso Cloud database.
#
# Usage:
#   ./scripts/apply-migration-to-turso.sh <db-name> [migration-file]
#
# Examples:
#   ./scripts/apply-migration-to-turso.sh gleamstack-dev
#   ./scripts/apply-migration-to-turso.sh gleamstack-dev db/migrations/001_initial_schema.sql
#
# Requires: turso CLI authenticated (turso auth login)

set -euo pipefail

DB_NAME="${1:?Usage: $0 <db-name> [migration-file]}"
MIGRATION_FILE="${2:-db/migrations/001_initial_schema.sql}"

if [ ! -f "$MIGRATION_FILE" ]; then
  echo "Error: Migration file not found: $MIGRATION_FILE"
  exit 1
fi

echo "Applying $MIGRATION_FILE to Turso database: $DB_NAME"
echo "---"
cat "$MIGRATION_FILE"
echo ""
echo "---"
read -p "Continue? [y/N] " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Aborted."
  exit 0
fi

turso db shell "$DB_NAME" < "$MIGRATION_FILE"
echo "Done. Verifying schema_migrations..."
turso db shell "$DB_NAME" "SELECT * FROM schema_migrations;"

#!/usr/bin/env bash
# Adapted from https://github.com/graphile/starter/blob/main/%40app/db/scripts/dump-db.js
pg_dump --no-sync --schema-only --file=./schema.sql --exclude-schema=graphile_migrate ${GM_DBURL?"must be set"}
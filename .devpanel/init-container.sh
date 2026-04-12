#!/bin/bash
set -euo pipefail
# ---------------------------------------------------------------------
# Copyright (C) 2025 DevPanel
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation version 3 of the
# License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# For GNU Affero General Public License see <https://www.gnu.org/licenses/>.
# ----------------------------------------------------------------------

#== Import database

echo "=== DevPanel Runtime Init ==="

DUMP_DB="$APP_ROOT/.devpanel/dumps/db.sql.gz"
DUMP_FILES="$APP_ROOT/.devpanel/dumps/files.tgz"
FILES_DIR="$WEB_ROOT/sites/default/files"

# Wait for MySQL
echo "Waiting for MySQL..."
for i in $(seq 1 60); do
  mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" --silent && break
  sleep 2
done

# Check if DB has tables
TABLE_COUNT=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SHOW TABLES;" | wc -l)

if [ "$TABLE_COUNT" -le 1 ]; then
  echo "Database empty → importing dump"

  if [ -f "$DUMP_DB" ]; then
    gunzip -c "$DUMP_DB" | mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
  else
    echo "⚠️ No DB dump found, skipping"
  fi
else
  echo "Database already populated → skipping import"
fi

# Restore files
if [ ! -d "$FILES_DIR" ] || [ -z "$(ls -A "$FILES_DIR")" ]; then
  echo "Restoring public files..."

  mkdir -p "$FILES_DIR"

  if [ -f "$DUMP_FILES" ]; then
    tar xzf "$DUMP_FILES" -C "$FILES_DIR"
  else
    echo "⚠️ No files dump found, skipping"
  fi
else
  echo "Files already exist → skipping restore"
fi

# Fix permissions
chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$FILES_DIR"

echo "Runtime init complete"

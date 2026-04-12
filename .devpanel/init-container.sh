#!/bin/bash
set -euo pipefail--------------------------------------
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

# Runtime bootstrap for a prebuilt image. If the attached database volume is
# empty, restore the bundled quickstart dump and public files.---------------------------------------
#== Import database
echo "=== DevPanel runtime init ==="

DUMP_DB="$APP_ROOT/.devpanel/dumps/db.sql.gz"
DUMP_FILES="$APP_ROOT/.devpanel/dumps/files.tgz"
FILES_DIR="$WEB_ROOT/sites/default/files"
DRUSH="$APP_ROOT/vendor/bin/drush"

# Wait for MySQL before checking the target database.
echo "Waiting for MySQL..."
for i in $(seq 1 60); do
  mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" --silent && break
  sleep 2
done

# Restore only when the attached database is empty.
TABLE_COUNT=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SHOW TABLES;" | wc -l)

if [ "$TABLE_COUNT" -le 1 ]; then
  echo "Database empty -> restoring snapshot"

  # Import DB
  if [ -f "$DUMP_DB" ]; then
    echo "Importing DB..."
    gunzip -c "$DUMP_DB" | mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
  else
    echo "DB dump missing -> skipping"
  fi

  echo "Restoring files..."
  sudo rm -rf "$FILES_DIR" || true
  sudo mkdir -p "$FILES_DIR"

  if [ -f "$DUMP_FILES" ]; then
    sudo tar xzf "$DUMP_FILES" -C "$FILES_DIR"
  else
    echo "files.tgz missing -> skipping"
  fi
else
  echo "Database already populated -> skipping restore"
fi

# Fix permissions
sudo chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$FILES_DIR"

# Clear Drupal cache (safe)
echo "Rebuilding cache..."
"$DRUSH" cr || true

echo "Runtime init complete"

#!/bin/bash
set -euo pipefail
# ---------------------------------------------------------------------
# Copyright (C) 2021 DevPanel
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

echo -e "-------------------------------"
echo -e "| DevPanel Quickstart Creator |"
echo -e "-------------------------------\n"

DUMPS_DIR="/tmp/devpanel/quickstart/dumps"
STATIC_FILES_DIR="$WEB_ROOT/sites/default/files"
APP_DUMPS_DIR="$APP_ROOT/.devpanel/dumps"
DRUSH="$APP_ROOT/vendor/bin/drush"

mkdir -p "$DUMPS_DIR"
mkdir -p "$APP_DUMPS_DIR"

echo "Listing STATIC_FILES_DIR"
ls -la "$STATIC_FILES_DIR"

cd "$APP_ROOT"

echo "Drush status"
"$DRUSH" status

echo "Listing tables"
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "show tables;"

# Step 1 - Export Drupal database
echo "> Export database to $APP_DUMPS_DIR"
"$DRUSH" cr --quiet

# Use direct mariadb-dump for more reliable output in container/CI environments.
mariadb-dump --skip-ssl \
  -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  --no-tablespaces | gzip > "$APP_DUMPS_DIR/db.sql.gz"

test -s "$APP_DUMPS_DIR/db.sql.gz"

# Step 2 - Compress public files
echo "> Compress static files"
tar czf "$DUMPS_DIR/files.tgz" -C "$STATIC_FILES_DIR" .

echo "> Store files.tgz to $APP_DUMPS_DIR"
mv "$DUMPS_DIR/files.tgz" "$APP_DUMPS_DIR/files.tgz"

test -s "$APP_DUMPS_DIR/files.tgz"

echo "Listing \$APP_ROOT/.devpanel/dumps files"
ls -la "$APP_DUMPS_DIR"

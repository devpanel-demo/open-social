#!/bin/bash
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

# Preparing
DUMPS_DIR=/tmp/devpanel/quickstart/dumps
STATIC_FILES_DIR=$WEB_ROOT/sites/default/files

mkdir -p $DUMPS_DIR

echo "Db connect info"
echo "Host: $DB_HOST"
echo "Port: $DB_PORT"
echo "User: $DB_USER"
echo "DB: $DB_NAME"

echo "Drush status"
./vendor/bin/drush status

echo "Listing tables"
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD $DB_NAME -e "show tables;"

cd $APP_ROOT
# Step 1 - Compress drupal database
echo -e "> Export database to $APP_ROOT/.devpanel/dumps"
mkdir -p $APP_ROOT/.devpanel/dumps
drush cr --quiet
drush sql-dump --result-file=../.devpanel/dumps/db.sql --gzip --extra-dump=--no-tablespaces

# Step 2 - Compress static files
echo -e "> Compress static files"
tar czf $DUMPS_DIR/files.tgz -C $STATIC_FILES_DIR .

echo -e "> Store files.tgz to $APP_ROOT/.devpanel/dumps"
mv $DUMPS_DIR/files.tgz $APP_ROOT/.devpanel/dumps/files.tgz

echo 'Listing $APP_ROOT/.devpanel/dumps files'
ls -la $APP_ROOT/.devpanel/dumps

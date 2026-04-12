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

# Re-config is used when the container starts from a prepared quickstart image
# and needs to restore the bundled database/files into a fresh environment.
# ----------------------------------------------------------------------

STATIC_FILES_PATH="$WEB_ROOT/sites/default/files/"
SETTINGS_FILES_PATH="$WEB_ROOT/sites/default/settings.php"
OVERWRITE_SETTING="$APP_ROOT/.devpanel/.devpanel-drupal-overwrite-settings"

if [[ ! -n "$APACHE_RUN_USER" ]]; then
  export APACHE_RUN_USER=www-data
fi
if [[ ! -n "$APACHE_RUN_GROUP" ]]; then
  export APACHE_RUN_GROUP=www-data
fi

# Install PHP/Drupal dependencies if they are not already present.
if [[ -f "$APP_ROOT/composer.json" ]]; then
  cd "$APP_ROOT" && composer install
fi
if [[ -f "$WEB_ROOT/composer.json" ]]; then
  cd "$WEB_ROOT" && composer install
fi

# Update submodules only when repository metadata is available.
if [ -d "$APP_ROOT/.git" ]; then
  cd "$WEB_ROOT" && git submodule update --init --recursive
fi

# Create settings.php if it does not exist yet.
if [[ ! -f "$SETTINGS_FILES_PATH" ]]; then
  sudo cp "$APP_ROOT/.devpanel/drupal-settings.php" "$SETTINGS_FILES_PATH"
fi

echo 'Generate hash salt ...'
DRUPAL_HASH_SALT=$(openssl rand -hex 32)
sudo sed -i -e "s/^\$settings\['hash_salt'\].*/\$settings\['hash_salt'\] = '$DRUPAL_HASH_SALT';/g" "$SETTINGS_FILES_PATH"

# Ensure the public files directory exists before extracting a snapshot.
[[ ! -d "$STATIC_FILES_PATH" ]] && sudo mkdir --mode 775 "$STATIC_FILES_PATH" || sudo chmod 775 -R "$STATIC_FILES_PATH"

# Only restore the snapshot into an empty database.
if [[ $(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "show tables;" | wc -l) -le 1 ]]; then
  if [[ -f "$APP_ROOT/.devpanel/dumps/files.tgz" ]]; then
    echo 'Extract static files ...'
    sudo mkdir -p "$STATIC_FILES_PATH"
    sudo tar xzf "$APP_ROOT/.devpanel/dumps/files.tgz" -C "$STATIC_FILES_PATH"
  fi

  # Import the current quickstart dump format (db.sql.gz).
  if [[ -f "$APP_ROOT/.devpanel/dumps/db.sql.gz" ]]; then
    echo 'Import mysql files ...'
    gunzip -c "$APP_ROOT/.devpanel/dumps/db.sql.gz" | mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
  fi
fi

# Ensure private files directory exists for Open Social before runtime.
[[ ! -d "$APP_ROOT/private" ]] && sudo mkdir -p --mode 775 "$APP_ROOT/private" || sudo chmod 775 -R "$APP_ROOT/private"
sudo chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$APP_ROOT/private"

echo 'Update permission ....'
"$APP_ROOT/vendor/bin/drush" cr || true
sudo chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$STATIC_FILES_PATH"
sudo chown www:www "$SETTINGS_FILES_PATH"
sudo chmod 644 "$SETTINGS_FILES_PATH"

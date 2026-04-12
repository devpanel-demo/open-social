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

STATIC_FILES_PATH="$WEB_ROOT/sites/default/files"
SETTINGS_FILES_PATH="$WEB_ROOT/sites/default/settings.php"
DRUSH="$APP_ROOT/vendor/bin/drush"

if [[ ! -n "$APACHE_RUN_USER" ]]; then
  export APACHE_RUN_USER=www-data
fi
if [[ ! -n "$APACHE_RUN_GROUP" ]]; then
  export APACHE_RUN_GROUP=www-data
fi

#== Composer install.
if [[ -f "$APP_ROOT/composer.json" ]]; then
  cd "$APP_ROOT" && composer install
fi
if [[ -f "$WEB_ROOT/composer.json" ]]; then
  cd "$WEB_ROOT" && composer install
fi

if [ -d "$APP_ROOT/.git" ]; then
  cd "$WEB_ROOT" && git submodule update --init --recursive
fi

mkdir -p "$WEB_ROOT"
mkdir -p "$WEB_ROOT/sites/default/files" && chmod 775 "$WEB_ROOT/sites/default/files"
mkdir -p "$APP_ROOT/private" && chmod 775 "$APP_ROOT/private"

echo "Checking frontend libraries..."

# If Composer already installed libraries into web/libraries, keep them.
if [ -d "$WEB_ROOT/libraries/select2" ]; then
  echo "Libraries already installed in $WEB_ROOT/libraries."
# Otherwise, if vendor/npm-asset exists, create a symlink.
elif [ -d "$APP_ROOT/vendor/npm-asset" ]; then
  echo "Linking $APP_ROOT/vendor/npm-asset to $WEB_ROOT/libraries..."
  if [ -L "$WEB_ROOT/libraries" ]; then
    rm -f "$WEB_ROOT/libraries"
  elif [ -d "$WEB_ROOT/libraries" ]; then
    rm -rf "$WEB_ROOT/libraries"
  fi
  ln -s "$APP_ROOT/vendor/npm-asset" "$WEB_ROOT/libraries"
# Otherwise, show debug info but do not hard-fail immediately.
else
  echo "No libraries found in $WEB_ROOT/libraries and no $APP_ROOT/vendor/npm-asset directory found."
  echo "Debugging library locations..."
  find "$APP_ROOT" -maxdepth 5 -type d \( -name select2 -o -name autosize -o -name nouislider \) || true
fi

echo "Verifying frontend libraries..."
[ -d "$WEB_ROOT/libraries/select2" ] && echo "select2 library found." || echo "select2 library missing."
[ -d "$WEB_ROOT/libraries/autosize" ] && echo "autosize library found." || echo "autosize library missing."
[ -d "$WEB_ROOT/libraries/nouislider" ] && echo "nouislider library found." || echo "nouislider library missing."

sudo chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$APP_ROOT/private"
sudo chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$WEB_ROOT/sites/default/files"

#== Setup settings.php file
sudo cp "$APP_ROOT/.devpanel/drupal-settings.php" "$SETTINGS_FILES_PATH"

#== Generate hash salt
echo 'Generate hash salt ...'
DRUPAL_HASH_SALT=$(openssl rand -hex 32)
sudo sed -i -e "s/^\$settings\['hash_salt'\].*/\$settings\['hash_salt'\] = '$DRUPAL_HASH_SALT';/g" "$SETTINGS_FILES_PATH"

#== Update permission
echo 'Update permission ....'
sudo chown www:www "$SETTINGS_FILES_PATH"
sudo chmod 644 "$SETTINGS_FILES_PATH"

#== Reset DB (CRITICAL)
sleep 5
echo "Reset database..."
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" -e "DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME};"

echo "Site installing ..."
cd "$APP_ROOT"

"$DRUSH" -y site:install social \
  --account-name=devpanel \
  --account-pass=devpanel \
  --site-name="Open Social" \
  --no-interaction \
  --verbose

# Ensure login works
"$DRUSH" user:password devpanel devpanel || true
"$DRUSH" user:unblock devpanel || true

"$DRUSH" cr

echo "Overwrite settings from site-install"
sudo cp "$APP_ROOT/.devpanel/drupal-settings.local.php" "$WEB_ROOT/sites/default/settings.local.php"

SETTINGS_INCLUDE="include \$app_root . '/' . \$site_path . '/settings.local.php';"

if ! grep -qF "$SETTINGS_INCLUDE" "$WEB_ROOT/sites/default/settings.php"; then
  sudo tee -a "$WEB_ROOT/sites/default/settings.php" > /dev/null <<'PHP'

if (file_exists($app_root . '/' . $site_path . '/settings.local.php')) {
  include $app_root . '/' . $site_path . '/settings.local.php';
}
PHP
fi

sudo chown www:www "$WEB_ROOT/sites/default/settings.php" "$WEB_ROOT/sites/default/settings.local.php"
sudo chmod 644 "$WEB_ROOT/sites/default/settings.php" "$WEB_ROOT/sites/default/settings.local.php"

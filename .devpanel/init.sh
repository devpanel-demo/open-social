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

mkdir -p "$WEB_ROOT/sites/default/files" && chmod 775 "$WEB_ROOT/sites/default/files"
mkdir -p "$APP_ROOT/private" && chmod 775 "$APP_ROOT/private"

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

# Fix broken module only
"$DRUSH" pm:uninstall activity_send_email -y || true

# Ensure login works
"$DRUSH" user:password devpanel devpanel || true
"$DRUSH" user:unblock devpanel || true

"$DRUSH" cr

echo "Overwrite settings from site-install"
sudo cp "$APP_ROOT/.devpanel/drupal-settings.local.php" "$WEB_ROOT/sites/default/settings.local.php"

grep -qxF "include \$app_root . '/' . \$site_path . '/settings.local.php';" "$WEB_ROOT/sites/default/settings.php" || \
echo -e "\nif (file_exists(\$app_root . '/' . \$site_path . '/settings.local.php')) {\n  include \$app_root . '/' . \$site_path . '/settings.local.php';\n}" | sudo tee -a "$WEB_ROOT/sites/default/settings.php" > /dev/null

sudo chown www:www "$WEB_ROOT/sites/default/settings.php" "$WEB_ROOT/sites/default/settings.local.php"
sudo chmod 644 "$WEB_ROOT/sites/default/settings.php" "$WEB_ROOT/sites/default/settings.local.php"

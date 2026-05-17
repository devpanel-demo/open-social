#!/usr/bin/env bash
if [ -n "${DEBUG_SCRIPT:-}" ]; then
  set -x
fi
set -eu -o pipefail
cd $APP_ROOT

LOG_FILE="logs/init-$(date +%F-%T).log"
exec > >(tee $LOG_FILE) 2>&1

TIMEFORMAT=%lR
# For faster performance, don't audit dependencies automatically.
export COMPOSER_NO_AUDIT=1
# For faster performance, don't install dev dependencies.
export COMPOSER_NO_DEV=1

#== Remove root-owned files.
echo
echo Remove root-owned files.
time sudo rm -rf lost+found

#== Composer install.
echo
if [ -f composer.json ]; then
  if composer show --locked cweagans/composer-patches ^2 &> /dev/null; then
    echo 'Update patches.lock.json.'
    time composer prl
    echo
  fi
else
  echo 'Generate composer.json.'
  time source .devpanel/composer_setup.sh
  echo
fi
# Install from lock file when available.
if [ -f composer.lock ]; then
  echo 'Install Composer dependencies from lock file.'
  time composer -n install --no-dev --no-progress --prefer-dist --optimize-autoloader
else
  echo 'No composer.lock found. Updating Composer dependencies.'
  time composer -n update --no-dev --no-progress --prefer-dist --optimize-autoloader
fi

#== Create the private files directory.
if [ ! -d private ]; then
  echo
  echo 'Create the private files directory.'
  time mkdir private
fi

#== Create the config sync directory.
if [ ! -d config/sync ]; then
  echo
  echo 'Create the config sync directory.'
  time mkdir -p config/sync
fi

#== Install Drupal.
echo
if [ -z "$(drush status --field=db-status)" ]; then
  echo 'Install Drupal.'

  echo 'Verify Open Social profile.'
  if [ ! -d web/profiles/contrib/open_social ]; then
    echo 'ERROR: Open Social profile is missing at web/profiles/contrib/open_social'
    echo 'Composer packages installed:'
    composer show goalgorilla/open_social || true
    echo 'Profiles directory:'
    ls -al web/profiles || true
    ls -al web/profiles/contrib || true
    exit 1
  fi

  #== Configure settings and private files before install.
  mkdir -p "${APP_ROOT}/private"
  chmod 777 "${APP_ROOT}/private"

  cp "${APP_ROOT}/.devpanel/drupal-settings.php" "${WEB_ROOT}/sites/default/settings.php"
  chmod 644 "${WEB_ROOT}/sites/default/settings.php"

  time drush -n site:install social \
    --account-name=admin \
    --account-pass=admin \
    --site-name="Open Social" \
    --db-url="mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}" \
    --yes

  echo
  echo 'Restore env-based settings.php.'
  chmod u+w "${WEB_ROOT}/sites/default/settings.php" || true
  cp "${APP_ROOT}/.devpanel/drupal-settings.php" "${WEB_ROOT}/sites/default/settings.php"
  chmod 644 "${WEB_ROOT}/sites/default/settings.php"

  echo
  echo 'Tell Automatic Updates about patches.'
  drush -n cset --input-format=yaml package_manager.settings additional_trusted_composer_plugins '["cweagans/composer-patches"]'
  time drush ev '\Drupal::moduleHandler()->invoke("automatic_updates", "modules_installed", [[], FALSE])'
else
  echo 'Update database.'
  time drush -n updb
fi

#== Warm up caches.
echo
echo 'Run cron.'
time drush cron
echo
echo 'Populate caches.'
time drush cache:warm &> /dev/null || :
time .devpanel/warm

#== Finish measuring script time.
INIT_DURATION=$SECONDS
INIT_HOURS=$(($INIT_DURATION / 3600))
INIT_MINUTES=$(($INIT_DURATION % 3600 / 60))
INIT_SECONDS=$(($INIT_DURATION % 60))
printf "\nTotal elapsed time: %d:%02d:%02d\n" $INIT_HOURS $INIT_MINUTES $INIT_SECONDS

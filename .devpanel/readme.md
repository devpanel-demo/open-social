# DevPanel project scripts

The files in `.devpanel` define how this Open Social project is built, initialized, exported as a reusable image, and restored at runtime.

This repository is set up for two related use cases:

1. **Build a prepared Open Social image** during CI or template creation.
2. **Start containers from that image** and restore the bundled database/files only when the attached database volume is empty.

## Project flow

### 1. Build-time preparation

These scripts run while building the prepared image or template:

- [`custom_package_installer.sh`](custom_package_installer.sh) installs extra OS packages and optional code-server extensions.
- [`init.sh`](init.sh) installs Composer dependencies, checks frontend libraries, creates required directories, copies DevPanel Drupal settings, resets the database, and performs a fresh `drush site:install social`.
- [`profile-module-install-order.patch`](profile-module-install-order.patch) adjusts the Open Social profile install order so `social_follow_content` is installed before event-related modules.

The result of this stage is a working Open Social site inside the container, ready to be exported.

### 2. Quickstart export

- [`create_quickstart.sh`](create_quickstart.sh) exports:
  - `db.sql.gz` for the Drupal database
  - `files.tgz` for `web/sites/default/files`

These files are stored in `.devpanel/dumps` and are intended to be baked into the prepared image.

### 3. Runtime restore

When a container starts from the prepared image:

- [`init-container.sh`](init-container.sh) waits for MySQL.
- If the target database is empty, it restores `.devpanel/dumps/db.sql.gz` and `.devpanel/dumps/files.tgz`.
- If the target database already contains tables, it skips restore so existing environments are not overwritten.
- A cache rebuild runs at the end as a safe finalization step.

### 4. Reconfigure an existing environment

- [`re-config.sh`](re-config.sh) is used when an environment starts from a quickstart-capable template and needs to restore the packaged snapshot into a fresh database.
- It ensures settings exist, restores the database/files when the database is empty, and fixes permissions.

### 5. Deployment and Git hooks

- [`config.yml`](config.yml) defines branch-based Git hook commands for DevPanel.
- [`deployment.sh`](deployment.sh) is the lightweight per-container startup hook.

## File reference

### Core scripts

- [`custom_package_installer.sh`](custom_package_installer.sh)
  Installs extra packages needed by the container. In this project it currently installs `nano` and optional VS Code extensions.

- [`init.sh`](init.sh)
  Main build-time installer for a fresh Open Social environment.

- [`create_quickstart.sh`](create_quickstart.sh)
  Exports the database and public files into `.devpanel/dumps`.

- [`init-container.sh`](init-container.sh)
  Runtime restore script for containers started from the prepared image.

- [`re-config.sh`](re-config.sh)
  Restores the quickstart snapshot when the environment is reconfigured.

### Drupal settings

- [`drupal-settings.php`](drupal-settings.php)
  Project settings template used during build/install.

- [`drupal-settings.local.php`](drupal-settings.local.php)
  Local/runtime overrides loaded after installation. This file contains the environment-driven database settings and private files path.

### Deployment helpers

- [`config.yml`](config.yml)
  Branch-specific DevPanel Git hook actions.

- [`deployment.sh`](deployment.sh)
  Minimal startup hook executed by each deployment container.

### Patch

- [`profile-module-install-order.patch`](profile-module-install-order.patch)
  Keeps the Open Social profile install order aligned with the current working setup.

## Important implementation notes

- The build flow expects Open Social to be installed fresh during image creation.
- The runtime flow is intentionally **restore-on-empty-db only** so that existing deployments are not overwritten.
- Frontend libraries are expected under `web/libraries`. If Composer does not install them there directly, `init.sh` falls back to symlinking `vendor/npm-asset`.
- The private files path is configured as `dirname($app_root) . '/private'`, which is required for Open Social installation.

## Recommended maintenance approach

Keep changes in this directory small and explicit:

- prefer comments over logic changes
- keep dump format changes synchronized between export and restore scripts
- keep README and scripts aligned whenever the build/runtime flow changes

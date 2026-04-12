# Open Social

This repository provides a **pre-configured Open Social distribution** for Drupal, optimized for **DevPanel / Docker-based environments**.

It automates:
- Drupal + Open Social installation
- Required frontend libraries (npm assets)
- Database setup
- Quickstart snapshot (DB + files)
- Ready-to-use Docker image deployment

## 🚀 What is Open Social?

[Open Social](https://www.drupal.org/project/social) is a Drupal-based distribution used to build:
- Online communities
- Intranets
- Collaboration platforms

It comes with:
- User profiles & groups
- Activity streams
- Events & discussions
- Social interactions (likes, comments, mentions)

## 🧩 What this repository adds

This repo extends Open Social with:

- ⚙️ Automated installation (no manual setup)
- 🐳 Docker-ready environment
- 📦 Prebuilt image support (DevPanel / Docker Hub)
- 🗄️ Database + files snapshot (quickstart)
- 🔁 Re-configurable runtime setup

## 🏗️ Project Structure

```

.devpanel/
init.sh                     # Main install script
init-container.sh          # Container entrypoint
custom_package_installer.sh# Composer / package handling
create_quickstart.sh       # Creates DB + file snapshot
re-config.sh               # Runtime reconfiguration
drupal-settings.php        # Base Drupal settings
drupal-settings.local.php  # Local overrides

````

## ⚙️ How it works (Flow)

### 1. Build Phase (CI / Docker build)

Triggered via GitHub Actions or DevPanel:

1. Code is copied into container
2. `custom_package_installer.sh` runs:
   - Installs Composer dependencies
   - Applies patches (Open Social fixes)
3. `init.sh` runs:
   - Installs Drupal using Open Social profile
   - Sets up DB
   - Configures settings.php
   - Installs all modules
4. `create_quickstart.sh` runs:
   - Dumps database
   - Archives `sites/default/files`

👉 Result: a **fully installed Open Social instance baked into the image**

### 2. Runtime Phase (Container start)

When container starts:

1. `init-container.sh` runs
2. If quickstart exists:
   - DB is imported
   - Files are restored
3. `re-config.sh` adjusts:
   - DB credentials
   - environment-specific settings

👉 Result: **site is ready instantly (no installer UI)**

## 🧪 Local Development

### Using Docker Compose

```bash
docker compose up
```

Access:

* Site: [http://localhost](http://localhost)
* Code server (if enabled): [http://localhost:8080](http://localhost:8080)

## 🔑 Default Credentials

```
Username: devpanel
Password: devpanel
```

## 📦 Frontend Libraries

Open Social requires external JS libraries like:

* select2
* autosize
* nouislider

These are installed via Composer (`npm-asset/*`) and made available in:

```
web/libraries/
```

If missing, they are automatically resolved during build.

## 🔍 Solr (Optional)

Open Social supports Solr for search.

If enabled:

* Default core: `drupal`
* Endpoint: `http://solr:8983`

Make sure your Solr container matches this configuration.

## 🛠️ CI/CD (Docker Build)

The repository includes a workflow that:

1. Builds Open Social inside container
2. Runs full install
3. Creates quickstart snapshot
4. Commits container state
5. Pushes image to Docker Hub

## 🧯 Troubleshooting

### White screen / install errors

* Usually caused by incomplete install
* Ensure `init.sh` completed successfully

### Missing libraries (select2, etc.)

* Check:

  ```
  web/libraries/
  ```
* Re-run:

  ```
  composer install
  ```

### Solr not reachable

* Verify container is running
* Check core name matches (`drupal`)

## 🤝 Contributing

* Keep changes minimal and compatible with Open Social
* Avoid modifying core or contrib unless patched
* Use `.devpanel` scripts for automation logic

## 📄 License

This project is licensed under the:

[GNU General Public License v2.0](LICENSE.txt)

## 🙌 Credits

- [Drupal community](https://www.drupal.org/community)
- [Open Social (GoalGorilla)](https://www.drupal.org/project/social)  
- [Drupal Forge](https://www.drupalforge.org) + [DevPanel](https://devpanel.com)  


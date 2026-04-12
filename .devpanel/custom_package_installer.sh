#!/bin/bash
# ---------------------------------------------------------------------
# Copyright (C) 2023 DevPanel
# You can install any service here to support your project
# Please make sure you run apt update before install any packages
# Example:
# - sudo apt-get update
# - sudo apt-get install nano
#
# You can install any service here to support your project.
# Run apt update before installing additional packages.
# ----------------------------------------------------------------------

# Minimal helper packages used during CI/container troubleshooting.
sudo apt-get update
sudo apt-get install -y nano

# Install optional VS Code extensions when the platform provides them through
# DP_VSCODE_EXTENSIONS as a comma-separated list.
if [[ -n "$DP_VSCODE_EXTENSIONS" ]]; then
    sudo chown -R www:www "$APP_ROOT/.vscode/extensions/"
    IFS=','
    for value in $DP_VSCODE_EXTENSIONS; do
        code-server --install-extension "$value" --user-data-dir="$APP_ROOT/.vscode"
    done
fi

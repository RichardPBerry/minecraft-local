#!/bin/bash
set -euo pipefail

# Lightweight update script for minecraft-local
# - Fast-forwards the git repo (safe)
# - Updates Python packages in the virtualenv
# - Pulls Docker images and restarts compose services (if present)
# - Restarts the systemd service (if present)
# - Logs to /var/log/minecraft-local/update.log

APP_DIR="/var/www/minecraft-local"
VENV="$APP_DIR/.venv"
SVC="minecraft-local.service"
LOG="/var/log/minecraft-local/update.log"
BRANCH="main"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG")"

echo "=== $(date -u +'%Y-%m-%d %H:%M:%SZ') START UPDATE ===" | tee -a "$LOG"
cd "$APP_DIR"

# Ensure repository exists
if [ ! -d ".git" ]; then
  echo "No git repository in $APP_DIR; aborting." | tee -a "$LOG"
  exit 1
fi

# Fetch and fast-forward only
sudo -u mcservice git fetch origin --prune | tee -a "$LOG"
sudo -u mcservice git checkout "$BRANCH" | tee -a "$LOG"
if sudo -u mcservice git pull --ff-only origin "$BRANCH" | tee -a "$LOG"; then
  echo "Pulled latest $BRANCH" | tee -a "$LOG"
else
  echo "No fast-forward possible; skipping automatic merge. Please update manually." | tee -a "$LOG"
  echo "=== END (no ff) ===" | tee -a "$LOG"
  exit 0
fi

# Show the commits that were just applied
echo "Recent commits:" | tee -a "$LOG"
sudo -u mcservice git --no-pager log --pretty=format:'%h %s (%an)' -n 10 | tee -a "$LOG"

# Python deps
if [ -f "$APP_DIR/requirements.txt" ] && [ -d "$VENV" ]; then
  echo "Updating Python packages..." | tee -a "$LOG"
  sudo -u mcservice "$VENV/bin/python" -m pip install --upgrade pip setuptools wheel >>"$LOG" 2>&1 || true
  sudo -u mcservice "$VENV/bin/python" -m pip install -r "$APP_DIR/requirements.txt" >>"$LOG" 2>&1 || { echo "pip install failed" | tee -a "$LOG"; exit 1; }
fi

# Docker compose
if [ -f "$APP_DIR/docker-compose.yml" ] || [ -f "$APP_DIR/docker-compose.yaml" ]; then
  echo "Updating docker images and restarting compose services..." | tee -a "$LOG"
  (cd "$APP_DIR" && docker compose pull >>"$LOG" 2>&1 && docker compose up -d >>"$LOG" 2>&1) || { echo "docker-compose step failed" | tee -a "$LOG"; exit 1; }
fi

# Restart systemd service if present
if systemctl list-units --full -all | grep -q "^$SVC"; then
  echo "Restarting $SVC..." | tee -a "$LOG"
  systemctl restart "$SVC" >>"$LOG" 2>&1 || { echo "Failed to restart $SVC" | tee -a "$LOG"; exit 1; }
fi

echo "=== $(date -u +'%Y-%m-%d %H:%M:%SZ') UPDATE COMPLETE ===" | tee -a "$LOG"

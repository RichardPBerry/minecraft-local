#!/bin/bash
set -euo pipefail

# Uninstall script for minecraft-local
# - Stops, disables and removes the systemd service unit
# - Removes application files from /var/www/minecraft-local
# - Optionally removes the 'mcservice' system user
#
# Usage (run as root):
#   sudo ./scripts/uninstall.sh [--yes] [--remove-user]
#
# Options:
#   --yes         Skip interactive confirmation and proceed
#   --remove-user Also attempt to remove the 'mcservice' system user (if exists)

APP_DIR="/var/www/minecraft-local"
SERVICE_UNIT="/etc/systemd/system/minecraft-local.service"
SERVICE_NAME="minecraft-local.service"
REMOVE_USER=false
ASSUME_YES=false

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --remove-user) REMOVE_USER=true ;;
    --yes) ASSUME_YES=true ;;
    -h|--help)
      sed -n '1,120p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $arg"; echo "Use --help for usage."; exit 2 ;;
  esac
done

confirm() {
  local msg="$1"
  if [ "$ASSUME_YES" = true ]; then
    return 0
  fi
  read -r -p "$msg [y/N]: " reply
  case "$reply" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

stop_and_remove_unit() {
  local unit_path="$1"
  local unit_name="$2"

  if systemctl list-unit-files --type=service --no-legend | awk '{print $1}' | grep -qx "$unit_name" || [ -f "$unit_path" ]; then
    echo "Stopping and disabling $unit_name if active..."
    # Stop the unit (ignore errors)
    systemctl stop "$unit_name" 2>/dev/null || true
    systemctl disable --now "$unit_name" 2>/dev/null || true

    if [ -f "$unit_path" ]; then
      echo "Removing unit file: $unit_path"
      rm -f "$unit_path"
    fi

    # Also try to remove any unit file under /lib/systemd/system if present
    if [ -f "/lib/systemd/system/$unit_name" ]; then
      rm -f "/lib/systemd/system/$unit_name"
    fi

    # Reload systemd configuration
    systemctl daemon-reload
    systemctl reset-failed
    echo "$unit_name removed (if it existed)."
  else
    echo "Unit $unit_name does not appear to be installed; skipping."
  fi
}


# Stop and remove service
if [ -f "$SERVICE_UNIT" ] || systemctl list-unit-files | awk '{print $1}' | grep -qx "$SERVICE_NAME"; then
  if confirm "Remove systemd service $SERVICE_NAME?"; then
    stop_and_remove_unit "$SERVICE_UNIT" "$SERVICE_NAME"
  else
    echo "Skipping removal of $SERVICE_NAME"
  fi
else
  echo "No systemd service $SERVICE_NAME found."
fi

# Remove application directory
if [ -d "$APP_DIR" ]; then
  echo "Application directory found at $APP_DIR"
  if [ "$ASSUME_YES" = true ]; then
    echo "Removing $APP_DIR"
    rm -rf "$APP_DIR"
  else
    du -sh "$APP_DIR" 2>/dev/null || true
    if confirm "Permanently delete $APP_DIR and all its contents?"; then
      rm -rf "$APP_DIR"
      echo "$APP_DIR removed."
    else
      echo "Skipping removal of application directory."
    fi
  fi
else
  echo "Application directory $APP_DIR does not exist; nothing to remove."
fi

# Optionally remove the mcservice user
if [ "$REMOVE_USER" = true ]; then
  if id -u mcservice >/dev/null 2>&1; then
    echo "User 'mcservice' exists."
    if confirm "Remove system user 'mcservice' and its home (if any)?"; then
      # Attempt to stop any processes owned by mcservice
      if pgrep -u mcservice >/dev/null 2>&1; then
        echo "Stopping processes owned by mcservice..."
        # Try to gracefully stop processes, then kill
        pkill -u mcservice || true
        sleep 1
        pkill -9 -u mcservice || true
      fi

      userdel -r mcservice 2>/dev/null || userdel mcservice 2>/dev/null || echo "Failed to remove user 'mcservice' or user has no removable home; continue."
      echo "User 'mcservice' removal attempted."
    else
      echo "Skipping removal of user 'mcservice'."
    fi
  else
    echo "User 'mcservice' does not exist; nothing to remove."
  fi
fi

echo "Uninstall steps complete. If any units remain listed by systemd, run 'systemctl daemon-reload' and inspect /etc/systemd/system and /lib/systemd/system for stray unit files."
exit 0

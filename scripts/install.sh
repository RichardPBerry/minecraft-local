#!/bin/bash
# Install script for the Minecraft local control panel and server environment.
# - Creates a system user, clones the repository, and prepares the app directory.
# - Optional: installs a systemd service to run the Flask control panel.
#
# Usage (run as root):
#   sudo ./scripts/install.sh [--install-service]
#
# Flags:
#   --install-service    Create, enable and start a systemd service at
#                        /etc/systemd/system/minecraft-local.service that runs
#                        the Flask app as the 'mcservice' user (starts on reboot).
#   -h, --help           Show this help message.
#
# Basic service commands (after installing service):
#   systemctl status minecraft-local.service
#   systemctl start|stop|restart minecraft-local.service
#   journalctl -u minecraft-local.service -f


# Configuration
APP_DIR="/var/www/minecraft-local"

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi 

# Create the service account if does not exist
if ! id "mcservice" &>/dev/null; then
    echo "Creating service account 'mcservice'..."
    sudo useradd --system --shell /usr/sbin/nologin mcservice
    sudo usermod -aG docker mcservice
fi

# Create the application directory if it does not exist
if [ ! -d "$APP_DIR" ]; then
    echo "Creating application directory at $APP_DIR..."
    sudo mkdir -p "$APP_DIR"
    sudo chown mcservice:mcservice "$APP_DIR"
fi

# Clone the repository into APP_DIR if not already present
REPO_URL="https://github.com/RichardPBerry/minecraft-local.git"
if [ -d "$APP_DIR/.git" ]; then
    echo "Repository already present in $APP_DIR"
else
    # If directory is not empty, avoid overwriting existing files
    if [ "$(ls -A "$APP_DIR")" ]; then
        echo "Directory $APP_DIR is not empty and does not contain a git repository. Skipping clone." >&2
    else
        echo "Cloning $REPO_URL into $APP_DIR..."
        # Clone as the service user
        sudo -u mcservice git clone "$REPO_URL" "$APP_DIR" || { echo "git clone failed" >&2; exit 1; }
        # Ensure correct ownership
        sudo chown -R mcservice:mcservice "$APP_DIR"
    fi
fi

# Parse flags
INSTALL_SERVICE=false
for arg in "$@"; do
    case "$arg" in
        --install-service) INSTALL_SERVICE=true ;;
        -h|--help)
            echo "Usage: $0 [--install-service]"
            echo "  --install-service    Create, enable and start a systemd service that runs the Flask app as 'mcservice'."
            exit 0
            ;;
        *) ;;
    esac
done

if [ "$INSTALL_SERVICE" = true ]; then
    echo "Installing systemd service for the Flask app..."

    UNIT_PATH="/etc/systemd/system/minecraft-local.service"

    cat > "$UNIT_PATH" <<'UNIT_EOF'
[Unit]
Description=Minecraft Local Control Panel (Flask)
After=network.target

[Service]
Type=simple
User=mcservice
Group=mcservice
WorkingDirectory=/var/www/minecraft-local
# Override FLASK_HOST/FLASK_PORT via environment if desired
Environment=FLASK_HOST=0.0.0.0
Environment=FLASK_PORT=5000
ExecStart=/usr/bin/env python3 /var/www/minecraft-local/app/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT_EOF

    # Ensure permissions
    chmod 644 "$UNIT_PATH"

    # Reload systemd, enable and start service
    systemctl daemon-reload
    systemctl enable --now minecraft-local.service

    echo "Service installed and started. Use 'systemctl status minecraft-local.service' to check status."
fi



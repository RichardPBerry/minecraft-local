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

# Ensure required commands are available
for cmd in git python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required command '$cmd' is not installed or not in PATH." >&2
        exit 1
    fi
done

docker_available=false
if command -v docker >/dev/null 2>&1; then
    docker_available=true
fi

if [ "$docker_available" = false ]; then
    echo "Warning: Docker is not installed or not in PATH. This app relies on Docker Compose to manage Minecraft servers." >&2
fi

# Create the service account if it does not exist
if ! id "mcservice" &>/dev/null; then
    echo "Creating service account 'mcservice'..."
    useradd --system --shell /usr/sbin/nologin mcservice
    usermod -aG docker mcservice
fi

# Ensure mcservice is a member of the docker group when the group exists.
# This is idempotent and handles the case where Docker (and its group) is
# installed after this script was first run.
if getent group docker >/dev/null 2>&1; then
    if id -nG mcservice 2>/dev/null | grep -qw docker; then
        echo "User 'mcservice' is already a member of the 'docker' group"
    else
        echo "Adding 'mcservice' to 'docker' group..."
        if usermod -aG docker mcservice; then
            echo "Added 'mcservice' to 'docker' group"
        else
            echo "Warning: failed to add 'mcservice' to 'docker' group" >&2
        fi
    fi
else
    echo "Note: 'docker' group not present; skipping adding 'mcservice' to docker group"
fi


# Create the application directory if it does not exist
if [ ! -d "$APP_DIR" ]; then
    echo "Creating application directory at $APP_DIR..."
    mkdir -p "$APP_DIR"
    chown mcservice:mcservice "$APP_DIR"
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

VENV_PATH="$APP_DIR/.venv"
REQUIREMENTS_PATH="$APP_DIR/requirements.txt"

if [ ! -d "$VENV_PATH" ]; then
    echo "Creating Python virtual environment at $VENV_PATH..."
    sudo -u mcservice python3 -m venv "$VENV_PATH" || { echo "Failed to create virtual environment" >&2; exit 1; }
    sudo chown -R mcservice:mcservice "$VENV_PATH"
fi

if [ -f "$REQUIREMENTS_PATH" ]; then
    echo "Installing Python dependencies from $REQUIREMENTS_PATH..."
    sudo -u mcservice "$VENV_PATH/bin/python" -m pip install --upgrade pip
    sudo -u mcservice "$VENV_PATH/bin/python" -m pip install -r "$REQUIREMENTS_PATH" || { echo "pip install failed" >&2; exit 1; }
fi

copy_example_if_missing() {
    local src="$1"
    local dst="$2"

    if [ ! -f "$src" ]; then
        echo "Example file not found: $src" >&2
        return 0
    fi

    if [ -e "$dst" ]; then
        echo "Keeping existing configuration at $dst"
        return 0
    fi

    echo "Creating $dst from $(basename "$src")..."
    install -o mcservice -g mcservice -m 0600 "$src" "$dst"
}

mkdir -p "$APP_DIR/servers/configuration-shared"
chown -R mcservice:mcservice "$APP_DIR"

copy_example_if_missing "$APP_DIR/app/.env.example" "$APP_DIR/app/.env"
copy_example_if_missing "$APP_DIR/servers/configuration-shared/ops-list.json.example" "$APP_DIR/servers/configuration-shared/ops-list.json"
copy_example_if_missing "$APP_DIR/servers/configuration-shared/rcon-password.txt.example" "$APP_DIR/servers/configuration-shared/rcon-password.txt"

chown -R mcservice:mcservice "$APP_DIR"
echo "Configuration files were created from examples. Update the values in app/.env, servers/configuration-shared/ops-list.json, and servers/configuration-shared/rcon-password.txt before running the app."

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
WorkingDirectory=/var/www/minecraft-local/app
# Override FLASK_HOST/FLASK_PORT via environment if desired
Environment=FLASK_HOST=0.0.0.0
Environment=FLASK_PORT=5000
ExecStart=/var/www/minecraft-local/.venv/bin/python /var/www/minecraft-local/app/app.py
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



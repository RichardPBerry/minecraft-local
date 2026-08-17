# Overview
This repository provides a lightweight Flask-based control panel and  docker environment for running multiple minecraft servers. The web app provides a simply control panel for starting & stopping docker servers.

Docker servers are based on [docker-minecraft-server](https://github.com/itzg/docker-minecraft-server/tree/master).

# Pre-requisities
1. Docker installed. These instructions are for an Ubuntu host
   - Add the official [docker apt repository](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)
   - Install the required packages: `sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
   - Confirm docker is running `sudo systemctl status docker`
   - (Optional). Configure docker to run in [rootless mode](https://docs.docker.com/engine/security/rootless/)
2. Python 3.10+ installed.
3. `pip` installed.
4. The app is intended for local use and should not be exposed publicly without additional security controls.


# Installing

1. Fork the repo
2. Clone your forked repo somewhere locally that you can work on
3. Update the minecraft servers under the `servers/` directory. The repo comes with some example servers, but you can add/remove or modify the folders and `compose.yaml` files to create your own.
4. Commit your changes to your forked repo.
4. Run the install script under `scripts/install.sh`. This script creates a system user (mcservice), clones the repository, and prepares the app directory. By default, the app and server are installed under `/var/www/minecraft-local` (this can be changed in the APP_DIR variable in the install script).
   - `sudo ./scripts/install.sh --install-service` - Creates the directory structure, clones the repository and configures the web application to run as a systemd service that restarts on system boot (RECOMMENDED)
   - `sudo ./scripts/install.sh` - Creates the application directory structure and clones the reposotiry. Web app needs to be manually started (no service).
5. (OPTIONAL) Update environment settings. The install script creates example configuration files if they are missing, but they should be reviewed and updated before first use. In particular, set the runtime values in `app/.env`, update the OP list in `servers/configuration-shared/ops-list.json`, and set the RCON password in `servers/configuration-shared/rcon-password.txt`.


# Firewall
The app is intended to run on a trusted network environment only. You may need to create firewall rules to allow incoming traffic from your local network.

## Linux using ufw
Allowing via `ufw` This can be done by creating two profiles under path: `/etc/ufw/applications.d/`.

```bash
cat /etc/ufw/applications.d/minecraft_servers
[Minecraft Servers]
title=Minecraft Servers
description=Minecraft Game Server and RCON
ports=25565:25570/tcp|25565:25570/udp|25575/tcp
```

```bash
cat /etc/ufw/applications.d/minecraft_cp
[Minecraft Control Panel]
title=Minecraft Server
description=Minecraft container control panel
ports=5000/tcp
```

Them add these profiles as firewall rules:
```bash
sudo ufw allow from 192.168.0.0/16 to any app "Minecraft Servers"
sudo ufw allow from 192.168.0.0/16 to any app "Minecraft Control Panel"
```


# Running the web app
The app honors `FLASK_HOST`, `FLASK_PORT`, and `FLASK_DEBUG` environment variables. By default the app will be listining on all network interfaces on port 5000.

## Run the web app as a Systemd service
If you installed with the `--install-service` option the web app should already be running. Open a browser and point to the ip of your server on port 5000, e.g. `http://127.0.0.0:5000` from the server itself.
Check the status of the service with `sudo systemctl status minecraft-local.service`.
Check the logs with `sudo journalctl -u minecraft-local.service`. 

## Manually run the web app as a standar user account
Run the app as the current account from project root.
```

usermod -aG docker [username]                # Allow [username] to run docker contains. Required first time only.
python -m venv .venv                         # Required first time only
source .venv/bin/activate                    # Activate python virtual environment
pip install -r requirements.txt              # Install required python libraries. Required first time only.
python app/app.py                            # Start the flask app.
```

## Manually run the web app as service account
Run the app as the service account. Update directory paths if these were changed.
```bash
sudo -u mcservice sh -c 'cd /var/www/minecraft-local && /var/www/minecraft-local/.venv/bin/python app/app.py'
```

## Manually starting a single minecraft server
```
git clone https://github.com/RichardPBerry/minecraft-local
cd servers/001-survival-vanilla && sudo docker compose up -d
```


# References:
- [Docker Installing docker](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)
- [Read the docs: Docker minecraft server](https://docker-minecraft-server.readthedocs.io/en/latest/)
- [GitHub: docker-minecraft-server](https://github.com/itzg/docker-minecraft-server/tree/master)

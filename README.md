# Overview
This repository provides a docker environment for running a minecraft server. It is built from [GitHub: docker-minecraft-server](https://github.com/itzg/docker-minecraft-server/tree/master)

# Pre-requisities
Docker must be installed. These instructions are for an Ubuntu host
1. Add the official [docker apt repository](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)
2. Install the required packages: `sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
3. Confirm docker is running `sudo systemctl status docker`
4. (Optional). Configure docker to run in [rootless mode](https://docs.docker.com/engine/security/rootless/)


# Configuration
See [supmc.com](https://setupmc.com/java-server/) for a super handy guide in setting up the compose file!

# Firewall
On linux servers you will also need to allow the application via `ufw`. This can be done by creating a profile under the following path: `/etc/ufw/applications.d/`. For example:

```
cat /etc/ufw/applications.d/minecraft 
[Minecraft Servers]
title=Minecraft Servers
description=Minecraft Game Server and RCON
ports=25565:25570/tcp|25565:25570/udp|25575/tcp
```
The add this as a firewall rule:
```
sudo ufw allow from 192.168.0.0/16 to any app "Minecraft Servers"
```

Your will need to do the same for the Minecraft Control Panel

# Running
1. Start the Minecraft container from the server directory:
   `cd servers/001-survival-vanilla && sudo docker compose up -d`
2. 

# Running the web app
The repository also includes a lightweight Flask-based control panel for the local server.

## Prerequisites
- Python 3.10+
- `pip` installed

## Quick start
```bash
cd app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp ./app/.env.example ./app/.env
python app/app.py --debug           # NOTE: Do not use debug when running for realsie!
```

To stop a running app: `pkill -f 'python app/app.py'`

By default the app will start on `http://127.0.0.1:5000/`.

## Notes
- Update the values in `.env` before using the app in a shared or LAN environment.
- The app is intended for local use and should not be exposed publicly without additional security controls.

# Seed values
#SEED: -7775094310068025774    # Grand canyon
SEED: -281032838528851848      # The forever world

# References:
- [Docker Installing docker](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)
- [Read the docs: Docker minecraft server](https://docker-minecraft-server.readthedocs.io/en/latest/)
- [GitHub: docker-minecraft-server](https://github.com/itzg/docker-minecraft-server/tree/master)

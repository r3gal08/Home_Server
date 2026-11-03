#!/bin/bash
set -euo pipefail

# Deploy files to the Minecraft server directory

# TODO: Deploy whitelist.json files
# Deploy and permission properties files
mkdir -p /etc/containers/systemd/users/mc-configs
cp conf/server.properties /etc/containers/systemd/users/mc-configs/server.properties
chown -R admin:admin /etc/containers/systemd/users/mc-configs/
chmod 770 /etc/containers/systemd/users/mc-configs
chmod 660 /etc/containers/systemd/users/mc-configs/server.properties

# Start service
systemctl --user daemon-reload
systemctl --user enable mc.service
systemctl --user start mc.service
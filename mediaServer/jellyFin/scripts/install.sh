#!/bin/bash
set -euo pipefail

#
# Install script for Jellyfin Media Server Quadlet
# Deploys quadlet and volume files to the system-wide rootless Quadlet directory:
# /etc/containers/systemd/users/
#
# Must be run as root / sudo.
#
# Sometime in the near future, this will be packaged into a nice Ansible role...
#

TARGET_USER="${1:-admin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JELLYFIN_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
QUADLET_DIR="/etc/containers/systemd/users"

if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root or with sudo:"
  echo "  sudo $0 [target_user]"
  exit 1
fi

echo "==> Installing Jellyfin Quadlet to /etc/ for user: ${TARGET_USER}"
echo "    Source:      ${JELLYFIN_DIR}"
echo "    Destination: ${QUADLET_DIR}"

# 3. Configure firewalld ports (if firewalld is active)
if systemctl is-active --quiet firewalld; then
  echo "==> Configuring firewalld ports for Jellyfin..."
  # 8096/tcp: Web UI and streaming
  # 1900/udp: DLNA/SSDP local auto-discovery
  # 7359/udp: Jellyfin native client discovery
  firewall-cmd --add-port=8096/tcp --permanent
  firewall-cmd --add-port=1900/udp --permanent
  firewall-cmd --add-port=7359/udp --permanent
  firewall-cmd --reload
  echo "    Firewall ports (8096/tcp, 1900/udp, 7359/udp) opened successfully."
else
  echo "==> Notice: firewalld is not active. Skipping firewall configuration."
fi

cp -v "${JELLYFIN_DIR}/jellyfin.container"     "${QUADLET_DIR}/"
cp -v "${JELLYFIN_DIR}/jellyfin-config.volume" "${QUADLET_DIR}/"
cp -v "${JELLYFIN_DIR}/jellyfin-cache.volume"  "${QUADLET_DIR}/"

# 6. Set ownership and secure permissions
# Owned by root:TARGET_USER with 644 permissions
chown "root:${TARGET_USER}" \
  "${QUADLET_DIR}/jellyfin.container" \
  "${QUADLET_DIR}/jellyfin-config.volume" \
  "${QUADLET_DIR}/jellyfin-cache.volume"

chmod 640 \
  "${QUADLET_DIR}/jellyfin.container" \
  "${QUADLET_DIR}/jellyfin-config.volume" \
  "${QUADLET_DIR}/jellyfin-cache.volume"

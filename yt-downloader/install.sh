#!/bin/bash
set -euo pipefail

#
# Install script for YouTube Downloader (ytd) Quadlet
# Builds the local ytj container image and deploys ytd.container to:
# /etc/containers/systemd/users/
# Must be run as root / sudo.
#

TARGET_USER="${1:-admin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUADLET_DIR="/etc/containers/systemd/users"

if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root or with sudo:"
  echo "  sudo $0 [target_user]"
  exit 1
fi

echo "==> Building ytj container image for user ${TARGET_USER}..."
# Build the image inside TARGET_USER's rootless Podman storage
sudo -u "${TARGET_USER}" podman build -t ytj:latest "${SCRIPT_DIR}"

echo "==> Deploying ytd.container to ${QUADLET_DIR}..."
cp -v "${SCRIPT_DIR}/ytd.container" "${QUADLET_DIR}/ytd.container"
chown "root:${TARGET_USER}" "${QUADLET_DIR}/ytd.container"
chmod 640 "${QUADLET_DIR}/ytd.container"

# Configure firewalld port if active (9998/udp for on-demand trigger)
if systemctl is-active --quiet firewalld; then
  echo "==> Configuring firewalld for port 9998/udp..."
  firewall-cmd --add-port=9998/udp --permanent
  firewall-cmd --reload
  echo "    Firewall port (9998/udp) opened successfully."
else
  echo "==> Notice: firewalld is not active. Skipping firewall configuration."
fi

echo ""
echo "==> Installation complete!"
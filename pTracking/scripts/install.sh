#!/bin/bash
set -euo pipefail

#
# Install script for Donetick (pTracking) Quadlet stack
# Deploys dt.container, dt-data.volume, and dt-config.volume
# to /etc/containers/systemd/users/ with generated DT_JWT_SECRET
#
# Must be run as root / sudo.
#

TARGET_USER="${1:-admin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
QUADLET_DIR="/etc/containers/systemd/users"
PORT="2021"

# 1. Require root execution
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root or with sudo:"
  echo "  sudo $0 [target_user]"
  exit 1
fi

echo "==> Installing Donetick Quadlet stack for user: ${TARGET_USER}"
echo "    Source:      ${SOURCE_DIR}"
echo "    Destination: ${QUADLET_DIR}"

# 3. Configure firewalld (if active)
if systemctl is-active --quiet firewalld; then
  echo "==> Configuring firewalld port ${PORT}/tcp..."
  firewall-cmd --add-port="${PORT}/tcp" --permanent
  firewall-cmd --reload
  echo "    Firewall port ${PORT}/tcp opened successfully."
else
  echo "==> Notice: firewalld is not active. Skipping firewall configuration."
fi

# 4. Ensure destination directory exists
mkdir -p "${QUADLET_DIR}"

# 5. Handle DT_JWT_SECRET generation
DEST_CONTAINER="${QUADLET_DIR}/dt.container"
JWT_SECRET=""

if [ -f "${DEST_CONTAINER}" ]; then
  # Check if existing installed container already has a secret
  EXISTING_SECRET=$(grep -E '^Environment=DT_JWT_SECRET=' "${DEST_CONTAINER}" | cut -d'=' -f3- || true)
  if [ -n "${EXISTING_SECRET}" ] && [ "${EXISTING_SECRET}" != "<gen_this_shit>" ]; then
    echo "==> Reusing existing DT_JWT_SECRET from ${DEST_CONTAINER}"
    JWT_SECRET="${EXISTING_SECRET}"
  fi
fi

if [ -z "${JWT_SECRET}" ]; then
  echo "==> Generating secure random DT_JWT_SECRET using openssl..."
  JWT_SECRET=$(openssl rand -hex 32)
fi

# 6. Copy volume quadlets
cp -v "${SOURCE_DIR}/dt-config.volume" "${QUADLET_DIR}/"
cp -v "${SOURCE_DIR}/dt-data.volume"   "${QUADLET_DIR}/"

# 7. Copy container quadlet and inject secret
echo "==> Copying dt.container and replacing DT_JWT_SECRET placeholder..."
sed "s|Environment=DT_JWT_SECRET=.*|Environment=DT_JWT_SECRET=${JWT_SECRET}|" \
  "${SOURCE_DIR}/dt.container" > "${DEST_CONTAINER}"

# 8. Set ownership (root:admin) and permissions (640 / -rw-r-----)
echo "==> Setting ownership and permissions on Quadlet files..."
chown "root:${TARGET_USER}" \
  "${QUADLET_DIR}/dt.container" \
  "${QUADLET_DIR}/dt-config.volume" \
  "${QUADLET_DIR}/dt-data.volume"

chmod 640 \
  "${QUADLET_DIR}/dt.container" \
  "${QUADLET_DIR}/dt-config.volume" \
  "${QUADLET_DIR}/dt-data.volume"

# Load required kernel modules for gluetun (tun, wireguard) 
printf 'tun\nwireguard\n' | sudo tee /etc/modules-load.d/gluetun.conf

#!/bin/bash
set -euo pipefail

#
# Install script for Nightlio (ngo) Quadlet pod stack
# Deploys ngo.pod, ngo-api.container, ngo-web.container, and ngo-data.volume
# to /etc/containers/systemd/users/ with generated SECRET_KEY and JWT_SECRET
#
# Must be run as root / sudo.
#

TARGET_USER="${1:-admin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
QUADLET_DIR="/etc/containers/systemd/users"
PORT="5050"

# Require root execution
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root or with sudo:"
  echo "  sudo $0 [target_user]"
  exit 1
fi


echo "==> Installing Nightlio Quadlet stack for user: ${TARGET_USER}"
echo "    Source:      ${SOURCE_DIR}"
echo "    Destination: ${QUADLET_DIR}"

# Configure firewalld (if active)
if systemctl is-active --quiet firewalld; then
  echo "==> Configuring firewalld port ${PORT}/tcp..."
  firewall-cmd --add-port="${PORT}/tcp" --permanent
  firewall-cmd --reload
  echo "    Firewall port ${PORT}/tcp opened successfully."
else
  echo "==> Notice: firewalld is not active. Skipping firewall configuration."
fi

# Ensure destination directory exists
mkdir -p "${QUADLET_DIR}"

# Handle secrets generation (SECRET_KEY & JWT_SECRET)
DEST_API_CONTAINER="${QUADLET_DIR}/ngo-api.container"
SECRET_KEY=""
JWT_SECRET=""

if [ -z "${SECRET_KEY}" ]; then
  echo "==> Generating secure random SECRET_KEY using openssl..."
  SECRET_KEY=$(openssl rand -hex 32)
fi

if [ -z "${JWT_SECRET}" ]; then
  echo "==> Generating secure random JWT_SECRET using openssl..."
  JWT_SECRET=$(openssl rand -hex 32)
fi

# 6. Copy non-secret quadlet files
cp -v "${SOURCE_DIR}/ngo.pod"           "${QUADLET_DIR}/"
cp -v "${SOURCE_DIR}/ngo-web.container" "${QUADLET_DIR}/"
cp -v "${SOURCE_DIR}/ngo-data.volume"   "${QUADLET_DIR}/"

# Copy API container quadlet and inject generated secrets
echo "==> Copying ngo-api.container and replacing secrets..."
sed -e "s|Environment=SECRET_KEY=.*|Environment=SECRET_KEY=${SECRET_KEY}|" \
    -e "s|Environment=JWT_SECRET=.*|Environment=JWT_SECRET=${JWT_SECRET}|" \
    "${SOURCE_DIR}/ngo-api.container" > "${DEST_API_CONTAINER}"

# Set ownership (root:admin) and permissions (640 / -rw-r-----)
echo "==> Setting ownership and permissions on Quadlet files..."
chown "root:${TARGET_USER}" \
  "${QUADLET_DIR}/ngo.pod" \
  "${QUADLET_DIR}/ngo-api.container" \
  "${QUADLET_DIR}/ngo-web.container" \
  "${QUADLET_DIR}/ngo-data.volume"

chmod 640 \
  "${QUADLET_DIR}/ngo.pod" \
  "${QUADLET_DIR}/ngo-api.container" \
  "${QUADLET_DIR}/ngo-web.container" \
  "${QUADLET_DIR}/ngo-data.volume"

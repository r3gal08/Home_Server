#!/bin/bash
set -euo pipefail

#
# Install script for VPN + qBittorrent Quadlet stack
# Deploys Gluetun (Mullvad VPN) + qBittorrent to /etc/containers/systemd/users/
#
# Must be run as root / sudo.

TARGET_USER="${1:-admin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPN_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
QUADLET_DIR="/etc/containers/systemd/users"

# 1. Require root execution
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root or with sudo:"
  echo "  sudo $0 [target_user]"
  exit 1
fi

# 2. Verify target user exists
if ! id "${TARGET_USER}" &>/dev/null; then
  echo "ERROR: User '${TARGET_USER}' does not exist on this system."
  echo "Usage: sudo $0 <existing_username>"
  exit 1
fi

echo "==> Installing VPN + qBittorrent Quadlet for user: ${TARGET_USER}"
echo "    Source:      ${VPN_DIR}"
echo "    Destination: ${QUADLET_DIR}"

# 3. Configure firewalld ports (if active)
if systemctl is-active --quiet firewalld; then
  echo "==> Configuring firewalld ports..."
  # 8080/tcp: qBittorrent WebUI (served through Gluetun's network namespace)
  firewall-cmd --add-port=8080/tcp --permanent
  firewall-cmd --reload
  echo "    Firewall port 8080/tcp opened successfully."
else
  echo "==> Notice: firewalld is not active. Skipping firewall configuration."
fi

# 4. Ensure the destination directory exists
mkdir -p "${QUADLET_DIR}"

# 5. Create the downloads directory on the host
DOWNLOADS_DIR="/home/${TARGET_USER}/downloads"
mkdir -p "${DOWNLOADS_DIR}"
chown "${TARGET_USER}:${TARGET_USER}" "${DOWNLOADS_DIR}"
chmod 750 "${DOWNLOADS_DIR}"
# SELinux: label the directory so rootless containers can write to it
chcon -t container_file_t "${DOWNLOADS_DIR}" 2>/dev/null || true
echo "==> Downloads directory created at ${DOWNLOADS_DIR}"

# Enable ELRepo and EPEL repositories if not already present
dnf install -y epel-release

# Install kernel module and tools
dnf install -y kmod-wireguard wireguard-tools

# Load the module now (ignore if already loaded)
# This allows us to avoid wireguard-go and improve performance for the VPN container
modprobe wireguard || true

# Persist across reboots
echo "wireguard" > /etc/modules-load.d/wireguard.conf

# 7. Copy quadlet files
cp -v "${VPN_DIR}/glt.container"       "${QUADLET_DIR}/"
cp -v "${VPN_DIR}/qbt.container"   "${QUADLET_DIR}/"
cp -v "${VPN_DIR}/qbt-data.volume"       "${QUADLET_DIR}/"

# 8. Set ownership and permissions
chown "root:${TARGET_USER}" \
  "${QUADLET_DIR}/glt.container" \
  "${QUADLET_DIR}/qbt.container" \
  "${QUADLET_DIR}/qbt-data.volume"

chmod 640 \
  "${QUADLET_DIR}/glt.container" \
  "${QUADLET_DIR}/qbt.container" \
  "${QUADLET_DIR}/qbt-data.volume"

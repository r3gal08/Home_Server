#!/bin/bash
set -euo pipefail

#
# Install Elastic Stack Quadlet files for rootless Podman into /etc/
#
# Target directory: /etc/containers/systemd/users/
# Target user:      admin (or passed as argument: ./install.sh <username>)
#
# What this does:
#   1. Copies .container, .volume, .network files → /etc/containers/systemd/users/
#   2. Copies helper scripts → /etc/containers/systemd/users/elastic-scripts/
#   3. Copies the env file → /etc/containers/systemd/users/elastic.env
#   4. Restricts elastic.env permissions (640, owned by target user)
#   5. Enables lingering for the user (starts automatically on host boot)
#   6. Reloads the user's systemd daemon
#

TARGET_USER="${1:-admin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUADLET_DIR="/etc/containers/systemd/users"
SCRIPTS_DIR="${QUADLET_DIR}/elastic-scripts"

# Must run with sudo / root to write to /etc/
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script with sudo or as root:"
  echo "  sudo $0 [target_user]"
  exit 1
fi

# Verify target user exists
if ! id "${TARGET_USER}" &>/dev/null; then
  echo "ERROR: User '${TARGET_USER}' does not exist on this system."
  echo "Usage: sudo $0 <existing_username>"
  exit 1
fi

echo "==> Installing Elastic Stack Quadlets to /etc/ for user: ${TARGET_USER}"
echo "    Source:      ${SCRIPT_DIR}"
echo "    Quadlet dir: ${QUADLET_DIR}"
echo "    Scripts dir: ${SCRIPTS_DIR}"
echo ""

# Create directories under /etc/
mkdir -p "${QUADLET_DIR}" "${SCRIPTS_DIR}"

# Copy quadlet unit files
echo "  Copying quadlet files to ${QUADLET_DIR}..."
cp -v "${SCRIPT_DIR}/elastic.network"                   "${QUADLET_DIR}/"
cp -v "${SCRIPT_DIR}/elastic-certs.volume"              "${QUADLET_DIR}/"
cp -v "${SCRIPT_DIR}/elastic-esdata01.volume"           "${QUADLET_DIR}/"
cp -v "${SCRIPT_DIR}/elastic-kibanadata.volume"         "${QUADLET_DIR}/"
cp -v "${SCRIPT_DIR}/elastic-setup-certs.container"     "${QUADLET_DIR}/"
cp -v "${SCRIPT_DIR}/elastic-es01.container"            "${QUADLET_DIR}/"
cp -v "${SCRIPT_DIR}/elastic-setup-passwords.container" "${QUADLET_DIR}/"
cp -v "${SCRIPT_DIR}/elastic-kibana.container"          "${QUADLET_DIR}/"
cp -v "${SCRIPT_DIR}/kibana.yml"                        "${QUADLET_DIR}/"
chmod 644 "${QUADLET_DIR}"/elastic*.{container,volume,network} "${QUADLET_DIR}/kibana.yml"
chcon -t container_file_t "${QUADLET_DIR}/kibana.yml" 2>/dev/null || true

# Copy environment file (don't overwrite if it already exists with passwords)
if [ -f "${QUADLET_DIR}/elastic.env" ]; then
  echo ""
  echo "  ⚠  ${QUADLET_DIR}/elastic.env already exists — skipping to preserve passwords."
else
  cp -v "${SCRIPT_DIR}/elastic.env" "${QUADLET_DIR}/"
fi

# Secure elastic.env so only root and TARGET_USER can read secrets
chown "root:${TARGET_USER}" "${QUADLET_DIR}/elastic.env"
chmod 640 "${QUADLET_DIR}/elastic.env"

# Copy and mark scripts executable, set SELinux label for container access
echo ""
echo "  Copying helper scripts..."
cp -v "${SCRIPT_DIR}/scripts/setup-certs.sh"         "${SCRIPTS_DIR}/"
cp -v "${SCRIPT_DIR}/scripts/setup-passwords.sh"     "${SCRIPTS_DIR}/"
chmod 755 "${SCRIPTS_DIR}"/*.sh
chown -R "${TARGET_USER}:${TARGET_USER}" "${SCRIPTS_DIR}"
# Pre-label scripts with container_file_t so rootless containers can read them without lsetxattr errors
chcon -R -t container_file_t "${SCRIPTS_DIR}" 2>/dev/null || true

# Enable lingering so user services start at host boot
echo ""
echo "  Enabling loginctl lingering for ${TARGET_USER}..."
loginctl enable-linger "${TARGET_USER}"

# Enable cgroup delegation so rootless Podman can manage cgroup resources
echo ""
echo "  Enabling cgroup delegation for user@.service..."
mkdir -p /etc/systemd/system/user@.service.d
cat > /etc/systemd/system/user@.service.d/delegate.conf <<'DELEGATE'
[Service]
Delegate=yes
DELEGATE
systemctl daemon-reload

# Reload systemd user daemon for TARGET_USER
echo ""
echo "  Reloading systemd user daemon for ${TARGET_USER}..."
if systemctl --machine="${TARGET_USER}@" --user daemon-reload 2>/dev/null; then
  echo "  Daemon reloaded via --machine=${TARGET_USER}@"
else
  # Fallback for systems where user dbus bridge isn't active until user session starts
  echo "  (User session not active yet; daemon will reload automatically when session starts)"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════════╗"
echo "║                                NEXT STEPS                                        ║"
echo "╠══════════════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                                  ║"
echo "║  1. Configure passwords in /etc:                                                 ║"
echo "║     sudo \$EDITOR ${QUADLET_DIR}/elastic.env                                      ║"
echo "║                                                                                  ║"
echo "║  2. Start the stack (from root or via sudo):                                     ║"
echo "║     sudo systemctl --machine=${TARGET_USER}@ --user start elastic-kibana         ║"
echo "║                                                                                  ║"
echo "║     OR as the ${TARGET_USER} user directly:                                      ║"
echo "║     systemctl --user start elastic-kibana                                        ║"
echo "║                                                                                  ║"
echo "║  3. Check status:                                                                ║"
echo "║     sudo systemctl --machine=${TARGET_USER}@ --user status elastic-es01          ║"
echo "║     sudo systemctl --machine=${TARGET_USER}@ --user status elastic-kibana        ║"
echo "║                                                                                  ║"
echo "║  4. View logs:                                                                   ║"
echo "║     sudo journalctl --machine=${TARGET_USER}@ --user -u elastic-es01 -f          ║"
echo "║     sudo journalctl --machine=${TARGET_USER}@ --user -u elastic-kibana -f        ║"
echo "║                                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════════════════════╝"

#!/bin/bash
# Installs the root-side pieces for the CHARGE LIMIT buttons (TUXEDO/uniwill only):
#   /usr/local/bin/tuxedo-charging-profile      root-owned helper that writes the EC sysfs attr
#   /etc/sudoers.d/tuxedo-charging              NOPASSWD for exactly three helper invocations
#   /etc/systemd/system/tuxedo-charging-profile.service   pins the cap at boot (EC resets to 100% otherwise)
# Idempotent. Run with: sudo ./install-system.sh [user] [profile]
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
user=${1:-${SUDO_USER:-$USER}}
profile=${2:-stationary}
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
[[ -d /sys/devices/platform/tuxedo_keyboard ]] || echo "warning: tuxedo_keyboard not loaded; installing anyway" >&2

install -o root -g root -m 755 "$here/system/tuxedo-charging-profile" /usr/local/bin/tuxedo-charging-profile
sed "s/^sspaeti /$user /" "$here/system/tuxedo-charging.sudoers" > /etc/sudoers.d/tuxedo-charging
chmod 440 /etc/sudoers.d/tuxedo-charging
visudo -cf /etc/sudoers.d/tuxedo-charging
sed "s/tuxedo-charging-profile stationary/tuxedo-charging-profile $profile/" \
  "$here/system/tuxedo-charging-profile.service" > /etc/systemd/system/tuxedo-charging-profile.service
systemctl daemon-reload
systemctl enable --now tuxedo-charging-profile.service
echo "charging profile now: $(cat /sys/devices/platform/tuxedo_keyboard/charging_profile/charging_profile 2>/dev/null || echo n/a)"

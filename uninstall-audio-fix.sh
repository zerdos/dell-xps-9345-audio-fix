#!/bin/bash
#
# Dell XPS 13 9345 Audio Fix - Uninstaller
#
# Usage: sudo ./uninstall-audio-fix.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Dell XPS 13 9345 Audio Fix - Uninstaller${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

read -p "Are you sure you want to uninstall the audio fix? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

echo "Stopping and disabling services..."
systemctl stop xps-audio-monitor.service 2>/dev/null || true
systemctl stop xps-audio-fix.service 2>/dev/null || true
systemctl disable xps-audio-monitor.service 2>/dev/null || true
systemctl disable xps-audio-fix.service 2>/dev/null || true

echo "Removing service files..."
rm -f /etc/systemd/system/xps-audio-fix.service
rm -f /etc/systemd/system/xps-audio-monitor.service
systemctl daemon-reload

echo "Removing scripts..."
rm -f /usr/local/bin/xps-audio-fix.sh
rm -f /usr/local/bin/xps-audio-monitor.sh

echo "Removing module configuration..."
rm -f /etc/modprobe.d/x1e-audio.conf

echo "Removing WirePlumber configuration..."
rm -f "$ACTUAL_HOME/.config/wireplumber/wireplumber.conf.d/51-alsa-use-ucm.conf"
rm -f "$ACTUAL_HOME/.config/wireplumber/wireplumber.conf.d/52-alsa-fix-channels.conf"

echo ""
echo -e "${YELLOW}Note:${NC} The following were NOT removed (shared with other systems):"
echo "  - Audio topology firmware: /lib/firmware/qcom/x1e80100/X1E80100-Dell-XPS-13-9345-tplg.bin"
echo "  - UCM configuration: /usr/share/alsa/ucm2/X1E80100DellXPS/"
echo "  - ALSA state: /var/lib/alsa/asound.state"
echo ""
echo "If you want to remove these manually:"
echo "  sudo rm -rf /usr/share/alsa/ucm2/X1E80100DellXPS"
echo "  sudo rm /lib/firmware/qcom/x1e80100/X1E80100-Dell-XPS-13-9345-tplg.bin"
echo ""
echo -e "${GREEN}Uninstall complete. Reboot to apply changes.${NC}"

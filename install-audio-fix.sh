#!/bin/bash
#
# Dell XPS 13 9345 Audio Fix - Automated Installer
# Supports: Ubuntu 24.04+ with Snapdragon X1 Elite
#
# Usage: sudo ./install-audio-fix.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Dell XPS 13 9345 Audio Fix - Automated Installer           ║${NC}"
echo -e "${GREEN}║   For Ubuntu Linux with Snapdragon X1 Elite                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if running on correct hardware
echo -e "${YELLOW}[1/8]${NC} Checking hardware compatibility..."
KERNEL=$(uname -r)
if [[ ! "$KERNEL" =~ qcom-x1e ]]; then
    echo -e "${RED}Warning: Kernel doesn't appear to be Qualcomm X1E specific${NC}"
    echo "Current kernel: $KERNEL"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

echo -e "${GREEN}✓${NC} Hardware check passed"
echo ""

# Step 1: Enable experimental audio driver
echo -e "${YELLOW}[2/8]${NC} Enabling experimental audio driver..."
cat > /etc/modprobe.d/x1e-audio.conf << 'EOF'
# Enable experimental audio support for Dell XPS 13 9345
options snd_soc_x1e80100 i_accept_the_danger=1
EOF
echo -e "${GREEN}✓${NC} Audio driver configuration created"
echo ""

# Step 2: Install dependencies
echo -e "${YELLOW}[3/8]${NC} Installing dependencies..."
apt update -qq
apt install -y cmake m4 git alsa-utils > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Dependencies installed"
echo ""

# Step 3: Build and install topology firmware
echo -e "${YELLOW}[4/8]${NC} Building audio topology firmware..."
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"

# Clone and build topology
git clone -q https://github.com/linux-msm/audioreach-topology.git
cd audioreach-topology
cmake . > /dev/null 2>&1
make topology_X1E80100-Dell-XPS-13-9345 > /dev/null 2>&1

# Install topology firmware
cp qcom/x1e80100/dell/xps13-9345/X1E80100-Dell-XPS-13-9345-tplg.bin \
   /lib/firmware/qcom/x1e80100/

echo -e "${GREEN}✓${NC} Topology firmware installed"
echo ""

# Step 4: Install UCM configuration
echo -e "${YELLOW}[5/8]${NC} Installing ALSA UCM configuration..."
cd "$WORK_DIR"

# Clone UCM configuration with Dell XPS support
git clone -q -b dell-xps-9345 https://github.com/alexVinarskis/alsa-ucm-conf.git
cd alsa-ucm-conf

# Copy updated UCM files
cp -r ucm2/Qualcomm/x1e80100/* /usr/share/alsa/ucm2/Qualcomm/x1e80100/

# Create card-specific UCM directory
mkdir -p /usr/share/alsa/ucm2/X1E80100DellXPS

# Create HiFi.conf with hardcoded card ID
cp /usr/share/alsa/ucm2/Qualcomm/x1e80100/Slim7x-HiFi.conf \
   /usr/share/alsa/ucm2/X1E80100DellXPS/HiFi.conf
sed -i 's/\${CardId}/0/g' /usr/share/alsa/ucm2/X1E80100DellXPS/HiFi.conf

# Create main UCM config
cat > /usr/share/alsa/ucm2/X1E80100DellXPS/X1E80100DellXPS.conf << 'UCMEOF'
Syntax 4

SectionUseCase."HiFi" {
	File "HiFi.conf"
	Comment "HiFi quality Music."
}

Include.card-init.File "/lib/card-init.conf"
Include.ctl-remap.File "/lib/ctl-remap.conf"
Include.wsa-init.File "/codecs/wsa884x/four-speakers/init.conf"
Include.wsam-init.File "/codecs/qcom-lpass/wsa-macro/four-speakers/init.conf"
UCMEOF

echo -e "${GREEN}✓${NC} UCM configuration installed"
echo ""

# Step 5: Configure WirePlumber
echo -e "${YELLOW}[6/8]${NC} Configuring WirePlumber..."
mkdir -p "$ACTUAL_HOME/.config/wireplumber/wireplumber.conf.d"

# Force UCM usage
cat > "$ACTUAL_HOME/.config/wireplumber/wireplumber.conf.d/51-alsa-use-ucm.conf" << 'WPEOF'
monitor.alsa.rules = [
  {
    matches = [
      {
        device.name = "~alsa_card.*"
      }
    ]
    actions = {
      update-props = {
        api.alsa.use-acp = false
        api.alsa.use-ucm = true
      }
    }
  }
]
WPEOF

# Fix channel counts
cat > "$ACTUAL_HOME/.config/wireplumber/wireplumber.conf.d/52-alsa-fix-channels.conf" << 'WPEOF'
monitor.alsa.rules = [
  {
    matches = [
      {
        node.name = "~alsa_output.platform-sound.*"
      }
    ]
    actions = {
      update-props = {
        audio.format = "S16LE"
        audio.rate = 48000
        audio.channels = 4
        audio.position = [ FL FR RL RR ]
        api.alsa.period-size = 768
        api.alsa.headroom = 1280
      }
    }
  }
  {
    matches = [
      {
        node.name = "~alsa_input.platform-sound.*"
      }
    ]
    actions = {
      update-props = {
        audio.format = "S16LE"
        audio.rate = 48000
        audio.channels = 2
        audio.position = [ FL FR ]
      }
    }
  }
]
WPEOF

chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.config/wireplumber"

echo -e "${GREEN}✓${NC} WirePlumber configured"
echo ""

# Step 6: Create audio fix scripts
echo -e "${YELLOW}[7/8]${NC} Installing audio fix scripts..."

cat > /usr/local/bin/xps-audio-fix.sh << 'FIXEOF'
#!/bin/bash
sleep 3

# Main audio routing
amixer -c 0 sset 'WSA_CODEC_DMA_RX_0 Audio Mixer MultiMedia2' on,on 2>/dev/null

# WSA1 audio paths
amixer -c 0 sset 'WSA WSA RX0 MUX' 'AIF1_PB' 2>/dev/null
amixer -c 0 sset 'WSA WSA RX1 MUX' 'AIF1_PB' 2>/dev/null
amixer -c 0 sset 'WSA WSA_RX0 INP0' 'RX0' 2>/dev/null
amixer -c 0 sset 'WSA WSA_RX1 INP0' 'RX1' 2>/dev/null
amixer -c 0 sset 'WSA WSA_COMP1' on 2>/dev/null
amixer -c 0 sset 'WSA WSA_COMP2' on 2>/dev/null

# WSA2 audio paths
amixer -c 0 sset 'WSA2 WSA RX0 MUX' 'AIF1_PB' 2>/dev/null
amixer -c 0 sset 'WSA2 WSA RX1 MUX' 'AIF1_PB' 2>/dev/null
amixer -c 0 sset 'WSA2 WSA_RX0 INP0' 'RX0' 2>/dev/null
amixer -c 0 sset 'WSA2 WSA_RX1 INP0' 'RX1' 2>/dev/null
amixer -c 0 sset 'WSA2 WSA_COMP1' on 2>/dev/null
amixer -c 0 sset 'WSA2 WSA_COMP2' on 2>/dev/null

# Enable all speaker components
for spk in TweeterLeft TweeterRight WooferLeft WooferRight; do
  for ctrl in BOOST COMP DAC PBR VISENSE; do
    amixer -c 0 sset "$spk $ctrl" on 2>/dev/null
  done
  amixer -c 0 sset "$spk PA" 70% 2>/dev/null
done

alsactl store 2>/dev/null
exit 0
FIXEOF

cat > /usr/local/bin/xps-audio-monitor.sh << 'MONEOF'
#!/bin/bash
# Monitor and maintain audio routing

while true; do
  sleep 5

  # Check if routing is correct
  ROUTING=$(amixer -c 0 sget 'WSA_CODEC_DMA_RX_0 Audio Mixer MultiMedia2' 2>/dev/null | grep "Front Right: Playback")

  if echo "$ROUTING" | grep -q "\[off\]"; then
    # Routing got reset, fix it
    amixer -c 0 sset 'WSA_CODEC_DMA_RX_0 Audio Mixer MultiMedia2' on,on 2>/dev/null
    amixer -c 0 sset 'WSA WSA RX0 MUX' 'AIF1_PB' 2>/dev/null
    amixer -c 0 sset 'WSA WSA RX1 MUX' 'AIF1_PB' 2>/dev/null
    amixer -c 0 sset 'WSA2 WSA RX0 MUX' 'AIF1_PB' 2>/dev/null
    amixer -c 0 sset 'WSA2 WSA RX1 MUX' 'AIF1_PB' 2>/dev/null
  fi
done
MONEOF

chmod +x /usr/local/bin/xps-audio-fix.sh
chmod +x /usr/local/bin/xps-audio-monitor.sh

echo -e "${GREEN}✓${NC} Audio fix scripts installed"
echo ""

# Step 7: Create systemd services
echo -e "${YELLOW}[8/8]${NC} Installing systemd services..."

# Create system-wide service for initial fix
cat > /etc/systemd/system/xps-audio-fix.service << 'SVCEOF'
[Unit]
Description=Dell XPS 13 9345 Audio Fix
After=sound.target alsa-restore.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xps-audio-fix.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF

# Create system-wide service for monitoring
cat > /etc/systemd/system/xps-audio-monitor.service << 'SVCEOF'
[Unit]
Description=Dell XPS 13 9345 Audio Monitor
After=xps-audio-fix.service

[Service]
Type=simple
ExecStart=/usr/local/bin/xps-audio-monitor.sh
Restart=always

[Install]
WantedBy=multi-user.target
SVCEOF

# Enable services
systemctl daemon-reload
systemctl enable xps-audio-fix.service
systemctl enable xps-audio-monitor.service

echo -e "${GREEN}✓${NC} Systemd services installed and enabled"
echo ""

# Cleanup
cd /
rm -rf "$WORK_DIR"

# Final steps
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Installation Complete!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Reboot your system: ${GREEN}sudo reboot${NC}"
echo "2. After reboot, audio should work automatically"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "- Check service status: ${GREEN}systemctl status xps-audio-fix${NC}"
echo "- View logs: ${GREEN}journalctl -u xps-audio-fix -u xps-audio-monitor${NC}"
echo "- Manual fix: ${GREEN}sudo /usr/local/bin/xps-audio-fix.sh${NC}"
echo ""
echo -e "${YELLOW}Documentation:${NC}"
echo "https://github.com/zerdos/dell-xps-9345-audio-fix"
echo ""

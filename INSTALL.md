# Dell XPS 13 9345 Audio Fix - Installation Guide

## Quick Install (Recommended)

### Method 1: One-Command Install

For the fastest installation, run:

```bash
curl -fsSL https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/master/install-audio-fix.sh | sudo bash
```

Or download and review first:

```bash
wget https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/master/install-audio-fix.sh
chmod +x install-audio-fix.sh
sudo ./install-audio-fix.sh
```

### Method 2: Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/zerdos/dell-xps-9345-audio-fix.git
cd dell-xps-9345-audio-fix
```

2. Run the installer:
```bash
chmod +x install-audio-fix.sh
sudo ./install-audio-fix.sh
```

3. Reboot:
```bash
sudo reboot
```

---

## Advanced Installation Methods

### Method 3: Cloud-Init (For Automated Deployments)

Perfect for:
- Mass deployments
- Cloud instances
- Automated provisioning

1. Create cloud-init seed ISO:
```bash
# Download the cloud-init configuration
wget https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/master/cloud-init-userdata.yaml

# Create empty meta-data
touch meta-data

# Create seed ISO
genisoimage -output seed.iso -volid cidata -joliet -rock cloud-init-userdata.yaml meta-data
```

2. Attach seed.iso during Ubuntu installation

3. The system will automatically:
   - Install all dependencies
   - Configure audio
   - Reboot when done

### Method 4: Manual Step-by-Step (For Understanding)

If you want to understand each step:

1. **Enable experimental driver:**
```bash
echo "options snd_soc_x1e80100 i_accept_the_danger=1" | sudo tee /etc/modprobe.d/x1e-audio.conf
```

2. **Install dependencies:**
```bash
sudo apt update
sudo apt install -y cmake m4 git alsa-utils
```

3. **Build topology firmware:**
```bash
cd /tmp
git clone https://github.com/linux-msm/audioreach-topology.git
cd audioreach-topology
cmake .
make topology_X1E80100-Dell-XPS-13-9345
sudo cp qcom/x1e80100/dell/xps13-9345/X1E80100-Dell-XPS-13-9345-tplg.bin /lib/firmware/qcom/x1e80100/
```

4. **Install UCM configuration:**
```bash
cd /tmp
git clone -b dell-xps-9345 https://github.com/alexVinarskis/alsa-ucm-conf.git
cd alsa-ucm-conf
sudo cp -r ucm2/Qualcomm/x1e80100/* /usr/share/alsa/ucm2/Qualcomm/x1e80100/
sudo mkdir -p /usr/share/alsa/ucm2/X1E80100DellXPS
sudo cp /usr/share/alsa/ucm2/Qualcomm/x1e80100/Slim7x-HiFi.conf /usr/share/alsa/ucm2/X1E80100DellXPS/HiFi.conf
sudo sed -i 's/\${CardId}/0/g' /usr/share/alsa/ucm2/X1E80100DellXPS/HiFi.conf
```

5. **Download and install scripts:**
```bash
wget https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/master/xps-audio-fix.sh
wget https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/master/xps-audio-monitor.sh
sudo mv xps-audio-fix.sh xps-audio-monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/xps-audio-*.sh
```

6. **Install systemd services:**
```bash
wget https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/master/xps-audio-fix.service
wget https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/master/xps-audio-monitor.service
sudo mv xps-audio-*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable xps-audio-fix.service xps-audio-monitor.service
```

7. **Reboot:**
```bash
sudo reboot
```

---

## Uninstallation

To remove the audio fix:

```bash
wget https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/master/uninstall-audio-fix.sh
chmod +x uninstall-audio-fix.sh
sudo ./uninstall-audio-fix.sh
```

---

## Verification

After installation and reboot, verify audio is working:

1. **Check sound card detection:**
```bash
aplay -l
```
Expected output: Shows "X1E80100-Dell-XPS-13-9345"

2. **Check PipeWire status:**
```bash
wpctl status
```
Expected output: Shows "Built-in Audio" under Sinks

3. **Check services:**
```bash
systemctl status xps-audio-fix.service
systemctl status xps-audio-monitor.service
```
Expected output: Both should be "active"

4. **Test audio:**
   - Open Settings → Sound
   - Click volume slider (should make a sound)
   - Play a video/music

---

## Troubleshooting

### No sound after installation:

1. **Manually run the fix:**
```bash
sudo /usr/local/bin/xps-audio-fix.sh
```

2. **Check mixer routing:**
```bash
amixer -c 0 sget 'WSA_CODEC_DMA_RX_0 Audio Mixer MultiMedia2'
```
Both channels should show `[on]`

3. **View service logs:**
```bash
journalctl -u xps-audio-fix.service -u xps-audio-monitor.service
```

### Audio stops working after a while:

This is normal - the monitor service should fix it automatically within 5 seconds. If not:

```bash
sudo systemctl restart xps-audio-monitor.service
```

### Installation failed:

1. Check you're on Ubuntu with Snapdragon X1 Elite:
```bash
uname -r
```
Should contain "qcom-x1e"

2. Check internet connection (needed to download firmware)

3. Try manual installation (Method 4)

---

## System Requirements

- **Hardware:** Dell XPS 13 9345 with Snapdragon X1 Elite (X1E80100)
- **OS:** Ubuntu 24.04 or newer (ARM64)
- **Kernel:** 6.14.0-32-qcom-x1e or newer
- **Internet:** Required for downloading firmware during installation

---

## What Gets Installed

### Files Created:
- `/etc/modprobe.d/x1e-audio.conf` - Driver configuration
- `/lib/firmware/qcom/x1e80100/X1E80100-Dell-XPS-13-9345-tplg.bin` - Audio topology
- `/usr/share/alsa/ucm2/X1E80100DellXPS/*` - ALSA UCM configuration
- `/usr/local/bin/xps-audio-fix.sh` - Audio fix script
- `/usr/local/bin/xps-audio-monitor.sh` - Monitoring script
- `/etc/systemd/system/xps-audio-fix.service` - Boot-time service
- `/etc/systemd/system/xps-audio-monitor.service` - Monitoring service
- `~/.config/wireplumber/wireplumber.conf.d/*` - WirePlumber configuration

### Services Enabled:
- `xps-audio-fix.service` - Runs at boot to configure audio
- `xps-audio-monitor.service` - Monitors and maintains audio routing

---

## Security Considerations

The installer script:
- Requires root access (uses `sudo`)
- Downloads code from GitHub
- Compiles firmware from source
- Modifies system configuration

**Recommendation:** Review the installer script before running it:
```bash
curl -fsSL https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/master/install-audio-fix.sh | less
```

---

## Support & Contributing

- **Issues:** https://github.com/zerdos/dell-xps-9345-audio-fix/issues
- **Documentation:** https://github.com/zerdos/dell-xps-9345-audio-fix
- **Original Research:** See README.md for detailed technical documentation

---

## License

This configuration is provided as-is for the Dell XPS 13 9345 community. See repository for license details.

---

## Credits

- Audio topology: [linux-msm/audioreach-topology](https://github.com/linux-msm/audioreach-topology)
- UCM configuration: [alexVinarskis/alsa-ucm-conf](https://github.com/alexVinarskis/alsa-ucm-conf)
- Community testing and feedback

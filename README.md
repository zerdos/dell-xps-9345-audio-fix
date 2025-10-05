# Dell XPS 13 9345 Audio Fix

Audio fix for Dell XPS 13 9345 with Snapdragon X1 Elite on Ubuntu Linux.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/main/install-audio-fix.sh | sudo bash
```

## What This Fixes

Enables audio on Dell XPS 13 9345 laptops with Qualcomm Snapdragon X1 Elite processors running Ubuntu Linux. Configures:

- **Qualcomm AudioReach DSP** - Audio processing
- **WSA884x Amplifiers** - 4-speaker setup (2 tweeters + 2 woofers)
- **ALSA UCM** - Audio routing configuration
- **Systemd services** - Boot-time setup and monitoring

## Installation Methods

### Method 1: One-Line Install (Recommended)

For installed systems or live USB with internet:

```bash
curl -fsSL https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/main/install-audio-fix.sh | sudo bash
sudo reboot
```

### Method 2: Cloud-Init Seed ISO

For automated installation during Ubuntu setup:

1. Download the seed ISO: [xps9345-audio-seed.iso](xps9345-audio-seed.iso) (368 KB)
2. Attach during Ubuntu installation
3. Audio fix installs automatically on first boot

### Method 3: Manual Installation

See [INSTALL.md](INSTALL.md) for step-by-step manual installation.

## Testing

See [TESTING_INSTRUCTIONS.md](TESTING_INSTRUCTIONS.md) for detailed testing guides including:
- Live USB testing
- Cloud-init deployment
- Verification steps

## Files

- `install-audio-fix.sh` - Automated installer
- `uninstall-audio-fix.sh` - Clean removal
- `cloud-init-userdata.yaml` - Cloud-init configuration
- `xps9345-audio-seed.iso` - Cloud-init seed ISO (368 KB)
- `INSTALL.md` - Installation guide
- `TESTING_INSTRUCTIONS.md` - Testing guide

## System Requirements

- **Hardware:** Dell XPS 13 9345
- **Processor:** Qualcomm Snapdragon X1 Elite (X1E80100)
- **OS:** Ubuntu 24.04+ ARM64
- **Kernel:** 6.14.0-32-qcom-x1e or newer

## What Gets Installed

1. **Kernel module configuration** - `/etc/modprobe.d/x1e-audio.conf`
2. **Audio topology firmware** - `/lib/firmware/qcom/x1e80100/X1E80100-Dell-XPS-13-9345-tplg.bin`
3. **ALSA UCM configuration** - `/usr/share/alsa/ucm2/X1E80100DellXPS/`
4. **Audio fix scripts** - `/usr/local/bin/xps-audio-fix.sh` and `xps-audio-monitor.sh`
5. **Systemd services** - `xps-audio-fix.service` and `xps-audio-monitor.service`

## Verification

After installation and reboot:

```bash
# Check sound card
aplay -l
# Should show: X1E80100-Dell-XPS-13-9345

# Check services
systemctl status xps-audio-fix.service
systemctl status xps-audio-monitor.service

# Test audio
wpctl status
# Should show "Built-in Audio" under Sinks
```

## Troubleshooting

If audio doesn't work:

```bash
# Manual fix
sudo /usr/local/bin/xps-audio-fix.sh

# Check logs
journalctl -u xps-audio-fix.service
journalctl -u xps-audio-monitor.service

# Reinstall
curl -fsSL https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/main/install-audio-fix.sh | sudo bash
```

## Uninstallation

```bash
curl -fsSL https://raw.githubusercontent.com/zerdos/dell-xps-9345-audio-fix/main/uninstall-audio-fix.sh | sudo bash
sudo reboot
```

## Credits

- **Audio topology:** [linux-msm/audioreach-topology](https://github.com/linux-msm/audioreach-topology)
- **UCM configuration:** [alexVinarskis/alsa-ucm-conf](https://github.com/alexVinarskis/alsa-ucm-conf)
- **Community:** Dell XPS 13 9345 users and testers

## Contributing

Issues and pull requests welcome! Help us improve audio support for Dell XPS 13 9345.

## License

Provided as-is for the Dell XPS 13 9345 community.

---

**🎵 Enjoy your working audio!**

# Dell XPS 13 9345 Audio Fix - Complete Documentation

## Overview
The Dell XPS 13 9345 with Snapdragon X1 Elite (X1E80100) processor requires special configuration to enable audio on Ubuntu Linux. This document details the complete process, including failed attempts and the final working solution.

## Hardware Configuration
- **Laptop:** Dell XPS 13 9345 (2024)
- **Processor:** Snapdragon X1 Elite (X1E80100) - ARM64 architecture
- **Audio Codec:** Qualcomm AudioReach with WSA884x amplifiers
- **Speakers:** 4 speakers (2 woofers + 2 tweeters) using two WSA884x chips
- **OS:** Ubuntu Linux with kernel 6.14.0-32-qcom-x1e

## Initial Problem
- Sound settings showed only "Dummy Output"
- No audio hardware detected
- ALSA reported "no soundcards found"

## Root Causes Identified
1. Audio driver marked as experimental and disabled by default
2. Missing audio topology firmware file
3. Missing/incorrect ALSA UCM (Use Case Manager) configuration
4. WirePlumber defaulting to ACP instead of UCM
5. Complex mixer routing not being initialized at boot
6. Multiple audio path controls left in disabled state

---

## Solution Process (Chronological with Failures)

### Step 1: Enable Experimental Audio Driver

**Issue:** The `snd_soc_x1e80100` audio driver has a safety parameter that prevents it from loading.

**Investigation:**
```bash
modinfo snd_soc_x1e80100
```
Found parameter: `i_accept_the_danger` (boolean)

**Solution:**
Created module configuration to enable experimental audio:
```bash
sudo sh -c 'echo "options snd_soc_x1e80100 i_accept_the_danger=1" > /etc/modprobe.d/x1e-audio.conf'
```

**Result:** Audio driver now loads, but still no sound card detected.

---

### Step 2: Install Audio Topology Firmware

**Issue:** Kernel log showed:
```
qcom-apm gprsvc:service:2:1: Direct firmware load for qcom/x1e80100/X1E80100-Dell-XPS-13-9345-tplg.bin failed with error -2
```

**Investigation:**
- Checked `/lib/firmware/qcom/x1e80100/` - no Dell XPS 13 9345 topology file
- Found that topology files exist for other X1E devices (Lenovo, etc.)

**Solution:**
1. Cloned the audioreach-topology repository:
```bash
cd /tmp
git clone https://github.com/linux-msm/audioreach-topology.git
```

2. Built the topology file from source:
```bash
sudo apt install cmake m4
cd audioreach-topology
cmake .
make topology_X1E80100-Dell-XPS-13-9345
```

3. Copied the compiled topology file:
```bash
sudo cp qcom/x1e80100/dell/xps13-9345/X1E80100-Dell-XPS-13-9345-tplg.bin /lib/firmware/qcom/x1e80100/
```

**Result:** Topology firmware installed, but still issues with UCM configuration.

---

### Step 3: Install ALSA UCM Configuration

**Issue:** ALSA UCM (Use Case Manager) configuration missing for Dell XPS 13 9345.

**Investigation:**
- Checked system UCM configs: `/usr/share/alsa/ucm2/Qualcomm/x1e80100/`
- Found configs for Lenovo devices but not Dell XPS 9345
- Dell XPS uses similar hardware to Lenovo Slim 7x (same WSA884x speakers)

**Failed Attempt #1:** Tried to use the generic x1e80100.conf
- Created symlink to x1e80100.conf
- Got error: `variable '${CardId}' is not defined`
- UCM syntax issue - CardId variable not accessible in included files

**Failed Attempt #2:** Tried to define CardId in main config
```
Define.CardId "0"
```
- Variable still not accessible in sub-scope (HiFi.conf)

**Working Solution:**
1. Cloned updated UCM configuration with Dell XPS support:
```bash
cd /tmp
git clone -b dell-xps-9345 https://github.com/alexVinarskis/alsa-ucm-conf.git alsa-ucm-conf-xps
```

2. Copied updated configs:
```bash
sudo cp -r /tmp/alsa-ucm-conf-xps/ucm2/Qualcomm/x1e80100/* /usr/share/alsa/ucm2/Qualcomm/x1e80100/
```

3. Created card-specific UCM directory and config:
```bash
sudo mkdir -p /usr/share/alsa/ucm2/X1E80100DellXPS
```

4. Created custom HiFi.conf with hardcoded card ID (replacing ${CardId} with "0"):
```bash
sudo cp /usr/share/alsa/ucm2/Qualcomm/x1e80100/Slim7x-HiFi.conf /usr/share/alsa/ucm2/X1E80100DellXPS/HiFi.conf
sudo sed -i 's/\${CardId}/0/g' /usr/share/alsa/ucm2/X1E80100DellXPS/HiFi.conf
```

5. Created main UCM config file with proper syntax

**Result:** UCM configuration in place, but WirePlumber not using it.

---

### Step 4: Configure WirePlumber to Use UCM

**Issue:** WirePlumber was using ACP (ALSA Card Profiles) instead of UCM.

**Investigation:**
```bash
wpctl inspect <device-id>
```
Showed: `api.alsa.use-acp = "true"`

**Solution:**
Created WirePlumber configuration to force UCM usage in `~/.config/wireplumber/wireplumber.conf.d/51-alsa-use-ucm.conf`

**Result:** Audio devices now appeared in PipeWire, but no sound output.

---

### Step 5: Fix Audio Channel Configuration

**Issue:** PipeWire logs showed:
```
spa.alsa: hw:0,1p: Channels doesn't match (requested 64, got 4)
```

**Investigation:**
- Default channel count was 64 (incorrect)
- Hardware supports 4 channels (quad speaker setup)
- Capture device also had wrong channel count

**Solution:**
Created WirePlumber configuration to fix channel counts in `~/.config/wireplumber/wireplumber.conf.d/52-alsa-fix-channels.conf`

Set output to 4 channels and input to 2 channels with proper channel positions.

**Result:** Channel errors resolved, but still no audio output.

---

### Step 6: Fix ALSA Mixer Routing (Critical Issue)

**Issue:** Kernel log showed:
```
MultiMedia2 Playback: ASoC: no backend DAIs enabled for MultiMedia2 Playback, possibly missing ALSA mixer-based routing
```

**Investigation:**
The audio path from application → MultiMedia2 → WSA speakers was not connected. Required multiple mixer controls to be enabled:

1. **Main routing control:** `WSA_CODEC_DMA_RX_0 Audio Mixer MultiMedia2` - Status: OFF

2. **WSA RX Mux controls:** Set to 'ZERO' instead of 'AIF1_PB'

3. **WSA RX Input routing:** Set to 'ZERO' instead of 'RX0'/'RX1'

4. **Speaker component switches:** All disabled (BOOST, COMP, DAC, PBR, VISENSE)

5. **WSA Compressor switches:** OFF

**Critical Discovery:** The laptop has TWO WSA884x chips (WSA and WSA2), each driving 2 speakers:
- WSA chip: Controls TweeterLeft and WooferLeft
- WSA2 chip: Controls TweeterRight and WooferRight

ALL controls must be enabled for BOTH chips!

**Solution:** Created comprehensive script to enable all audio path controls for both WSA chips.

**Result:** Audio now works! But with distortion issues...

---

### Step 7: Fix Audio Distortion

**Issue:** Audio was overdriven/distorted at high frequencies. Login sound was distorted.

**Root Cause:** Speaker volumes set to 100% (37.5dB) which was too high, causing clipping.

**Solution:**
Reduced speaker volumes to 70% (24dB):
```bash
for spk in TweeterLeft TweeterRight WooferLeft WooferRight; do
  amixer -c 0 sset "$spk PA" 70%
done
alsactl store
```

**Result:** Audio quality improved, no more distortion.

---

### Step 8: Persistent Configuration (Boot Issue)

**Issue:** The "backend DAI" error happens during card probe at boot. The mixer routing MUST be configured BEFORE the card initializes, but we can only set it AFTER the card is up. This is a chicken-and-egg problem.

**Failed Attempt:** Tried to reload the audio driver after setting mixer controls - card failed to re-initialize.

**Working Solution - Multi-Part Approach:**

1. **Save ALSA state for boot restore:**
```bash
sudo alsactl store
```

2. **Created audio fix script:** `/usr/local/bin/xps-audio-fix.sh`

3. **Created systemd user service:** `~/.config/systemd/user/xps-audio-fix.service`

**Result after reboot:** Audio works! But becomes unstable after a few seconds...

---

### Step 9: Fix Audio Stability (Routing Reset Issue)

**Issue:** Audio would work for a few seconds then stop. Investigation showed mixer routing getting reset (Front Right channel turning off).

**Root Cause:** Something (possibly PulseAudio compatibility layer or UCM EnableSequence failures) was periodically resetting mixer controls.

**Solution - Monitoring Service:**

Created background service `/usr/local/bin/xps-audio-monitor.sh` that:
- Checks audio routing every 5 seconds
- Automatically re-enables routing if it gets disabled
- Runs as systemd user service

**Result:** Audio now stable and working!

---

## Final Working Configuration

### Files Created/Modified:

1. **Module configuration:** `/etc/modprobe.d/x1e-audio.conf`

2. **Firmware:** `/lib/firmware/qcom/x1e80100/X1E80100-Dell-XPS-13-9345-tplg.bin`

3. **UCM configuration:**
   - `/usr/share/alsa/ucm2/X1E80100DellXPS/X1E80100DellXPS.conf`
   - `/usr/share/alsa/ucm2/X1E80100DellXPS/HiFi.conf`
   - `/usr/share/alsa/ucm2/Qualcomm/x1e80100/*` (updated files)

4. **WirePlumber configuration:**
   - `~/.config/wireplumber/wireplumber.conf.d/51-alsa-use-ucm.conf`
   - `~/.config/wireplumber/wireplumber.conf.d/52-alsa-fix-channels.conf`

5. **Audio fix scripts:**
   - `/usr/local/bin/xps-audio-fix.sh`
   - `/usr/local/bin/xps-audio-monitor.sh`

6. **Systemd services:**
   - `~/.config/systemd/user/xps-audio-fix.service`
   - `~/.config/systemd/user/xps-audio-monitor.service`

7. **ALSA state:** `/var/lib/alsa/asound.state`

### Audio Signal Path:

```
Application (e.g., Browser)
    ↓
PipeWire (with 4-channel output)
    ↓
ALSA MultiMedia2 Playback (hw:0,1)
    ↓
WSA_CODEC_DMA_RX_0 Audio Mixer [MUST BE ON]
    ↓
    ├─→ WSA RX0 MUX (set to AIF1_PB)
    │       ↓
    │   WSA_RX0 INP0 (set to RX0)
    │       ↓
    │   WSA_COMP1 [ON]
    │       ↓
    │   ├─→ TweeterLeft: BOOST→COMP→DAC→PBR→VISENSE→PA (70% volume)
    │   └─→ WooferLeft: BOOST→COMP→DAC→PBR→VISENSE→PA (70% volume)
    │
    └─→ WSA RX1 MUX (set to AIF1_PB)
            ↓
        WSA_RX1 INP0 (set to RX1)
            ↓
        WSA_COMP2 [ON]
            ↓
        (Routes to WSA2 chip)
            ↓
        WSA2 RX0 MUX (set to AIF1_PB)
            ↓
        WSA2_RX0 INP0 (set to RX0)
            ↓
        WSA2_COMP1 [ON]
            ↓
        ├─→ TweeterRight: BOOST→COMP→DAC→PBR→VISENSE→PA (70% volume)
        └─→ WooferRight: BOOST→COMP→DAC→PBR→VISENSE→PA (70% volume)
```

### Boot Sequence:

1. Kernel loads with `snd_soc_x1e80100` module (with `i_accept_the_danger=1`)
2. Audio topology firmware loaded from `/lib/firmware/qcom/x1e80100/`
3. ALSA card initializes (may show "backend DAI" error initially)
4. `alsa-restore.service` restores mixer state from `/var/lib/alsa/asound.state`
5. PipeWire starts
6. WirePlumber starts (configured to use UCM, not ACP)
7. `xps-audio-fix.service` runs to ensure all routing is correct
8. `xps-audio-monitor.service` starts background monitoring

---

## Why Each Component Was Necessary

### 1. Experimental Driver Flag
Without `i_accept_the_danger=1`, the audio driver refuses to load because Dell XPS 9345 support is still being actively developed upstream.

### 2. Topology Firmware
The topology file defines the DSP (Digital Signal Processor) configuration, including:
- Audio processing graphs
- Mixer routing definitions
- Widget connections

Without it, the audio subsystem doesn't know how to route audio.

### 3. UCM Configuration
UCM defines:
- Which PCM devices to use for playback/capture
- Mixer control sequences for enabling audio
- Device profiles (HiFi, Voice, etc.)

The generic ALSA configuration doesn't know about the specific hardware layout.

### 4. WirePlumber UCM Enforcement
By default, WirePlumber uses ACP (ALSA Card Profiles) which doesn't understand the complex Qualcomm AudioReach architecture. UCM is required for proper Qualcomm audio handling.

### 5. Channel Count Fix
The default detection returns 64 channels (possibly due to DSP capabilities), but the actual hardware path supports 4 channels. Without fixing this, audio streams fail to start.

### 6. Complex Mixer Routing
The Qualcomm AudioReach architecture uses a graph-based audio routing system with multiple stages:
- **Main mixer:** Connects MultiMedia2 to codec DMA
- **Muxes:** Select audio input source (AIF1_PB = Audio Interface 1 Playback)
- **Input routing:** Routes RX streams to correct outputs
- **Component switches:** Enable DAC, compressor, boost, protection circuits
- **Dual WSA chips:** Each chip needs independent configuration

All these MUST be enabled or audio won't flow.

### 7. Volume Reduction
The speaker amplifiers can output up to 37.5dB, but this causes clipping/distortion with most content. 70% (24dB) provides clean audio.

### 8. Monitoring Service
Some process (possibly compatibility code in ALSA/PipeWire) occasionally resets mixer controls. The monitor detects and fixes this automatically.

---

## Known Limitations

1. **Experimental Support:** Audio driver is marked experimental - expect potential bugs
2. **UCM Workarounds:** Had to hardcode card ID due to variable scoping issues
3. **Mixer Reset Issue:** Unknown cause of periodic mixer resets (hence monitoring service)
4. **Backend DAI Warning:** Boot-time warning still appears but doesn't affect functionality after configuration is applied
5. **No Headphone Jack Support:** This configuration focuses on speakers; headphone routing not tested

---

## Troubleshooting

### Audio stops working:
```bash
/usr/local/bin/xps-audio-fix.sh
```

### Check if monitoring service is running:
```bash
systemctl --user status xps-audio-monitor.service
```

### Check audio routing status:
```bash
amixer -c 0 sget 'WSA_CODEC_DMA_RX_0 Audio Mixer MultiMedia2'
```
Both Front Left and Front Right should show `[on]`

### Check if sound card is detected:
```bash
aplay -l
```

### View audio topology errors:
```bash
sudo dmesg | grep -i "audio\|wsa\|tplg"
```

### Check PipeWire status:
```bash
wpctl status
```

### Manually fix routing if needed:
```bash
amixer -c 0 sset 'WSA_CODEC_DMA_RX_0 Audio Mixer MultiMedia2' on,on
amixer -c 0 sset 'WSA WSA RX0 MUX' 'AIF1_PB'
amixer -c 0 sset 'WSA WSA RX1 MUX' 'AIF1_PB'
amixer -c 0 sset 'WSA2 WSA RX0 MUX' 'AIF1_PB'
amixer -c 0 sset 'WSA2 WSA RX1 MUX' 'AIF1_PB'
```

---

## Technical Details

### Audio Architecture:
- **Kernel Driver:** `snd_soc_x1e80100` (ASoC - ALSA System on Chip)
- **DSP:** Qualcomm AudioReach running on ADSP (Audio DSP)
- **Codec:** Qualcomm LPASS (Low Power Audio Subsystem)
- **Amplifiers:** 2x WSA884x (Qualcomm SoundWire amplifiers)
- **Interface:** SoundWire (not I2C or I2S)
- **Audio Framework:** PipeWire → ALSA → ASoC → SoundWire → WSA884x

### Mixer Control Naming Convention:
- **WSA/WSA2:** Refers to first/second WSA884x chip
- **RX0/RX1:** Receive channels (from DSP perspective)
- **MUX:** Multiplexer (audio source selector)
- **INP0:** Input routing selector
- **COMP:** Compressor/limiter
- **BOOST:** Speaker boost circuit
- **DAC:** Digital-to-Analog Converter
- **PBR:** Playback (enable switch)
- **VISENSE:** VI-Sense (voltage/current sensing for speaker protection)
- **PA:** Power Amplifier volume

---

## Future Improvements

1. **Proper UCM EnableSequence:** Fix UCM so mixer routing happens automatically at card probe
2. **Eliminate Monitor Service:** Once UCM is working correctly, monitoring shouldn't be needed
3. **Headphone Support:** Add configuration for 3.5mm jack and USB-C audio
4. **Upstream Integration:** Get these fixes merged into upstream alsa-ucm-conf
5. **Dynamic Volume Limiting:** Implement proper speaker protection via VISENSE
6. **Profile Switching:** Support different audio profiles (Music, Voice, Movies)

---

## References

- Kernel driver: `drivers/sound/soc/qcom/x1e80100.c`
- AudioReach topology: https://github.com/linux-msm/audioreach-topology
- ALSA UCM: https://github.com/alsa-project/alsa-ucm-conf
- Dell XPS 9345 patches: https://github.com/alexVinarskis/linux-x1e80100-dell-tributo
- Qualcomm WSA884x driver: `drivers/sound/soc/codecs/wsa884x.c`

---

## Credits

This configuration was developed through systematic debugging and analysis of:
- Kernel driver source code
- ALSA/ASoC debug outputs
- UCM configuration examples from other Qualcomm devices
- Community contributions from linux-msm and alsa-project

---

**Document created:** 2025-10-05
**System:** Dell XPS 13 9345, Ubuntu Linux, Kernel 6.14.0-32-qcom-x1e
**Status:** Working audio with monitoring service maintaining stability

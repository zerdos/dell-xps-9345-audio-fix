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

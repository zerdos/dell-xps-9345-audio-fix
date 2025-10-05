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

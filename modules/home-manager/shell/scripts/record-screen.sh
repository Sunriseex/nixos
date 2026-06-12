#!/bin/sh
file="$HOME/Videos/$(date +%Y-%m-%d_%H-%M-%S).mp4"
notify-send " Recording" "Started — saving to $(basename "$file")"
wf-recorder -o HDMI-A-1 -f "$file"
notify-send " Recording" "Finished — saved to $(basename "$file")"

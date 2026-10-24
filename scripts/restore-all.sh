#!/bin/bash
# Bring back every window hidden from the current workspace (by minimize.sh or
# minimize-others.sh), plus any on the bare legacy special:minimized, which the
# bar widget lists on every workspace. Focus stays where it is.

set -euo pipefail

ws=$(hyprctl -j activeworkspace | jq -r '.name')
[[ -n $ws && $ws != null ]] || exit 0

hyprctl -j clients | jq -r --arg ws "$ws" \
  '.[] | select(.workspace.name == "special:minimized-" + $ws or .workspace.name == "special:minimized") | .address' |
  while read -r addr; do
    hyprctl dispatch "hl.dsp.window.move({ window = \"address:$addr\", workspace = \"$ws\", follow = false })" >/dev/null
  done

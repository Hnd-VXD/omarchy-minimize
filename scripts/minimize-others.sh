#!/bin/bash
# Hide every window on the current workspace except the focused one, the same
# way minimize.sh hides one (special:minimized-<workspace>), so the focused
# window gets the whole workspace and the rest wait in the bar widget.

set -euo pipefail

ws=$(hyprctl -j activeworkspace | jq -r '.name')
[[ -n $ws && $ws != null ]] || exit 0

active=$(hyprctl -j activewindow | jq -r '.address // empty')
[[ -n $active ]] || exit 0

hyprctl -j clients | jq -r --arg ws "$ws" --arg active "$active" \
  '.[] | select(.workspace.name == $ws and .address != $active) | .address' |
  while read -r addr; do
    hyprctl dispatch "hl.dsp.window.move({ window = \"address:$addr\", workspace = \"special:minimized-$ws\", follow = false })" >/dev/null
  done

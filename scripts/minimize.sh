#!/bin/bash
# Hide the focused window on a per-workspace hidden workspace
# (special:minimized-<workspace>), so the bar widget can list it only on the
# workspace it came from.

set -euo pipefail

ws=$(hyprctl -j activeworkspace | jq -r '.name')
[[ -n $ws && $ws != null ]] || exit 0

hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:minimized-$ws\", follow = false })" >/dev/null

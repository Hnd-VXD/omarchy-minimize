#!/bin/bash
# Add (or with --remove, take out) this plugin's keybindings in
# ~/.config/hypr/bindings.lua. The bindings live in one marked block, so
# running it again replaces the block instead of adding a second copy.

set -euo pipefail

bindings="${HYPR_BINDINGS:-$HOME/.config/hypr/bindings.lua}"
scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
begin="-- >>> io.github.hnd-vxd.minimize keybindings >>>"
end="-- <<< io.github.hnd-vxd.minimize keybindings <<<"

[[ -f $bindings ]] || { echo "Not found: $bindings" >&2; exit 1; }

# Drop an existing block, if any.
tmp=$(mktemp)
awk -v b="$begin" -v e="$end" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$bindings" >"$tmp"

if [[ ${1:-} == --remove ]]; then
  cat "$tmp" >"$bindings"
  rm -f "$tmp"
  echo "Removed Minimized Windows keybindings from $bindings"
  hyprctl reload >/dev/null 2>&1 || true
  exit 0
fi

cat >>"$tmp" <<EOF

$begin
-- SUPER + click binds below fire only when the mouse doesn't move; dragging
-- past drag_threshold pixels still moves (left) or resizes (right) windows.
hl.config({ binds = { drag_threshold = 10 } })
o.bind("SUPER + H", "Minimize window", "bash $scripts/minimize.sh")
o.bind("SUPER + SHIFT + H", "Minimize other windows", "bash $scripts/minimize-others.sh")
o.bind("SUPER + ALT + H", "Restore minimized windows", "bash $scripts/restore-all.sh")
o.bind("SUPER + mouse:273", "Minimize window (click)", "bash $scripts/minimize.sh", { click = true })
o.bind("SUPER + mouse:272", "Minimize other windows (click)", "bash $scripts/minimize-others.sh", { click = true })
$end
EOF

cat "$tmp" >"$bindings"
rm -f "$tmp"
echo "Added Minimized Windows keybindings to $bindings"
hyprctl reload >/dev/null 2>&1 || true

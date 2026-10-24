-- Minimized Windows keybindings for Hyprland (Omarchy).
--
-- Omarchy plugins can't add keybindings themselves. Either run
--   bash ~/.config/omarchy/plugins/io.github.hnd-vxd.minimize/scripts/install-keybindings.sh
-- or paste the lines below into ~/.config/hypr/bindings.lua yourself.
--
--   SUPER + H              Minimize the focused window
--   SUPER + SHIFT + H      Minimize every other window on the workspace
--   SUPER + ALT + H        Restore every window minimized from the workspace
--   SUPER + right-click    Minimize the window under the cursor
--   SUPER + left-click     Minimize every other window
--
-- The mouse bindings fire only on a click without movement. Dragging past
-- drag_threshold pixels still moves (left) or resizes (right) windows.

hl.config({ binds = { drag_threshold = 10 } })

o.bind("SUPER + H", "Minimize window", "bash $HOME/.config/omarchy/plugins/io.github.hnd-vxd.minimize/scripts/minimize.sh")
o.bind("SUPER + SHIFT + H", "Minimize other windows", "bash $HOME/.config/omarchy/plugins/io.github.hnd-vxd.minimize/scripts/minimize-others.sh")
o.bind("SUPER + ALT + H", "Restore minimized windows", "bash $HOME/.config/omarchy/plugins/io.github.hnd-vxd.minimize/scripts/restore-all.sh")
o.bind("SUPER + mouse:273", "Minimize window (click)", "bash $HOME/.config/omarchy/plugins/io.github.hnd-vxd.minimize/scripts/minimize.sh", { click = true })
o.bind("SUPER + mouse:272", "Minimize other windows (click)", "bash $HOME/.config/omarchy/plugins/io.github.hnd-vxd.minimize/scripts/minimize-others.sh", { click = true })

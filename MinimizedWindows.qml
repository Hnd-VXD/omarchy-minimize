import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Minimized windows in the Omarchy bar.
//
// SUPER+H (in ~/.config/hypr/bindings.lua, via scripts/minimize.sh) parks the
// focused window on the hidden workspace `special:minimized-<workspace>`. This
// widget lists the windows parked from the current workspace:
//   - the first `maxButtons` apps get a button each. A single window restores
//     on click; an app with several ("Foot (3)") opens a list.
//   - the remaining apps go into a "More (N)" button opening a list of their
//     windows, grouped by app.
// In lists and on buttons, left-click restores, right-click closes. List rows
// also get an x button on the right that closes the window.
BarWidget {
  id: root

  readonly property string hiddenWorkspace: "special:minimized"
  readonly property string moreGroup: "__more__"
  readonly property int maxButtons: 3
  readonly property int maxLabel: 18
  readonly property int maxTitle: 48

  // Terminal apps that run inside a plain terminal window (app id "foot")
  // get their own button, recognized by the window title they set.
  readonly property var titleApps: [
    { pattern: /^Yazi(:|$)/, name: "Yazi" }
  ]

  function titleAppName(title) {
    for (var i = 0; i < titleApps.length; i++)
      if (titleApps[i].pattern.test(title)) return titleApps[i].name
    return ""
  }

  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var windows: []    // [{ address, name, title }]
  property var groups: []     // [{ name, windows: [...] }]
  property var buttons: []    // what the bar shows
  property bool popupOpen: false
  property string popupGroup: ""   // an app name, or moreGroup for the overflow
  property Item popupAnchor: null

  function dispatch(expr) { Util.execArgv(["hyprctl", "dispatch", expr]) }

  function currentWorkspace() {
    var monitor = Hyprland.focusedMonitor
    var ws = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : ""
    return ws ? String(ws) : "1"
  }

  // Move first, then focus, in sequence: focusing a window that is still on
  // the hidden workspace would open that workspace over the screen.
  function restore(addr) {
    Util.execArgv(["sh", "-c", 'hyprctl dispatch "$1" && hyprctl dispatch "$2"', "sh",
      'hl.dsp.window.move({ window = "address:' + addr + '", workspace = "' + currentWorkspace() + '" })',
      'hl.dsp.focus({ window = "address:' + addr + '" })'])
  }

  function closeWindow(addr) {
    dispatch('hl.dsp.window.close({ window = "address:' + addr + '" })')
  }

  // Called by PopupCard on an outside click.
  function close() { popupOpen = false }

  // When the list was last closed by a click outside it (see listGrab).
  property double grabClosedAt: 0

  function togglePopup(group, anchor) {
    // A click on this list's own button closes it through the grab first;
    // don't reopen it on the same click.
    if (!popupOpen && popupGroup === group && Date.now() - grabClosedAt < 300) return
    if (popupOpen && popupGroup === group) {
      popupOpen = false
      return
    }
    popupGroup = group
    popupAnchor = anchor
    popupOpen = true
  }

  function shorten(text, max) {
    return text.length > max ? text.slice(0, max - 1) + "…" : text
  }

  function appId(t) {
    if (t.wayland && t.wayland.appId) return String(t.wayland.appId)
    var ipc = t.lastIpcObject
    return ipc && ipc["class"] ? String(ipc["class"]) : ""
  }

  // Friendly app name: the desktop entry's name when one matches, otherwise
  // the app id's last segment, capitalized ("org.gnome.Nautilus" -> "Nautilus").
  function appName(id) {
    if (!id) return "Window"
    if (typeof DesktopEntries !== "undefined" && DesktopEntries.heuristicLookup) {
      var entry = DesktopEntries.heuristicLookup(id)
      if (entry && entry.name) return String(entry.name)
    }
    var tail = id.split(".").pop()
    return tail.charAt(0).toUpperCase() + tail.slice(1)
  }

  property string lastWorkspace: ""

  function refresh() {
    var list = []
    var current = currentWorkspace()

    // An open list belongs to the workspace it was opened on.
    if (current !== lastWorkspace) {
      lastWorkspace = current
      popupOpen = false
    }
    var tops = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < tops.length; i++) {
      var t = tops[i]
      if (!t || !t.workspace) continue
      var ws = String(t.workspace.name)
      // Windows hidden from this workspace; the bare legacy name shows everywhere.
      if (ws !== hiddenWorkspace + "-" + current && ws !== hiddenWorkspace) continue
      var addr = String(t.address || "")
      if (!addr) continue
      if (addr.indexOf("0x") !== 0) addr = "0x" + addr
      var name = titleAppName(String(t.title || "")) || appName(appId(t))
      list.push({ address: addr, name: name, title: String(t.title || name) })
    }

    // Group by app, in order of first appearance.
    var byName = ({})
    var grouped = []
    for (var j = 0; j < list.length; j++) {
      var w = list[j]
      if (!byName[w.name]) {
        byName[w.name] = { name: w.name, windows: [] }
        grouped.push(byName[w.name])
      }
      byName[w.name].windows.push(w)
    }

    var shown = []
    var overflow = 0
    for (var k = 0; k < grouped.length; k++) {
      var g = grouped[k]
      g.overflow = k >= maxButtons
      if (g.overflow) {
        overflow += g.windows.length
        continue
      }
      var single = g.windows.length === 1
      shown.push({
        kind: single ? "window" : "group",
        label: single ? g.name : g.name + " (" + g.windows.length + ")",
        group: g.name,
        address: single ? g.windows[0].address : "",
        title: single ? g.windows[0].title : g.windows.length + " windows"
      })
    }
    if (overflow > 0)
      shown.push({ kind: "more", label: "More (" + overflow + ")", group: moreGroup, address: "" })

    // Only reassign when something changed, so open popups don't rebuild.
    if (JSON.stringify(list) !== JSON.stringify(root.windows)) {
      root.windows = list
      root.groups = grouped
      root.buttons = shown
    }
    // Close an open list once its last window is gone (e.g. closed with x).
    if (root.popupOpen) {
      var more = root.popupGroup === moreGroup
      var left = grouped.some(function(g) { return more ? g.overflow : g.name === root.popupGroup })
      if (!left) root.popupOpen = false
    }
  }

  // Rows for the popup: for "More", a header per overflow app, then the
  // windows. Titles repeated within an app get a number.
  function popupRows() {
    var rows = []
    var more = popupGroup === moreGroup
    for (var i = 0; i < groups.length; i++) {
      var g = groups[i]
      if (more ? !g.overflow : g.name !== popupGroup) continue
      if (more) rows.push({ kind: "header", text: g.name + (g.windows.length > 1 ? " (" + g.windows.length + ")" : "") })
      var seen = ({})
      var counts = ({})
      for (var c = 0; c < g.windows.length; c++) counts[g.windows[c].title] = (counts[g.windows[c].title] || 0) + 1
      for (var j = 0; j < g.windows.length; j++) {
        var w = g.windows[j]
        var text = w.title
        if (counts[text] > 1) {
          seen[text] = (seen[text] || 0) + 1
          text += " (" + seen[text] + ")"
        }
        rows.push({ kind: "window", text: shorten(text, maxTitle), address: w.address })
      }
    }
    return rows
  }

  implicitWidth: row.implicitWidth
  implicitHeight: barSize
  visible: windows.length > 0

  Timer {
    interval: 300
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
  Component.onCompleted: root.refresh()

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    // The minimized group is wrapped in braces: { Foot (3) Files More (2) }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "{"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Repeater {
      model: root.buttons
      // Each button but the last is followed by a comma: { Foot, Files }
      delegate: Row {
        id: item
        required property var modelData
        required property int index
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        spacing: 0

        WidgetButton {
          id: button
          anchors.verticalCenter: parent.verticalCenter
          bar: root.bar
          text: root.shorten(item.modelData.label, root.maxLabel)
          tooltipText: item.modelData.kind === "window"
            ? item.modelData.title + " (click: restore, right-click: close)"
            : "Click to list windows"

          onPressed: function(mouseButton) {
            if (item.modelData.kind === "window") {
              if (mouseButton === Qt.RightButton) root.closeWindow(item.modelData.address)
              else root.restore(item.modelData.address)
            } else {
              root.togglePopup(item.modelData.group, button)
            }
          }
        }

        Text {
          visible: item.index < root.buttons.length - 1
          anchors.verticalCenter: parent.verticalCenter
          text: ","
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "}"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  // PopupCard's own outside-click grab also covers the bar, so clicks on the
  // bar leave the list open. Turn that grab off ("hover") and use one that
  // covers only the list: any click outside it, the bar included, closes it.
  HyprlandFocusGrab {
    id: listGrab
    active: root.popupOpen
    windows: [popup]
    onCleared: {
      root.grabClosedAt = Date.now()
      root.popupOpen = false
    }
  }

  PopupCard {
    id: popup
    anchorItem: root.popupAnchor || root
    owner: root
    bar: root.bar
    open: root.popupOpen
    triggerMode: "hover"
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(listColumn.implicitHeight)

    Column {
      id: listColumn
      anchors.fill: parent
      spacing: Style.space(2)

      Text {
        text: root.popupGroup === root.moreGroup ? "More minimized windows" : root.popupGroup
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        bottomPadding: Style.space(6)
      }

      Repeater {
        model: root.popupOpen ? root.popupRows() : []
        delegate: Item {
          id: entry
          required property var modelData
          width: listColumn.width
          implicitHeight: modelData.kind === "header" ? 24 : 28

          // A HoverHandler, not the MouseArea, so the row stays highlighted
          // while the pointer is on its close button.
          HoverHandler { id: rowHover }

          Rectangle {
            anchors.fill: parent
            radius: 6
            visible: entry.modelData.kind === "window" && rowHover.hovered
            color: Util.alpha(root.foreground, 0.1)
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: entry.modelData.kind === "header" ? 0 : Style.space(10)
            anchors.rightMargin: entry.modelData.kind === "header" ? 0 : closeButton.width + Style.space(8)
            text: entry.modelData.text
            elide: Text.ElideRight
            color: entry.modelData.kind === "header" ? Qt.darker(root.foreground, 1.4) : root.foreground
            font.family: root.fontFamily
            font.pixelSize: entry.modelData.kind === "header" ? Style.font.caption : Style.font.bodySmall
            font.bold: entry.modelData.kind === "header"
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            enabled: entry.modelData.kind === "window"
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
              // Close the popup last: it empties the Repeater's model and
              // destroys this row, after which `root` no longer resolves here.
              if (mouse.button === Qt.RightButton) {
                root.closeWindow(entry.modelData.address)
              } else {
                root.restore(entry.modelData.address)
                root.popupOpen = false
              }
            }
          }

          // Declared after rowMouse so it sits on top and takes its own clicks.
          PanelActionButton {
            id: closeButton
            visible: entry.modelData.kind === "window"
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Style.space(3)
            size: Style.space(22)
            iconText: "x"
            tooltipText: "Close window"
            foreground: root.foreground
            hoverColor: Commons.Color.urgent
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            onClicked: root.closeWindow(entry.modelData.address)
          }
        }
      }
    }
  }
}

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.modules.common

Scope {
  id: root
  FontLoader { id: materialIcons; source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf" }
  property bool opened: false
  property real revealProgress: 0
  property int selectedAction: 0
  readonly property var actions: [
    { label: "Lock", icon: "󰌾", command: ["qs", "-c", "comic", "ipc", "call", "lockscreen", "lock"] },
    { label: "Sleep", icon: "󰤄", command: ["systemctl", "suspend"] },
    { label: "Restart", icon: "󰜉", command: ["systemctl", "reboot"] },
    { label: "Power off", icon: "󰐥", command: ["systemctl", "poweroff"] },
    { label: "Log out", icon: "󰍃", command: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"] }
  ]

  function activateSelected(): void {
    opened = false;
    Quickshell.execDetached(actions[selectedAction].command);
  }
  onOpenedChanged: revealProgress = opened ? 1 : 0

  Behavior on revealProgress {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  IpcHandler {
    target: "powermenu"
    function toggle(): void { root.opened = !root.opened; }
    function open(): void { root.opened = true; }
    function close(): void { root.opened = false; }
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.opened || root.revealProgress > 0
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "comic-powermenu"
      WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      anchors { top: true; left: true; right: true; bottom: true }

      TapHandler {
        onTapped: eventPoint => {
          const local = powerPanel.mapFromItem(powerPanel.parent, eventPoint.position);
          if (!powerPanel.contains(local))
            root.opened = false;
        }
      }

      Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.opened = false }
      Shortcut { sequence: "Left"; enabled: root.opened; onActivated: root.selectedAction = (root.selectedAction + root.actions.length - 1) % root.actions.length }
      Shortcut { sequence: "Right"; enabled: root.opened; onActivated: root.selectedAction = (root.selectedAction + 1) % root.actions.length }
      Shortcut { sequence: "Return"; enabled: root.opened; onActivated: root.activateSelected() }

      Rectangle {
        id: powerPanel
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 10 }
        width: 120 + 430 * root.revealProgress
        height: 36 + 94 * root.revealProgress
        radius: 18 + 4 * root.revealProgress
        topLeftRadius: 0
        topRightRadius: 0
        color: Colors.md3.surface
        clip: true

        TapHandler {}


        Row {
          anchors.centerIn: parent
          spacing: 10
          opacity: Math.max(0, (root.revealProgress - 0.25) / 0.75)

          Repeater {
            model: root.actions

            Rectangle {
              required property var modelData
              required property int index
              width: 94
              height: 82
              radius: 16
              color: actionHover.hovered || index === root.selectedAction ? (modelData.label === "Power off" ? Colors.md3.error_container : Colors.md3.primary_container) : Colors.md3.surface_container
              scale: actionHover.hovered ? 1.04 : 1
              Behavior on color { ColorAnimation { duration: 120 } }
              Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              Column {
                anchors.centerIn: parent
                spacing: 6
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: modelData.label === "Power off" && actionHover.hovered ? Colors.md3.on_error_container : Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 25 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: Colors.md3.on_surface; font.pixelSize: 11; font.bold: true }
              }
              HoverHandler { id: actionHover }
              TapHandler { onTapped: { root.opened = false; Quickshell.execDetached(modelData.command); } }
            }
          }
        }
      }

      RoundCorner {
        anchors { top: powerPanel.top; right: powerPanel.left; rightMargin: -1 }
        implicitSize: 14; color: Colors.md3.surface; opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopRight
      }
      RoundCorner {
        anchors { top: powerPanel.top; left: powerPanel.right; leftMargin: -1 }
        implicitSize: 14; color: Colors.md3.surface; opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopLeft
      }
    }
  }
}

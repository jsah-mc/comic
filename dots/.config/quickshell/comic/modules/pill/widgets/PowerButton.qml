import Quickshell
import QtQuick
import qs.modules.common

Rectangle {
  FontLoader { id: materialIcons; source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf" }
  width: 28
  height: 28
  radius: Appearance.radius(14)
  color: buttonHover.hovered ? Colors.md3.error_container : Colors.md3.surface_container_high
  scale: buttonHover.hovered ? 1.08 : 1
  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  Text { anchors.centerIn: parent; text: "󰐥"; color: buttonHover.hovered ? Colors.md3.on_error_container : Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 15 }
  HoverHandler { id: buttonHover }
  TapHandler { onTapped: Quickshell.execDetached(["qs", "-c", "comic", "ipc", "call", "powermenu", "toggle"]) }
}

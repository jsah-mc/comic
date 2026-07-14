pragma Singleton

import QtQuick
import QtCore
import Quickshell

QtObject {
  id: root
  property real cornerRadius: 24

  function applyHyprlandRounding() {
    Quickshell.execDetached([
      "hyprctl", "eval",
      "hl.config({ decoration = { rounding = " + Math.round(cornerRadius) + " } })"
    ]);
  }

  property Timer hyprlandRoundingDebounce: Timer {
    interval: 80
    onTriggered: root.applyHyprlandRounding()
  }

  onCornerRadiusChanged: hyprlandRoundingDebounce.restart()
  Component.onCompleted: hyprlandRoundingDebounce.restart()

  function radius(preferred) {
    return Math.max(0, Math.min(Number(preferred), cornerRadius));
  }

  property Settings persisted: Settings {
    location: "file://" + Quickshell.env("HOME") + "/.local/state/quickshell/appearance.ini"
    category: "ComicAppearance"
    property alias cornerRadius: root.cornerRadius
  }
}

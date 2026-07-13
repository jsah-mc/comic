pragma Singleton

import QtQuick
import QtCore
import Quickshell

QtObject {
  id: root
  property real cornerRadius: 24

  function radius(preferred) {
    return Math.max(0, Math.min(Number(preferred), cornerRadius));
  }

  property Settings persisted: Settings {
    location: "file://" + Quickshell.env("HOME") + "/.local/state/quickshell/appearance.ini"
    category: "ComicAppearance"
    property alias cornerRadius: root.cornerRadius
  }
}

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

Rectangle {
  id: root

  FontLoader {
    id: materialIcons
    source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf"
  }

  property bool wifiEnabled: false
  property bool bluetoothEnabled: false
  property bool vertical: false

  width: trayContent.implicitWidth + 16
  height: trayContent.implicitHeight + (vertical ? 12 : 8)
  radius: Appearance.radius(height / 2)
  color: Colors.md3.surface_container_high

  function refresh() {
    wifiStatus.running = true;
    bluetoothStatus.running = true;
  }

  Grid {
    id: trayContent
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 2
    columnSpacing: 8
    rowSpacing: 6

    Text {
      text: root.wifiEnabled ? "󰤨" : "󰤭"
      color: root.wifiEnabled ? Colors.md3.primary : Colors.md3.on_surface_variant
      font.family: materialIcons.name
      font.pixelSize: 16

      TapHandler {
        onTapped: Quickshell.execDetached(["qs", "-c", "comic", "ipc", "call", "connectivity", "wifi"])
      }
    }

    Text {
      text: root.bluetoothEnabled ? "󰂯" : "󰂲"
      color: root.bluetoothEnabled ? Colors.md3.primary : Colors.md3.on_surface_variant
      font.family: materialIcons.name
      font.pixelSize: 16

      TapHandler {
        onTapped: Quickshell.execDetached(["qs", "-c", "comic", "ipc", "call", "connectivity", "bluetooth"])
      }
    }
  }

  Process {
    id: wifiStatus
    command: ["nmcli", "radio", "wifi"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.wifiEnabled = text.trim() === "enabled" }
  }

  Process {
    id: bluetoothStatus
    command: ["bluetoothctl", "show"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.bluetoothEnabled = text.includes("Powered: yes") }
  }

  Process {
    id: wifiToggle
    onExited: root.refresh()
  }

  Process {
    id: bluetoothToggle
    onExited: root.refresh()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
}

import Quickshell.Io
import QtQuick
import qs.modules.common

Item {
  id: root

  FontLoader {
    id: materialIcons
    source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf"
  }

  property bool available: false
  property bool charging: false
  property int percentage: 0

  function batteryIcon() {
    if (charging)
      return "󰂄";
    if (percentage <= 10)
      return "󰁺";
    if (percentage <= 20)
      return "󰁻";
    if (percentage <= 30)
      return "󰁼";
    if (percentage <= 40)
      return "󰁽";
    if (percentage <= 50)
      return "󰁾";
    if (percentage <= 60)
      return "󰁿";
    if (percentage <= 70)
      return "󰂀";
    if (percentage <= 80)
      return "󰂁";
    if (percentage <= 90)
      return "󰂂";
    return "󰁹";
  }

  visible: available
  implicitWidth: available ? batteryContent.implicitWidth : 0
  implicitHeight: 24

  Row {
    id: batteryContent
    anchors.centerIn: parent
    spacing: 3

    Text {
      text: root.batteryIcon()
      color: root.percentage <= 15 ? Colors.md3.error : Colors.md3.on_surface
      font.family: materialIcons.name
      font.pixelSize: 15
      font.hintingPreference: Font.PreferNoHinting
    }

    Text {
      text: root.percentage + "%"
      color: Colors.md3.on_surface
      font.pixelSize: 12
      font.weight: Font.Medium
    }
  }

  Process {
    id: batteryStatus
    command: ["sh", "-c", "for device in $(upower -e | grep battery); do info=$(upower -i \"$device\"); echo \"$info\" | grep -q 'power supply: *yes' && { echo \"$info\"; exit 0; }; done; exit 1"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const percentageMatch = text.match(/percentage:\s*([0-9]+)%/);
        const stateMatch = text.match(/state:\s*([^\n]+)/);
        root.available = percentageMatch !== null;

        if (percentageMatch)
          root.percentage = Number(percentageMatch[1]);
        if (stateMatch)
          root.charging = stateMatch[1].trim() === "charging";
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: batteryStatus.running = true
  }
}

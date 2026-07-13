import Quickshell.Io
import QtQuick
import qs.modules.common

Item {
  id: root

  implicitWidth: clockText.implicitWidth
  implicitHeight: 24

  Text {
    id: clockText
    anchors.centerIn: parent
    text: root.time
    color: Colors.md3.on_surface
    font.pixelSize: 13
    font.weight: Font.DemiBold
    font.letterSpacing: 0.3
  }

  property string time

  Process {
    id: dateProc
    command: ["date", "+%H:%M"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: root.time = text.trim()
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: dateProc.running = true
  }
}

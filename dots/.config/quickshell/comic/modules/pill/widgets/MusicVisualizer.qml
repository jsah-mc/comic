import Quickshell.Io
import QtQuick
import qs.modules.common

Item {
  id: root

  property bool playing: false
  property var levels: [0, 0, 0, 0, 0, 0]
  readonly property string cavaConfig: Qt.resolvedUrl("../../../scripts/cava_pill.conf").toString().replace("file://", "")

  implicitWidth: playing ? 34 : 0
  implicitHeight: 24
  visible: implicitWidth > 0
  clip: true

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Row {
    anchors.centerIn: parent
    height: 20
    spacing: 2

    Repeater {
      model: 6

      Rectangle {
        required property int index
        anchors.bottom: parent.bottom
        width: 3
        height: Math.max(2, root.levels[index] / 100 * 20)
        radius: Appearance.radius(1.5)
        color: index === 2 ? Colors.md3.secondary : Colors.md3.primary

        Behavior on height {
          NumberAnimation { duration: 90; easing.type: Easing.InOutSine }
        }
      }
    }
  }

  Process {
    id: cavaProcess
    command: ["cava", "-p", root.cavaConfig]
    running: root.playing

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        const values = data.trim().split(";").filter(value => value.length).map(value => Math.max(0, Math.min(100, Number(value))));
        if (values.length >= 6)
          root.levels = values.slice(0, 6);
      }
    }

    onRunningChanged: {
      if (!running)
        root.levels = [0, 0, 0, 0, 0, 0];
    }
  }

  Process {
    id: playbackStatus
    command: ["playerctl", "-a", "status"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.playing = text.split("\n").some(status => status.trim() === "Playing")
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.length > 0)
          root.playing = false;
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      if (!playbackStatus.running)
        playbackStatus.running = true;
    }
  }
}

import Quickshell.Io
import QtQuick
import qs.modules.common

Item {
  id: root

  property bool active: false
  property bool ipcControlled: false
  property real progress: -1
  property int animationFrame: 0

  implicitWidth: active ? 24 : 0
  implicitHeight: 24
  visible: implicitWidth > 0
  clip: true

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  IpcHandler {
    target: "codexProgress"

    function start(): void {
      root.ipcControlled = true;
      root.progress = -1;
      root.active = true;
    }

    function set(percent: int): void {
      root.ipcControlled = true;
      root.progress = Math.max(0, Math.min(1, percent / 100));
      root.active = true;
    }

    function finish(): void {
      root.progress = 1;
      doneAnimation.restart();
      finishTimer.restart();
    }

    function hide(): void {
      root.ipcControlled = false;
      root.active = false;
      root.progress = -1;
    }
  }

  Item {
    id: spriteHolder
    anchors.centerIn: parent
    width: 20
    height: 20
    transformOrigin: Item.Center

    Image {
      anchors.fill: parent
      source: Qt.resolvedUrl("../../../assets/codex/coffee-sprites.png")
      sourceClipRect: Qt.rect((root.progress === 1 ? 4 : root.animationFrame % 4) * 396.6,
                              150, 396.6, 470)
      fillMode: Image.PreserveAspectFit
      smooth: false
      mipmap: false
    }
  }

  SequentialAnimation {
    id: doneAnimation

    ParallelAnimation {
      NumberAnimation {
        target: spriteHolder
        property: "scale"
        from: 0.55
        to: 1.1
        duration: 260
        easing.type: Easing.OutBack
      }
      NumberAnimation {
        target: spriteHolder
        property: "rotation"
        from: -10
        to: 7
        duration: 260
        easing.type: Easing.OutCubic
      }
    }

    ParallelAnimation {
      NumberAnimation {
        target: spriteHolder
        property: "scale"
        to: 1
        duration: 180
        easing.type: Easing.OutBounce
      }
      NumberAnimation {
        target: spriteHolder
        property: "rotation"
        to: 0
        duration: 180
        easing.type: Easing.OutCubic
      }
    }
  }

  Timer {
    interval: 450
    running: root.active && root.progress !== 1
    repeat: true
    onTriggered: root.animationFrame = (root.animationFrame + 1) % 4
  }

  Timer {
    id: finishTimer
    interval: 10000
    onTriggered: {
      root.active = false;
      root.ipcControlled = false;
      root.progress = -1;
    }
  }

  Process {
    id: codexActivity
    // Codex records the lifecycle of every turn in this database. Reading the
    // newest lifecycle event is more reliable than guessing from CPU usage.
    command: ["sh", "-c", "sqlite3 -readonly \"$HOME/.codex/logs_2.sqlite\" \"SELECT CASE WHEN feedback_log_body LIKE '%turn/started%' THEN 'working' ELSE 'idle' END FROM logs WHERE target = 'codex_app_server::outgoing_message' AND (feedback_log_body LIKE '%turn/started%' OR feedback_log_body LIKE '%turn/completed%') ORDER BY id DESC LIMIT 1;\" 2>/dev/null || true"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.ipcControlled)
          return;

        const working = text.trim() === "working";
        if (working) {
          finishTimer.stop();
          root.progress = -1;
          root.active = true;
        } else if (root.active && root.progress !== 1) {
          root.progress = 1;
          doneAnimation.restart();
          finishTimer.restart();
        }
      }
    }
  }

  Timer {
    interval: 750
    running: true
    repeat: true
    onTriggered: {
      if (!codexActivity.running)
        codexActivity.running = true;
    }
  }
}

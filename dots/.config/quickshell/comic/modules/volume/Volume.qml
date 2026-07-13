import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.modules.common

Scope {
  id: root

  property int level: 0
  property bool muted: false
  property bool shown: false
  property real revealProgress: 0

  FontLoader { id: materialIcons; source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf" }

  onShownChanged: revealProgress = shown ? 1 : 0
  Behavior on revealProgress { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

  function showOsd(): void {
    shown = true;
    hideTimer.restart();
  }

  function refresh(): void {
    if (!statusProcess.running) statusProcess.running = true;
  }

  function setVolume(value: int): void {
    const target = Math.max(0, Math.min(150, value));
    level = target;
    commandProcess.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", target + "%"];
    commandProcess.running = true;
    showOsd();
  }

  function changeVolume(delta: int): void {
    setVolume(level + delta);
  }

  function toggleMute(): void {
    muted = !muted;
    commandProcess.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
    commandProcess.running = true;
    showOsd();
  }

  IpcHandler {
    target: "volume"
    function set(percent: int): void { root.setVolume(percent); }
    function up(): void { root.changeVolume(5); }
    function down(): void { root.changeVolume(-5); }
    function adjust(amount: int): void { root.changeVolume(amount); }
    function mute(): void { root.toggleMute(); }
    function display(): void { root.refresh(); root.showOsd(); }
  }

  Process {
    id: commandProcess
    onExited: root.refresh()
  }

  Process {
    id: statusProcess
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const match = text.match(/Volume:\s+([0-9.]+)/);
        if (match) root.level = Math.round(Number(match[1]) * 100);
        root.muted = text.includes("[MUTED]");
      }
    }
  }

  Timer { id: hideTimer; interval: 1600; onTriggered: root.shown = false }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.shown || root.revealProgress > 0
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "comic-volume-osd"
      anchors { top: true; left: true; right: true }
      implicitHeight: 130

      Rectangle {
        id: volumePanel
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 10 }
        width: 120 + 230 * root.revealProgress
        height: 36 + 62 * root.revealProgress
        radius: Appearance.radius(18 + 10 * root.revealProgress)
        topLeftRadius: 0
        topRightRadius: 0
        color: Colors.md3.surface
        clip: true

        Row {
          anchors.fill: parent
          anchors.margins: 18
          spacing: 14
          opacity: Math.max(0, (root.revealProgress - 0.2) / 0.8)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "󰝟" : root.level < 35 ? "󰕿" : root.level < 75 ? "󰖀" : "󰕾"
            color: root.muted ? Colors.md3.error : Colors.md3.primary
            font.family: materialIcons.name
            font.pixelSize: 24
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 54
            spacing: 7

            Row {
              width: parent.width
              Text { width: parent.width - 45; text: root.muted ? "Muted" : "Volume"; color: Colors.md3.on_surface; font.bold: true }
              Text { text: root.level + "%"; color: Colors.md3.on_surface_variant; font.pixelSize: 12 }
            }

            Rectangle {
              width: parent.width
              height: 8
              radius: Appearance.radius(4)
              color: Colors.md3.surface_container_highest
              Rectangle {
                width: parent.width * Math.min(root.level, 150) / 150
                height: parent.height
                radius: Appearance.radius(4)
                color: root.muted ? Colors.md3.error : Colors.md3.primary
                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
              }
            }
          }
        }
      }

      RoundCorner {
        anchors { top: volumePanel.top; right: volumePanel.left; rightMargin: -1 }
        implicitSize: Appearance.radius(14); color: Colors.md3.surface; opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopRight
      }
      RoundCorner {
        anchors { top: volumePanel.top; left: volumePanel.right; leftMargin: -1 }
        implicitSize: Appearance.radius(14); color: Colors.md3.surface; opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopLeft
      }
    }
  }
}

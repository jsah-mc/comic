import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.modules.common

Scope {
  id: root
  property string kind: "brightness"
  property int level: 0
  property bool muted: false
  property bool shown: false
  property real revealProgress: 0

  FontLoader { id: materialIcons; source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf" }
  onShownChanged: revealProgress = shown ? 1 : 0
  Behavior on revealProgress { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

  function showOsd(type: string): void {
    kind = type;
    shown = true;
    hideTimer.restart();
  }

  function setBrightness(value: int): void {
    level = Math.max(1, Math.min(100, value));
    brightnessCommand.command = ["brightnessctl", "-c", "backlight", "set", level + "%"];
    brightnessCommand.running = true;
    showOsd("brightness");
  }

  function setMic(value: int): void {
    level = Math.max(0, Math.min(150, value));
    micCommand.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", level + "%"];
    micCommand.running = true;
    showOsd("microphone");
  }

  function toggleMic(): void {
    muted = !muted;
    micCommand.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"];
    micCommand.running = true;
    showOsd("microphone");
  }

  IpcHandler {
    target: "brightness"
    function set(percent: int): void { root.setBrightness(percent); }
    function up(): void { root.setBrightness(root.level + 5); }
    function down(): void { root.setBrightness(root.level - 5); }
    function adjust(amount: int): void { root.setBrightness(root.level + amount); }
    function display(): void { brightnessStatus.running = true; root.showOsd("brightness"); }
  }

  IpcHandler {
    target: "microphone"
    function set(percent: int): void { root.setMic(percent); }
    function up(): void { root.setMic(root.level + 5); }
    function down(): void { root.setMic(root.level - 5); }
    function adjust(amount: int): void { root.setMic(root.level + amount); }
    function mute(): void { root.toggleMic(); }
    function display(): void { micStatus.running = true; root.showOsd("microphone"); }
  }

  Process { id: brightnessCommand; onExited: brightnessStatus.running = true }
  Process { id: micCommand; onExited: micStatus.running = true }

  Process {
    id: brightnessStatus
    command: ["brightnessctl", "-c", "backlight", "-m"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const match = text.match(/,([0-9]+)%,/);
        if (match) root.level = Number(match[1]);
      }
    }
  }

  Process {
    id: micStatus
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
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
      WlrLayershell.namespace: "comic-controls-osd"
      anchors { top: true; left: true; right: true }
      implicitHeight: 130

      Rectangle {
        id: osdPanel
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 10 }
        width: 120 + 230 * root.revealProgress
        height: 36 + 62 * root.revealProgress
        radius: Appearance.radius(18 + 10 * root.revealProgress)
        topLeftRadius: 0; topRightRadius: 0
        color: Colors.md3.surface
        clip: true

        Row {
          anchors.fill: parent; anchors.margins: 18; spacing: 14
          opacity: Math.max(0, (root.revealProgress - 0.2) / 0.8)
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.kind === "brightness" ? "󰃟" : root.muted ? "󰍭" : "󰍬"
            color: root.muted ? Colors.md3.error : Colors.md3.primary
            font.family: materialIcons.name; font.pixelSize: 24
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 54; spacing: 7
            Row {
              width: parent.width
              Text { width: parent.width - 45; text: root.kind === "brightness" ? "Brightness" : root.muted ? "Microphone muted" : "Microphone"; color: Colors.md3.on_surface; font.bold: true }
              Text { text: root.level + "%"; color: Colors.md3.on_surface_variant; font.pixelSize: 12 }
            }
            Rectangle {
              width: parent.width; height: 8; radius: Appearance.radius(4); color: Colors.md3.surface_container_highest
              Rectangle {
                width: parent.width * Math.min(root.level, root.kind === "brightness" ? 100 : 150) / (root.kind === "brightness" ? 100 : 150)
                height: parent.height; radius: Appearance.radius(4)
                color: root.muted ? Colors.md3.error : Colors.md3.primary
                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
              }
            }
          }
        }
      }

      RoundCorner {
        anchors { top: osdPanel.top; right: osdPanel.left; rightMargin: -1 }
        implicitSize: Appearance.radius(14)
        color: Colors.md3.surface
        opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopRight
      }
      RoundCorner {
        anchors { top: osdPanel.top; left: osdPanel.right; leftMargin: -1 }
        implicitSize: Appearance.radius(14)
        color: Colors.md3.surface
        opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopLeft
      }
    }
  }
}

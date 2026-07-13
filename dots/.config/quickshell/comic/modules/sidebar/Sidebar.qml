import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.common

Scope {
  id: root

  FontLoader {
    id: materialIcons
    source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf"
  }

  property bool wifiEnabled: false
  property bool bluetoothEnabled: false
  property real volume: 0
  property real microphoneVolume: 0
  property bool microphoneMuted: false
  property int brightness: 50
  property bool mediaPlaying: false
  property string mediaTitle: "Nothing playing"
  property string mediaArtist: "Open a media player"
  property real mediaPosition: 0
  property real mediaDuration: 0
  property string mediaPlayer: ""
  property bool mediaSeeking: false
  property bool sidebarVisible: false
  property real revealProgress: 0
  property int frameInset: 10

  onSidebarVisibleChanged: revealProgress = sidebarVisible ? 1 : 0

  Behavior on revealProgress {
    NumberAnimation {
      duration: 240
      easing.type: Easing.OutCubic
    }
  }

  function run(command) {
    Quickshell.execDetached(command);
  }

  function formatTime(seconds: real): string {
    const safe = Math.max(0, Math.floor(seconds));
    const remainder = safe % 60;
    return Math.floor(safe / 60) + ":" + (remainder < 10 ? "0" : "") + remainder;
  }

  component IPhoneSlider: Slider {
    id: control
    property color accentColor: Colors.md3.primary

    background: Rectangle {
      x: control.leftPadding
      y: control.topPadding + control.availableHeight / 2 - height / 2
      width: control.availableWidth
      height: 9
      radius: 4.5
      color: Colors.md3.surface_container_highest

      Rectangle {
        width: control.visualPosition * parent.width
        height: parent.height
        radius: parent.radius
        color: control.accentColor
      }
    }

    handle: Rectangle {
      x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
      y: control.topPadding + control.availableHeight / 2 - height / 2
      width: control.pressed ? 25 : 22
      height: width
      radius: width / 2
      color: "white"
      scale: control.pressed ? 1.08 : 1
      Behavior on width { NumberAnimation { duration: 120 } }
      Behavior on scale { NumberAnimation { duration: 120 } }
    }
  }

  component IOSControlSlider: Item {
    id: control
    property color accentColor: Colors.md3.primary
    property string icon: ""
    property real from: 0
    property real to: 1
    property real value: 0
    property real levelMinimum: 0
    property real levelMaximum: 1
    readonly property real fillLevel: Math.max(0, Math.min(1, (value - levelMinimum) / Math.max(0.001, levelMaximum - levelMinimum)))
    signal moved

    Item {
      id: sliderCapsule
      anchors.fill: parent

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Colors.md3.surface_container_highest
      }

      Item {
        id: fillSource
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: control.fillLevel * parent.width
          color: control.accentColor

          Behavior on width {
            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
          }
        }
      }

      Rectangle {
        id: capsuleMask
        anchors.fill: parent
        radius: height / 2
        color: "white"
        visible: false
        layer.enabled: true
      }

      MultiEffect {
        anchors.fill: parent
        source: fillSource
        maskEnabled: true
        maskSource: capsuleMask
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        text: control.icon
        color: control.fillLevel > 0.18 ? Colors.md3.on_primary : Colors.md3.on_surface
        font.family: materialIcons.name
        font.pixelSize: 20
      }
    }

    MouseArea {
      anchors.fill: parent
      preventStealing: true
      propagateComposedEvents: false

      function updateValue(pointerX: real): void {
        const fraction = Math.max(0, Math.min(1, pointerX / Math.max(1, width)));
        control.value = control.levelMinimum + fraction * (control.levelMaximum - control.levelMinimum);
        control.moved();
      }

      onPressed: mouse => updateValue(mouse.x)
      onPositionChanged: mouse => {
        if (pressed)
          updateValue(mouse.x);
      }
    }
  }

  IpcHandler {
    target: "sidebar"

    function toggle(): void {
      root.sidebarVisible = !root.sidebarVisible;
    }

    function open(): void {
      root.sidebarVisible = true;
    }

    function close(): void {
      root.sidebarVisible = false;
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.sidebarVisible || root.revealProgress > 0
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      TapHandler {
        onTapped: eventPoint => {
          const local = sidebarPanel.mapFromItem(sidebarPanel.parent, eventPoint.position);
          if (!sidebarPanel.contains(local))
            root.sidebarVisible = false;
        }
      }

      Rectangle {
        id: sidebarPanel
        x: (parent.width - width) / 2
        y: 10
        width: 120 + (Math.min(1016, parent.width - root.frameInset * 2) - 120) * root.revealProgress
        height: 36 + (Math.min(480, parent.height - root.frameInset * 2) - 36) * root.revealProgress
        opacity: root.revealProgress
        radius: 18 + 2 * root.revealProgress
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 20
        bottomRightRadius: 20
        color: Colors.md3.surface
        clip: true


        TapHandler {}

        Flickable {
          anchors.fill: parent
          anchors.margins: 14
          contentHeight: content.implicitHeight
          clip: true
          opacity: Math.max(0, (root.revealProgress - 0.25) / 0.75)

          ColumnLayout {
            id: content
            width: parent.width
            spacing: 10

            RowLayout {
              Layout.fillWidth: true

              ColumnLayout {
                spacing: 2

                Text {
                  text: "Control Center"
                  color: Colors.md3.on_surface
                  font.pixelSize: 20
                  font.bold: true
                }

                Text {
                  text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
                  color: Colors.md3.on_surface_variant
                  font.pixelSize: 12
                }
              }

              Item { Layout.fillWidth: true }

              Rectangle {
                width: 36
                height: 36
                radius: 18
                color: powerHover.hovered ? Colors.md3.secondary_container : Colors.md3.surface_container_high

                Text {
                  anchors.centerIn: parent
                  text: "󰐥"
                  color: Colors.md3.on_surface
                  font.family: materialIcons.name
                  font.pixelSize: 18
                }

                HoverHandler { id: powerHover }
                TapHandler { onTapped: Quickshell.execDetached(["qs", "-c", "comic", "ipc", "call", "powermenu", "open"]) }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              Layout.preferredHeight: 102
              spacing: 12

              Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                radius: 18
                color: Colors.md3.primary_container
                Column {
                  anchors.centerIn: parent
                  width: parent.width - 24
                  spacing: 8
                  Row {
                    width: parent.width
                    spacing: 8
                    Text {
                      text: root.mediaPlaying ? "󰏤" : "󰐊"
                      color: Colors.md3.on_primary_container
                      font.family: materialIcons.name
                      font.pixelSize: 25
                      TapHandler {
                        onTapped: {
                          if (root.mediaPlayer.length)
                            root.run(["playerctl", "-p", root.mediaPlayer, "play-pause"]);
                        }
                      }
                    }
                    Column {
                      width: parent.width - 34
                      Text { width: parent.width; text: root.mediaTitle; color: Colors.md3.on_primary_container; font.bold: true; elide: Text.ElideRight }
                      Text { width: parent.width; text: root.mediaArtist; color: Colors.md3.on_primary_container; opacity: 0.75; font.pixelSize: 10; elide: Text.ElideRight }
                    }
                  }
                  IPhoneSlider {
                    width: parent.width
                    height: 24
                    from: 0
                    to: Math.max(1, root.mediaDuration)
                    value: root.mediaPosition
                    accentColor: Colors.md3.on_primary_container
                    enabled: root.mediaDuration > 0
                    onMoved: {
                      root.mediaPosition = value;
                    }
                    onPressedChanged: {
                      root.mediaSeeking = pressed;
                      if (!pressed && root.mediaPlayer.length)
                        root.run(["playerctl", "-p", root.mediaPlayer, "position", String(value)]);
                    }
                  }
                  Row {
                    width: parent.width
                    Text { width: parent.width / 2; text: root.formatTime(root.mediaPosition); color: Colors.md3.on_primary_container; opacity: 0.72; font.pixelSize: 9 }
                    Text { width: parent.width / 2; text: root.formatTime(root.mediaDuration); color: Colors.md3.on_primary_container; opacity: 0.72; font.pixelSize: 9; horizontalAlignment: Text.AlignRight }
                  }
                }
              }

              Rectangle {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                radius: 18
                color: Colors.md3.surface_container
                clip: true
                Column {
                  anchors.fill: parent
                  anchors.leftMargin: 14
                  anchors.rightMargin: 14
                  anchors.topMargin: 10
                  anchors.bottomMargin: 8
                  spacing: 0
                  Text { text: Qt.formatDateTime(new Date(), "MMMM yyyy"); color: Colors.md3.on_surface; font.pixelSize: 16; font.bold: true }
                  Text { text: Qt.formatDateTime(new Date(), "dddd"); color: Colors.md3.on_surface_variant; font.pixelSize: 11 }
                  Text { text: Qt.formatDateTime(new Date(), "dd"); color: Colors.md3.primary; font.pixelSize: 36; font.bold: true; lineHeight: 0.85 }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 18
                color: Colors.md3.surface_container
                Column {
                  anchors.fill: parent
                  anchors.margins: 16
                  spacing: 20
                  Row {
                    width: parent.width
                    Text { width: parent.width - 30; text: "Notifications"; color: Colors.md3.on_surface; font.bold: true }
                    Text { text: "󰂚"; color: Colors.md3.on_surface_variant; font.family: materialIcons.name; font.pixelSize: 18 }
                  }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: "You're all caught up"; color: Colors.md3.on_surface_variant; font.pixelSize: 13 }
                }
              }
            }

            GridLayout {
              Layout.fillWidth: true
              columns: 4
              rowSpacing: 10
              columnSpacing: 10

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 14
                color: root.wifiEnabled ? Colors.md3.primary_container : Colors.md3.surface_container

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 12

                  Text { text: "󰤨"; color: Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 22 }
                  ColumnLayout {
                    Text { text: "Wi-Fi"; color: Colors.md3.on_surface; font.bold: true }
                    Text { text: root.wifiEnabled ? "Enabled" : "Disabled"; color: Colors.md3.on_surface_variant; font.pixelSize: 11 }
                  }
                }

                TapHandler {
                  onTapped: {
                    root.run(["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]);
                    root.wifiEnabled = !root.wifiEnabled;
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 14
                color: root.bluetoothEnabled ? Colors.md3.primary_container : Colors.md3.surface_container

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 12

                  Text { text: "󰂯"; color: Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 22 }
                  ColumnLayout {
                    Text { text: "Bluetooth"; color: Colors.md3.on_surface; font.bold: true }
                    Text { text: root.bluetoothEnabled ? "Enabled" : "Disabled"; color: Colors.md3.on_surface_variant; font.pixelSize: 11 }
                  }
                }

                TapHandler {
                  onTapped: {
                    root.run(["bluetoothctl", "power", root.bluetoothEnabled ? "off" : "on"]);
                    root.bluetoothEnabled = !root.bluetoothEnabled;
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: NotificationState.doNotDisturb ? 24 : 16
                color: NotificationState.doNotDisturb ? Colors.md3.primary_container : (dndHover.hovered ? Colors.md3.surface_container_high : Colors.md3.surface_container)
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                Row {
                  anchors.centerIn: parent
                  spacing: 10
                  Rectangle {
                    width: 36; height: 36; radius: NotificationState.doNotDisturb ? 12 : 18
                    color: NotificationState.doNotDisturb ? Colors.md3.primary : Colors.md3.surface_container_highest
                    Text { anchors.centerIn: parent; text: "󰂛"; color: NotificationState.doNotDisturb ? Colors.md3.on_primary : Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 18 }
                  }
                  Column {
                    Text { text: "Do Not Disturb"; color: NotificationState.doNotDisturb ? Colors.md3.on_primary_container : Colors.md3.on_surface; font.bold: true }
                    Text { text: NotificationState.doNotDisturb ? "Notifications paused" : "Notifications allowed"; color: NotificationState.doNotDisturb ? Colors.md3.on_primary_container : Colors.md3.on_surface_variant; font.pixelSize: 10 }
                  }
                }
                HoverHandler { id: dndHover }
                TapHandler { onTapped: NotificationState.doNotDisturb = !NotificationState.doNotDisturb }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 14
                color: lockHover.hovered ? Colors.md3.surface_container_high : Colors.md3.surface_container
                Row {
                  anchors.centerIn: parent
                  spacing: 6
                  Text { text: "󰌾"; color: Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 18 }
                  Text { text: "Lock Screen"; color: Colors.md3.on_surface }
                }
                HoverHandler { id: lockHover }
                TapHandler { onTapped: Quickshell.execDetached(["qs", "-c", "comic", "ipc", "call", "lockscreen", "lock"]) }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              Layout.preferredHeight: 88
              spacing: 10

              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: Colors.md3.surface_container
                ColumnLayout {
                  anchors.fill: parent; anchors.margins: 10; spacing: 4
                  RowLayout {
                    Layout.fillWidth: true
                    Text { text: "󰕾"; color: Colors.md3.primary; font.family: materialIcons.name; font.pixelSize: 18 }
                    Text { text: "Volume"; color: Colors.md3.on_surface; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(root.volume * 100) + "%"; color: Colors.md3.on_surface_variant; font.pixelSize: 11 }
                  }
                  IOSControlSlider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    from: 1; to: 0; value: root.volume
                    levelMaximum: 1
                    icon: "󰕾"
                    onMoved: { root.volume = value; root.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(value * 100) + "%"]); }
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: root.microphoneMuted ? Colors.md3.error_container : Colors.md3.surface_container
                ColumnLayout {
                  anchors.fill: parent; anchors.margins: 10; spacing: 4
                  RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.microphoneMuted ? "󰍭" : "󰍬"; color: root.microphoneMuted ? Colors.md3.on_error_container : Colors.md3.primary; font.family: materialIcons.name; font.pixelSize: 18 }
                    Text { text: "Microphone"; color: root.microphoneMuted ? Colors.md3.on_error_container : Colors.md3.on_surface; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(root.microphoneVolume * 100) + "%"; color: root.microphoneMuted ? Colors.md3.on_error_container : Colors.md3.on_surface_variant; font.pixelSize: 11 }
                  }
                  IOSControlSlider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    from: 1.5; to: 0; value: root.microphoneVolume
                    levelMaximum: 1.5
                    accentColor: root.microphoneMuted ? Colors.md3.error : Colors.md3.primary
                    icon: root.microphoneMuted ? "󰍭" : "󰍬"
                    onMoved: { root.microphoneVolume = value; root.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", Math.round(value * 100) + "%"]); }
                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]) }
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: Colors.md3.surface_container
                ColumnLayout {
                  anchors.fill: parent; anchors.margins: 10; spacing: 4
                  RowLayout {
                    Layout.fillWidth: true
                    Text { text: "󰃟"; color: Colors.md3.primary; font.family: materialIcons.name; font.pixelSize: 18 }
                    Text { text: "Brightness"; color: Colors.md3.on_surface; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: root.brightness + "%"; color: Colors.md3.on_surface_variant; font.pixelSize: 11 }
                  }
                  IOSControlSlider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    from: 100; to: 1; value: root.brightness
                    levelMinimum: 1
                    levelMaximum: 100
                    icon: "󰃟"
                    onMoved: { root.brightness = Math.round(value); root.run(["brightnessctl", "-c", "backlight", "set", root.brightness + "%"]); }
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 40
              radius: 14
              color: Colors.md3.surface_container

              RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                Text { text: "󰍹"; color: Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 20 }
                ColumnLayout {
                  Text { text: "Display"; color: Colors.md3.on_surface; font.bold: true }
                  Text { text: "Open display settings"; color: Colors.md3.on_surface_variant; font.pixelSize: 11 }
                }
                Item { Layout.fillWidth: true }
                Text { text: "󰅂"; color: Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 24 }
              }

              TapHandler { onTapped: root.run(["wdisplays"]) }
            }
          }
        }
      }

      RoundCorner {
        anchors {
          top: sidebarPanel.top
          right: sidebarPanel.left
          rightMargin: -1
        }
        implicitSize: 14
        color: Colors.md3.surface
        opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopRight
      }

      RoundCorner {
        anchors {
          top: sidebarPanel.top
          left: sidebarPanel.right
          leftMargin: -1
        }
        implicitSize: 14
        color: Colors.md3.surface
        opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopLeft
      }

    }
  }

  Process {
    command: ["nmcli", "radio", "wifi"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.wifiEnabled = text.trim() === "enabled" }
  }

  Process {
    command: ["bluetoothctl", "show"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.bluetoothEnabled = text.includes("Powered: yes") }
  }

  Process {
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const match = text.match(/Volume:\s+([0-9.]+)/);
        if (match)
          root.volume = Number(match[1]);
      }
    }
  }

  Process {
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const match = text.match(/Volume:\s+([0-9.]+)/);
        if (match) root.microphoneVolume = Number(match[1]);
        root.microphoneMuted = text.includes("[MUTED]");
      }
    }
  }

  Process {
    command: ["brightnessctl", "-c", "backlight", "-m"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const match = text.match(/,([0-9]+)%,/);
        if (match) root.brightness = Number(match[1]);
      }
    }
  }

  Process {
    id: mediaStatus
    command: ["playerctl", "-a", "metadata", "--format", "{{playerName}}\t{{status}}\t{{title}}\t{{artist}}\t{{mpris:length}}\t{{position}}"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n").filter(line => line.length);
        const preferred = lines.find(line => line.includes("\tPlaying\t")) || lines[0];
        if (!preferred) {
          root.mediaPlaying = false;
          root.mediaTitle = "Nothing playing";
          root.mediaArtist = "Open a media player";
          root.mediaPosition = 0;
          root.mediaDuration = 0;
          root.mediaPlayer = "";
          return;
        }
        const parts = preferred.split("\t");
        root.mediaPlayer = parts[0] || "";
        root.mediaPlaying = parts[1] === "Playing";
        root.mediaTitle = parts[2] || "Unknown title";
        root.mediaArtist = parts[3] || "Unknown artist";
        root.mediaDuration = Number(parts[4] || 0) / 1000000;
        if (!root.mediaSeeking)
          root.mediaPosition = Number(parts[5] || 0) / 1000000;
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.length > 0) {
          root.mediaPlaying = false;
          root.mediaTitle = "Nothing playing";
          root.mediaArtist = "Open a media player";
          root.mediaPosition = 0;
          root.mediaDuration = 0;
          root.mediaPlayer = "";
        }
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: { if (!mediaStatus.running) mediaStatus.running = true; }
  }
}

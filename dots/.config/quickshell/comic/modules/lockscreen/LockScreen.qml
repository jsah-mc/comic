pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Controls
import qs.modules.common

Scope {
  id: root

  property bool locked: false
  property string pendingPassword: ""
  property string authMessage: ""
  property bool authenticating: false
  property string wallpaperPath: ""
  property bool lockExpanded: false

  FontLoader { id: materialIcons; source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf" }
  SystemClock { id: clock; precision: SystemClock.Seconds }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/quickshell/wallpaper/current.txt"
    preload: true
    watchChanges: true
    onLoaded: root.wallpaperPath = text().trim()
    onFileChanged: reload()
  }

  function lock(): void {
    authMessage = "";
    pendingPassword = "";
    lockExpanded = false;
    locked = true;
  }

  function authenticate(password: string): void {
    if (!password.length || authenticating) return;
    pendingPassword = password;
    authMessage = "Checking…";
    authenticating = true;
    if (!pam.start()) {
      authenticating = false;
      pendingPassword = "";
      authMessage = "Authentication unavailable";
    }
  }

  IpcHandler {
    target: "lockscreen"
    function lock(): void { root.lock(); }
  }

  PamContext {
    id: pam
    config: "login"
    user: Quickshell.env("USER")

    onPamMessage: {
      if (this.responseRequired)
        this.respond(root.pendingPassword);
    }

    onCompleted: result => {
      root.authenticating = false;
      root.pendingPassword = "";
      if (result === PamResult.Success) {
        root.authMessage = "";
        root.locked = false;
      } else {
        root.authMessage = "Incorrect password";
      }
    }

    onError: error => {
      root.authenticating = false;
      root.pendingPassword = "";
      root.authMessage = "Authentication unavailable";
    }
  }

  WlSessionLock {
    id: sessionLock
    locked: root.locked

    WlSessionLockSurface {
      id: lockSurface
      color: Colors.md3.background

      Image {
        anchors.fill: parent
        source: root.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        opacity: 0.22
      }

      Rectangle {
        anchors.fill: parent
        color: Colors.md3.scrim
        opacity: 0.34
      }

      Column {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 0 }
        spacing: 12

        Rectangle {
          id: lockPill
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.lockExpanded ? 390 : 190
          height: root.lockExpanded ? 194 : 40
          radius: root.lockExpanded ? 28 : 20
          topLeftRadius: 0
          topRightRadius: 0
          color: Colors.md3.surface
          clip: false

          Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
          Behavior on radius { NumberAnimation { duration: 180 } }

          Row {
            anchors.centerIn: parent
            spacing: 10
            opacity: root.lockExpanded ? 0 : 1
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 100 } }

            Text {
              text: Qt.formatDateTime(clock.date, "HH:mm")
              color: Colors.md3.on_surface
              font.pixelSize: 14
              font.bold: true
            }

            Text {
              text: "󰌾"
              color: Colors.md3.primary
              font.family: materialIcons.name
              font.pixelSize: 16
            }
          }

          TapHandler {
            enabled: !root.lockExpanded
            onTapped: root.lockExpanded = true
          }

          Column {
            anchors.centerIn: parent
            width: parent.width - 56
            spacing: 8
            opacity: root.lockExpanded ? 1 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Qt.formatDateTime(clock.date, "HH:mm")
              color: Colors.md3.on_surface
              font.pixelSize: 42
              font.weight: Font.Light
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
              color: Colors.md3.on_surface_variant
              font.pixelSize: 13
            }

            TextField {
              id: passwordField
              width: parent.width
              height: 44
              placeholderText: "Password"
              echoMode: TextInput.Password
              color: Colors.md3.on_surface
              placeholderTextColor: Colors.md3.on_surface_variant
              leftPadding: 18
              rightPadding: 48
              focus: root.lockExpanded
              enabled: root.lockExpanded
              onEnabledChanged: {
                if (enabled)
                  Qt.callLater(() => forceActiveFocus());
              }
              background: Rectangle {
                radius: 22
                color: Colors.md3.surface_container_high
              }
              Keys.onReturnPressed: root.authenticate(text)
              Keys.onEnterPressed: root.authenticate(text)

              Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 15 }
                text: root.authenticating ? "󰑐" : "󰌾"
                color: Colors.md3.primary
                font.family: materialIcons.name
                font.pixelSize: 18
                RotationAnimator on rotation { from: 0; to: 360; duration: 850; loops: Animation.Infinite; running: root.authenticating }
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.authMessage
              color: root.authMessage === "Incorrect password" ? Colors.md3.error : Colors.md3.on_surface_variant
              font.pixelSize: 11
            }
          }

          RoundCorner {
            anchors { top: parent.top; right: parent.left; rightMargin: -1 }
            implicitSize: 14
            color: Colors.md3.surface
            corner: RoundCorner.CornerEnum.TopRight
          }

          RoundCorner {
            anchors { top: parent.top; left: parent.right; leftMargin: -1 }
            implicitSize: 14
            color: Colors.md3.surface
            corner: RoundCorner.CornerEnum.TopLeft
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 10
          opacity: root.lockExpanded ? 1 : 0
          visible: opacity > 0

          Behavior on opacity { NumberAnimation { duration: 160 } }

          Repeater {
            model: [
              { icon: "󰤄", command: ["systemctl", "suspend"] },
              { icon: "󰜉", command: ["systemctl", "reboot"] },
              { icon: "󰐥", command: ["systemctl", "poweroff"] }
            ]
            Rectangle {
              required property var modelData
              width: 48; height: 48; radius: 24
              color: powerHover.hovered ? Colors.md3.primary_container : Colors.md3.surface_container_high
              Text { anchors.centerIn: parent; text: modelData.icon; color: Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 20 }
              HoverHandler { id: powerHover }
              TapHandler { onTapped: Quickshell.execDetached(modelData.command) }
            }
          }
        }
      }

    }
  }
}

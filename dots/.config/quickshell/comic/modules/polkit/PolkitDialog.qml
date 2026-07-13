import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs.modules.common

Scope {
  id: root

  property bool opened: false
  property real revealProgress: 0
  readonly property var flow: agent.flow

  function openDialog() {
    opened = true;
    revealProgress = 1;
    Qt.callLater(() => passwordField.forceActiveFocus());
  }

  function closeDialog() {
    opened = false;
    revealProgress = 0;
    passwordField.clear();
  }

  function submit() {
    if (!flow || !flow.isResponseRequired || passwordField.text.length === 0)
      return;
    flow.submit(passwordField.text);
    passwordField.clear();
  }

  PolkitAgent {
    id: agent
    path: "/org/quickshell/ComicPolkitAgent"

    onAuthenticationRequestStarted: root.openDialog()
  }

  Connections {
    target: root.flow
    enabled: root.flow !== null
    ignoreUnknownSignals: true

    function onIsCompletedChanged() {
      if (root.flow?.isCompleted)
        root.closeDialog();
    }

    function onIsCancelledChanged() {
      if (root.flow?.isCancelled)
        root.closeDialog();
    }

    function onIsResponseRequiredChanged() {
      if (root.flow?.isResponseRequired)
        Qt.callLater(() => passwordField.forceActiveFocus());
    }
  }

  Behavior on revealProgress {
    NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
  }

  PanelWindow {
    visible: root.opened || root.revealProgress > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "comic-polkit-agent"

    anchors {
      top: true
      left: true
      right: true
      bottom: true
    }

    mask: Region { item: authPanel }

    Shortcut {
      sequence: "Escape"
      enabled: root.opened
      onActivated: {
        if (root.flow)
          root.flow.cancelAuthenticationRequest();
        root.closeDialog();
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Colors.md3.scrim
      opacity: 0.16 * root.revealProgress
    }

    Rectangle {
      id: authPanel
      anchors {
        top: parent.top
        horizontalCenter: parent.horizontalCenter
        topMargin: 10
      }

      width: 120 + 400 * root.revealProgress
      height: 36 + 224 * root.revealProgress
      opacity: root.revealProgress
      radius: Appearance.radius(18 + 6 * root.revealProgress)
      topLeftRadius: 0
      topRightRadius: 0
      color: Colors.md3.surface
      clip: true

      Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        opacity: Math.max(0, (root.revealProgress - 0.2) / 0.8)

        Row {
          width: parent.width
          spacing: 12

          Rectangle {
            width: 42
            height: 42
            radius: Appearance.radius(21)
            color: Colors.md3.primary_container

            Text {
              anchors.centerIn: parent
              text: "󰌾"
              color: Colors.md3.on_primary_container
              font.family: authIconFont.name
              font.pixelSize: 21
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 94
            spacing: 2

            Text {
              width: parent.width
              text: "Authentication required"
              color: Colors.md3.on_surface
              font.pixelSize: 18
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.flow?.message || "An application is requesting administrator privileges"
              color: Colors.md3.on_surface_variant
              font.pixelSize: 11
              maximumLineCount: 2
              wrapMode: Text.Wrap
              elide: Text.ElideRight
            }
          }

          Rectangle {
            width: 40
            height: 40
            radius: Appearance.radius(20)
            color: cancelHover.hovered ? Colors.md3.error_container : Colors.md3.surface_container_high

            Text { anchors.centerIn: parent; text: "×"; color: Colors.md3.on_surface; font.pixelSize: 23 }
            HoverHandler { id: cancelHover }
            TapHandler {
              onTapped: {
                if (root.flow)
                  root.flow.cancelAuthenticationRequest();
                root.closeDialog();
              }
            }
          }
        }

        TextField {
          id: passwordField
          width: parent.width
          height: 46
          enabled: root.flow?.isResponseRequired ?? false
          placeholderText: root.flow?.inputPrompt || "Password"
          echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
          color: Colors.md3.on_surface
          placeholderTextColor: Colors.md3.on_surface_variant
          selectionColor: Colors.md3.primary
          selectedTextColor: Colors.md3.on_primary
          leftPadding: 18
          rightPadding: 18
          Keys.onReturnPressed: root.submit()
          Keys.onEnterPressed: root.submit()
          background: Rectangle {
            radius: Appearance.radius(23)
            color: Colors.md3.surface_container_high
          }
        }

        Text {
          width: parent.width
          height: 18
          text: root.flow?.supplementaryMessage || ""
          color: root.flow?.supplementaryIsError ? Colors.md3.error : Colors.md3.on_surface_variant
          font.pixelSize: 11
          elide: Text.ElideRight
        }

        Row {
          anchors.right: parent.right
          spacing: 8

          Rectangle {
            width: 92
            height: 38
            radius: Appearance.radius(19)
            color: Colors.md3.surface_container_high
            Text { anchors.centerIn: parent; text: "Cancel"; color: Colors.md3.on_surface; font.pixelSize: 12; font.bold: true }
            TapHandler {
              onTapped: {
                if (root.flow)
                  root.flow.cancelAuthenticationRequest();
                root.closeDialog();
              }
            }
          }

          Rectangle {
            width: 108
            height: 38
            radius: Appearance.radius(19)
            color: passwordField.text.length ? Colors.md3.primary : Colors.md3.surface_container_highest
            Text {
              anchors.centerIn: parent
              text: "Authenticate"
              color: passwordField.text.length ? Colors.md3.on_primary : Colors.md3.on_surface_variant
              font.pixelSize: 12
              font.bold: true
            }
            TapHandler { enabled: passwordField.text.length > 0; onTapped: root.submit() }
          }
        }
      }

      FontLoader {
        id: authIconFont
        source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf"
      }
    }

    RoundCorner {
      anchors { top: authPanel.top; right: authPanel.left; rightMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Colors.md3.surface
      opacity: root.revealProgress
      corner: RoundCorner.CornerEnum.TopRight
    }

    RoundCorner {
      anchors { top: authPanel.top; left: authPanel.right; leftMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Colors.md3.surface
      opacity: root.revealProgress
      corner: RoundCorner.CornerEnum.TopLeft
    }
  }
}

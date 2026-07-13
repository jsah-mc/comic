import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.common

Scope {
  id: root

  property bool failed: false
  property bool opened: false
  property string errorString: ""
  property real revealProgress: 0
  property int timeoutDuration: failed ? 12000 : 2600
  property int timeoutRemaining: 0

  function showPopup(isFailure, error) {
    failed = isFailure;
    errorString = error || "";
    timeoutDuration = isFailure ? 12000 : 2600;
    timeoutRemaining = timeoutDuration;
    opened = true;
    revealProgress = 1;
    dismissTimer.restart();
  }

  function closePopup() {
    opened = false;
    revealProgress = 0;
    dismissTimer.stop();
  }

  Connections {
    target: Quickshell

    function onReloadCompleted() {
      root.showPopup(false, "Configuration loaded successfully");
    }

    function onReloadFailed(error: string) {
      root.showPopup(true, error);
    }
  }

  Behavior on revealProgress {
    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
  }

  Timer {
    id: dismissTimer
    interval: 50
    repeat: true
    onTriggered: {
      if (panelHover.hovered)
        return;
      root.timeoutRemaining -= interval;
      if (root.timeoutRemaining <= 0)
        root.closePopup();
    }
  }

  PanelWindow {
    visible: root.opened || root.revealProgress > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "comic-reload-popup"

    anchors {
      top: true
      left: true
      right: true
    }

    implicitHeight: 390
    mask: Region { item: reloadPanel }

    Rectangle {
      id: reloadPanel
      anchors {
        top: parent.top
        horizontalCenter: parent.horizontalCenter
        topMargin: 10
      }

      width: 120 + 440 * root.revealProgress
      height: 36 + ((root.failed ? 250 : 76) - 36) * root.revealProgress
      opacity: root.revealProgress
      radius: Appearance.radius(18 + 6 * root.revealProgress)
      topLeftRadius: 0
      topRightRadius: 0
      color: Colors.md3.surface
      clip: true

      Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      HoverHandler { id: panelHover }

      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        opacity: Math.max(0, (root.revealProgress - 0.2) / 0.8)

        Row {
          width: parent.width
          spacing: 12

          Rectangle {
            width: 40
            height: 40
            radius: Appearance.radius(20)
            color: root.failed ? Colors.md3.error_container : Colors.md3.primary_container

            Text {
              anchors.centerIn: parent
              text: root.failed ? "!" : "✓"
              color: root.failed ? Colors.md3.on_error_container : Colors.md3.on_primary_container
              font.pixelSize: 20
              font.bold: true
            }
          }

          Column {
            width: parent.width - 92
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
              width: parent.width
              text: root.failed ? "Config reload failed" : "Quickshell reloaded"
              color: Colors.md3.on_surface
              font.pixelSize: 17
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.failed ? "The previous configuration is still running" : root.errorString
              color: Colors.md3.on_surface_variant
              font.pixelSize: 11
              elide: Text.ElideRight
            }
          }

          Rectangle {
            width: 40
            height: 40
            radius: Appearance.radius(20)
            color: closeHover.hovered ? Colors.md3.surface_container_highest : Colors.md3.surface_container_high

            Text {
              anchors.centerIn: parent
              text: "×"
              color: Colors.md3.on_surface
              font.pixelSize: 23
            }

            HoverHandler { id: closeHover }
            TapHandler { onTapped: root.closePopup() }
          }
        }

        Rectangle {
          visible: root.failed
          width: parent.width
          height: root.failed ? 142 : 0
          radius: Appearance.radius(14)
          color: Colors.md3.surface_container
          clip: true

          Flickable {
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: errorText.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
              id: errorText
              width: parent.width
              text: root.errorString
              color: Colors.md3.on_surface_variant
              font.family: "monospace"
              font.pixelSize: 11
              wrapMode: Text.WrapAnywhere
            }
          }
        }
      }

      Rectangle {
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
          leftMargin: 16
          rightMargin: 16
          bottomMargin: 8
        }
        height: 4
        radius: Appearance.radius(2)
        color: Colors.md3.surface_container_highest

        Rectangle {
          width: parent.width * Math.max(0, root.timeoutRemaining / Math.max(1, root.timeoutDuration))
          height: parent.height
          radius: parent.radius
          color: root.failed ? Colors.md3.error : Colors.md3.primary
        }
      }
    }

    RoundCorner {
      anchors { top: reloadPanel.top; right: reloadPanel.left; rightMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Colors.md3.surface
      opacity: root.revealProgress
      corner: RoundCorner.CornerEnum.TopRight
    }

    RoundCorner {
      anchors { top: reloadPanel.top; left: reloadPanel.right; leftMargin: -1 }
      implicitSize: Appearance.radius(14)
      color: Colors.md3.surface
      opacity: root.revealProgress
      corner: RoundCorner.CornerEnum.TopLeft
    }
  }
}

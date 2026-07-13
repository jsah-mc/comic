import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.modules.common

Scope {
  id: root

  property int frameWidth: 10
  property int cornerRadius: 24
  property color frameColor: Colors.md3.surface
  property color outerCornerColor: "black"

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "comic-screen-frame"

      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.cornerRadius
        border.width: root.frameWidth
        border.color: root.frameColor
      }

      RoundCorner {
        anchors { top: parent.top; left: parent.left }
        implicitSize: root.cornerRadius
        color: root.outerCornerColor
        corner: RoundCorner.CornerEnum.TopLeft
      }

      RoundCorner {
        anchors { top: parent.top; right: parent.right }
        implicitSize: root.cornerRadius
        color: root.outerCornerColor
        corner: RoundCorner.CornerEnum.TopRight
      }

      RoundCorner {
        anchors { bottom: parent.bottom; left: parent.left }
        implicitSize: root.cornerRadius
        color: root.outerCornerColor
        corner: RoundCorner.CornerEnum.BottomLeft
      }

      RoundCorner {
        anchors { bottom: parent.bottom; right: parent.right }
        implicitSize: root.cornerRadius
        color: root.outerCornerColor
        corner: RoundCorner.CornerEnum.BottomRight
      }
    }
  }
}

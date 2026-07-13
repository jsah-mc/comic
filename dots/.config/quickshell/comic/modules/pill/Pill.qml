import Quickshell
import QtQuick
import "widgets"
import qs.modules.common

Scope {
  id: root

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      color: "transparent"

      anchors {
        top: true
        left: true
        right: true
      }
    
      implicitHeight: 50

      Rectangle {
        id: pill
        anchors {
          top: parent.top
          horizontalCenter: parent.horizontalCenter
          topMargin: 10
        }
        readonly property real collapsedWidth: collapsedContent.childrenRect.width + 100
        readonly property real expandedWidth: hoverContent.childrenRect.width + 24

        width: hoverHandler.hovered
          ? Math.max(collapsedWidth, expandedWidth)
          : collapsedWidth
        height: 40
        radius: Appearance.radius(height / 2)
        topLeftRadius: 0
        topRightRadius: 0
        color: Colors.md3.surface
        clip: true

        Behavior on width {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        HoverHandler {
          id: hoverHandler
        }

        Row {
          id: collapsedContent
          anchors.centerIn: parent
          spacing: 7
          opacity: hoverHandler.hovered ? 0 : 1

          Behavior on opacity {
            NumberAnimation { duration: 100 }
          }

          CurrentWindowWidget {}
          ClockWidget {}
          MusicVisualizer {}
          BatteryWidget {}
        }

        Row {
          id: hoverContent
          anchors.centerIn: parent
          spacing: 6
          opacity: hoverHandler.hovered ? 1 : 0

          Behavior on opacity {
            NumberAnimation { duration: 140 }
          }

          WorkspacesWidget {
            id: workspaceWidget
          }

          ConnectivityTray {}
          WallpaperButton {}
          SidebarButton {}
          SettingsButton {}
          LauncherButton {}
          PowerButton {}
        }

      }

      RoundCorner {
        anchors {
          top: pill.top
          right: pill.left
          rightMargin: -1
        }
        implicitSize: Appearance.radius(14)
        color: Colors.md3.surface
        corner: RoundCorner.CornerEnum.TopRight
      }

      RoundCorner {
        anchors {
          top: pill.top
          left: pill.right
          leftMargin: -1
        }
        implicitSize: Appearance.radius(14)
        color: Colors.md3.surface
        corner: RoundCorner.CornerEnum.TopLeft
      }
    }
  }
}

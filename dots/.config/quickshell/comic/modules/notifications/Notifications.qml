import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import qs.modules.common

Scope {
  id: root
  FontLoader { id: materialIcons; source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf" }
  property var currentNotification: null
  property var notificationQueue: []
  property real revealProgress: 0
  property real timeoutProgress: 1
  property int timeoutDuration: 5000
  property int timeoutRemaining: 0
  property bool activeExpanded: false

  function showNext(): void {
    if (currentNotification !== null || notificationQueue.length === 0) return;
    currentNotification = notificationQueue[0];
    activeExpanded = false;
    notificationQueue = notificationQueue.slice(1);
    timeoutDuration = Math.max(3500, Math.min(currentNotification.expireTimeout > 0 ? currentNotification.expireTimeout : 5500, 10000));
    timeoutRemaining = timeoutDuration;
    timeoutProgress = 1;
    revealProgress = 1;
    countdown.start();
  }

  function hide(): void {
    revealProgress = 0;
    countdown.stop();
    swapTimer.restart();
  }

  function dismissQueued(notification): void {
    notificationQueue = notificationQueue.filter(item => item !== notification);
    notification.dismiss();
  }

  function advance(): void {
    countdown.stop();
    currentNotification = null;
    if (notificationQueue.length > 0)
      showNext();
    else
      hide();
  }

  NotificationServer {
    id: server
    keepOnReload: false
    bodySupported: true
    bodyMarkupSupported: false
    actionsSupported: true
    imageSupported: true

    onNotification: notification => {
      notification.tracked = true;
      if (NotificationState.doNotDisturb) return;
      root.notificationQueue = root.notificationQueue.concat([notification]);
      root.showNext();
    }
  }

  IpcHandler {
    target: "notifications"
    function toggleDnd(): void { NotificationState.doNotDisturb = !NotificationState.doNotDisturb; }
    function enableDnd(): void { NotificationState.doNotDisturb = true; }
    function disableDnd(): void { NotificationState.doNotDisturb = false; }
    function dismiss(): void { root.hide(); }
  }

  Timer {
    id: countdown
    interval: 55
    repeat: true
    onTriggered: {
      root.timeoutRemaining -= interval;
      root.timeoutProgress = Math.max(0, root.timeoutRemaining / root.timeoutDuration);
      if (root.timeoutRemaining <= 0) {
        if (root.currentNotification) root.currentNotification.expire();
        root.advance();
      }
    }
  }
  Timer {
    id: swapTimer
    interval: 270
    onTriggered: {
      root.currentNotification = null;
      Qt.callLater(() => root.showNext());
    }
  }
  Behavior on revealProgress { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.currentNotification !== null && root.revealProgress > 0
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "comic-notifications"
      anchors { top: true; left: true; right: true }
      implicitHeight: 560
      mask: Region {
        Region { item: popup }
        Region { item: notificationStack }
      }

      Rectangle {
        id: popup
        anchors { top: parent.top; left: parent.left }
        width: 120 + 280 * root.revealProgress
        height: root.activeExpanded ? 118 : 64
        scale: 0.98 + root.revealProgress * 0.02
        opacity: root.revealProgress
        radius: Appearance.radius(0)
        topLeftRadius: 0
        bottomLeftRadius: root.notificationQueue.length === 0 ? Appearance.radius(18) : 0
        topRightRadius: 0
        bottomRightRadius: root.notificationQueue.length === 0 ? Appearance.radius(18) : 0
        color: Colors.md3.surface

        clip: true

        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle { z: -1; x: -6; y: 5; width: parent.width + 6; height: parent.height + 6; radius: Appearance.radius(14); color: "#66000000" }

        Row {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 10
          anchors.topMargin: 8
          anchors.bottomMargin: 8
          spacing: 10
          opacity: Math.max(0, (root.revealProgress - 0.3) / 0.7)

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: Appearance.radius(20)
            color: Colors.md3.surface

            Text {
              anchors.centerIn: parent
              text: root.currentNotification?.appName === "Quickshell" ? "󰑐" : "󰋼"
              color: root.currentNotification?.appName === "Quickshell" ? Colors.md3.primary : Colors.md3.on_surface
              font.family: materialIcons.name
              font.pixelSize: 23
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 72
            spacing: 1
            Text { width: parent.width; text: (root.currentNotification?.summary ?? "Notification") + "  ·  now"; color: Colors.md3.on_surface; font.pixelSize: 14; font.weight: Font.Medium; elide: Text.ElideRight }
            Text { width: parent.width; text: root.currentNotification?.body ?? ""; color: Colors.md3.on_surface_variant; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: root.activeExpanded ? 5 : 1; elide: Text.ElideRight }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.activeExpanded ? "⌃" : "⌄"
            color: Colors.md3.on_surface_variant
            font.pixelSize: 15
            TapHandler { onTapped: root.activeExpanded = !root.activeExpanded }
          }
        }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: { if (root.currentNotification) root.currentNotification.dismiss(); root.advance(); } }
      }

      Column {
        id: notificationStack
        anchors { top: popup.bottom; left: parent.left }
        width: 400
        spacing: 0
        opacity: root.revealProgress

        move: Transition {
          NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic }
        }

        add: Transition {
          ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { property: "x"; from: 420; to: 0; duration: 280; easing.type: Easing.OutBack }
          }
        }

        Repeater {
          model: root.notificationQueue.slice(0, 3)

          Rectangle {
            required property var modelData
            required property int index
            property bool expanded: false
            readonly property bool isLastVisible: index === Math.min(root.notificationQueue.length, 3) - 1
            width: 400
            height: expanded ? 118 : 64
            radius: Appearance.radius(0)
            topLeftRadius: 0
            bottomLeftRadius: isLastVisible ? Appearance.radius(14) : 0
            topRightRadius: 0
            bottomRightRadius: isLastVisible ? Appearance.radius(14) : 0
            color: Colors.md3.surface
            clip: true

            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Rectangle { z: -1; x: -6; y: 5; width: parent.width + 6; height: parent.height + 6; radius: Appearance.radius(14); color: "#66000000" }

            Row {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 10
              anchors.topMargin: 8
              anchors.bottomMargin: 8
              spacing: 10

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: Appearance.radius(20)
                color: Colors.md3.surface_container_high
                Text {
                  anchors.centerIn: parent
                  text: modelData.appName === "Quickshell" ? "󰑐" : "󰋼"
                  color: modelData.appName === "Quickshell" ? Colors.md3.primary : Colors.md3.on_surface
                  font.family: materialIcons.name
                  font.pixelSize: 23
                }
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 72
                spacing: 1
                Text { width: parent.width; text: modelData.summary + "  ·  now"; color: Colors.md3.on_surface; font.pixelSize: 14; font.weight: Font.Medium; elide: Text.ElideRight }
                Text { width: parent.width; text: modelData.body; color: Colors.md3.on_surface_variant; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: expanded ? 5 : 1; elide: Text.ElideRight }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: expanded ? "⌃" : "⌄"
                color: Colors.md3.on_surface_variant
                font.pixelSize: 15
                TapHandler { onTapped: expanded = !expanded }
              }
            }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.dismissQueued(modelData) }
          }
        }
      }

      RoundCorner {
        anchors { top: popup.top; right: popup.left; rightMargin: -1 }
        implicitSize: Appearance.radius(14)
        color: Colors.md3.surface
        opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopRight
      }

      RoundCorner {
        anchors { top: popup.top; left: popup.right; leftMargin: -1 }
        implicitSize: Appearance.radius(14)
        color: Colors.md3.surface
        opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopLeft
      }

    }
  }
}

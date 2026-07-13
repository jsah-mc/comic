import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs.modules.common

Scope {
  id: root

  property bool opened: false
  property real revealProgress: 0
  property string page: "apps"
  property var clipboardHistory: []
  property var emojis: []
  property int selectedIndex: 0
  property string searchQuery: ""

  function addClipboard(value): void {
    const clean = value.trim();
    if (!clean.length || clipboardHistory[0] === clean) return;
    clipboardHistory = [clean].concat(clipboardHistory.filter(item => item !== clean)).slice(0, 100);
  }

  function filteredApps() {
    const query = searchQuery.toLowerCase();
    return DesktopEntries.applications.values.filter(app => !app.noDisplay && (app.name + " " + app.genericName + " " + app.keywords).toLowerCase().includes(query));
  }

  function filteredClipboard() {
    const query = searchQuery.toLowerCase();
    return clipboardHistory.filter(item => item.toLowerCase().includes(query));
  }

  function filteredEmojis() {
    const query = searchQuery.toLowerCase();
    return emojis.filter(item => !query.length || item.name.includes(query) || item.emoji.includes(query));
  }

  function currentItems() {
    return page === "apps" ? filteredApps() : page === "clipboard" ? filteredClipboard() : filteredEmojis();
  }

  function moveSelection(delta: int): void {
    const count = currentItems().length;
    if (!count) return;
    selectedIndex = (selectedIndex + delta + count) % count;
  }

  function activateSelected(): void {
    const items = currentItems();
    if (!items.length) return;
    const item = items[Math.max(0, Math.min(selectedIndex, items.length - 1))];
    if (page === "apps") item.execute();
    else if (page === "clipboard") Quickshell.clipboardText = item;
    else {
      Quickshell.clipboardText = item.emoji;
      Quickshell.execDetached(["wtype", item.emoji]);
    }
    opened = false;
  }

  Connections {
    target: Quickshell
    function onClipboardTextChanged(): void {
      root.addClipboard(Quickshell.clipboardText);
    }
  }

  Process {
    id: emojiLoader
    command: ["jq", "-r", "to_entries[] | [.key, .value] | @tsv", "/usr/share/code/resources/app/extensions/git/resources/emojis.json"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.emojis = text.trim().split("\n").filter(line => line.includes("\t")).map(line => {
        const split = line.indexOf("\t");
        return { name: String(line.slice(0, split)).split("_").join(" "), emoji: line.slice(split + 1) };
      })
    }
  }

  Process {
    id: clipboardPoll
    command: ["wl-paste", "-n"]
    stdout: StdioCollector { onStreamFinished: root.addClipboard(text) }
  }

  Timer {
    interval: 750
    running: true
    repeat: true
    onTriggered: { if (!clipboardPoll.running) clipboardPoll.running = true; }
  }

  Behavior on revealProgress {
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  onOpenedChanged: {
    revealProgress = opened ? 1 : 0;
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void { root.opened = !root.opened; }
    function open(): void { root.opened = true; }
    function close(): void { root.opened = false; }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: launcherWindow
      required property var modelData
      screen: modelData
      visible: root.opened || root.revealProgress > 0
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "comic-launcher"

      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      TapHandler {
        onTapped: eventPoint => {
          const local = launcherPanel.mapFromItem(launcherPanel.parent, eventPoint.position);
          if (!launcherPanel.contains(local))
            root.opened = false;
        }
      }

      Connections {
        target: root

        function onOpenedChanged(): void {
          if (root.opened)
            Qt.callLater(() => searchField.forceActiveFocus());
          else
            searchField.clear();
        }
      }

      Shortcut {
        sequence: "Escape"
        enabled: root.opened
        onActivated: root.opened = false
      }

      Rectangle {
        id: launcherPanel
        anchors {
          top: parent.top
          horizontalCenter: parent.horizontalCenter
          topMargin: 10
        }
        width: 120 + 400 * root.revealProgress
        height: 36 + 470 * root.revealProgress
        radius: 18 + 6 * root.revealProgress
        topLeftRadius: 0
        topRightRadius: 0
        color: Colors.md3.surface
        clip: true

        TapHandler {}


        Column {
          anchors.fill: parent
          anchors.margins: 18
          spacing: 14
          opacity: Math.max(0, (root.revealProgress - 0.25) / 0.75)
          visible: opacity > 0

          Row {
            width: parent.width
            spacing: 10

            TextField {
              id: searchField
              width: parent.width - closeButton.width - parent.spacing
              height: 40
              placeholderText: "Search applications…"
              color: Colors.md3.on_surface
              placeholderTextColor: Colors.md3.on_surface_variant
              selectionColor: Colors.md3.primary
              selectedTextColor: Colors.md3.on_primary
              font.pixelSize: 15
              selectByMouse: true
              leftPadding: 16
              rightPadding: 16
              onTextChanged: {
                root.searchQuery = text;
                root.selectedIndex = 0;
              }

              Keys.onPressed: event => {
                const columns = root.page === "apps" ? 5 : root.page === "emoji" ? 8 : 1;
                if (event.key === Qt.Key_Left) root.moveSelection(-1);
                else if (event.key === Qt.Key_Right) root.moveSelection(1);
                else if (event.key === Qt.Key_Up) root.moveSelection(-columns);
                else if (event.key === Qt.Key_Down) root.moveSelection(columns);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activateSelected();
                else return;
                event.accepted = true;
              }

              cursorDelegate: Rectangle {
                width: 2
                color: Colors.md3.primary
              }

              background: Rectangle {
                radius: 20
                color: Colors.md3.surface_container_high
              }

              Keys.onEscapePressed: root.opened = false
            }

            Rectangle {
              id: closeButton
              width: 40
              height: 40
              radius: 20
              color: closeHover.hovered ? Colors.md3.primary_container : Colors.md3.surface_container_high

              Text {
                anchors.centerIn: parent
                text: "×"
                color: Colors.md3.on_surface
                font.pixelSize: 24
              }

              HoverHandler { id: closeHover }
              TapHandler { onTapped: root.opened = false }
            }
          }

          Row {
            width: parent.width
            spacing: 8

            Repeater {
              model: [{ key: "apps", label: "Apps" }, { key: "clipboard", label: "Clipboard" }, { key: "emoji", label: "Emoji" }]
              Rectangle {
                required property var modelData
                width: (parent.width - 16) / 3
                height: 32
                radius: 16
                color: root.page === modelData.key ? Colors.md3.primary_container : Colors.md3.surface_container
                Behavior on color { ColorAnimation { duration: 140 } }
                Text { anchors.centerIn: parent; text: modelData.label; color: root.page === modelData.key ? Colors.md3.on_primary_container : Colors.md3.on_surface }
                TapHandler {
                  onTapped: {
                    root.page = modelData.key;
                    root.selectedIndex = 0;
                    searchField.placeholderText = modelData.key === "apps" ? "Search applications…" : modelData.key === "emoji" ? "Search emoji…" : "Search clipboard…";
                    searchField.clear();
                    searchField.forceActiveFocus();
                  }
                }
              }
            }
          }

          Flickable {
            visible: root.page === "apps"
            width: parent.width
            height: parent.height - y
            contentHeight: appGrid.childrenRect.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Grid {
              id: appGrid
              width: parent.width
              columns: 5
              columnSpacing: 8
              rowSpacing: 8

              Repeater {
                model: root.filteredApps()

                Rectangle {
                  required property var modelData
                  required property int index
                  width: (appGrid.width - appGrid.columnSpacing * 4) / 5
                  height: 88
                  radius: 14
                  color: index === root.selectedIndex ? Colors.md3.primary_container : appHover.hovered ? Colors.md3.surface_container_high : "transparent"
                  scale: appHover.hovered || index === root.selectedIndex ? 1.04 : 1
                  Behavior on color { ColorAnimation { duration: 120 } }
                  Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                  Column {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    spacing: 6

                    Image {
                      anchors.horizontalCenter: parent.horizontalCenter
                      width: 40
                      height: 40
                      source: Quickshell.iconPath(modelData.icon)
                      sourceSize: Qt.size(40, 40)
                      fillMode: Image.PreserveAspectFit
                    }

                    Text {
                      width: parent.width
                      text: modelData.name
                      color: Colors.md3.on_surface
                      font.pixelSize: 12
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }
                  }

                  HoverHandler { id: appHover }
                  TapHandler {
                    onTapped: {
                      modelData.execute();
                      root.opened = false;
                    }
                  }
                }
              }
            }
          }

          Flickable {
            visible: root.page === "clipboard"
            width: parent.width
            height: parent.height - y
            contentHeight: clipboardList.childrenRect.height
            clip: true

            Column {
              id: clipboardList
              width: parent.width
              spacing: 7

              Text {
                visible: root.clipboardHistory.length === 0
                width: parent.width
                text: "Copy some text to build clipboard history"
                color: Colors.md3.on_surface_variant
                horizontalAlignment: Text.AlignHCenter
                topPadding: 30
              }

              Repeater {
                model: root.filteredClipboard()
                Rectangle {
                  required property var modelData
                  required property int index
                  width: clipboardList.width
                  height: 54
                  radius: 12
                  color: index === root.selectedIndex ? Colors.md3.primary_container : clipHover.hovered ? Colors.md3.surface_container_high : Colors.md3.surface_container
                  Behavior on color { ColorAnimation { duration: 120 } }
                  Text { anchors.fill: parent; anchors.margins: 12; text: modelData; color: Colors.md3.on_surface; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                  HoverHandler { id: clipHover }
                  TapHandler { onTapped: { Quickshell.clipboardText = modelData; root.opened = false; } }
                }
              }
            }
          }

          Flickable {
            visible: root.page === "emoji"
            width: parent.width
            height: parent.height - y
            contentHeight: emojiGrid.childrenRect.height
            clip: true

            Grid {
              id: emojiGrid
              width: parent.width
              columns: 8
              spacing: 7
              Repeater {
                model: root.filteredEmojis()
                Rectangle {
                  required property var modelData
                  required property int index
                  width: (emojiGrid.width - 49) / 8
                  height: width
                  radius: 12
                  color: index === root.selectedIndex || emojiHover.hovered ? Colors.md3.primary_container : Colors.md3.surface_container
                  scale: emojiHover.hovered || index === root.selectedIndex ? 1.06 : 1
                  Behavior on color { ColorAnimation { duration: 120 } }
                  Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                  Text { anchors.centerIn: parent; text: modelData.emoji; font.pixelSize: 24 }
                  HoverHandler { id: emojiHover }
                  TapHandler {
                    onTapped: {
                      Quickshell.clipboardText = modelData.emoji;
                      Quickshell.execDetached(["wtype", modelData.emoji]);
                      root.opened = false;
                    }
                  }
                }
              }
            }
          }
        }
      }

      RoundCorner {
        anchors {
          top: launcherPanel.top
          right: launcherPanel.left
          rightMargin: -1
        }
        implicitSize: 14
        color: Colors.md3.surface
        opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopRight
      }

      RoundCorner {
        anchors {
          top: launcherPanel.top
          left: launcherPanel.right
          leftMargin: -1
        }
        implicitSize: 14
        color: Colors.md3.surface
        opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopLeft
      }
    }
  }
}

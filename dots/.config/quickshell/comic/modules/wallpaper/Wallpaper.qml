import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import qs.modules.common

Scope {
  id: root

  FontLoader {
    id: materialIcons
    source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf"
  }

  property bool opened: false
  property real revealProgress: 0
  property string wallpaperDirectory: Quickshell.env("HOME") + "/Pictures/Wallpapers"
  property string selectedPath: wallpaperDirectory + "/default.jpg"
  property string themeMode: "dark"
  property string schemeType: "auto"
  property string colorFlag: ""
  property string accentColor: ""
  property real wallpaperTransition: 1
  property int wallpaperAnimation: 0
  readonly property string currentWallpaperPath: Quickshell.env("HOME") + "/.local/state/quickshell/wallpaper/current.txt"
  readonly property string currentThemePath: Quickshell.env("HOME") + "/.local/state/quickshell/wallpaper/theme.txt"
  readonly property string setWallScript: Qt.resolvedUrl("../../scripts/set_wall").toString().replace("file://", "")

  onOpenedChanged: revealProgress = opened ? 1 : 0

  Behavior on revealProgress {
    NumberAnimation {
      duration: 240
      easing.type: Easing.OutCubic
    }
  }

  function isVideoPath(path) {
    const value = String(path).toLowerCase();
    return value.endsWith(".mp4") || value.endsWith(".webm") || value.endsWith(".mkv")
      || value.endsWith(".avi") || value.endsWith(".mov");
  }

  function setWallpaper(path) {
    wallpaperAnimation = Math.floor(Math.random() * 4);
    wallpaperTransition = 0;
    selectedPath = path;
    Quickshell.execDetached([setWallScript, path, themeMode, schemeType, colorFlag, accentColor]);
    Qt.callLater(() => wallpaperChangeAnimation.restart());
    opened = false;
  }

  function toggleTheme() {
    themeMode = themeMode === "dark" ? "light" : "dark";
    if (selectedPath.length > 0)
      Quickshell.execDetached([setWallScript, selectedPath, themeMode, schemeType, colorFlag, accentColor]);
  }

  function loadCurrentWallpaper() {
    const path = currentWallpaperFile.text().trim();
    if (path.length > 0)
      selectedPath = path;
  }

  FileView {
    id: currentWallpaperFile
    path: root.currentWallpaperPath
    watchChanges: true
    preload: true
    printErrors: false

    onLoaded: root.loadCurrentWallpaper()
    onFileChanged: reload()
  }

  FileView {
    id: currentThemeFile
    path: root.currentThemePath
    watchChanges: true
    preload: true
    printErrors: false
    onLoaded: {
      const mode = text().trim();
      if (mode === "light" || mode === "dark")
        root.themeMode = mode;
    }
    onFileChanged: reload()
  }

  Process {
    id: folderPicker
    command: ["kdialog", "--getexistingdirectory", root.wallpaperDirectory, "--title", "Choose wallpaper folder"]
    stdout: StdioCollector {
      onStreamFinished: {
        const folder = text.trim();
        if (folder.length > 0)
          root.wallpaperDirectory = folder;
        root.opened = true;
      }
    }
    stderr: StdioCollector {
      onStreamFinished: root.opened = true
    }
  }

  NumberAnimation {
    id: wallpaperChangeAnimation
    target: root
    property: "wallpaperTransition"
    from: 0
    to: 1
    duration: 700
    easing.type: Easing.OutCubic
  }

  IpcHandler {
    target: "wallpaper"

    function toggle(): void { root.opened = !root.opened; }
    function open(): void { root.opened = true; }
    function close(): void { root.opened = false; }
    function set(path: string): void { root.setWallpaper(path); }
  }

  FolderListModel {
    id: wallpapers
    folder: "file://" + root.wallpaperDirectory
    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.mp4", "*.webm", "*.mkv", "*.avi", "*.mov"]
    showDirs: false
    sortField: FolderListModel.Name
  }

  // Quickshell owns the desktop background. No external wallpaper daemon is used.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: !root.isVideoPath(root.selectedPath)
      color: "black"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.namespace: "comic-wallpaper"

      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      Image {
        anchors.fill: parent
        source: root.selectedPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: root.wallpaperTransition
        scale: root.wallpaperAnimation === 1 ? 0.9 + root.wallpaperTransition * 0.1
          : root.wallpaperAnimation === 3 ? 0.96 + root.wallpaperTransition * 0.04
          : 1
        rotation: root.wallpaperAnimation === 3 ? (1 - root.wallpaperTransition) * 2.5 : 0
        transform: Translate {
          x: root.wallpaperAnimation === 2 ? (1 - root.wallpaperTransition) * 140 : 0
        }
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.opened || root.revealProgress > 0
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
          const local = wallpaperPanel.mapFromItem(wallpaperPanel.parent, eventPoint.position);
          if (!wallpaperPanel.contains(local))
            root.opened = false;
        }
      }

      Rectangle {
        id: wallpaperPanel
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 900)
        height: Math.min(parent.height - 80, 650)
        scale: 0.94 + root.revealProgress * 0.06
        opacity: root.revealProgress
        radius: 22
        color: Colors.md3.surface


        TapHandler {}

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 20
          spacing: 16

          RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
              spacing: 2

              Text {
                text: "Wallpapers"
                color: Colors.md3.on_surface
                font.pixelSize: 22
                font.bold: true
              }

              Text {
                text: root.wallpaperDirectory
                color: Colors.md3.on_surface
                font.pixelSize: 11
                elide: Text.ElideMiddle
              }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              width: 122
              height: 34
              radius: 17
              color: folderHover.hovered ? Colors.md3.primary_container : Colors.md3.surface_container_high
              scale: folderHover.hovered ? 1.04 : 1
              Behavior on color { ColorAnimation { duration: 150 } }
              Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
              Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "󰉋"; color: Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 16 }
                Text { text: "Choose folder"; color: Colors.md3.on_surface; font.pixelSize: 11; font.bold: true }
              }
              HoverHandler { id: folderHover }
              TapHandler {
                onTapped: {
                  root.opened = false;
                  if (!folderPicker.running)
                    folderPicker.running = true;
                }
              }
            }

            Rectangle {
              width: 100
              height: 34
              radius: 17
              color: themeHover.hovered ? Colors.md3.primary_container : Colors.md3.surface_container_high
              scale: themeHover.hovered ? 1.04 : 1
              Behavior on color { ColorAnimation { duration: 150 } }
              Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
              Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: root.themeMode === "dark" ? "󰖔" : "󰖨"; color: Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 16 }
                Text { text: root.themeMode === "dark" ? "Dark" : "Light"; color: Colors.md3.on_surface; font.pixelSize: 11; font.bold: true }
              }
              HoverHandler { id: themeHover }
              TapHandler { onTapped: root.toggleTheme() }
            }

            Rectangle {
              width: 34
              height: 34
              radius: 17
              color: closeHover.hovered ? Colors.md3.surface_container_highest : Colors.md3.surface_container_high
              Text {
                anchors.centerIn: parent
                text: "×"
                color: Colors.md3.on_surface
                font.pixelSize: 22
                font.bold: true
              }
              HoverHandler { id: closeHover }
              TapHandler { onTapped: root.opened = false }
            }
          }

          GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: wallpapers
            cellWidth: 210
            cellHeight: 140

            delegate: Item {
              id: wallpaperDelegate
              required property url fileUrl
              required property string fileName
              property bool appeared: false
              readonly property bool isVideo: root.isVideoPath(fileName)

              width: grid.cellWidth
              height: grid.cellHeight
              opacity: appeared ? 1 : 0
              scale: appeared ? 1 : 0.88

              Component.onCompleted: thumbnailEntrance.start()

              SequentialAnimation {
                id: thumbnailEntrance
                PauseAnimation { duration: Math.floor(Math.random() * 260) }
                ParallelAnimation {
                  NumberAnimation { target: wallpaperDelegate; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                  NumberAnimation { target: wallpaperDelegate; property: "scale"; to: 1; duration: 300; easing.type: Easing.OutBack }
                }
                ScriptAction { script: wallpaperDelegate.appeared = true }
              }

              Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: 14
                color: Colors.md3.surface_container
                clip: true

                Image {
                  anchors.fill: parent
                  source: fileUrl
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  cache: true
                  visible: !wallpaperDelegate.isVideo
                }

                Rectangle {
                  anchors.fill: parent
                  visible: wallpaperDelegate.isVideo
                  color: Colors.md3.surface_container_high

                  Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "󰕧"
                      color: Colors.md3.primary
                      font.family: materialIcons.name
                      font.pixelSize: 38
                    }

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "Live wallpaper"
                      color: Colors.md3.on_surface
                      font.pixelSize: 11
                      font.bold: true
                    }
                  }
                }

                Rectangle {
                  anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                  }
                  height: 32
                  color: "#b3000000"

                  Text {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: fileName
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: "#80000000"
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideMiddle
                    font.pixelSize: 11
                    font.weight: Font.Medium
                  }
                }

                HoverHandler { id: wallpaperHover }
                TapHandler {
                  onTapped: root.setWallpaper(parent.parent.fileUrl.toString().replace("file://", ""))
                }

                scale: wallpaperHover.hovered ? 1.02 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 160 } }
              }
            }
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            visible: wallpapers.count === 0
            text: "No images found in the wallpaper folder"
            color: Colors.md3.on_surface_variant
          }
        }
      }
    }
  }
}

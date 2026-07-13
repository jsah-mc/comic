import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  readonly property var activeWindow: ToplevelManager.activeToplevel
  property string hyprlandAppClass: ""
  property bool hyprlandDataReady: false
  readonly property string appClass: hyprlandDataReady ? hyprlandAppClass : (activeWindow?.appId || "")
  readonly property var desktopEntry: findDesktopEntry(appClass)
  readonly property string iconName: resolveIcon(appClass, desktopEntry)

  function normalized(value) {
    return String(value || "").toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]/g, "");
  }

  function findDesktopEntry(appClass) {
    const target = String(appClass).toLowerCase();
    const normalizedTarget = normalized(target);
    if (!target.length)
      return null;

    return DesktopEntries.applications.values.find(entry => {
      const id = String(entry.id || "").toLowerCase().replace(".desktop", "");
      const startupClass = String(entry.startupClass || "").toLowerCase();
      const command = entry.command || [];
      const executable = command.length ? String(command[0]).split("/").pop().toLowerCase() : "";
      return startupClass === target
        || id === target
        || normalized(startupClass) === normalizedTarget
        || normalized(id) === normalizedTarget
        || normalized(executable) === normalizedTarget;
    }) || null;
  }

  function resolveIcon(appClass, entry) {
    const original = String(appClass);
    const lower = original.toLowerCase();
    if (Quickshell.hasThemeIcon(original))
      return original;
    if (Quickshell.hasThemeIcon(lower))
      return lower;
    if (entry && entry.icon)
      return entry.icon;
    return "application-x-executable";
  }

  visible: appClass.length > 0
  implicitWidth: visible ? 24 : 0
  implicitHeight: 24

  Image {
    anchors.centerIn: parent
    width: 20
    height: 20
    source: root.visible ? Quickshell.iconPath(root.iconName, "application-x-executable") : ""
    sourceSize: Qt.size(20, 20)
    fillMode: Image.PreserveAspectFit
    asynchronous: true
  }

  Process {
    id: activeWindowProcess
    command: ["hyprctl", "activewindow", "-j"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const window = JSON.parse(text);
          root.hyprlandAppClass = window.class || window.initialClass || "";
          root.hyprlandDataReady = true;
        } catch (error) {
          root.hyprlandDataReady = false;
        }
      }
    }
  }

  Timer {
    interval: 400
    running: true
    repeat: true
    onTriggered: {
      if (!activeWindowProcess.running)
        activeWindowProcess.running = true;
    }
  }
}

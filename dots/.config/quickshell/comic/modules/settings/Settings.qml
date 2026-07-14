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
  property string page: "theme"
  property bool darkMode: true
  property string schemeType: "auto"
  property bool wifiEnabled: false
  property bool bluetoothEnabled: false
  property bool wifiLoading: false
  property bool bluetoothLoading: false
  property var wifiNetworks: []
  property var bluetoothDevices: []
  readonly property string currentSchemePath: Quickshell.env("HOME") + "/.local/state/quickshell/wallpaper/scheme.txt"
  readonly property var schemes: [
    { key: "auto", label: "Automatic" },
    { key: "scheme-tonal-spot", label: "Tonal Spot" },
    { key: "scheme-content", label: "Content" },
    { key: "scheme-expressive", label: "Expressive" },
    { key: "scheme-fidelity", label: "Fidelity" },
    { key: "scheme-fruit-salad", label: "Fruit Salad" },
    { key: "scheme-monochrome", label: "Monochrome" },
    { key: "scheme-neutral", label: "Neutral" },
    { key: "scheme-rainbow", label: "Rainbow" }
  ]

  function run(command) { Quickshell.execDetached(command); }
  function call(target, method) { run(["qs", "-c", "comic", "ipc", "call", target, method]); }
  function selectScheme(type) {
    schemeType = type;
    run(["qs", "-c", "comic", "ipc", "call", "wallpaper", "setScheme", type]);
  }

  function loadCurrentScheme() {
    const savedScheme = currentSchemeFile.text().trim();
    if (schemes.some(scheme => scheme.key === savedScheme))
      schemeType = savedScheme;
  }
  function refreshWifi() {
    wifiLoading = true;
    if (!wifiStatus.running) wifiStatus.running = true;
    if (!wifiScan.running) wifiScan.running = true;
  }
  function refreshBluetooth() {
    bluetoothLoading = true;
    if (!bluetoothStatus.running) bluetoothStatus.running = true;
    if (!bluetoothScan.running) bluetoothScan.running = true;
  }

  onOpenedChanged: {
    revealProgress = opened ? 1 : 0;
    if (opened) {
      currentSchemeFile.reload();
      refreshWifi();
      refreshBluetooth();
    }
  }

  Behavior on revealProgress { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }

  IpcHandler {
    target: "settings"
    function toggle(): void { root.opened = !root.opened; }
    function open(): void { root.opened = true; }
    function close(): void { root.opened = false; }
  }

  FileView {
    id: currentSchemeFile
    path: root.currentSchemePath
    watchChanges: true
    preload: true
    printErrors: false
    onLoaded: root.loadCurrentScheme()
    onFileChanged: reload()
  }

  Process {
    id: wifiStatus
    command: ["nmcli", "radio", "wifi"]
    stdout: StdioCollector { onStreamFinished: root.wifiEnabled = text.trim() === "enabled" }
  }
  Process {
    id: wifiScan
    command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]
    stdout: StdioCollector {
      onStreamFinished: {
        const seen = {};
        root.wifiNetworks = text.trim().split("\n").filter(line => line.length).map(line => {
          const parts = line.split(":");
          return { connected: parts[0] === "*", ssid: parts[1] || "Hidden network", signal: Number(parts[2] || 0), security: parts.slice(3).join(":") || "Open" };
        }).filter(item => { if (seen[item.ssid]) return false; seen[item.ssid] = true; return true; });
        root.wifiLoading = false;
      }
    }
  }
  Process {
    id: bluetoothStatus
    command: ["bluetoothctl", "show"]
    stdout: StdioCollector { onStreamFinished: root.bluetoothEnabled = text.includes("Powered: yes") }
  }
  Process {
    id: bluetoothScan
    command: ["bluetoothctl", "devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.bluetoothDevices = text.trim().split("\n").filter(line => line.startsWith("Device ")).map(line => {
          const parts = line.split(" ");
          return { address: parts[1], name: parts.slice(2).join(" ") || parts[1] };
        });
        root.bluetoothLoading = false;
      }
    }
  }

  PanelWindow {
    visible: root.opened || root.revealProgress > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "comic-settings"
    anchors { top: true; left: true; right: true; bottom: true }

    TapHandler {
      onTapped: eventPoint => {
        const local = settingsPanel.mapFromItem(settingsPanel.parent, eventPoint.position);
        if (!settingsPanel.contains(local)) root.opened = false;
      }
    }
    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.opened = false }

    Rectangle {
      id: settingsPanel
      anchors.centerIn: parent
      width: Math.min(900, parent.width - 24)
      height: Math.min(590, parent.height - 24)
      opacity: root.revealProgress
      scale: 0.96 + 0.04 * root.revealProgress
      radius: Appearance.radius(18)
      color: Colors.md3.surface
      border.width: 1
      border.color: Colors.md3.outline_variant
      clip: true
      TapHandler {}

      Text {
        anchors { top: parent.top; topMargin: 11; horizontalCenter: parent.horizontalCenter }
        text: "Settings"
        color: Colors.md3.on_surface
        font.pixelSize: 20
        font.bold: true
      }

      Rectangle {
        anchors { top: parent.top; right: parent.right; margins: 10 }
        width: 34; height: 34; radius: Appearance.radius(10)
        color: closeHover.hovered ? Colors.md3.surface_container_highest : "transparent"
        Text { anchors.centerIn: parent; text: "×"; color: Colors.md3.on_surface; font.pixelSize: 21; font.bold: true }
        HoverHandler { id: closeHover }
        TapHandler { onTapped: root.opened = false }
      }

      Row {
        anchors { fill: parent; topMargin: 58; leftMargin: 10; rightMargin: 10; bottomMargin: 10 }
        spacing: 10
        opacity: Math.max(0, (root.revealProgress - 0.18) / 0.82)

        Rectangle {
          width: 148
          height: parent.height
          radius: Appearance.radius(14)
          color: "transparent"

          Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 9

            Text { text: "󰍜"; color: Colors.md3.on_surface_variant; font.family: iconFont.name; font.pixelSize: 20 }
            Item { width: 1; height: 10 }

            NavButton { icon: "󰔎"; label: "Theme"; selected: root.page === "theme"; onActivated: root.page = "theme" }
            NavButton { icon: "󰤨"; label: "Wi-Fi"; selected: root.page === "wifi"; onActivated: root.page = "wifi" }
            NavButton { icon: "󰂯"; label: "Bluetooth"; selected: root.page === "bluetooth"; onActivated: root.page = "bluetooth" }

          }
        }

        Rectangle {
          width: parent.width - 158
          height: parent.height
          radius: Appearance.radius(14)
          color: Colors.md3.surface_container
          clip: true

          Column {
            anchors { fill: parent; margins: 18 }
            spacing: 14
            visible: root.page === "theme"

            Text { text: "Theme & background"; color: Colors.md3.on_surface; font.pixelSize: 22; font.bold: true }
            Text { text: "Choose the shell appearance and generated Material palette."; color: Colors.md3.on_surface_variant; font.pixelSize: 11 }

            Row {
              width: parent.width; spacing: 10
              ActionCard { width: (parent.width - 10) / 2; icon: root.darkMode ? "󰖔" : "󰖨"; title: root.darkMode ? "Dark mode" : "Light mode"; subtitle: "Change color mode"; active: true; onActivated: { root.darkMode = !root.darkMode; root.call("wallpaper", "toggleTheme"); } }
              ActionCard { width: (parent.width - 10) / 2; icon: "󰸉"; title: "Background"; subtitle: "Wallpaper and live wallpaper"; onActivated: { root.opened = false; root.call("wallpaper", "open"); } }
            }

            Text { text: "Color scheme"; color: Colors.md3.primary; font.pixelSize: 12; font.bold: true }
            Grid {
              width: parent.width; columns: 3; columnSpacing: 8; rowSpacing: 8
              Repeater {
                model: root.schemes
                Rectangle {
                  required property var modelData
                  readonly property bool selected: root.schemeType === modelData.key
                  width: (parent.width - 16) / 3; height: 38; radius: Appearance.radius(19)
                  color: selected ? Colors.md3.primary : schemeHover.hovered ? Colors.md3.surface_container_high : Colors.md3.surface_container
                  Text { anchors.centerIn: parent; width: parent.width - 12; text: modelData.label; color: parent.selected ? Colors.md3.on_primary : Colors.md3.on_surface; font.pixelSize: 11; font.bold: parent.selected; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                  HoverHandler { id: schemeHover }
                  TapHandler { onTapped: root.selectScheme(modelData.key) }
                }
              }
            }

            Text { text: "Corner rounding"; color: Colors.md3.primary; font.pixelSize: 12; font.bold: true }
            Row {
              width: parent.width
              height: 42
              spacing: 12

              Slider {
                id: roundingSlider
                width: parent.width - roundingValue.width - 12
                height: parent.height
                from: 0
                to: 32
                stepSize: 1
                value: Appearance.cornerRadius
                onMoved: Appearance.cornerRadius = value
                background: Rectangle {
                  x: roundingSlider.leftPadding
                  y: roundingSlider.topPadding + roundingSlider.availableHeight / 2 - height / 2
                  width: roundingSlider.availableWidth
                  height: 8
                  radius: Appearance.radius(4)
                  color: Colors.md3.surface_container_highest
                  Rectangle { width: parent.width * roundingSlider.visualPosition; height: parent.height; radius: parent.radius; color: Colors.md3.primary }
                }
                handle: Rectangle {
                  x: roundingSlider.leftPadding + roundingSlider.visualPosition * (roundingSlider.availableWidth - width)
                  y: roundingSlider.topPadding + roundingSlider.availableHeight / 2 - height / 2
                  width: 22; height: 22; radius: Appearance.radius(11); color: Colors.md3.primary
                }
              }

              Text {
                id: roundingValue
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(Appearance.cornerRadius) + " px"
                color: Colors.md3.on_surface
                font.pixelSize: 12
                font.bold: true
              }
            }

          }

          Column {
            anchors { fill: parent; margins: 18 }
            spacing: 12
            visible: root.page === "wifi"
            Text { text: "Wi-Fi"; color: Colors.md3.on_surface; font.pixelSize: 22; font.bold: true }
            Row {
              spacing: 8
              SmallButton { label: root.wifiEnabled ? "Turn off" : "Turn on"; active: root.wifiEnabled; onActivated: { root.run(["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]); root.wifiEnabled = !root.wifiEnabled; Qt.callLater(root.refreshWifi); } }
              SmallButton { label: root.wifiLoading ? "Scanning…" : "Rescan"; onActivated: root.refreshWifi() }
            }
            ListView {
              width: parent.width; height: 405; spacing: 7; clip: true; model: root.wifiNetworks
              delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: 60; radius: Appearance.radius(18)
                color: modelData.connected ? Colors.md3.primary_container : networkHover.hovered ? Colors.md3.surface_container_high : Colors.md3.surface_container
                Row { anchors.fill: parent; anchors.margins: 12; spacing: 12; Text { anchors.verticalCenter: parent.verticalCenter; text: "󰤨"; color: Colors.md3.on_surface; font.family: iconFont.name; font.pixelSize: 20 } Column { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; Text { width: parent.width; text: modelData.ssid; color: Colors.md3.on_surface; font.bold: true; elide: Text.ElideRight } Text { text: (modelData.connected ? "Connected  •  " : "") + modelData.signal + "%  •  " + modelData.security; color: Colors.md3.on_surface_variant; font.pixelSize: 10 } } }
                HoverHandler { id: networkHover }
                TapHandler { onTapped: root.run(["nmcli", "connection", "up", "id", modelData.ssid]) }
              }
            }
          }

          Column {
            anchors { fill: parent; margins: 18 }
            spacing: 12
            visible: root.page === "bluetooth"
            Text { text: "Bluetooth"; color: Colors.md3.on_surface; font.pixelSize: 22; font.bold: true }
            Row {
              spacing: 8
              SmallButton { label: root.bluetoothEnabled ? "Turn off" : "Turn on"; active: root.bluetoothEnabled; onActivated: { root.run(["bluetoothctl", "power", root.bluetoothEnabled ? "off" : "on"]); root.bluetoothEnabled = !root.bluetoothEnabled; Qt.callLater(root.refreshBluetooth); } }
              SmallButton { label: root.bluetoothLoading ? "Scanning…" : "Rescan"; onActivated: { root.run(["bluetoothctl", "scan", "on"]); root.refreshBluetooth(); } }
            }
            ListView {
              width: parent.width; height: 405; spacing: 7; clip: true; model: root.bluetoothDevices
              delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: 60; radius: Appearance.radius(18)
                color: deviceHover.hovered ? Colors.md3.surface_container_high : Colors.md3.surface_container
                Row { anchors.fill: parent; anchors.margins: 12; spacing: 12; Text { anchors.verticalCenter: parent.verticalCenter; text: "󰂯"; color: Colors.md3.primary; font.family: iconFont.name; font.pixelSize: 20 } Column { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 70; Text { width: parent.width; text: modelData.name; color: Colors.md3.on_surface; font.bold: true; elide: Text.ElideRight } Text { text: modelData.address; color: Colors.md3.on_surface_variant; font.pixelSize: 10 } } }
                HoverHandler { id: deviceHover }
                TapHandler { onTapped: root.run(["bluetoothctl", "connect", modelData.address]) }
              }
            }
          }
        }
      }
    }
  }

  component NavButton: Rectangle {
    id: nav
    property string icon: ""; property string label: ""; property bool selected: false; signal activated
    width: parent.width; height: 44; radius: Appearance.radius(18)
    color: selected ? Colors.md3.primary_container : navHover.hovered ? Colors.md3.surface_container_high : "transparent"
    Row { anchors.fill: parent; anchors.margins: 11; spacing: 10; Text { text: nav.icon; color: Colors.md3.on_surface; font.family: iconFont.name; font.pixelSize: 18 } Text { text: nav.label; color: Colors.md3.on_surface; font.pixelSize: 12; font.bold: nav.selected } }
    HoverHandler { id: navHover } TapHandler { onTapped: nav.activated() }
  }
  component ActionCard: Rectangle {
    id: card
    property string icon: ""; property string title: ""; property string subtitle: ""; property bool active: false; signal activated
    height: 76; radius: Appearance.radius(20); color: active ? Colors.md3.primary_container : cardHover.hovered ? Colors.md3.surface_container_high : Colors.md3.surface_container
    Row { anchors.fill: parent; anchors.margins: 12; spacing: 10; Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 42; height: 42; radius: Appearance.radius(21); color: card.active ? Colors.md3.primary : Colors.md3.surface_container_highest; Text { anchors.centerIn: parent; text: card.icon; color: card.active ? Colors.md3.on_primary : Colors.md3.on_surface; font.family: iconFont.name; font.pixelSize: 20 } } Column { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 52; Text { width: parent.width; text: card.title; color: Colors.md3.on_surface; font.bold: true; elide: Text.ElideRight } Text { width: parent.width; text: card.subtitle; color: Colors.md3.on_surface_variant; font.pixelSize: 10; elide: Text.ElideRight } } }
    HoverHandler { id: cardHover } TapHandler { onTapped: card.activated() }
  }
  component SmallButton: Rectangle {
    id: button
    property string label: ""; property bool active: false; signal activated
    width: 112; height: 36; radius: Appearance.radius(18); color: active ? Colors.md3.primary : buttonHover.hovered ? Colors.md3.surface_container_high : Colors.md3.surface_container
    Text { anchors.centerIn: parent; text: button.label; color: button.active ? Colors.md3.on_primary : Colors.md3.on_surface; font.pixelSize: 11; font.bold: true }
    HoverHandler { id: buttonHover } TapHandler { onTapped: button.activated() }
  }

  FontLoader { id: iconFont; source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf" }
}

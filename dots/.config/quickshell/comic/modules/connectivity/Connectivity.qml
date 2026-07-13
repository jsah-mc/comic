import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs.modules.common

Scope {
  id: root
  FontLoader { id: materialIcons; source: "file:///usr/share/fonts/TTF/MaterialDesignIcons.ttf" }
  property bool opened: false
  property real revealProgress: 0
  property string page: "wifi"
  property var entries: []
  property string selectedName: ""
  property string selectedSecurity: ""
  property string password: ""
  property string statusMessage: ""
  property int selectedIndex: 0
  property bool wifiEnabled: false
  property bool bluetoothEnabled: false
  property string connectedWifi: "Not connected"
  readonly property bool loading: page === "wifi" ? wifiScan.running : bluetoothScan.running

  onOpenedChanged: revealProgress = opened ? 1 : 0

  Behavior on revealProgress {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  function show(kind: string): void {
    page = kind;
    opened = true;
    refresh();
  }

  function connectWifi(name: string, security: string): void {
    selectedName = name;
    selectedSecurity = security;
    password = "";
    statusMessage = "";
    if (security === "Open" || security === "--")
      submitWifi();
  }

  function submitWifi(): void {
    const args = ["nmcli", "device", "wifi", "connect", selectedName];
    if (password.length) args.push("password", password);
    actionProcess.command = args;
    statusMessage = "Connecting…";
    actionProcess.running = true;
  }

  function connectBluetooth(address: string): void {
    statusMessage = "Pairing and connecting…";
    actionProcess.command = ["bash", "-lc", "bluetoothctl pair " + address + " && bluetoothctl trust " + address + " && bluetoothctl connect " + address];
    actionProcess.running = true;
  }

  function refresh(): void {
    wifiState.running = true;
    bluetoothState.running = true;
    if (page === "wifi") wifiScan.running = true;
    else bluetoothScan.running = true;
  }

  function toggleWifi(): void {
    toggleProcess.command = ["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"];
    toggleProcess.running = true;
  }

  function toggleBluetooth(): void {
    toggleProcess.command = ["bluetoothctl", "power", bluetoothEnabled ? "off" : "on"];
    toggleProcess.running = true;
  }

  IpcHandler {
    target: "connectivity"
    function wifi(): void { root.show("wifi"); }
    function bluetooth(): void { root.show("bluetooth"); }
    function close(): void { root.opened = false; }
  }

  Process {
    id: wifiScan
    command: ["nmcli", "--escape", "no", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]
    stdout: StdioCollector {
      onStreamFinished: root.entries = text.trim().split("\n").filter(line => line.length).map(line => {
        const p = line.split(":");
        const security = p.slice(3).join(":") || "Open";
        return { active: p[0] === "yes", name: p[1] || "Hidden network", security: security, detail: (p[2] || "0") + "%  " + security };
      })
    }
  }

  Process {
    id: wifiState
    command: ["bash", "-lc", "printf '%s\\n' \"$(nmcli radio wifi)\"; nmcli --escape no -t -f ACTIVE,SSID device wifi | sed -n 's/^yes://p' | head -n1"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        root.wifiEnabled = lines[0] === "enabled";
        root.connectedWifi = lines.length > 1 && lines[1].length ? lines[1] : "Not connected";
      }
    }
  }

  Process {
    id: bluetoothState
    command: ["bluetoothctl", "show"]
    stdout: StdioCollector { onStreamFinished: root.bluetoothEnabled = text.includes("Powered: yes") }
  }

  Process {
    id: toggleProcess
    onExited: refreshDelay.restart()
  }

  Process {
    id: bluetoothScan
    command: ["bash", "-lc", "bluetoothctl --timeout 4 scan on >/dev/null; bluetoothctl devices"]
    stdout: StdioCollector {
      onStreamFinished: root.entries = text.trim().split("\n").filter(line => line.startsWith("Device ")).map(line => {
        const p = line.split(" ");
        return { address: p[1], name: p.slice(2).join(" "), active: false, detail: p[1] };
      })
    }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { id: actionOutput }
    stderr: StdioCollector { id: actionError }
    onExited: exitCode => {
      root.statusMessage = exitCode === 0 ? "Connected" : (actionError.text.trim() || actionOutput.text.trim() || "Connection failed");
      if (exitCode === 0) {
        root.selectedName = "";
        refreshDelay.restart();
      }
    }
  }

  Timer { id: refreshDelay; interval: 800; onTriggered: root.refresh() }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.opened || root.revealProgress > 0
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
      WlrLayershell.namespace: "comic-connectivity"
      anchors { top: true; left: true; right: true; bottom: true }

      Shortcut { sequence: "Up"; enabled: root.opened && root.entries.length > 0; onActivated: root.selectedIndex = (root.selectedIndex + root.entries.length - 1) % root.entries.length }
      Shortcut { sequence: "Down"; enabled: root.opened && root.entries.length > 0; onActivated: root.selectedIndex = (root.selectedIndex + 1) % root.entries.length }
      Shortcut {
        sequence: "Return"
        enabled: root.opened && root.entries.length > 0 && !passwordField.visible
        onActivated: {
          const item = root.entries[root.selectedIndex];
          if (root.page === "wifi") root.connectWifi(item.name, item.security);
          else root.connectBluetooth(item.address);
        }
      }

      TapHandler {
        onTapped: eventPoint => {
          const local = connectivityPanel.mapFromItem(connectivityPanel.parent, eventPoint.position);
          if (!connectivityPanel.contains(local))
            root.opened = false;
        }
      }

      Rectangle {
        id: connectivityPanel
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 10 }
        width: 120 + 280 * root.revealProgress
        height: 36 + 334 * root.revealProgress
        radius: 18 + 2 * root.revealProgress
        topLeftRadius: 0
        topRightRadius: 0
        color: Colors.md3.surface
        clip: true

        TapHandler {}


        Column {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12
          opacity: Math.max(0, (root.revealProgress - 0.25) / 0.75)
          visible: opacity > 0
          Row {
            width: parent.width
            Text { width: parent.width - 40; text: root.page === "wifi" ? "Wi-Fi networks" : "Bluetooth devices"; color: Colors.md3.on_surface; font.pixelSize: 19; font.bold: true }
            Text { text: "×"; color: Colors.md3.on_surface; font.pixelSize: 24; TapHandler { onTapped: root.opened = false } }
          }
          Row {
            width: parent.width
            spacing: 8

            Rectangle {
              width: 90
              height: 34
              radius: 17
              color: (root.page === "wifi" ? root.wifiEnabled : root.bluetoothEnabled) ? Colors.md3.primary_container : Colors.md3.surface_container_high
              Text {
                anchors.centerIn: parent
                text: (root.page === "wifi" ? root.wifiEnabled : root.bluetoothEnabled) ? "On" : "Off"
                color: (root.page === "wifi" ? root.wifiEnabled : root.bluetoothEnabled) ? Colors.md3.on_primary_container : Colors.md3.on_surface
                font.bold: true
              }
              TapHandler { onTapped: root.page === "wifi" ? root.toggleWifi() : root.toggleBluetooth() }
            }

            Rectangle {
              width: root.page === "wifi" ? 90 : 120
              height: 34
              radius: 17
              color: actionHover.hovered ? Colors.md3.primary_container : Colors.md3.surface_container_high
              Text {
                anchors.centerIn: parent
                text: root.page === "wifi" ? "󰑐  Rescan" : "󰂰  Pair device"
                color: Colors.md3.on_surface
                font.family: materialIcons.name
                font.pixelSize: 12
              }
              HoverHandler { id: actionHover }
              TapHandler {
                onTapped: {
                  if (root.page === "wifi") wifiScan.running = true;
                  else bluetoothScan.running = true;
                }
              }
            }

            Text {
              visible: root.page === "wifi"
              width: parent.width - 196
              anchors.verticalCenter: parent.verticalCenter
              text: "Connected: " + root.connectedWifi
              color: Colors.md3.on_surface_variant
              font.pixelSize: 11
              elide: Text.ElideRight
            }
          }
          TextField {
            id: passwordField
            visible: root.page === "wifi" && root.selectedName.length > 0 && root.selectedSecurity !== "Open" && root.selectedSecurity !== "--"
            width: parent.width
            height: visible ? 40 : 0
            placeholderText: "Password for " + root.selectedName + " — press Enter"
            echoMode: TextInput.Password
            text: root.password
            onTextChanged: root.password = text
            color: Colors.md3.on_surface
            placeholderTextColor: Colors.md3.on_surface_variant
            leftPadding: 14
            rightPadding: 14
            background: Rectangle { radius: 20; color: passwordField.activeFocus ? Colors.md3.primary_container : Colors.md3.surface_container_high }
            onVisibleChanged: { if (visible) Qt.callLater(() => forceActiveFocus()); }
            Keys.onReturnPressed: root.submitWifi()
            Keys.onEnterPressed: root.submitWifi()
            Keys.onEscapePressed: root.opened = false
          }
          Text {
            visible: root.statusMessage.length > 0
            width: parent.width
            text: root.statusMessage
            color: root.statusMessage === "Connected" ? Colors.md3.primary : Colors.md3.on_surface_variant
            font.pixelSize: 11
            wrapMode: Text.Wrap
          }
          Flickable {
            width: parent.width
            height: parent.height - y
            contentHeight: deviceList.childrenRect.height
            clip: true
            Column {
              id: deviceList
              width: parent.width
              spacing: 6
              Repeater {
                model: root.entries
                Rectangle {
                  required property var modelData
                  required property int index
                  width: deviceList.width
                  height: 58
                  radius: 14
                  color: index === root.selectedIndex ? Colors.md3.primary_container : itemHover.hovered ? Colors.md3.surface_container_high : Colors.md3.surface_container
                  Behavior on color { ColorAnimation { duration: 120 } }
                  Row {
                    anchors.fill: parent; anchors.margins: 12; spacing: 10
                    Text { text: root.page === "wifi" ? (modelData.active ? "󰤨" : "󰤯") : "󰂯"; color: modelData.active ? Colors.md3.primary : Colors.md3.on_surface; font.family: materialIcons.name; font.pixelSize: 20 }
                    Column {
                      width: parent.width - 34
                      Text { width: parent.width; text: modelData.name; color: Colors.md3.on_surface; font.bold: true; elide: Text.ElideRight }
                      Text { width: parent.width; text: modelData.active ? "Connected" : modelData.detail; color: Colors.md3.on_surface_variant; font.pixelSize: 11; elide: Text.ElideRight }
                    }
                  }
                  HoverHandler { id: itemHover }
                  TapHandler {
                    onTapped: {
                      if (root.page === "wifi")
                        root.connectWifi(modelData.name, modelData.security);
                      else
                        root.connectBluetooth(modelData.address);
                    }
                  }
                }
              }
            }
          }
        }
        Item {
          visible: root.loading
          anchors.centerIn: parent
          width: 44
          height: 44
          Rectangle { anchors.fill: parent; radius: 22; color: Colors.md3.surface_container_high; opacity: 0.92 }
          Text {
            anchors.centerIn: parent
            text: "󰑐"
            color: Colors.md3.primary
            font.family: materialIcons.name
            font.pixelSize: 25
            RotationAnimator on rotation { from: 0; to: 360; duration: 850; loops: Animation.Infinite; running: root.loading }
          }
        }
      }

      RoundCorner {
        anchors { top: connectivityPanel.top; right: connectivityPanel.left; rightMargin: -1 }
        implicitSize: 14
        color: Colors.md3.surface
        opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopRight
      }

      RoundCorner {
        anchors { top: connectivityPanel.top; left: connectivityPanel.right; leftMargin: -1 }
        implicitSize: 14
        color: Colors.md3.surface
        opacity: root.revealProgress
        corner: RoundCorner.CornerEnum.TopLeft
      }
    }
  }
}

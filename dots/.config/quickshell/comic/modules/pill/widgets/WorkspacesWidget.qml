import Quickshell.Hyprland
import QtQuick
import qs.modules.common

Row {
  id: root

  readonly property real contentWidth: childrenRect.width
  spacing: 6

  function switchWorkspace(direction) {
    const workspaces = Hyprland.workspaces.values;
    const ids = [];

    for (let i = 0; i < workspaces.length; i++)
      ids.push(workspaces[i].id);

    ids.sort((a, b) => a - b);

    if (ids.length === 0)
      return;

    const currentId = Hyprland.focusedWorkspace?.id;
    const currentIndex = ids.indexOf(currentId);
    const nextIndex = currentIndex < 0
      ? 0
      : (currentIndex + direction + ids.length) % ids.length;

    Hyprland.dispatch("hl.dsp.workspace('" + ids[nextIndex] + "')");
  }

  WheelHandler {
    onWheel: event => {
      if (event.angleDelta.y === 0)
        return;

      root.switchWorkspace(event.angleDelta.y > 0 ? -1 : 1);
      event.accepted = true;
    }
  }

  Repeater {
    model: Hyprland.workspaces.values

    Rectangle {
      required property var modelData
      readonly property bool isFocused: modelData.id === Hyprland.focusedWorkspace?.id

      width: isFocused ? 42 : 30
      height: 28
      radius: Appearance.radius(height / 2)
      color: isFocused ? Colors.md3.primary_container
        : workspaceHover.hovered ? Colors.md3.surface_container_highest
        : Colors.md3.surface_container_high

      Behavior on width {
        NumberAnimation { duration: 140 }
      }

      Text {
        anchors.centerIn: parent
        text: modelData.id
        color: Colors.md3.on_surface
        font.pixelSize: 12
        font.bold: parent.isFocused
      }

      HoverHandler {
        id: workspaceHover
      }

      TapHandler {
        onTapped: Hyprland.dispatch("hl.dsp.focus({workspace = '" + parent.modelData.id + "' })")
      }
    }
  }
}

import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "ussego.otoru"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function openPanel() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { root.openPanel() }
  function close() { if (panelLoader.item && panelLoader.item.close) panelLoader.item.close() }
  function toggle() { root.togglePanel() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property bool isExtracting: panelLoader.item ? panelLoader.item.extracting : false
  readonly property bool isBusy: root.isExtracting || (panelLoader.item ? panelLoader.item.activeStatus === "downloading" : false)
  readonly property string downloadProgress: panelLoader.item && panelLoader.item.activeProgressPercent ? panelLoader.item.activeProgressPercent : ""

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: root.injectPanel()
  onSettingsChanged: root.injectPanel()

  // Subtle pulse on the icon while a download is running, matching the
  // owarp plugin's connecting micro-animation.
  SequentialAnimation {
    running: root.isBusy
    loops: Animation.Infinite
    onRunningChanged: if (!running && button) button.opacity = 1.0
    NumberAnimation { target: button; property: "opacity"; to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
    NumberAnimation { target: button; property: "opacity"; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf019"
    slotSize: Style.bar.statusSlot
    tooltipText: root.isExtracting ? "Extracting…" :
                 root.isBusy ? "Downloading " + root.downloadProgress : "Otoru download"

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) {
        // Future: quick settings or history. For now, toggle the panel.
        root.togglePanel()
      } else {
        root.togglePanel()
      }
    }
  }
}

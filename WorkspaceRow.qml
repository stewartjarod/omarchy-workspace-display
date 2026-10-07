import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Ui

Column {
  id: root
  required property var host
  required property string targetKey
  required property var workspace
  property string previewColor: host.colorFor(targetKey)
  property bool cursorActive: false
  property string focusSection: "style"
  property int cursorColumn: 0
  property int templateCursorIndex: 0
  readonly property bool dropdownOpen: autoLaunchDropdown.popupOpen || iconDropdown.popupOpen
  readonly property bool editingText: nameField.activeFocus
  signal pickerRequested()
  signal navigationFocusRequested()
  signal ensureCursorVisible(var item)
  width: parent ? parent.width : Style.space(300)
  height: implicitHeight
  spacing: Style.space(10)

  readonly property Item colorSwatch: swatch
  function resetCursor() {
    root.cursorActive = false
    root.focusSection = "style"
    root.cursorColumn = 0
    root.templateCursorIndex = 0
  }
  function templateCount() { return root.host.templatesFor(root.targetKey).length }
  // Cursor rows run top to bottom: style, name, new layout, auto-launch, one
  // row per layout card, then the workspace icon's Windows/Custom row and its picker.
  function navRows() {
    var rows = ["style", "icon-mode", "icon-pick", "name", "new-layout", "auto-launch"]
    for (var i = 0; i < root.templateCount(); i++) rows.push("template:" + i)
    return rows
  }
  function verticalIndex() {
    var key = root.focusSection === "template" ? "template:" + root.templateCursorIndex : root.focusSection
    return Math.max(0, root.navRows().indexOf(key))
  }
  function setVerticalIndex(index) {
    var rows = root.navRows()
    index = Math.max(0, Math.min(rows.length - 1, index))
    root.cursorColumn = 0
    var key = rows[index]
    if (key.indexOf("template:") === 0) {
      root.focusSection = "template"
      root.templateCursorIndex = Number(key.slice("template:".length))
    } else {
      root.focusSection = key
    }
  }
  function cursorItem() {
    if (root.focusSection === "style") return styleSelector.cursorItem(root.cursorColumn)
    if (root.focusSection === "name") return root.cursorColumn === 0 ? nameFrame : swatchFrame
    if (root.focusSection === "new-layout") return addLayoutButton
    if (root.focusSection === "auto-launch") return autoLaunchDropdown
    if (root.focusSection === "icon-mode") return root.cursorColumn === 0 ? windowsIconButton : customIconButton
    if (root.focusSection === "icon-pick") return iconDropdown
    var card = templateRepeater.itemAt(root.templateCursorIndex)
    return card ? card.actionItem(root.cursorColumn) : null
  }
  function revealCursor() {
    var item = root.cursorItem()
    if (item) root.ensureCursorVisible(item)
  }
  function setCursor(section, column, templateIndex) {
    root.cursorActive = true
    root.focusSection = section
    root.cursorColumn = Math.max(0, Number(column) || 0)
    if (templateIndex !== undefined) root.templateCursorIndex = Math.max(0, Number(templateIndex) || 0)
    Qt.callLater(root.revealCursor)
  }
  function movePanelCursor(dx, dy) {
    if (!root.cursorActive) { root.cursorActive = true; root.revealCursor(); return }
    if (dy !== 0) root.setVerticalIndex(root.verticalIndex() + dy)
    else if (dx !== 0) {
      var maxColumn = root.focusSection === "style" ? 2
        : (root.focusSection === "name" || root.focusSection === "icon-mode" ? 1 : (root.focusSection === "template" ? 2 : 0))
      root.cursorColumn = Math.max(0, Math.min(maxColumn, root.cursorColumn + dx))
    }
    Qt.callLater(root.revealCursor)
  }
  function activatePanelCursor() {
    if (!root.cursorActive) { root.cursorActive = true; root.revealCursor(); return }
    if (root.focusSection === "style") styleSelector.activate(root.cursorColumn)
    else if (root.focusSection === "name") {
      if (root.cursorColumn === 0) nameField.forceActiveFocus()
      else root.pickerRequested()
    } else if (root.focusSection === "new-layout") root.host.openTemplateEditor(root.targetKey, "")
    else if (root.focusSection === "auto-launch") autoLaunchDropdown.toggle()
    else if (root.focusSection === "template") {
      var card = templateRepeater.itemAt(root.templateCursorIndex)
      if (card) card.activateAction(root.cursorColumn)
    } else if (root.focusSection === "icon-mode") {
      if (root.cursorColumn === 0) windowsIconButton.clicked()
      else customIconButton.clicked()
    } else if (root.focusSection === "icon-pick") {
      if (iconDropdown.enabled) iconDropdown.toggle()
    }
  }
  // Whichever picker is open owns the arrow keys and Enter.
  function openDropdown() {
    if (autoLaunchDropdown.popupOpen) return autoLaunchDropdown
    return iconDropdown.popupOpen ? iconDropdown : null
  }
  function moveDropdownCursor(delta) { if (root.openDropdown()) root.openDropdown().moveCursor(delta) }
  function activateDropdownCursor() { if (root.openDropdown()) root.openDropdown().activateCursor() }
  function closeDropdown() { if (root.openDropdown()) root.openDropdown().close() }
  function autoLaunchOptions() {
    var options = [{ value: "", label: "Off" }]
    var templates = root.host.templatesFor(root.targetKey)
    for (var i = 0; i < templates.length; i++)
      options.push({ value: templates[i].id, label: templates[i].name })
    return options
  }
  Text {
    width: parent.width
    text: root.host.targetLabel(root.targetKey)
    color: root.host.foreground
    font.family: root.host.bar ? root.host.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.heading
    font.weight: Font.DemiBold
  }
  PanelSeparator {
    foreground: root.host.bar ? root.host.bar.foreground : Color.foreground
  }
  PanelSectionHeader {
    text: "DISPLAY"
    foreground: root.host.bar ? root.host.bar.foreground : Color.foreground
    fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
  }
  Row {
    width: parent.width; spacing: Style.space(6); height: Style.space(36)
    StyleSelector {
      id: styleSelector
      width: parent.width
      value: root.host.styleFor(root.targetKey)
      fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
      labelFontSize: Style.font.caption
      cursorActive: root.cursorActive && root.focusSection === "style"
      cursorIndex: root.cursorColumn
      anchors.verticalCenter: parent.verticalCenter
      onSelected: function(value) { root.host.setStyle(root.targetKey, value) }
      onHovered: function(index, hovered) { if (hovered) root.setCursor("style", index) }
    }
  }
  // Windows: each window on this workspace shows its own icon.
  // Custom: this workspace shows the icon picked below instead.
  PanelSectionHeader {
    text: "WORKSPACE ICON"
    foreground: root.host.bar ? root.host.bar.foreground : Color.foreground
    fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
  }
  Row {
    id: iconModeRow
    readonly property bool custom: root.host.iconKeyFor(root.targetKey) !== ""
    width: parent.width
    height: Style.space(36)
    spacing: Style.space(6)
    Button {
      id: windowsIconButton
      width: (iconModeRow.width - iconModeRow.spacing) / 2
      height: iconModeRow.height
      text: "Windows"
      selected: !iconModeRow.custom
      fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
      fontSize: Style.font.caption
      hasCursor: root.cursorActive && root.focusSection === "icon-mode" && root.cursorColumn === 0
      onHovered: function(hovered) { if (hovered) root.setCursor("icon-mode", 0) }
      onClicked: root.host.setIcon(root.targetKey, "")
    }
    Button {
      id: customIconButton
      width: (iconModeRow.width - iconModeRow.spacing) / 2
      height: iconModeRow.height
      text: "Custom"
      selected: iconModeRow.custom
      fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
      fontSize: Style.font.caption
      hasCursor: root.cursorActive && root.focusSection === "icon-mode" && root.cursorColumn === 1
      onHovered: function(hovered) { if (hovered) root.setCursor("icon-mode", 1) }
      onClicked: root.host.setIcon(root.targetKey, root.host.iconKeyFor(root.targetKey) || root.host.iconChoices()[0].value)
    }
  }
  WorkspaceDropdown {
    id: iconDropdown
    width: parent.width
    showLabel: false
    enabled: iconModeRow.custom
    opacity: enabled ? 1 : 0.4
    value: root.host.iconKeyFor(root.targetKey) || root.host.iconChoices()[0].value
    options: root.host.iconChoices()
    foreground: root.host.foreground
    fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
    hasCursor: root.cursorActive && root.focusSection === "icon-pick"
    onHovered: function(hovered) { if (hovered) root.setCursor("icon-pick", 0) }
    onChanged: function(key) { root.host.setIcon(root.targetKey, key) }
  }
  PanelSeparator {
    foreground: root.host.bar ? root.host.bar.foreground : Color.foreground
  }
  PanelSectionHeader {
    text: "NAME"
    foreground: root.host.bar ? root.host.bar.foreground : Color.foreground
    fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
  }
  Row {
    id: editorRow
    width: parent.width
    spacing: Style.space(6)
    Item {
      id: nameFrame
      width: parent.width - swatchFrame.width - parent.spacing
      height: Style.space(32)
      TextField {
        id: nameField
        anchors.fill: parent
        hasCursor: root.cursorActive && root.focusSection === "name" && root.cursorColumn === 0 && !activeFocus
        verticalPadding: Style.space(1)
        font.family: root.host.bar ? root.host.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        text: root.host.nameFor(root.targetKey)
        placeholderText: root.host.targetFallbackLabel(root.targetKey)
        background: BorderSurface {
          color: Style.controlFill(nameField.activeFocus, nameField.hasCursor, nameField.foreground, nameField.accent)
          borderSpec: (nameField.activeFocus || nameField.hasCursor)
            ? Border.controlSpec(nameField.activeFocus ? "focus" : "hover-cursor", nameField.foreground, nameField.accent)
            : Border.none()
          radius: Style.cornerRadius
        }
        onActiveFocusChanged: if (activeFocus) root.setCursor("name", 0)
        onEditingFinished: root.host.setName(root.targetKey, text)
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.host.setName(root.targetKey, text)
            root.navigationFocusRequested()
            event.accepted = true
          } else if (event.key === Qt.Key_Escape) {
            text = root.host.nameFor(root.targetKey)
            root.navigationFocusRequested()
            event.accepted = true
          }
        }
      }
      HoverHandler { onHoveredChanged: if (hovered) root.setCursor("name", 0) }
    }
    CursorSurface {
      id: swatchFrame
      // Keep the swatch square, but align its full height with the name field.
      width: nameFrame.height
      height: nameFrame.height
      anchors.verticalCenter: parent.verticalCenter
      hasCursor: root.cursorActive && root.focusSection === "name" && root.cursorColumn === 1
      foreground: root.host.foreground
      bordered: true
      Rectangle {
        id: swatch
        anchors.fill: parent
        anchors.margins: Math.max(1, Style.space(2))
        color: root.previewColor !== "" ? root.previewColor : Color.accent
      }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) root.setCursor("name", 1)
        onClicked: root.pickerRequested()
      }
    }
  }

  PanelSeparator {
    foreground: root.host.bar ? root.host.bar.foreground : Color.foreground
  }
  Column {
    width: parent.width
    spacing: Style.space(6)
    Row {
      width: parent.width
      spacing: Style.space(8)
      PanelSectionHeader {
        text: "LAUNCH LAYOUTS"
        width: parent.width - addLayoutButton.width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        foreground: root.host.bar ? root.host.bar.foreground : Color.foreground
        fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
      }
      Button {
        id: addLayoutButton
        text: "+ New Layout"
        fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
        fontSize: Style.font.caption
        hasCursor: root.cursorActive && root.focusSection === "new-layout"
        onHovered: function(hovered) { if (hovered) root.setCursor("new-layout", 0) }
        onClicked: root.host.openTemplateEditor(root.targetKey, "")
      }
    }

    PanelSectionHeader {
      text: "AUTO-LAUNCH AT LOGIN"
      foreground: root.host.bar ? root.host.bar.foreground : Color.foreground
      fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
    }
  }
  WorkspaceDropdown {
    id: autoLaunchDropdown
    width: parent.width
    showLabel: false
    value: root.host.autoLaunchTemplateIdFor(root.targetKey)
    options: root.autoLaunchOptions()
    foreground: root.host.foreground
    fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
    hasCursor: root.cursorActive && root.focusSection === "auto-launch"
    onHovered: function(hovered) { if (hovered) root.setCursor("auto-launch", 0) }
    onChanged: function(templateId) {
      root.host.setAutoLaunchTemplateId(root.targetKey, templateId)
    }
  }

  Repeater {
    id: templateRepeater
    model: root.host.templatesFor(root.targetKey)
    BorderSurface {
      id: templateCard
      required property var modelData
      required property int index
      property bool deleteArmed: false
      readonly property bool isRunning: root.host.launchActive && root.host.launchTargetKey === root.targetKey
      function actionItem(action) {
        return action === 0 ? launchButton : (action === 1 ? editButton : deleteButton)
      }
      function activateAction(action) {
        var item = actionItem(action)
        if (item && item.enabled) item.clicked()
      }
      width: root.width
      implicitHeight: Style.space(56)
      height: implicitHeight
      radius: Style.cornerRadius
      color: Util.alpha(Color.foreground, 0.05)
      borderSpec: Border.none()

      Text {
        id: layoutIcon
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(24)
        textFormat: Text.PlainText
        text: String(templateCard.modelData.layoutType) === "scrolling" ? "󰕭" : "󰕮"
        color: root.host.foreground
        horizontalAlignment: Text.AlignHCenter
        font.family: root.host.bar ? root.host.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.title
      }

      Row {
        id: actionButtons
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        PanelActionButton {
          id: launchButton
          size: Style.space(32)
          iconText: templateCard.isRunning ? "󰑐" : "󰐊"
          tooltipText: templateCard.isRunning ? "Launching layout" : "Launch layout"
          enabled: root.host.canLaunch(root.targetKey)
          fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
          fontSize: Style.font.title
          foreground: root.host.foreground
          focusable: true
          hasCursor: root.cursorActive && root.focusSection === "template" && root.templateCursorIndex === templateCard.index && root.cursorColumn === 0
          onHovered: function(hovered) { if (hovered) root.setCursor("template", 0, templateCard.index) }
          onClicked: root.host.launchTemplate(root.targetKey, templateCard.modelData.id)
        }

        PanelActionButton {
          id: editButton
          size: Style.space(32)
          iconText: "󰏫"
          tooltipText: "Edit layout"
          fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
          fontSize: Style.font.title
          foreground: root.host.foreground
          focusable: true
          hasCursor: root.cursorActive && root.focusSection === "template" && root.templateCursorIndex === templateCard.index && root.cursorColumn === 1
          onHovered: function(hovered) { if (hovered) root.setCursor("template", 1, templateCard.index) }
          onClicked: root.host.openTemplateEditor(root.targetKey, templateCard.modelData.id)
        }

        PanelActionButton {
          id: deleteButton
          size: Style.space(32)
          iconText: templateCard.deleteArmed ? "󰄬" : "󰆴"
          tooltipText: templateCard.deleteArmed ? "Confirm delete" : "Delete layout"
          fontFamily: root.host.bar ? root.host.bar.fontFamily : Style.font.family
          fontSize: Style.font.title
          foreground: templateCard.deleteArmed ? Color.urgent : root.host.foreground
          hoverColor: Color.urgent
          focusable: true
          hasCursor: root.cursorActive && root.focusSection === "template" && root.templateCursorIndex === templateCard.index && root.cursorColumn === 2
          onHovered: function(hovered) { if (hovered) root.setCursor("template", 2, templateCard.index) }
          onClicked: {
            if (templateCard.deleteArmed) {
              deleteArmTimeout.stop()
              root.host.removeTemplate(root.targetKey, templateCard.modelData.id)
            } else {
              templateCard.deleteArmed = true
              deleteArmTimeout.restart()
            }
          }
        }
      }

      Timer {
        id: deleteArmTimeout
        interval: 3000
        onTriggered: templateCard.deleteArmed = false
      }

      Column {
        anchors.left: layoutIcon.right
        anchors.leftMargin: Style.space(10)
        anchors.right: autoBadge.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Row {
          width: parent.width
          spacing: Style.space(6)

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: String(templateCard.modelData.name || "Launch layout")
            color: root.host.foreground
            elide: Text.ElideRight
            font.family: root.host.bar ? root.host.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }

        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.host.templateLayoutLabel(templateCard.modelData) + " · " + root.host.templateAppCount(templateCard.modelData) + " apps"
          color: root.host.foreground
          opacity: 0.62
          elide: Text.ElideRight
          font.family: root.host.bar ? root.host.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Rectangle {
        id: autoBadge
        visible: root.host.autoLaunchTemplateIdFor(root.targetKey) === templateCard.modelData.id
        anchors.right: actionButtons.left
        anchors.rightMargin: Style.space(8)
        width: visible ? autoBadgeText.implicitWidth + Style.space(8) : 0
        height: Style.space(16)
        y: Math.round((templateCard.height - height) / 2)
        radius: Style.cornerRadius
        color: Util.alpha(Color.accent, 0.16)
        border.width: Math.max(1, Style.space(1))
        border.color: Color.accent

        Text {
          id: autoBadgeText
          anchors.centerIn: parent
          text: "AUTO"
          color: Color.accent
          font.family: root.host.bar ? root.host.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

    }
  }

  Text {
    visible: !root.host.canLaunch(root.targetKey) && !root.host.launchActive && root.host.templatesFor(root.targetKey).length > 0
    width: parent.width
    text: "Close existing windows on " + root.host.targetLabel(root.targetKey) + " to launch a saved layout."
    color: root.host.foreground
    opacity: 0.72
    wrapMode: Text.WordWrap
    font.family: root.host.bar ? root.host.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.caption
  }

  Text {
    visible: root.host.launchNotice !== ""
    width: parent.width
    text: root.host.launchNotice
    color: root.host.launchNoticeIsError ? Color.urgent : Color.accent
    wrapMode: Text.WordWrap
    font.family: root.host.bar ? root.host.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.caption
  }
}

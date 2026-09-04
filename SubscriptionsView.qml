import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var hostWidget: null
  property var subscriptions: []
  property color contentForeground: Color.foreground
  property string contentFontFamily: Style.font.family

  property string filterQuery: ""
  property bool showAddComposer: false
  property string draftUrl: ""
  property string draftTitle: ""
  property string draftCategory: ""
  property string editingUrl: ""
  readonly property bool isEditing: Boolean(root.editingUrl)
  property string selectedCategory: ""
  property bool isCustomCategoryMode: false
  property bool categoryDropdownOpen: false
  property string customCategoryText: ""
  readonly property int addComposerHeight: Style.space(110)

  property string statusMessage: ""
  property bool statusIsError: false

  onVisibleChanged: {
    if (!root.visible) {
      root.statusMessage = ""
      root.statusIsError = false
      root.showAddComposer = false
      root.draftUrl = ""
      root.draftTitle = ""
      root.draftCategory = ""
      root.editingUrl = ""
      root.selectedCategory = ""
      root.isCustomCategoryMode = false
      root.categoryDropdownOpen = false
      root.customCategoryText = ""
    }
  }

  signal backRequested()
  signal subscriptionsUpdated(var nextSubs)

  readonly property var filteredSubs: {
    var list = root.subscriptions || []
    var q = root.filterQuery.trim().toLowerCase()
    if (!q) return list
    var out = []
    for (var i = 0; i < list.length; i++) {
      var s = list[i]
      var hay = [s.title, s.url, s.category].join(" ").toLowerCase()
      if (hay.indexOf(q) !== -1) out.push(s)
    }
    return out
  }

  function resetComposer() {
    root.draftUrl = ""
    root.draftTitle = ""
    root.draftCategory = ""
    root.editingUrl = ""
    root.selectedCategory = ""
    root.isCustomCategoryMode = false
    root.categoryDropdownOpen = false
    root.customCategoryText = ""
  }

  function startAddFeed() {
    root.resetComposer()
    root.showAddComposer = true
    root.statusMessage = ""
  }

  function startEditFeed(sub) {
    if (!sub) return
    root.draftUrl = sub.url || ""
    root.draftTitle = sub.title || ""
    root.draftCategory = sub.category || ""
    root.editingUrl = sub.url || ""
    root.selectedCategory = sub.category || ""
    root.isCustomCategoryMode = false
    root.categoryDropdownOpen = false
    root.customCategoryText = ""
    root.showAddComposer = true
    root.statusMessage = ""
  }

  function saveFeed() {
    console.log("[RSS-CLIENT] saveFeed entered with draftUrl:", root.draftUrl, "editing:", root.editingUrl)
    var catToSave = root.isCustomCategoryMode ? root.customCategoryText : (root.selectedCategory || root.draftCategory)
    var res = root.isEditing
      ? Model.updateSubscription(root.subscriptions, root.editingUrl, root.draftUrl, root.draftTitle, catToSave)
      : Model.addSubscription(root.subscriptions, root.draftUrl, root.draftTitle, catToSave)
    if (!res.ok) {
      console.log("[RSS-CLIENT] saveFeed failed:", res.error)
      root.statusMessage = res.error
      root.statusIsError = true
      return
    }

    var saved = root.isEditing ? res.updatedSub : res.newSub
    root.statusMessage = (root.isEditing ? "Updated " : "Added ") + (saved.title || saved.url)
    root.statusIsError = false
    root.resetComposer()
    root.showAddComposer = false

    if (root.hostWidget && typeof root.hostWidget.updateSubscriptions === "function") {
      root.hostWidget.updateSubscriptions(res.subscriptions)
    }
    root.subscriptionsUpdated(res.subscriptions)
  }

  function removeSub(sub) {
    var res = Model.removeSubscription(root.subscriptions, sub.url)
    if (res.ok) {
      root.statusMessage = "Removed " + (sub.title || sub.url)
      root.statusIsError = false
      if (root.hostWidget && typeof root.hostWidget.updateSubscriptions === "function") {
        root.hostWidget.updateSubscriptions(res.subscriptions)
      }
      root.subscriptionsUpdated(res.subscriptions)
    }
  }

  Column {
    anchors.fill: parent
    spacing: Style.space(8)

    // 1. Header Bar
    Item {
      width: parent.width
      height: Style.space(32)

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        // Back Button
        Rectangle {
          width: Style.space(28)
          height: Style.space(28)
          radius: Style.space(4)
          color: backHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰁍"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.subtitle
            color: root.contentForeground
          }

          MouseArea {
            id: backHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backRequested()
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Subscriptions"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          color: root.contentForeground
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "(" + (root.subscriptions || []).length + ")"
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.45)
        }
      }

      // Add Button
      Rectangle {
        id: addBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Style.space(26)
        width: addText.implicitWidth + Style.space(16)
        radius: Style.space(4)
        color: root.showAddComposer
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
          : (addHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04))
        border.color: root.showAddComposer ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
        border.width: 1

        Row {
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.showAddComposer ? "󰅖" : "󰐕"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            color: root.showAddComposer ? Color.accent : root.contentForeground
          }

          Text {
            id: addText
            anchors.verticalCenter: parent.verticalCenter
            text: root.showAddComposer ? "Cancel" : "Add feed"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.showAddComposer ? Color.accent : root.contentForeground
          }
        }

        MouseArea {
          id: addHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.showAddComposer) {
              root.resetComposer()
              root.showAddComposer = false
            } else {
              root.startAddFeed()
            }
          }
        }
      }
    }

    // Status / Feedback Banner
    Rectangle {
      visible: Boolean(root.statusMessage)
      width: parent.width
      height: Style.space(24)
      radius: Style.space(4)
      color: root.statusIsError ? Qt.rgba(1.0, 0.2, 0.2, 0.12) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
      border.color: root.statusIsError ? Qt.rgba(1.0, 0.2, 0.2, 0.35) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
      border.width: 1

      Row {
        anchors.centerIn: parent
        spacing: Style.space(6)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.statusIsError ? "󰅚" : "󰄬"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          color: root.statusIsError ? "#ff6b6b" : Color.accent
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.statusMessage
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          color: root.statusIsError ? "#ff6b6b" : Color.accent
        }
      }
    }

    // 2. Add Composer (when toggled)
    Rectangle {
      visible: root.showAddComposer
      width: parent.width
      height: root.addComposerHeight
      radius: Style.space(6)
      color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
      border.width: 1
      z: 50

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(6)

        // URL input
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
          border.color: urlInput.activeFocus ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
          border.width: 1

          TextInput {
            id: urlInput
            anchors.fill: parent
            anchors.margins: Style.space(4)
            text: root.draftUrl
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            color: root.contentForeground
            onTextChanged: {
              root.draftUrl = text
              if (root.statusIsError) root.statusMessage = ""
            }
            onAccepted: root.saveFeed()
            Keys.onReturnPressed: root.saveFeed()
            Keys.onEnterPressed: root.saveFeed()
            selectByMouse: true

            Text {
              anchors.fill: parent
              text: "Feed URL (https://...)"
              textFormat: Text.PlainText
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.3)
              visible: !urlInput.text && !urlInput.activeFocus
            }
          }
        }

        // Title, Category selector, and Save button
        Row {
          width: parent.width
          spacing: Style.space(6)

          Rectangle {
            width: (parent.width - Style.space(80) - Style.space(12)) / 2
            height: Style.space(28)
            radius: Style.space(4)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
            border.color: titleInput.activeFocus ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
            border.width: 1

            TextInput {
              id: titleInput
              anchors.fill: parent
              anchors.margins: Style.space(4)
              text: root.draftTitle
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              color: root.contentForeground
              onTextChanged: root.draftTitle = text
              onAccepted: root.saveFeed()
              Keys.onReturnPressed: root.saveFeed()
              Keys.onEnterPressed: root.saveFeed()
              selectByMouse: true

              Text {
                anchors.fill: parent
                text: "Title (optional)"
                textFormat: Text.PlainText
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.3)
                visible: !titleInput.text && !titleInput.activeFocus
              }
            }
          }

          // Category Selector or Custom Input
          Item {
            id: categorySelector
            width: (parent.width - Style.space(80) - Style.space(12)) / 2
            height: Style.space(28)
            z: 30

            // Custom category input mode
            Rectangle {
              visible: root.isCustomCategoryMode
              anchors.fill: parent
              radius: Style.space(4)
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
              border.color: customCatInput.activeFocus ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
              border.width: 1

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(4)
                spacing: Style.space(2)

                TextInput {
                  id: customCatInput
                  width: parent.width - Style.space(20)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.customCategoryText
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  color: root.contentForeground
                  onTextChanged: root.customCategoryText = text
                  onAccepted: root.saveFeed()
                  Keys.onReturnPressed: root.saveFeed()
                  Keys.onEnterPressed: root.saveFeed()
                  selectByMouse: true

                  Text {
                    anchors.fill: parent
                    text: "New category..."
                    textFormat: Text.PlainText
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.35)
                    visible: !customCatInput.text && !customCatInput.activeFocus
                  }
                }

                Rectangle {
                  width: Style.space(18)
                  height: Style.space(18)
                  radius: Style.space(3)
                  anchors.verticalCenter: parent.verticalCenter
                  color: cancelCustomHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.15) : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.6)
                  }

                  MouseArea {
                    id: cancelCustomHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.isCustomCategoryMode = false
                      root.customCategoryText = ""
                    }
                  }
                }
              }
            }

            // Dropdown Selector Button
            Rectangle {
              visible: !root.isCustomCategoryMode
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: Style.space(28)
              radius: Style.space(4)
              color: catBtnHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
              border.color: root.categoryDropdownOpen ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
              border.width: 1

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(4)

                Text {
                  width: parent.width - Style.space(18)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.selectedCategory ? root.selectedCategory : "Category: None"
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: Boolean(root.selectedCategory)
                  color: root.selectedCategory ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.65)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.categoryDropdownOpen ? "󰅃" : "󰅀"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.5)
                }
              }

              MouseArea {
                id: catBtnHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.categoryDropdownOpen = !root.categoryDropdownOpen
              }
            }

          }

          Rectangle {
            width: Style.space(80)
            height: Style.space(28)
            radius: Style.space(4)
            readonly property bool canSave: Boolean(String(root.draftUrl || "").trim())
            color: canSave ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
            opacity: canSave ? 1.0 : 0.4

            Text {
              anchors.centerIn: parent
              text: root.isEditing ? "Update" : "Save"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              color: Color.background
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: parent.canSave ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.saveFeed()
            }
          }
        }
      }
    }

    // 3. Search Bar
    SearchField {
      width: parent.width
      placeholderText: "Search subscriptions..."
      contentForeground: root.contentForeground
      contentFontFamily: root.contentFontFamily
      onTextChanged: root.filterQuery = text
      onCleared: root.filterQuery = ""
    }

    // 4. Subscriptions List
    ListView {
      id: subListView
      width: parent.width
      height: parent.height - Style.space(32) - (root.showAddComposer ? root.addComposerHeight + Style.space(8) : 0) - Style.space(36) - Style.space(8)
      model: root.filteredSubs
      spacing: Style.space(4)
      clip: true

      delegate: Rectangle {
        id: subRow
        width: subListView.width
        height: Style.space(46)
        radius: Style.space(4)
        color: rowHover.containsMouse
          ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
          : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.02)
        border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
        border.width: 1

        MouseArea {
          id: rowHover
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
        }

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          // Feed details (Title, Domain)
          Column {
            width: parent.width - (catBadge.visible ? catBadge.width + Style.space(8) : 0) - Style.space(60)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
              width: parent.width
              text: modelData.title || modelData.url
              elide: Text.ElideRight
              textFormat: Text.PlainText
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              color: modelData.enabled !== false ? root.contentForeground : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)
            }

            Text {
              width: parent.width
              text: modelData.url
              elide: Text.ElideRight
              textFormat: Text.PlainText
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)
            }
          }

          // Category Badge Pill
          Rectangle {
            id: catBadge
            visible: Boolean(modelData.category)
            height: Style.space(20)
            width: catBadgeText.implicitWidth + Style.space(10)
            radius: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
            border.width: 1

            Text {
              id: catBadgeText
              anchors.centerIn: parent
              text: modelData.category || ""
              textFormat: Text.PlainText
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Color.accent
            }
          }

          // Edit button
          Rectangle {
            width: Style.space(26)
            height: Style.space(26)
            radius: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            color: editHover.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : "transparent"

            Text {
              anchors.centerIn: parent
              text: "󰏫"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              color: editHover.containsMouse ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.45)
            }

            MouseArea {
              id: editHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.startEditFeed(modelData)
            }
          }

          // Delete button
          Rectangle {
            width: Style.space(26)
            height: Style.space(26)
            radius: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            color: delHover.containsMouse ? Qt.rgba(Color.negative.r, Color.negative.g, Color.negative.b, 0.15) : "transparent"

            Text {
              anchors.centerIn: parent
              text: "󰆴"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              color: delHover.containsMouse ? Color.negative : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.35)
            }

            MouseArea {
              id: delHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.removeSub(modelData)
            }
          }
        }
      }
    }
  }

  // Root-level dropdown overlay. This avoids changing the Column/Row layout
  // while keeping the popup in an item whose bounds cover the click target.
  Item {
    id: dropdownOverlay
    anchors.fill: parent
    visible: root.categoryDropdownOpen && !root.isCustomCategoryMode
    z: 1000

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      onClicked: root.categoryDropdownOpen = false
    }

    Rectangle {
      // mapToItem() is unreliable here because this overlay is a sibling of
      // the form content in Quickshell's panel tree. Compute the same visual
      // position from the add-composer row geometry instead: left margin +
      // title field width + row spacing.
      x: Style.space(8) + ((dropdownOverlay.width - Style.space(16) - Style.space(80) - Style.space(12)) / 2) + Style.space(6)
      y: Style.space(32) + (root.statusMessage ? Style.space(32) : 0) + Style.space(8) + Style.space(8) + Style.space(28) + Style.space(6) + Style.space(32)
      width: categorySelector.width
      height: Math.min(Style.space(200), overlayCatMenuColumn.implicitHeight + Style.space(8))
      radius: Style.space(4)
      color: Color.background
      border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.2)
      border.width: 1
      clip: true

      Flickable {
        anchors.fill: parent
        anchors.margins: Style.space(4)
        contentHeight: overlayCatMenuColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: overlayCatMenuColumn
          width: parent.width
          spacing: Style.space(2)

          Rectangle {
            width: parent.width
            height: Style.space(24)
            radius: Style.space(3)
            color: overlayNoCatHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : (!root.selectedCategory ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : "transparent")

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              text: "No category"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: !root.selectedCategory
              color: !root.selectedCategory ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.7)
            }

            MouseArea {
              id: overlayNoCatHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.selectedCategory = ""
                root.categoryDropdownOpen = false
              }
            }
          }

          Repeater {
            model: Model.getAvailableCategories(root.subscriptions)
            delegate: Rectangle {
              width: overlayCatMenuColumn.width
              height: Style.space(24)
              radius: Style.space(3)
              readonly property bool isSelected: root.selectedCategory === modelData.display || root.selectedCategory === modelData.name
              color: overlayCatItemHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : (isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : "transparent")

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(6)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.display
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: isSelected
                color: isSelected ? Color.accent : root.contentForeground
              }

              MouseArea {
                id: overlayCatItemHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selectedCategory = modelData.display
                  root.categoryDropdownOpen = false
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
          }

          Rectangle {
            width: parent.width
            height: Style.space(24)
            radius: Style.space(3)
            color: overlayNewCatBtnHover.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : "transparent"

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              text: "+ Create new category"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Color.accent
            }

            MouseArea {
              id: overlayNewCatBtnHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.isCustomCategoryMode = true
                root.categoryDropdownOpen = false
                root.customCategoryText = ""
              }
            }
          }
        }
      }
    }
  }
}

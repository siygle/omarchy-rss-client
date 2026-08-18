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

  function addFeed() {
    var url = String(root.draftUrl || "").trim()
    if (!Model.isHttpsUrl(url)) return

    var title = String(root.draftTitle || "").trim() || Model.extractDomainTitle(url)
    var cat = String(root.draftCategory || "").trim()
    var catPath = cat ? [cat] : []

    var newSub = {
      url: url,
      title: title,
      categoryPath: catPath,
      category: cat,
      enabled: true
    }

    var next = Model.mergeSubscriptions(root.subscriptions, [newSub])
    root.subscriptions = next
    if (root.hostWidget && typeof root.hostWidget.updateSubscriptions === "function") {
      root.hostWidget.updateSubscriptions(next)
    }
    root.draftUrl = ""
    root.draftTitle = ""
    root.draftCategory = ""
    root.showAddComposer = false
  }

  function toggleSubEnabled(sub) {
    var next = []
    for (var i = 0; i < root.subscriptions.length; i++) {
      var s = root.subscriptions[i]
      if (s.url === sub.url) {
        next.push({
          url: s.url,
          title: s.title,
          categoryPath: s.categoryPath,
          category: s.category,
          enabled: !s.enabled
        })
      } else {
        next.push(s)
      }
    }
    root.subscriptions = next
    if (root.hostWidget && typeof root.hostWidget.updateSubscriptions === "function") {
      root.hostWidget.updateSubscriptions(next)
    }
  }

  function removeSub(sub) {
    var next = []
    for (var i = 0; i < root.subscriptions.length; i++) {
      if (root.subscriptions[i].url !== sub.url) {
        next.push(root.subscriptions[i])
      }
    }
    root.subscriptions = next
    if (root.hostWidget && typeof root.hostWidget.updateSubscriptions === "function") {
      root.hostWidget.updateSubscriptions(next)
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
          onClicked: root.showAddComposer = !root.showAddComposer
        }
      }
    }

    // 2. Add Composer (when toggled)
    Rectangle {
      visible: root.showAddComposer
      width: parent.width
      height: Style.space(110)
      radius: Style.space(6)
      color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
      border.width: 1

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
            onTextChanged: root.draftUrl = text
            selectByMouse: true

            Text {
              anchors.fill: parent
              text: "Feed URL (https://...)"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.3)
              visible: !urlInput.text && !urlInput.activeFocus
            }
          }
        }

        // Title and Category inputs row + Submit button
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
              selectByMouse: true

              Text {
                anchors.fill: parent
                text: "Title (optional)"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.3)
                visible: !titleInput.text && !titleInput.activeFocus
              }
            }
          }

          Rectangle {
            width: (parent.width - Style.space(80) - Style.space(12)) / 2
            height: Style.space(28)
            radius: Style.space(4)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
            border.color: catInput.activeFocus ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
            border.width: 1

            TextInput {
              id: catInput
              anchors.fill: parent
              anchors.margins: Style.space(4)
              text: root.draftCategory
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              color: root.contentForeground
              onTextChanged: root.draftCategory = text
              selectByMouse: true

              Text {
                anchors.fill: parent
                text: "Category (optional)"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.3)
                visible: !catInput.text && !catInput.activeFocus
              }
            }
          }

          Rectangle {
            width: Style.space(80)
            height: Style.space(28)
            radius: Style.space(4)
            color: Model.isHttpsUrl(root.draftUrl) ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
            opacity: Model.isHttpsUrl(root.draftUrl) ? 1.0 : 0.4

            Text {
              anchors.centerIn: parent
              text: "Save"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              color: Color.background
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Model.isHttpsUrl(root.draftUrl) ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                if (Model.isHttpsUrl(root.draftUrl)) root.addFeed()
              }
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
      height: parent.height - Style.space(32) - (root.showAddComposer ? Style.space(118) : 0) - Style.space(36) - Style.space(8)
      model: root.filteredSubs
      spacing: Style.space(4)
      clip: true

      delegate: Rectangle {
        width: subListView.width
        height: Style.space(46)
        radius: Style.space(4)
        color: feedMouse.containsMouse
          ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
          : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.02)
        border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
        border.width: 1

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          // Enable/Disable toggle indicator
          Rectangle {
            width: Style.space(18)
            height: Style.space(18)
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: modelData.enabled !== false ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"
            border.color: modelData.enabled !== false ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.2)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData.enabled !== false ? "●" : ""
              font.pixelSize: Style.font.caption
              color: Color.accent
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleSubEnabled(modelData)
            }
          }

          // Feed details (Title, Domain)
          Column {
            width: parent.width - Style.space(30) - (catBadge.visible ? catBadge.width + Style.space(8) : 0) - Style.space(30)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
              width: parent.width
              text: modelData.title || modelData.url
              elide: Text.ElideRight
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              color: modelData.enabled !== false ? root.contentForeground : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)
            }

            Text {
              width: parent.width
              text: modelData.url
              elide: Text.ElideRight
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
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Color.accent
            }
          }

          // Delete button
          Rectangle {
            width: Style.space(24)
            height: Style.space(24)
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

        MouseArea {
          id: feedMouse
          anchors.fill: parent
          hoverEnabled: true
        }
      }
    }
  }
}

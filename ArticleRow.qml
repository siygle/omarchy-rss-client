import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var item: ({})
  property bool isRead: false
  property bool isSelected: false
  property string categoryName: ""
  property color contentForeground: Color.foreground
  property string contentFontFamily: Style.font.family

  signal activated()
  signal toggleRead()

  height: Style.space(48)
  width: parent ? parent.width : 300

  readonly property color mutedColor: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.45)
  readonly property bool hovered: mouseArea.containsMouse

  Rectangle {
    anchors.fill: parent
    radius: Style.space(4)
    color: root.isSelected
      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.14)
      : (root.hovered ? Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.05) : "transparent")

    Behavior on color { ColorAnimation { duration: 80 } }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    spacing: Style.space(8)

    // Unread dot indicator
    Item {
      width: Style.space(8)
      height: parent.height

      Rectangle {
        anchors.centerIn: parent
        width: root.isRead ? Style.space(4) : Style.space(6)
        height: width
        radius: width / 2
        color: root.isRead ? "transparent" : Color.accent
        border.color: root.isRead ? Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.15) : "transparent"
        border.width: 1
      }
    }

    // Title and metadata column
    Column {
      width: parent.width - Style.space(8) - (actionRow.visible ? actionRow.width + Style.space(12) : Style.space(8))
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: root.item.title || "Untitled"
        elide: Text.ElideRight
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
        font.bold: !root.isRead
        color: root.isRead ? root.mutedColor : root.contentForeground
      }

      Row {
        width: parent.width
        spacing: Style.space(6)
        clip: true

        Text {
          text: {
            var parts = []
            if (root.categoryName) parts.push(root.categoryName)
            if (root.item.feedName) parts.push(root.item.feedName)
            var rel = Model.relativeTime(root.item.pubDateMs)
            if (rel) parts.push(rel)
            return parts.join(" · ")
          }
          elide: Text.ElideRight
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          color: root.mutedColor
        }
      }
    }

    // Action buttons visible on hover or selection
    Row {
      id: actionRow
      visible: root.hovered || root.isSelected
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      // Mark read/unread toggle
      Rectangle {
        width: Style.space(24)
        height: Style.space(24)
        radius: Style.space(4)
        color: markHover.containsMouse ? Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.1) : "transparent"

        Text {
          anchors.centerIn: parent
          text: root.isRead ? "󰄱" : "󰄬"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          color: root.isRead ? root.mutedColor : Color.accent
        }

        MouseArea {
          id: markHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleRead()
        }
      }

      // Open in browser button
      Rectangle {
        width: Style.space(24)
        height: Style.space(24)
        radius: Style.space(4)
        color: linkHover.containsMouse ? Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.1) : "transparent"

        Text {
          anchors.centerIn: parent
          text: "󰌹"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          color: root.mutedColor
        }

        MouseArea {
          id: linkHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activated()
        }
      }
    }
  }
}

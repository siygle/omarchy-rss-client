import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var item: ({})
  property bool isRead: false
  property color contentForeground: Color.foreground
  property string contentFontFamily: Style.font.family

  signal backRequested()
  signal openExternalRequested()
  signal toggleReadRequested()

  readonly property color mutedColor: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.55)
  readonly property string articleText: {
    var text = String((root.item && root.item.excerpt) || "").trim()
    return text || "This feed item does not include readable article text. Open it in your browser to read the full article."
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background
  }

  Column {
    anchors.fill: parent
    spacing: Style.space(10)

    Item {
      width: parent.width
      height: Style.space(32)

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

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
          text: "Article"
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          color: root.contentForeground
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)

        Rectangle {
          width: Style.space(30)
          height: Style.space(30)
          radius: Style.space(4)
          color: readHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

          Text {
            anchors.centerIn: parent
            text: root.isRead ? "󰄱" : "󰄬"
            font.family: root.contentFontFamily
            font.pixelSize: Math.round(Style.font.body * 1.15)
            color: root.isRead ? root.mutedColor : Color.accent
          }

          MouseArea {
            id: readHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleReadRequested()
          }
        }

        Rectangle {
          width: Style.space(30)
          height: Style.space(30)
          radius: Style.space(4)
          color: browserHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰌹"
            font.family: root.contentFontFamily
            font.pixelSize: Math.round(Style.font.body * 1.15)
            color: root.contentForeground
          }

          MouseArea {
            id: browserHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openExternalRequested()
          }
        }
      }
    }

    Flickable {
      width: parent.width
      height: parent.height - Style.space(42)
      clip: true
      contentHeight: articleColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: articleColumn
        width: parent.width
        spacing: Style.space(10)

        Text {
          width: parent.width
          text: (root.item && root.item.title) ? root.item.title : "Untitled"
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          color: root.contentForeground
        }

        Text {
          width: parent.width
          text: {
            var parts = []
            if (root.item && root.item.feedName) parts.push(root.item.feedName)
            var rel = root.item ? Model.relativeTime(root.item.pubDateMs) : ""
            if (rel) parts.push(rel)
            return parts.join(" · ")
          }
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          color: root.mutedColor
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
        }

        Text {
          width: parent.width
          text: root.articleText
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          lineHeight: 1.18
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          color: root.contentForeground
        }
      }
    }
  }
}

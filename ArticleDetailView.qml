import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var item: ({})
  property string fullText: ""
  property bool isFetchingFull: false
  property string fetchStatus: ""
  property int readerFontSize: 16
  property real readerLineHeight: 1.3
  property bool zenMode: false
  property bool isRead: false
  property color contentForeground: Color.foreground
  property string contentFontFamily: Style.font.family

  signal backRequested()
  signal openExternalRequested()
  signal fetchFullRequested()
  signal readerPreferencesChanged(int fontSize, real lineHeight)
  signal toggleReadRequested()

  readonly property color mutedColor: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.55)
  readonly property string articleText: {
    var text = String(root.fullText || (root.item && root.item.excerpt) || "").trim()
    return text || "This feed item does not include readable article text. Open it in your browser to read the full article."
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background
  }

  Column {
    anchors.fill: parent
    spacing: root.zenMode ? Style.space(14) : Style.space(10)

    Item {
      width: parent.width
      height: root.zenMode ? Style.space(28) : Style.space(32)

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
          visible: !root.zenMode
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
          color: fetchHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

          Text {
            anchors.centerIn: parent
            text: root.isFetchingFull ? "󰑐" : "󰜎"
            font.family: root.contentFontFamily
            font.pixelSize: Math.round(Style.font.body * 1.15)
            color: root.isFetchingFull ? Color.accent : root.contentForeground
          }

          MouseArea {
            id: fetchHover
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.isFetchingFull
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.fetchFullRequested()
          }
        }

        Rectangle {
          width: Style.space(30)
          height: Style.space(30)
          radius: Style.space(4)
          color: smallerHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "A-"
            textFormat: Text.PlainText
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.contentForeground
          }

          MouseArea {
            id: smallerHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.readerPreferencesChanged(root.readerFontSize - 1, root.readerLineHeight)
          }
        }

        Rectangle {
          width: Style.space(30)
          height: Style.space(30)
          radius: Style.space(4)
          color: biggerHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "A+"
            textFormat: Text.PlainText
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.contentForeground
          }

          MouseArea {
            id: biggerHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.readerPreferencesChanged(root.readerFontSize + 1, root.readerLineHeight)
          }
        }

        Rectangle {
          width: Style.space(30)
          height: Style.space(30)
          radius: Style.space(4)
          color: lineHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰉢"
            font.family: root.contentFontFamily
            font.pixelSize: Math.round(Style.font.body * 1.15)
            color: root.contentForeground
          }

          MouseArea {
            id: lineHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.readerPreferencesChanged(root.readerFontSize, root.readerLineHeight >= 1.8 ? 1.1 : root.readerLineHeight + 0.1)
          }
        }

        Rectangle {
          width: Style.space(30)
          height: Style.space(30)
          radius: Style.space(4)
          color: zenHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰊴"
            font.family: root.contentFontFamily
            font.pixelSize: Math.round(Style.font.body * 1.15)
            color: root.zenMode ? Color.accent : root.contentForeground
          }

          MouseArea {
            id: zenHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.zenMode = !root.zenMode
          }
        }

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
      height: parent.height - (root.zenMode ? Style.space(42) : Style.space(42))
      clip: true
      contentHeight: articleColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: articleColumn
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.zenMode ? Style.space(14) : Style.space(10)

        Text {
          width: parent.width
          text: (root.item && root.item.title) ? root.item.title : "Untitled"
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: root.readerFontSize + 4
          font.bold: true
          color: root.contentForeground
        }

        Text {
          visible: !root.zenMode
          width: parent.width
          text: {
            var parts = []
            if (root.item && root.item.feedName) parts.push(root.item.feedName)
            var rel = root.item ? Model.relativeTime(root.item.pubDateMs) : ""
            if (rel) parts.push(rel)
            if (root.fullText) parts.push("Full article")
            return parts.join(" · ")
          }
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: Math.max(10, root.readerFontSize - 4)
          color: root.mutedColor
        }

        Text {
          visible: root.isFetchingFull
          width: parent.width
          text: "Fetching full article…"
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: Math.max(10, root.readerFontSize - 3)
          color: Color.accent
        }

        Text {
          visible: root.fetchStatus === "error"
          width: parent.width
          text: "Could not fetch the full article. You can still open it in your browser."
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: Math.max(10, root.readerFontSize - 3)
          color: "#ff6b6b"
        }

        Rectangle {
          visible: !root.zenMode
          width: parent.width
          height: 1
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
        }

        Text {
          width: parent.width
          text: root.articleText
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          lineHeight: root.readerLineHeight
          font.family: root.contentFontFamily
          font.pixelSize: root.readerFontSize
          color: root.contentForeground
        }
      }
    }
  }
}

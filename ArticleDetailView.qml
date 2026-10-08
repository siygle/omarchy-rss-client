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
  readonly property bool hasReadableText: String(root.fullText || (root.item && root.item.excerpt) || "").trim() !== ""
  readonly property string articleText: {
    var text = String(root.fullText || (root.item && root.item.excerpt) || "").trim()
    return text || "This feed item does not include readable article text. Open it in your browser to read the full article."
  }
  readonly property int readingMinutes: root.hasReadableText ? Model.readingMinutes(root.articleText) : 0
  readonly property string metaText: {
    var parts = []
    if (root.item && root.item.feedName) parts.push(root.item.feedName)
    var rel = root.item ? Model.relativeTime(root.item.pubDateMs) : ""
    if (rel) parts.push(rel)
    if (root.readingMinutes > 0) parts.push(root.readingMinutes + " min read")
    if (root.fullText) parts.push("Full article")
    return parts.join(" · ")
  }
  // Zen mode caps the measure at roughly 65-75 characters so long lines stay
  // easy to track on wide screens.
  readonly property real readingWidth: root.zenMode
    ? Math.min(articleFlick.width - Style.space(32), Math.round(root.readerFontSize * 38))
    : articleFlick.width

  function scrollBy(delta) {
    var maxY = Math.max(0, articleFlick.contentHeight - articleFlick.height)
    articleFlick.contentY = Math.max(0, Math.min(maxY, articleFlick.contentY + delta))
  }

  function scrollLine(direction) {
    root.scrollBy(direction * Math.round(root.readerFontSize * root.readerLineHeight * 3))
  }

  function scrollPage(direction) {
    root.scrollBy(direction * Math.round(articleFlick.height * 0.9))
  }

  function scrollToEdge(toEnd) {
    articleFlick.contentY = toEnd ? Math.max(0, articleFlick.contentHeight - articleFlick.height) : 0
  }

  onItemChanged: articleFlick.contentY = 0

  component ToolbarButton: Rectangle {
    id: btn

    property string icon: ""
    property string tip: ""
    property color foreground: Color.foreground
    property color iconColor: foreground
    property bool iconBold: false
    property real iconSize: Math.round(Style.font.body * 1.15)
    property bool active: true

    signal clicked()

    width: Style.space(30)
    height: Style.space(30)
    radius: Style.space(4)
    color: btnMouse.containsMouse && btn.active ? Qt.rgba(btn.foreground.r, btn.foreground.g, btn.foreground.b, 0.08) : "transparent"

    Text {
      anchors.centerIn: parent
      text: btn.icon
      textFormat: Text.PlainText
      font.family: Style.font.family
      font.pixelSize: btn.iconSize
      font.bold: btn.iconBold
      color: btn.iconColor
    }

    MouseArea {
      id: btnMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: btn.active ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: if (btn.active) btn.clicked()
    }

    PanelToolTip {
      visible: btnMouse.containsMouse && btn.tip !== ""
      text: btn.tip
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background
  }

  Item {
    id: headerBar
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(32)
    z: 1
    // In zen mode the controls recede until the pointer reaches them.
    opacity: root.zenMode && !headerHover.hovered ? 0.3 : 1.0

    Behavior on opacity { NumberAnimation { duration: 160 } }

    HoverHandler {
      id: headerHover
    }

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      ToolbarButton {
        width: Style.space(28)
        height: Style.space(28)
        icon: "󰁍"
        iconSize: Style.font.subtitle
        foreground: root.contentForeground
        tip: "Back to list (Esc)"
        onClicked: root.backRequested()
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

      ToolbarButton {
        icon: root.isFetchingFull ? "󰑐" : "󰜎"
        foreground: root.contentForeground
        iconColor: root.isFetchingFull ? Color.accent : root.contentForeground
        active: !root.isFetchingFull
        tip: root.isFetchingFull ? "Fetching full article…" : "Fetch full article (F)"
        onClicked: root.fetchFullRequested()
      }

      ToolbarButton {
        icon: "A-"
        iconSize: Style.font.caption
        iconBold: true
        foreground: root.contentForeground
        tip: "Smaller text (-) · " + root.readerFontSize + "px"
        onClicked: root.readerPreferencesChanged(root.readerFontSize - 1, root.readerLineHeight)
      }

      ToolbarButton {
        icon: "A+"
        iconSize: Style.font.caption
        iconBold: true
        foreground: root.contentForeground
        tip: "Larger text (+) · " + root.readerFontSize + "px"
        onClicked: root.readerPreferencesChanged(root.readerFontSize + 1, root.readerLineHeight)
      }

      ToolbarButton {
        icon: "󰉢"
        foreground: root.contentForeground
        tip: "Line spacing · " + root.readerLineHeight.toFixed(1) + "×"
        onClicked: root.readerPreferencesChanged(root.readerFontSize, root.readerLineHeight >= 1.8 ? 1.1 : root.readerLineHeight + 0.1)
      }

      ToolbarButton {
        icon: "󰊴"
        foreground: root.contentForeground
        iconColor: root.zenMode ? Color.accent : root.contentForeground
        tip: root.zenMode ? "Exit zen mode (Z)" : "Zen mode: full-screen reading (Z)"
        onClicked: root.zenMode = !root.zenMode
      }

      ToolbarButton {
        icon: root.isRead ? "󰄱" : "󰄬"
        foreground: root.contentForeground
        iconColor: root.isRead ? root.mutedColor : Color.accent
        tip: root.isRead ? "Mark as unread (M)" : "Mark as read (M)"
        onClicked: root.toggleReadRequested()
      }

      ToolbarButton {
        icon: "󰌹"
        foreground: root.contentForeground
        tip: "Open in browser (O)"
        onClicked: root.openExternalRequested()
      }
    }
  }

  // Reading progress (zen mode only)
  Rectangle {
    id: progressTrack
    visible: root.zenMode && articleFlick.contentHeight > articleFlick.height
    anchors.top: headerBar.bottom
    anchors.topMargin: Style.space(4)
    anchors.left: parent.left
    anchors.right: parent.right
    height: 2
    radius: 1
    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)

    Rectangle {
      height: parent.height
      radius: parent.radius
      color: Color.accent
      width: {
        var range = articleFlick.contentHeight - articleFlick.height
        if (range <= 0) return parent.width
        return parent.width * Math.max(0, Math.min(1, articleFlick.contentY / range))
      }
    }
  }

  Flickable {
    id: articleFlick
    anchors.top: headerBar.bottom
    anchors.topMargin: root.zenMode ? Style.space(8) : Style.space(10)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    clip: true
    contentWidth: width
    contentHeight: articleColumn.implicitHeight + articleColumn.y + (root.zenMode ? Style.space(48) : Style.space(8))
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: articleColumn
      x: Math.round((articleFlick.width - width) / 2)
      y: root.zenMode ? Style.space(28) : 0
      width: root.readingWidth
      spacing: root.zenMode ? Style.space(14) : Style.space(10)

      // Zen mode: metadata sits above the title as a quiet kicker.
      Text {
        visible: root.zenMode && text !== ""
        width: parent.width
        text: root.metaText
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        font.family: root.contentFontFamily
        font.pixelSize: Math.max(10, root.readerFontSize - 4)
        font.letterSpacing: 0.4
        color: root.mutedColor
      }

      Text {
        width: parent.width
        text: (root.item && root.item.title) ? root.item.title : "Untitled"
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        lineHeight: root.zenMode ? 1.15 : 1.0
        font.family: root.contentFontFamily
        font.pixelSize: root.zenMode ? Math.round(root.readerFontSize * 1.6) : root.readerFontSize + 4
        font.bold: true
        color: root.contentForeground
      }

      Text {
        visible: !root.zenMode
        width: parent.width
        text: root.metaText
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
        width: root.zenMode ? Style.space(40) : parent.width
        height: root.zenMode ? 2 : 1
        radius: height / 2
        color: root.zenMode
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
          : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
      }

      Text {
        width: parent.width
        text: root.articleText
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        lineHeight: root.zenMode ? Math.max(root.readerLineHeight, 1.5) : root.readerLineHeight
        font.family: root.contentFontFamily
        font.pixelSize: root.zenMode ? root.readerFontSize + 1 : root.readerFontSize
        color: root.zenMode
          ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.9)
          : root.contentForeground
      }

      // End-of-article marker with a way out to the source.
      Column {
        visible: root.zenMode
        width: parent.width
        topPadding: Style.space(20)
        spacing: Style.space(10)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "· · ·"
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: root.readerFontSize
          color: root.mutedColor
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Read the original in your browser 󰌹"
          textFormat: Text.PlainText
          font.family: root.contentFontFamily
          font.pixelSize: Math.max(10, root.readerFontSize - 3)
          font.underline: endLinkMouse.containsMouse
          color: endLinkMouse.containsMouse ? Color.accent : root.mutedColor

          MouseArea {
            id: endLinkMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openExternalRequested()
          }
        }
      }
    }
  }
}

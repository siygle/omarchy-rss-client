import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.rafaelvzago.rss"
  ipcTarget: "io.github.rafaelvzago.rss"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string emptyCopy: "Add feed URLs in Settings."
  property var items: []
  property var feedUrls: []
  property var readSet: []
  property int pollIntervalMinutes: 15
  property int maxItemsPerFeed: 10
  property int itemsPerPage: 10
  property string barSection: "right"
  property bool showingSettings: false
  property string settingsTab: "feeds"
  property string activeTab: "new"
  property int currentPage: 0
  property string draftUrl: ""
  property string draftPoll: "15"
  property string draftMax: "10"
  property string draftPageSize: "10"
  property string draftSection: "right"
  property string importText: ""
  property string shareStatus: ""
  property string filterText: ""

  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var tabRows: Model.filterItems(Model.tabItems(root.items, root.readSet, root.activeTab), root.filterText)
  readonly property int newCount: Model.tabItems(root.items, root.readSet, "new").length
  readonly property int readCount: Model.tabItems(root.items, root.readSet, "read").length
  readonly property var pageRows: Model.pageItems(root.tabRows, root.currentPage, root.itemsPerPage)
  readonly property int pages: Model.pageCount(root.tabRows, root.itemsPerPage)
  readonly property string tabEmptyCopy: {
    if (!root.items || root.items.length === 0) return root.emptyCopy
    if (String(root.filterText || "").trim())
      return root.activeTab === "read" ? "No read items match." : "No unread items match."
    return root.activeTab === "read" ? "No read items." : "No new items."
  }

  onItemsChanged: root.currentPage = Model.pageIndex(root.tabRows, 0, root.itemsPerPage)
  onActiveTabChanged: root.currentPage = 0
  onReadSetChanged: root.currentPage = Model.pageIndex(root.tabRows, root.currentPage, root.itemsPerPage)
  onItemsPerPageChanged: root.currentPage = Model.pageIndex(root.tabRows, root.currentPage, root.itemsPerPage)
  onFilterTextChanged: root.currentPage = 0

  function open() {
    root.showingSettings = false
    root.activeTab = "new"
    root.currentPage = 0
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  property var lastImportResult: null

  function openSettings() {
    root.draftUrl = ""
    root.draftPoll = String(root.pollIntervalMinutes)
    root.draftMax = String(root.maxItemsPerFeed)
    root.draftPageSize = String(root.itemsPerPage)
    root.draftSection = Model.barSection(root.barSection)
    root.importText = ""
    root.feedUrls = Model.httpsFeedUrls(Model.serializeFeedUrls(root.hostWidget ? root.hostWidget.configuredFeedUrls : root.feedUrls))
    root.shareStatus = (root.hostWidget && root.hostWidget.lastImportMessage) ? root.hostWidget.lastImportMessage : ""
    root.settingsTab = "feeds"
    root.showingSettings = true
  }

  function showReadTab() {
    root.close()
  }

  function markRowRead(item) {
    if (root.hostWidget && typeof root.hostWidget.markItemRead === "function")
      root.hostWidget.markItemRead(item)
  }

  function markVisibleRead() {
    if (root.hostWidget && typeof root.hostWidget.markItemsRead === "function")
      root.hostWidget.markItemsRead(root.tabRows)
  }

  function activateRow(item) {
    if (root.hostWidget && typeof root.hostWidget.activateItem === "function")
      root.hostWidget.activateItem(item)
    else {
      var url = Model.activateUrl(item)
      if (url) Qt.openUrlExternally(url)
    }
    root.close()
  }

  function addDraftFeed() {
    var value = String(root.draftUrl || "").trim()
    if (!Model.isHttpsUrl(value)) return
    root.feedUrls = Model.addFeedUrl(root.feedUrls, value)
    root.draftUrl = ""
  }

  function removeListedFeed(url) {
    root.feedUrls = Model.removeFeedUrl(root.feedUrls, url)
  }

  function shareFeeds() {
    var count = 0
    if (root.hostWidget && typeof root.hostWidget.shareFeeds === "function")
      count = root.hostWidget.shareFeeds(root.feedUrls)
    root.shareStatus = count ? ("Copied " + count + " feeds") : "No feeds to share"
  }

  function importSharedFeeds() {
    var text = String(root.importText || "").trim()
    root.importText = ""
    if (root.hostWidget && typeof root.hostWidget.importSharedPayload === "function") {
      root.hostWidget.importSharedPayload(text)
    } else {
      var incoming = Model.parseSharePayload(text)
      if (!incoming.length) {
        root.shareStatus = "Nothing to import"
        return
      }
      var prevCount = root.feedUrls ? root.feedUrls.length : 0
      root.feedUrls = Model.mergeFeedLists(root.feedUrls, incoming)
      var addedCount = root.feedUrls.length - prevCount
      if (root.hostWidget && typeof root.hostWidget.importFeeds === "function")
        root.hostWidget.importFeeds(root.feedUrls)
      root.shareStatus = addedCount > 0
        ? ("Imported " + addedCount + " new " + (addedCount === 1 ? "feed" : "feeds"))
        : ("All " + incoming.length + " feeds already added")
    }
  }

  function selectOpmlFile() {
    if (root.hostWidget && typeof root.hostWidget.requestOpmlFileImport === "function") {
      root.hostWidget.requestOpmlFileImport()
    } else if (root.hostWidget && typeof root.hostWidget.selectOpmlFile === "function") {
      root.hostWidget.selectOpmlFile()
    }
  }

  function saveSettings() {
    if (root.hostWidget && typeof root.hostWidget.saveConfig === "function")
      root.hostWidget.saveConfig(root.feedUrls, root.draftPoll, root.draftMax, root.draftPageSize, root.draftSection)
    root.showingSettings = false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)

        Row {
          id: headerRow
          width: parent.width
          spacing: Style.space(8)

          Text {
            id: headerRssIcon
            text: "󰑫"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.display
            verticalAlignment: Text.AlignVCenter
          }

          Text {
            id: headerTitle
            text: root.showingSettings ? "Settings" : "RSS"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            verticalAlignment: Text.AlignVCenter
          }

          Item {
            width: Math.max(0, headerRow.width
                            - headerRssIcon.implicitWidth
                            - headerTitle.implicitWidth
                            - headerSettingsIcon.implicitWidth
                            - headerRow.spacing * 3)
            height: 1
          }

          Text {
            id: headerSettingsIcon
            text: "󰒓"
            color: root.showingSettings ? Color.accent : root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.display
            verticalAlignment: Text.AlignVCenter

            MouseArea {
              anchors.fill: parent
              anchors.margins: -Style.space(6)
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.showingSettings) root.showingSettings = false
                else root.openSettings()
              }
            }
          }
        }

        Column {
          visible: root.showingSettings
          width: parent.width
          spacing: Style.space(8)

          Row {
            spacing: Style.space(16)

            Repeater {
              model: [
                { id: "feeds", label: "Feeds" },
                { id: "options", label: "Options" },
                { id: "share", label: "Share" }
              ]

              Text {
                required property var modelData
                text: modelData.label
                color: root.settingsTab === modelData.id ? Color.accent : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: root.settingsTab === modelData.id
                font.underline: root.settingsTab === modelData.id

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.settingsTab = modelData.id
                }
              }
            }
          }

          Column {
            visible: root.settingsTab === "feeds"
            width: parent.width
            spacing: Style.space(8)

          Text {
            width: parent.width
            text: "Feeds"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Repeater {
            model: root.feedUrls

            Row {
              required property var modelData
              width: content.width
              spacing: Style.space(8)

              Text {
                width: parent.width - Style.space(70)
                text: modelData
                textFormat: Text.PlainText
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WrapAnywhere
              }

              Text {
                text: "Remove"
                color: Color.accent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.underline: true

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.removeListedFeed(modelData)
                }
              }
            }
          }

          TextField {
            id: urlField
            width: parent.width
            placeholderText: "https://mitchellh.com/writing"
            text: root.draftUrl
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            onTextChanged: root.draftUrl = text
            Keys.onReturnPressed: root.addDraftFeed()
          }

          Text {
            text: "Add feed"
            color: Color.accent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.underline: true

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.addDraftFeed()
            }
          }
          }

          Column {
            visible: root.settingsTab === "options"
            width: parent.width
            spacing: Style.space(8)

          Text {
            width: parent.width
            text: "Check feeds every (minutes)"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          TextField {
            id: pollField
            width: Style.space(80)
            text: root.draftPoll
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            inputMethodHints: Qt.ImhDigitsOnly
            onTextChanged: root.draftPoll = text
          }

          Text {
            width: parent.width
            text: "Max items per feed"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          TextField {
            id: maxField
            width: Style.space(80)
            text: root.draftMax
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            inputMethodHints: Qt.ImhDigitsOnly
            onTextChanged: root.draftMax = text
          }

          Text {
            width: parent.width
            text: "Items per page"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          TextField {
            id: pageSizeField
            width: Style.space(80)
            text: root.draftPageSize
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            inputMethodHints: Qt.ImhDigitsOnly
            onTextChanged: root.draftPageSize = text
          }

          Text {
            width: parent.width
            text: "Bar position"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Row {
            spacing: Style.space(16)

            Repeater {
              model: ["left", "center", "right"]

              Text {
                required property string modelData
                text: modelData === "left" ? "Left" : (modelData === "center" ? "Center" : "Right")
                color: root.draftSection === modelData ? Color.accent : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: root.draftSection === modelData
                font.underline: root.draftSection === modelData

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.draftSection = modelData
                }
              }
            }
          }
          }

          Column {
            visible: root.settingsTab === "share"
            width: parent.width
            spacing: Style.space(8)

          Text {
            width: parent.width
            text: "Share and import"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Row {
            spacing: Style.space(8)

            Rectangle {
              implicitWidth: shareRow.implicitWidth + Style.space(20)
              implicitHeight: shareRow.implicitHeight + Style.space(10)
              radius: 0
              color: shareMouse.containsMouse
                ? Style.hoverFillFor(root.contentForeground, Color.accent)
                : "transparent"
              border.width: Math.max(1, Style.spacing.hairline)
              border.color: root.contentForeground

              Row {
                id: shareRow
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: "󰜎"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.title
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  text: "Share"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  verticalAlignment: Text.AlignVCenter
                }
              }

              MouseArea {
                id: shareMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shareFeeds()
              }
            }

            Rectangle {
              implicitWidth: importFileRow.implicitWidth + Style.space(20)
              implicitHeight: importFileRow.implicitHeight + Style.space(10)
              radius: 0
              color: importFileMouse.containsMouse
                ? Style.hoverFillFor(root.contentForeground, Color.accent)
                : "transparent"
              border.width: Math.max(1, Style.spacing.hairline)
              border.color: root.contentForeground

              Row {
                id: importFileRow
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: "󰉋"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.title
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  text: "Import OPML file"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  verticalAlignment: Text.AlignVCenter
                }
              }

              MouseArea {
                id: importFileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectOpmlFile()
              }
            }
          }

          TextField {
            width: parent.width
            placeholderText: "Paste a shared list, OPML, or feed URLs"
            text: root.importText
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            onTextChanged: root.importText = text
          }

          Text {
            text: "Import"
            color: Color.accent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.underline: true

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.importSharedFeeds()
            }
          }

          Text {
            visible: root.shareStatus !== ""
            width: parent.width
            text: root.shareStatus
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
          }

          Row {
            spacing: Style.space(10)

            Rectangle {
              implicitWidth: saveLabel.implicitWidth + Style.space(20)
              implicitHeight: saveLabel.implicitHeight + Style.space(10)
              radius: 0
              color: saveMouse.containsMouse
                ? Style.hoverFillFor(root.contentForeground, Color.accent)
                : "transparent"
              border.width: Math.max(1, Style.spacing.hairline)
              border.color: root.contentForeground

              Text {
                id: saveLabel
                anchors.centerIn: parent
                text: "Save"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }

              MouseArea {
                id: saveMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.saveSettings()
              }
            }

            Rectangle {
              implicitWidth: dismissLabel.implicitWidth + Style.space(20)
              implicitHeight: dismissLabel.implicitHeight + Style.space(10)
              radius: 0
              color: dismissMouse.containsMouse
                ? Style.hoverFillFor(root.contentForeground, Color.accent)
                : "transparent"
              border.width: Math.max(1, Style.spacing.hairline)
              border.color: root.contentForeground

              Text {
                id: dismissLabel
                anchors.centerIn: parent
                text: "Dismiss"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }

              MouseArea {
                id: dismissMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showingSettings = false
              }
            }
          }
        }

        Column {
          visible: !root.showingSettings
          width: parent.width
          spacing: Style.space(8)

          Row {
            spacing: Style.space(16)

            Text {
              text: "󰎔 New " + Model.compactCount(root.newCount)
              color: root.activeTab === "new" ? Color.accent : root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: root.activeTab === "new"
              font.underline: root.activeTab === "new"

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = "new"
              }
            }

            Text {
              text: "󰄬 Read " + Model.compactCount(root.readCount)
              color: root.activeTab === "read" ? Color.accent : root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: root.activeTab === "read"
              font.underline: root.activeTab === "read"

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = "read"
              }
            }

            Text {
              visible: root.activeTab === "new" && root.tabRows && root.tabRows.length > 0
              text: "Mark all read"
              color: Color.accent
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.underline: true

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.markVisibleRead()
              }
            }
          }

          TextField {
            width: parent.width
            placeholderText: root.activeTab === "read" ? "Filter read" : "Filter unread"
            text: root.filterText
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            onTextChanged: root.filterText = text
          }

          Text {
            visible: !root.tabRows || root.tabRows.length === 0
            width: parent.width
            text: root.tabEmptyCopy
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Repeater {
            model: root.pageRows

            Column {
              required property var modelData
              width: content.width
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: Model.rowText(modelData)
                textFormat: Text.PlainText
                color: Model.activateUrl(modelData) ? Color.accent : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap

                MouseArea {
                  anchors.fill: parent
                  enabled: Model.activateUrl(modelData) !== ""
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.activateRow(modelData)
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  width: parent.width - (root.activeTab === "new" ? Style.space(90) : 0)
                  text: {
                    var name = modelData && modelData.feedName ? modelData.feedName : ""
                    var when = Model.relativeTime(modelData ? modelData.pubDateMs : null)
                    if (name && when) return name + " · " + when
                    return name || when
                  }
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }

                Text {
                  visible: root.activeTab === "new"
                  text: "Mark read"
                  color: Color.accent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.underline: true

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.markRowRead(modelData)
                  }
                }
              }
            }
          }

          Row {
            visible: root.tabRows && root.tabRows.length > Model.pageSize(root.itemsPerPage)
            spacing: Style.space(12)

            Text {
              text: "Prev"
              color: root.currentPage > 0 ? Color.accent : Qt.darker(root.contentForeground, 1.8)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.underline: root.currentPage > 0

              MouseArea {
                anchors.fill: parent
                enabled: root.currentPage > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentPage = Model.pageIndex(root.tabRows, root.currentPage - 1, root.itemsPerPage)
              }
            }

            Text {
              text: (root.currentPage + 1) + " / " + root.pages
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              text: "Next"
              color: root.currentPage < root.pages - 1 ? Color.accent : Qt.darker(root.contentForeground, 1.8)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.underline: root.currentPage < root.pages - 1

              MouseArea {
                anchors.fill: parent
                enabled: root.currentPage < root.pages - 1
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentPage = Model.pageIndex(root.tabRows, root.currentPage + 1, root.itemsPerPage)
              }
            }
          }
        }
      }
    }
  }
}

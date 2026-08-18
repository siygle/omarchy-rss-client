import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.sanjyay.rss-reeder"
  ipcTarget: "io.github.sanjyay.rss-reeder"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string emptyCopy: "Add feed URLs in Settings."
  property var items: []
  property var subscriptions: []
  property var feedUrls: []
  property var categories: []
  property var feedCategoryMap: ({})
  property var readSet: []
  property int pollIntervalMinutes: 15
  property int maxItemsPerFeed: 10
  property int itemsPerPage: 10
  property int retentionDays: 30
  property bool unreadOnlyDefault: false
  property string barSection: "right"
  property var lastImportResult: null
  property string shareStatus: ""

  // Views: "reader" | "settings" | "subscriptions"
  property string currentView: "reader"

  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.currentView = "reader"
    if (root.hostWidget) {
      root.subscriptions = root.hostWidget.configuredSubscriptions
      root.feedUrls = root.hostWidget.configuredFeedUrls
      root.categories = root.hostWidget.configuredCategories
      root.feedCategoryMap = root.hostWidget.feedCategoryMap
      root.items = root.hostWidget.items
      root.readSet = root.hostWidget.readSet
      root.pollIntervalMinutes = root.hostWidget.configuredPollIntervalMinutes
      root.maxItemsPerFeed = root.hostWidget.configuredMaxItemsPerFeed
      root.itemsPerPage = root.hostWidget.configuredItemsPerPage
      root.retentionDays = root.hostWidget.configuredRetentionDays
      root.unreadOnlyDefault = root.hostWidget.configuredUnreadOnlyDefault
      root.barSection = root.hostWidget.configuredBarSection
      root.lastImportResult = root.hostWidget.lastImportResult
      root.shareStatus = root.hostWidget.lastImportMessage
    }
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

  function refreshFeeds() {
    if (root.hostWidget && typeof root.hostWidget.fetchFeed === "function") {
      root.hostWidget.fetchFeed()
    }
  }

  function requestOpmlFileImport() {
    if (root.hostWidget && typeof root.hostWidget.requestOpmlFileImport === "function") {
      root.hostWidget.requestOpmlFileImport()
    }
  }

  function shareFeeds() {
    if (root.hostWidget && typeof root.hostWidget.shareFeeds === "function") {
      var count = root.hostWidget.shareFeeds()
      root.shareStatus = "Exported " + count + " subscriptions to clipboard"
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.currentView === "subscriptions") {
          root.currentView = "settings"
        } else if (root.currentView === "settings") {
          root.currentView = "reader"
        } else if (readerView.drawerOpen) {
          readerView.drawerOpen = false
        } else {
          root.close()
        }
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Keys.onPressed: function(event) {
        // If a TextInput has active focus, let it handle standard typing
        var activeItem = keyCatcher.activeFocusItem
        if (activeItem && (activeItem instanceof TextInput || activeItem.selectByMouse !== undefined)) {
          if (event.key === Qt.Key_Escape) {
            keyCatcher.forceActiveFocus()
            event.accepted = true
          }
          return
        }

        if (root.currentView === "reader") {
          if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            readerView.selectNextArticle()
            event.accepted = true
          } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            readerView.selectPrevArticle()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            readerView.activateCurrentArticle()
            event.accepted = true
          } else if (event.key === Qt.Key_M) {
            readerView.toggleReadCurrentArticle()
            event.accepted = true
          } else if (event.key === Qt.Key_R) {
            root.refreshFeeds()
            event.accepted = true
          } else if (event.key === Qt.Key_Slash) {
            readerView.focusSearch()
            event.accepted = true
          } else if (event.key === Qt.Key_C) {
            readerView.toggleCategoryDrawer()
            event.accepted = true
          }
        }
      }

      Item {
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        anchors.topMargin: Style.space(10)
        anchors.bottomMargin: Style.space(10)

        // 1. Primary Reader View
        ReaderView {
          id: readerView
          anchors.fill: parent
          visible: root.currentView === "reader"
          hostWidget: root.hostWidget
          items: root.items
          subscriptions: root.subscriptions
          categories: root.categories
          feedCategoryMap: root.feedCategoryMap
          readSet: root.readSet
          emptyCopy: root.emptyCopy
          contentForeground: root.contentForeground
          contentFontFamily: root.contentFontFamily
          itemsPerPage: root.itemsPerPage
          unreadOnlyDefault: root.unreadOnlyDefault

          onOpenSettingsRequested: {
            root.currentView = "settings"
          }
          onRefreshRequested: root.refreshFeeds()
        }

        // 2. Settings Home View
        SettingsView {
          id: settingsView
          anchors.fill: parent
          visible: root.currentView === "settings"
          hostWidget: root.hostWidget
          subscriptions: root.subscriptions
          pollIntervalMinutes: root.pollIntervalMinutes
          maxItemsPerFeed: root.maxItemsPerFeed
          itemsPerPage: root.itemsPerPage
          retentionDays: root.retentionDays
          barSection: root.barSection
          unreadOnlyDefault: root.unreadOnlyDefault
          shareStatus: root.shareStatus
          contentForeground: root.contentForeground
          contentFontFamily: root.contentFontFamily

          onBackRequested: root.currentView = "reader"
          onManageSubscriptionsRequested: root.currentView = "subscriptions"
          onImportOpmlRequested: root.requestOpmlFileImport()
          onShareFeedsRequested: root.shareFeeds()
        }

        // 3. Subscriptions Subview
        SubscriptionsView {
          id: subsView
          anchors.fill: parent
          visible: root.currentView === "subscriptions"
          hostWidget: root.hostWidget
          subscriptions: root.subscriptions
          contentForeground: root.contentForeground
          contentFontFamily: root.contentFontFamily

          onBackRequested: root.currentView = "settings"
          onSubscriptionsUpdated: function(next) {
            root.subscriptions = next
          }
        }
      }
    }
  }
}

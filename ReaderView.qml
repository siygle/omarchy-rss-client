import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var hostWidget: null
  property var items: []
  property var subscriptions: []
  property var categories: []
  property var feedCategoryMap: ({})
  property var readSet: []
  property string emptyCopy: "Add feed URLs in Settings."
  property color contentForeground: Color.foreground
  property string contentFontFamily: Style.font.family
  property int itemsPerPage: 10
  property bool unreadOnlyDefault: false

  property string currentCategory: "all"
  property bool unreadOnly: unreadOnlyDefault
  property string searchQuery: ""
  property bool drawerOpen: false
  property int selectedIndex: 0
  property int currentPage: 0

  signal openSettingsRequested()
  signal refreshRequested()
  signal markAllReadRequested()

  function toggleCategoryDrawer() {
    root.drawerOpen = !root.drawerOpen
  }

  function focusSearch() {
    searchField.focusField()
  }

  function selectNextArticle() {
    if (pageArticles.length === 0) return
    root.selectedIndex = Math.min(pageArticles.length - 1, root.selectedIndex + 1)
  }

  function selectPrevArticle() {
    if (pageArticles.length === 0) return
    root.selectedIndex = Math.max(0, root.selectedIndex - 1)
  }

  function activateCurrentArticle() {
    if (pageArticles.length === 0) return
    var item = pageArticles[root.selectedIndex]
    if (item) root.activateItem(item)
  }

  function toggleReadCurrentArticle() {
    if (pageArticles.length === 0) return
    var item = pageArticles[root.selectedIndex]
    if (item) root.toggleReadItem(item)
  }

  function activateItem(item) {
    if (root.hostWidget && typeof root.hostWidget.activateItem === "function") {
      root.hostWidget.activateItem(item)
    } else {
      var url = Model.activateUrl(item)
      if (url) Qt.openUrlExternally(url)
    }
  }

  function toggleReadItem(item) {
    if (!item) return
    var isCurrentlyRead = Model.isRead(root.readSet, item)
    if (isCurrentlyRead) {
      // Mark unread by removing from readSet
      var next = []
      var id = Model.itemIdentity(item)
      for (var i = 0; i < root.readSet.length; i++) {
        if (root.readSet[i] !== id) next.push(root.readSet[i])
      }
      if (root.hostWidget && typeof root.hostWidget.applyLocalRead === "function") {
        root.hostWidget.applyLocalRead(next)
      }
    } else {
      if (root.hostWidget && typeof root.hostWidget.markItemRead === "function") {
        root.hostWidget.markItemRead(item)
      }
    }
  }

  // Derived filtered articles model
  readonly property var allFilteredArticles: Model.filterReaderArticles(root.items, {
    category: root.currentCategory,
    unreadOnly: root.unreadOnly,
    search: root.searchQuery,
    readSet: root.readSet,
    subscriptions: root.subscriptions,
    feedCategoryMap: root.feedCategoryMap
  })

  readonly property int totalFilteredCount: allFilteredArticles.length
  readonly property int totalPages: Math.max(1, Math.ceil(totalFilteredCount / Math.max(1, root.itemsPerPage)))
  readonly property var pageArticles: {
    var start = root.currentPage * root.itemsPerPage
    return allFilteredArticles.slice(start, start + root.itemsPerPage)
  }

  readonly property int totalUnreadCount: Model.unreadCount(root.items, root.readSet)
  readonly property bool hasCategories: (root.categories || []).length > 1

  onCurrentCategoryChanged: {
    root.currentPage = 0
    root.selectedIndex = 0
  }

  onUnreadOnlyChanged: {
    root.currentPage = 0
    root.selectedIndex = 0
  }

  onSearchQueryChanged: {
    root.currentPage = 0
    root.selectedIndex = 0
  }

  Column {
    anchors.fill: parent
    spacing: Style.space(8)

    // 1. Header Bar
    Item {
      width: parent.width
      height: Style.space(32)

      // App Title & Badge
      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Text {
          text: "󰑫"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          color: Color.accent
        }

        Text {
          text: "RSS"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          color: root.contentForeground
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: {
            var subCount = (root.subscriptions || []).length
            return subCount + (subCount === 1 ? " feed" : " feeds") + " · " + root.totalUnreadCount + " unread"
          }
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.45)
        }
      }

      // Actions (Refresh & Settings)
      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        // Refresh action
        Rectangle {
          width: Style.space(28)
          height: Style.space(28)
          radius: Style.space(4)
          color: refreshHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰑐"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            color: root.contentForeground
          }

          MouseArea {
            id: refreshHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.refreshRequested()
          }
        }

        // Settings action
        Rectangle {
          width: Style.space(28)
          height: Style.space(28)
          radius: Style.space(4)
          color: settingsHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰒓"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            color: root.contentForeground
          }

          MouseArea {
            id: settingsHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openSettingsRequested()
          }
        }
      }
    }

    // 2. Responsive Toolbar (Category toggle, Scope chip, Unread toggle, Search, Mark read)
    Item {
      width: parent.width
      height: Style.space(30)

      Row {
        id: toolbarLeft
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        // Category Drawer Toggle (only if categories exist)
        Rectangle {
          visible: root.hasCategories
          width: Style.space(28)
          height: Style.space(28)
          radius: Style.space(4)
          color: root.drawerOpen
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
            : (drawerHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent")
          border.color: root.drawerOpen ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "󰍜"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            color: root.drawerOpen ? Color.accent : root.contentForeground
          }

          MouseArea {
            id: drawerHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleCategoryDrawer()
          }
        }

        // Scope Pill Badge
        Rectangle {
          height: Style.space(26)
          width: scopeText.implicitWidth + Style.space(14)
          radius: Style.space(13)
          color: root.currentCategory.toLowerCase() !== "all"
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.14)
            : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
          border.color: root.currentCategory.toLowerCase() !== "all" ? Color.accent : "transparent"
          border.width: 1

          Row {
            anchors.centerIn: parent
            spacing: Style.space(4)

            Text {
              id: scopeText
              text: root.currentCategory.toLowerCase() === "all" ? "All feeds" : root.currentCategory
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              color: root.currentCategory.toLowerCase() !== "all" ? Color.accent : root.contentForeground
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.currentCategory.toLowerCase() !== "all") {
                root.currentCategory = "all"
              } else if (root.hasCategories) {
                root.toggleCategoryDrawer()
              }
            }
          }
        }

        // Unread-Only Toggle Chip
        Rectangle {
          height: Style.space(26)
          width: unreadText.implicitWidth + Style.space(16)
          radius: Style.space(13)
          color: root.unreadOnly
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
            : (unreadHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent")
          border.color: root.unreadOnly ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
          border.width: 1

          Row {
            anchors.centerIn: parent
            spacing: Style.space(4)

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(6)
              height: width
              radius: width / 2
              color: Color.accent
            }

            Text {
              id: unreadText
              text: "Unread"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.unreadOnly
              color: root.unreadOnly ? Color.accent : root.contentForeground
            }
          }

          MouseArea {
            id: unreadHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.unreadOnly = !root.unreadOnly
          }
        }
      }

      // Mark all read button (anchored right)
      Rectangle {
        id: markAllBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(28)
        height: Style.space(28)
        radius: Style.space(4)
        color: markAllHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

        Text {
          anchors.centerIn: parent
          text: "󰄬"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.6)
        }

        MouseArea {
          id: markAllHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.hostWidget && typeof root.hostWidget.markItemsRead === "function") {
              root.hostWidget.markItemsRead(root.allFilteredArticles)
            }
          }
        }
      }

      // Search Field (expands responsively between left controls and right button)
      SearchField {
        id: searchField
        anchors.left: toolbarLeft.right
        anchors.leftMargin: Style.space(6)
        anchors.right: markAllBtn.left
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        contentForeground: root.contentForeground
        contentFontFamily: root.contentFontFamily
        onTextChanged: root.searchQuery = text
        onCleared: root.searchQuery = ""
      }
    }

    // 3. Main Content Row: Category Drawer (Left) + Article List (Right)
    Row {
      width: parent.width
      height: parent.height - Style.space(32) - Style.space(30) - Style.space(24) - Style.space(24)
      spacing: (catDrawer.width > 0) ? Style.space(8) : 0

      // Category Drawer (0 width when closed, reclaims 100% space)
      CategoryDrawer {
        id: catDrawer
        height: parent.height
        isOpen: root.drawerOpen && root.hasCategories
        categories: root.categories || []
        selectedCategory: root.currentCategory
        contentForeground: root.contentForeground
        contentFontFamily: root.contentFontFamily
        onCategorySelected: function(catId) {
          root.currentCategory = catId
        }
        onCloseRequested: root.drawerOpen = false
      }

      // Article List Container (takes 100% of remaining width)
      Item {
        width: parent.width - (catDrawer.width > 0 ? catDrawer.width + Style.space(8) : 0)
        height: parent.height

        // Empty state message
        Column {
          anchors.centerIn: parent
          spacing: Style.space(8)
          visible: root.pageArticles.length === 0

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (root.subscriptions || []).length === 0 ? "󰑫" : "󰄬"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.title
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.3)
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
              if ((root.subscriptions || []).length === 0) return root.emptyCopy
              if (root.searchQuery) return "No articles match \"" + root.searchQuery + "\""
              if (root.unreadOnly) return "All caught up! No unread articles"
              return "No articles in this category"
            }
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.5)
          }
        }

        // Articles ListView
        ListView {
          id: articleListView
          anchors.fill: parent
          visible: root.pageArticles.length > 0
          model: root.pageArticles
          spacing: Style.space(2)
          clip: true

          delegate: ArticleRow {
            item: modelData
            isRead: Model.isRead(root.readSet, modelData)
            isSelected: index === root.selectedIndex
            categoryName: modelData.category || root.feedCategoryMap[modelData.feedUrl] || ""
            contentForeground: root.contentForeground
            contentFontFamily: root.contentFontFamily

            onActivated: root.activateItem(modelData)
            onToggleRead: root.toggleReadItem(modelData)
          }
        }
      }
    }

    // 4. Footer Pagination & Status (Cleanly anchored inside boundaries)
    Item {
      width: parent.width
      height: Style.space(24)

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: paginationRow.visible ? paginationRow.left : parent.right
        anchors.rightMargin: Style.space(8)
        elide: Text.ElideRight
        text: {
          if (root.totalFilteredCount === 0) return "0 articles"
          var start = root.currentPage * root.itemsPerPage + 1
          var end = Math.min(root.totalFilteredCount, (root.currentPage + 1) * root.itemsPerPage)
          return "Showing " + start + "-" + end + " of " + root.totalFilteredCount
        }
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
        color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)
      }

      // Pagination controls (Prev / Page Indicator / Next)
      Row {
        id: paginationRow
        visible: root.totalPages > 1
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        Rectangle {
          width: Style.space(22)
          height: Style.space(22)
          radius: Style.space(4)
          color: prevMouse.containsMouse && root.currentPage > 0 ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"
          opacity: root.currentPage > 0 ? 1.0 : 0.3

          Text {
            anchors.centerIn: parent
            text: "󰅁"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            color: root.contentForeground
          }

          MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.currentPage > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              if (root.currentPage > 0) {
                root.currentPage--
                root.selectedIndex = 0
              }
            }
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: (root.currentPage + 1) + " / " + root.totalPages
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.6)
        }

        Rectangle {
          width: Style.space(22)
          height: Style.space(22)
          radius: Style.space(4)
          color: nextMouse.containsMouse && root.currentPage < root.totalPages - 1 ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"
          opacity: root.currentPage < root.totalPages - 1 ? 1.0 : 0.3

          Text {
            anchors.centerIn: parent
            text: "󰅂"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            color: root.contentForeground
          }

          MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.currentPage < root.totalPages - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              if (root.currentPage < root.totalPages - 1) {
                root.currentPage++
                root.selectedIndex = 0
              }
            }
          }
        }
      }
    }
  }
}

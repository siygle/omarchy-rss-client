import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.rafaelvzago.rss"

  readonly property var configuredFeedUrls: {
    var urls = Model.httpsFeedUrls(setting("feedUrls", ""))
    return urls ? urls : []
  }
  readonly property int configuredMaxItemsPerFeed: {
    var raw = setting("maxItemsPerFeed", null)
    if (raw === undefined || raw === null || raw === "")
      return Model.maxItemsPerFeed(setting("recentListSize", 10))
    return Model.maxItemsPerFeed(raw)
  }
  readonly property int configuredPollIntervalMinutes: Model.pollIntervalMinutes(setting("pollIntervalMinutes", 15))
  readonly property int configuredItemsPerPage: Model.pageSize(setting("itemsPerPage", 10))
  readonly property string configuredBarSection: {
    var fromLayout = Model.sectionFromLayout(root.bar && root.bar.layoutConfig, root.moduleName)
    if (fromLayout) return fromLayout
    return Model.barSection(setting("barSection", "right"))
  }
  readonly property var settingsReadSet: Model.readIdentities(setting("readIdentities", ""))
  property var localReadSet: []
  readonly property var readSet: {
    var next = Model.readIdentities(Model.serializeReadIdentities(root.localReadSet))
    var extra = root.settingsReadSet || []
    for (var i = 0; i < extra.length; i++)
      next = Model.markRead(next, { identity: extra[i] })
    return next
  }
  readonly property int badgeCount: Model.unreadCount(root.items, root.readSet)
  readonly property string statePath: {
    var home = Quickshell.env("HOME") || ""
    return home + "/.local/share/omarchy-rss-plugin/state.json"
  }
  property var items: []
  property var pendingUrls: []
  property var collectedItems: []
  property var seenUrls: []
  property string currentFetchUrl: ""
  property bool restartWhenIdle: false
  property bool stateReady: false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("emptyCopy" in target) target.emptyCopy = Model.emptyPanelCopy(root.configuredFeedUrls)
    if ("items" in target) target.items = root.items
    if ("feedUrls" in target) target.feedUrls = Model.httpsFeedUrls(Model.serializeFeedUrls(root.configuredFeedUrls))
    if ("pollIntervalMinutes" in target) target.pollIntervalMinutes = root.configuredPollIntervalMinutes
    if ("maxItemsPerFeed" in target) target.maxItemsPerFeed = root.configuredMaxItemsPerFeed
    if ("itemsPerPage" in target) target.itemsPerPage = root.configuredItemsPerPage
    if ("barSection" in target) target.barSection = root.configuredBarSection
    if ("readSet" in target) target.readSet = root.readSet
    if ("lastImportResult" in target) target.lastImportResult = root.lastImportResult
    if ("shareStatus" in target && root.lastImportMessage) target.shareStatus = root.lastImportMessage
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function persistState() {
    if (!root.stateReady) return
    stateFile.setText(Model.serializeState(root.items, root.readSet) + "\n")
  }

  function applyLocalRead(next) {
    root.localReadSet = next
    persistSettings({
      readIdentities: Model.serializeReadIdentities(next)
    })
    persistState()
    injectPanel()
  }

  function applyBarSection(section) {
    var next = Model.barSection(section)
    persistSettings({ barSection: next })
    if (root.bar && typeof root.bar.run === "function")
      root.bar.run("omarchy bar move " + root.moduleName + " --section " + next)
  }

  property var lastImportResult: null
  property string lastImportMessage: ""
  property string selectedOpmlPath: ""

  function requestOpmlFileImport() {
    if (opmlSelectProcess.running || opmlValidateAndReadProcess.running) return
    root.selectedOpmlPath = ""
    console.log("[RSS-D696463-LIVE] requestOpmlFileImport entered")
    console.log("[RSS-D696463-LIVE] command passed to omarchy-file-select:", JSON.stringify(opmlSelectProcess.command))
    console.log("[RSS-D696463-LIVE] process started: opmlSelectProcess")
    opmlSelectProcess.running = true
  }

  function selectOpmlFile() {
    root.requestOpmlFileImport()
  }

  function handleSelectedOpmlFile(fileUrlOrPath) {
    var raw = String(fileUrlOrPath || "").trim()
    if (!raw) return
    console.log("[RSS-D696463-LIVE] handleSelectedOpmlFile entered with raw path/url:", JSON.stringify(raw))
    var resolvedPath = Model.filePathFromUrl(raw)
    if (!resolvedPath) return
    console.log("[RSS-D696463-LIVE] normalized selected path:", resolvedPath)
    root.selectedOpmlPath = resolvedPath
    opmlValidateAndReadProcess.sourcePath = resolvedPath
    opmlValidateAndReadProcess.command = [
      "python3", "-c",
      "import os, sys\n" +
      "path = sys.argv[1]\n" +
      "if not os.path.exists(path):\n" +
      "    sys.stderr.write('File not found\\n')\n" +
      "    sys.exit(1)\n" +
      "if os.path.isdir(path):\n" +
      "    sys.stderr.write('Selected path is a directory\\n')\n" +
      "    sys.exit(2)\n" +
      "if not os.path.isfile(path):\n" +
      "    sys.stderr.write('Selected path is not a regular file\\n')\n" +
      "    sys.exit(3)\n" +
      "size = os.path.getsize(path)\n" +
      "if size > 5242880:\n" +
      "    sys.stderr.write('File exceeds 5 MiB limit\\n')\n" +
      "    sys.exit(4)\n" +
      "with open(path, 'rb') as f:\n" +
      "    sys.stdout.buffer.write(f.read())\n",
      resolvedPath
    ]
    console.log("[RSS-D696463-LIVE] validation reader started for:", resolvedPath)
    opmlValidateAndReadProcess.running = true
  }

  function importSharedPayload(payloadText) {
    var raw = String(payloadText || "").trim()
    if (!raw) {
      root.lastImportMessage = "Nothing to import"
      root.lastImportResult = { status: "error", imported: 0, duplicates: 0, invalid: 0, message: "Nothing to import" }
      if (panelLoader.item) {
        panelLoader.item.shareStatus = "Nothing to import"
        panelLoader.item.lastImportResult = root.lastImportResult
      }
      return
    }
    var parseDetails = Model.parseOpmlDetails(raw)
    if (!parseDetails.feeds.length) {
      var parsed = Model.parseSharePayload(raw)
      parseDetails = { feeds: parsed, invalidCount: 0, totalFound: parsed.length }
    }
    var result = Model.calculateImportResult(root.configuredFeedUrls, parseDetails, "")
    root.lastImportResult = result
    root.lastImportMessage = result.message
    if (result.status === "success" && result.imported > 0) {
      persistSettings({ feedUrls: Model.serializeFeedUrls(result.newFeeds) })
      fetchFeed()
    }
    if (panelLoader.item) {
      panelLoader.item.feedUrls = Model.httpsFeedUrls(Model.serializeFeedUrls(root.configuredFeedUrls))
      panelLoader.item.shareStatus = result.message
      panelLoader.item.lastImportResult = result
    }
    injectPanel()
  }

  function shareFeeds(urls) {
    var list = urls && urls.length ? urls : root.configuredFeedUrls
    var payload = Model.sharePayload(list)
    var quoted = "'" + String(payload).replace(/'/g, "'\\''") + "'"
    Quickshell.execDetached(["bash", "-lc", "printf %s " + quoted + " | wl-copy"])
    return Model.httpsFeedUrls(list).length
  }

  function importFeeds(urls) {
    var next = Model.httpsFeedUrls(Model.serializeFeedUrls(urls))
    persistSettings({ feedUrls: Model.serializeFeedUrls(next) })
    fetchFeed()
    return next.length
  }

  function saveConfig(urls, minutes, perFeed, perPage, section) {
    persistSettings({
      feedUrls: Model.serializeFeedUrls(Model.httpsFeedUrls(urls)),
      pollIntervalMinutes: Model.pollIntervalMinutes(minutes),
      maxItemsPerFeed: Model.maxItemsPerFeed(perFeed),
      itemsPerPage: Model.pageSize(perPage),
      barSection: Model.barSection(section)
    })
    applyBarSection(section)
    fetchFeed()
  }

  function markItemRead(item) {
    applyLocalRead(Model.markRead(root.readSet, item))
  }

  function markItemsRead(items) {
    applyLocalRead(Model.markAllRead(root.readSet, items))
  }

  function activateItem(item) {
    var url = Model.activateUrl(item)
    if (!url) return
    Qt.openUrlExternally(url)
    applyLocalRead(Model.markRead(root.readSet, item))
    if (panelLoader.item) panelLoader.item.close()
  }

  function enqueueUnique(urls) {
    var queue = root.pendingUrls ? root.pendingUrls.slice() : []
    var seen = root.seenUrls ? root.seenUrls.slice() : []
    var list = urls || []
    for (var i = 0; i < list.length; i++) {
      var url = String(list[i] || "")
      if (!Model.isHttpsUrl(url)) continue
      var already = false
      for (var s = 0; s < seen.length; s++) if (seen[s] === url) already = true
      for (var q = 0; q < queue.length; q++) if (queue[q] === url) already = true
      if (already) continue
      seen.push(url)
      queue.unshift(url)
    }
    root.seenUrls = seen
    root.pendingUrls = queue
  }

  function applyBody(raw) {
    var split = Model.splitFetchedBody(raw)
    var body = split.body
    if (!Model.isFeedTextResponse(split.contentType, body)) return
    var parsed = Model.parseFeed(body)
    if (parsed.ok && parsed.items && parsed.items.length) {
      var next = []
      var existing = root.collectedItems || []
      for (var i = 0; i < existing.length; i++) next.push(existing[i])
      var incoming = Model.recentList(parsed.items, root.configuredMaxItemsPerFeed)
      for (var j = 0; j < incoming.length; j++) next.push(incoming[j])
      root.collectedItems = next
      return
    }
    if (!Model.looksLikeHtml(body)) return
    var discovered = Model.discoverFeedUrls(body, root.currentFetchUrl)
    if (!discovered || discovered.length === 0)
      discovered = Model.guessFeedUrls(root.currentFetchUrl)
    root.enqueueUnique(discovered)
  }

  function finishFetch() {
    root.items = Model.uniqueItems(root.collectedItems)
    persistState()
    injectPanel()
  }

  function fetchNext() {
    var queue = root.pendingUrls
    if (!queue || queue.length === 0) {
      root.finishFetch()
      return
    }
    var next = queue[0]
    var rest = []
    for (var i = 1; i < queue.length; i++) rest.push(queue[i])
    root.pendingUrls = rest
    if (!Model.isHttpsUrl(next)) {
      root.fetchNext()
      return
    }
    root.currentFetchUrl = next
    var seen = root.seenUrls ? root.seenUrls.slice() : []
    var known = false
    for (var s = 0; s < seen.length; s++) if (seen[s] === next) known = true
    if (!known) {
      seen.push(next)
      root.seenUrls = seen
    }
    fetchProcess.command = [
      "curl", "-fsSL",
      "--proto", "=https",
      "--proto-redir", "=https",
      "--max-redirs", "5",
      "--max-filesize", String(Model.maxFeedBytes()),
      "--max-time", "20",
      "-A", "omarchy-rss-plugin/0.1",
      "-H", "Accept: application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.9, text/html;q=0.8",
      "-w", "\n__OMARCHY_CT__:%{content_type}",
      next
    ]
    fetchProcess.running = true
  }

  function startFetch() {
    var urls = root.configuredFeedUrls
    root.collectedItems = []
    root.seenUrls = []
    root.currentFetchUrl = ""
    root.restartWhenIdle = false
    if (!urls || urls.length === 0) {
      root.pendingUrls = []
      root.items = []
      persistState()
      injectPanel()
      return
    }
    var queue = []
    for (var i = 0; i < urls.length; i++) queue.push(urls[i])
    root.pendingUrls = queue
    root.fetchNext()
  }

  function fetchFeed() {
    if (fetchProcess.running) {
      root.restartWhenIdle = true
      return
    }
    root.startFetch()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onConfiguredFeedUrlsChanged: fetchFeed()

  Component.onCompleted: mkdirProcess.running = true

  Timer {
    interval: root.configuredPollIntervalMinutes * 60 * 1000
    repeat: true
    running: root.configuredFeedUrls && root.configuredFeedUrls.length > 0
    onTriggered: root.fetchFeed()
  }

  Process {
    id: mkdirProcess
    command: ["mkdir", "-p", String(Quickshell.env("HOME") || "") + "/.local/share/omarchy-rss-plugin"]
    onExited: stateFile.reload()
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var parsed = Model.parseState(text())
      root.localReadSet = parsed.readIdentities
      if (parsed.items && parsed.items.length) root.items = parsed.items
      root.stateReady = true
      root.injectPanel()
      root.fetchFeed()
    }
    onLoadFailed: {
      root.stateReady = true
      root.localReadSet = root.settingsReadSet
      root.fetchFeed()
    }
  }

  Process {
    id: fetchProcess
    stdout: StdioCollector {
      id: fetchStdout
      waitForEnd: true
      onStreamFinished: root.applyBody(fetchStdout.text)
    }
    onExited: function() {
      if (root.restartWhenIdle) {
        root.startFetch()
        return
      }
      root.fetchNext()
    }
  }

  Process {
    id: opmlSelectProcess
    command: ["omarchy-file-select", "--title", "Select OPML file", "--extensions", "opml xml"]
    stdout: StdioCollector {
      id: opmlSelectStdout
      waitForEnd: true
      onStreamFinished: {
        console.log("[RSS-D696463-LIVE] raw stdout: " + JSON.stringify(opmlSelectStdout.text))
        var path = String(opmlSelectStdout.text || "").trim()
        if (path) root.selectedOpmlPath = path
      }
    }
    onExited: function(exitCode) {
      console.log("[RSS-D696463-LIVE] process exited: opmlSelectProcess, exit code: " + exitCode)
      console.log("[RSS-D696463-LIVE] raw selected path: " + JSON.stringify(root.selectedOpmlPath))
      if (exitCode === 0 && root.selectedOpmlPath) {
        root.handleSelectedOpmlFile(root.selectedOpmlPath)
      }
    }
  }

  Process {
    id: opmlValidateAndReadProcess
    property string sourcePath: ""
    stdout: StdioCollector {
      id: opmlStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: opmlStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      console.log("[RSS-D696463-LIVE] validation reader exit code: " + exitCode)
      if (exitCode !== 0) {
        var err = String(opmlStderr.text || "").trim() || "Failed to read file"
        root.lastImportResult = {
          status: "error",
          imported: 0,
          duplicates: 0,
          invalid: 0,
          message: err
        }
        root.lastImportMessage = err
        if (panelLoader.item) {
          panelLoader.item.shareStatus = err
          panelLoader.item.lastImportResult = root.lastImportResult
        }
        return
      }
      var content = String(opmlStdout.text || "")
      console.log("[RSS-D696463-LIVE] parser entered with payload length: " + content.length)
      var filename = Model.filenameFromPath(opmlValidateAndReadProcess.sourcePath)
      var parseDetails = Model.parseOpmlDetails(content)
      if (!parseDetails.feeds.length) {
        var parsed = Model.parseSharePayload(content)
        parseDetails = { feeds: parsed, invalidCount: 0, totalFound: parsed.length }
      }
      var result = Model.calculateImportResult(root.configuredFeedUrls, parseDetails, filename)
      console.log("[RSS-D696463-LIVE] parsed count: " + parseDetails.feeds.length + ", result: " + JSON.stringify(result))
      root.lastImportResult = result
      root.lastImportMessage = result.message
      if (result.status === "success" && result.imported > 0) {
        persistSettings({ feedUrls: Model.serializeFeedUrls(result.newFeeds) })
        fetchFeed()
        console.log("[RSS-D696463-LIVE] persisted feed count: " + result.newFeeds.length)
      }
      if (panelLoader.item) {
        panelLoader.item.feedUrls = Model.httpsFeedUrls(Model.serializeFeedUrls(root.configuredFeedUrls))
        panelLoader.item.shareStatus = result.message
        panelLoader.item.lastImportResult = result
      }
      injectPanel()
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰑫"
    tooltipText: root.badgeCount > 0 ? ("RSS · " + root.badgeCount + " unread") : "RSS"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.togglePanel()
    }

    Rectangle {
      visible: root.badgeCount > 0
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: 1
      anchors.bottomMargin: 1
      width: Style.space(4)
      height: width
      radius: width / 2
      color: Color.accent
    }
  }
}

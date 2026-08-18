function barSection(value) {
  var name = String(value || "").trim().toLowerCase()
  if (name === "left" || name === "center" || name === "right") return name
  return "right"
}

function sectionFromLayout(layout, id) {
  var key = String(id || "")
  var sections = ["left", "center", "right"]
  if (!layout) return ""
  for (var s = 0; s < sections.length; s++) {
    var entries = layout[sections[s]] || []
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      var entryId = entry && typeof entry === "object" ? entry.id : entry
      if (String(entryId || "") === key) return sections[s]
    }
  }
  return ""
}

function pollIntervalMinutes(value) {
  var n = Number(value)
  if (value === undefined || value === null || value === "" || !isFinite(n)) return 15
  if (n < 5) return 5
  return n
}

function recentListSize(value) {
  var n = Number(value)
  if (value === undefined || value === null || value === "" || !isFinite(n)) return 20
  if (n < 1) return 1
  return Math.floor(n)
}

function maxItemsPerFeed(value) {
  var n = Number(value)
  if (value === undefined || value === null || value === "" || !isFinite(n)) return 10
  if (n < 1) return 1
  return Math.floor(n)
}

function maxFeedBytes() {
  return 2097152
}

function isHttpsUrl(url) {
  var value = String(url || "").trim()
  if (!value) return false
  if (/\s/.test(value)) return false
  return /^https:\/\/[^\/?#\s]+/i.test(value)
}

function httpsFeedUrls(value) {
  var list = feedUrls(value)
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (isHttpsUrl(list[i])) out.push(list[i])
  }
  return out
}

function feedUrls(value) {
  if (value === undefined || value === null) return []
  if (typeof value !== "string" && value.length !== undefined && typeof value !== "function") {
    var fromList = []
    for (var i = 0; i < value.length; i++) {
      var item = String(value[i] || "").trim()
      if (item) fromList.push(item)
    }
    if (fromList.length) return fromList
  }
  var text = String(value)
  var lines = text.split(/\r?\n/)
  var urls = []
  for (var j = 0; j < lines.length; j++) {
    var line = lines[j].trim()
    if (line.length > 0) urls.push(line)
  }
  return urls
}

function filterItems(items, query) {
  var needle = String(query || "").trim().toLowerCase()
  var list = items || []
  if (!needle) return list
  var out = []
  for (var i = 0; i < list.length; i++) {
    var item = list[i] || {}
    var hay = [item.title, item.excerpt, item.feedName, item.link, item.identity].join(" ").toLowerCase()
    if (hay.indexOf(needle) !== -1) out.push(item)
  }
  return out
}

function serializeState(items, readSet) {
  return JSON.stringify({
    version: 1,
    items: items || [],
    readIdentities: readIdentities(serializeReadIdentities(readSet))
  })
}

function parseState(text) {
  var empty = { items: [], readIdentities: [] }
  if (!text) return empty
  try {
    var data = JSON.parse(String(text))
    if (!data || typeof data !== "object") return empty
    return {
      items: uniqueItems(data.items || []),
      readIdentities: readIdentities(data.readIdentities)
    }
  } catch (e) {
    return empty
  }
}

function uniqueItems(items) {
  var list = recentList(items || [], (items && items.length) || 1)
  var seen = {}
  var out = []
  for (var i = 0; i < list.length; i++) {
    var id = itemIdentity(list[i])
    if (!id || seen[id]) continue
    seen[id] = true
    out.push(list[i])
  }
  return out
}

function emptyPanelCopy(urls) {
  if (!urls || urls.length === 0) return "Add feed URLs in Settings."
  return "No recent items"
}

function pageSize(value) {
  var n = Number(value)
  if (value === undefined || value === null || value === "" || !isFinite(n)) return 10
  if (n < 1) return 1
  if (n > 100) return 100
  return Math.floor(n)
}

function pageCount(items, perPage) {
  var n = items && items.length ? items.length : 0
  if (n === 0) return 1
  return Math.ceil(n / pageSize(perPage))
}

function pageIndex(items, page, perPage) {
  var max = pageCount(items, perPage) - 1
  var n = Number(page)
  if (!isFinite(n) || n < 0) return 0
  if (n > max) return max
  return Math.floor(n)
}

function pageItems(items, page, perPage) {
  var list = items || []
  var size = pageSize(perPage)
  var index = pageIndex(list, page, size)
  var start = index * size
  return list.slice(start, start + size)
}

function serializeFeedUrls(urls) {
  var list = urls || []
  var lines = []
  for (var i = 0; i < list.length; i++) {
    var line = String(list[i] || "").trim()
    if (line) lines.push(line)
  }
  return lines.join("\n")
}

function sharePayload(urls) {
  return JSON.stringify({
    omarchyRss: 1,
    feeds: httpsFeedUrls(serializeFeedUrls(urls))
  })
}

function filePathFromUrl(urlOrPath) {
  var raw = String(urlOrPath || "").trim()
  if (!raw) return ""
  if (/^file:\/\//i.test(raw)) {
    var pathOnly = raw.replace(/^file:\/\/(localhost)?/i, "")
    try {
      return decodeURIComponent(pathOnly)
    } catch (e) {
      return pathOnly
    }
  }
  return raw
}

function filenameFromPath(filePath) {
  var raw = String(filePath || "").trim()
  if (!raw) return ""
  return raw.replace(/^.*[\\\/]/, "")
}

function parseOpmlDetails(text) {
  var raw = String(text || "").trim()
  if (!raw) return { feeds: [], invalidCount: 0, totalFound: 0 }
  var valid = []
  var invalid = 0
  var total = 0
  var re = /xmlUrl\s*=\s*["']([^"']+)["']/gi
  var match
  while ((match = re.exec(raw))) {
    total++
    var url = decodeEntities(match[1]).trim()
    if (isHttpsUrl(url)) {
      valid.push(url)
    } else {
      invalid++
    }
  }
  return {
    feeds: valid,
    invalidCount: invalid,
    totalFound: total
  }
}

function parseOpml(text) {
  return parseOpmlDetails(text).feeds
}

function calculateImportResult(currentFeeds, parsedResult, filename) {
  var current = httpsFeedUrls(currentFeeds)
  var incoming = []
  var invalidCount = 0
  if (parsedResult && typeof parsedResult === "object" && parsedResult.feeds) {
    incoming = httpsFeedUrls(parsedResult.feeds)
    invalidCount = typeof parsedResult.invalidCount === "number" ? parsedResult.invalidCount : 0
  } else {
    incoming = httpsFeedUrls(parsedResult)
  }
  var incomingUnique = []
  for (var i = 0; i < incoming.length; i++) {
    if (incomingUnique.indexOf(incoming[i]) === -1) incomingUnique.push(incoming[i])
  }
  var added = []
  var duplicates = 0
  for (var j = 0; j < incomingUnique.length; j++) {
    if (current.indexOf(incomingUnique[j]) === -1) {
      added.push(incomingUnique[j])
    } else {
      duplicates++
    }
  }
  var nameLabel = filename ? (" from " + filename) : ""
  var parts = []
  if (added.length > 0) {
    parts.push("Imported " + added.length + " feed" + (added.length === 1 ? "" : "s") + nameLabel)
  } else if (duplicates > 0) {
    parts.push("All " + duplicates + " feed" + (duplicates === 1 ? "" : "s") + nameLabel + " already added")
  } else {
    parts.push("No valid feeds found" + nameLabel)
  }
  if (duplicates > 0 && added.length > 0) {
    parts.push(duplicates + " duplicate" + (duplicates === 1 ? "" : "s"))
  }
  if (invalidCount > 0) {
    parts.push(invalidCount + " need attention")
  }
  var message = parts.join(" · ")
  var nextFeeds = current.slice()
  for (var k = 0; k < added.length; k++) nextFeeds.push(added[k])
  return {
    status: (added.length > 0 || duplicates > 0) ? "success" : "error",
    imported: added.length,
    duplicates: duplicates,
    invalid: invalidCount,
    message: message,
    newFeeds: nextFeeds
  }
}

function parseSharePayload(text) {
  var raw = String(text || "").trim()
  if (!raw) return []
  try {
    var data = JSON.parse(raw)
    if (data && typeof data === "object") {
      if (data.feeds) return httpsFeedUrls(data.feeds)
      if (data.omarchyRss && data.urls) return httpsFeedUrls(data.urls)
    }
  } catch (e) {}
  var fromOpml = parseOpml(raw)
  if (fromOpml.length) return fromOpml
  return httpsFeedUrls(raw)
}

function mergeFeedLists(current, incoming) {
  var next = httpsFeedUrls(serializeFeedUrls(current))
  var add = httpsFeedUrls(serializeFeedUrls(incoming))
  for (var i = 0; i < add.length; i++) next = addFeedUrl(next, add[i])
  return next
}

function addFeedUrl(urls, url) {
  var next = httpsFeedUrls(serializeFeedUrls(urls))
  var value = String(url || "").trim()
  if (!isHttpsUrl(value)) return next
  for (var i = 0; i < next.length; i++) {
    if (next[i] === value) return next
  }
  next.push(value)
  return next
}

function removeFeedUrl(urls, url) {
  var next = []
  var value = String(url || "").trim()
  var list = urls || []
  for (var i = 0; i < list.length; i++) {
    if (String(list[i] || "").trim() !== value) next.push(list[i])
  }
  return next
}

function activateUrl(item) {
  if (!item) return ""
  var link = String(item.link || "").trim()
  return isHttpsUrl(link) ? link : ""
}

function itemIdentity(item) {
  if (!item) return ""
  return String(item.identity || "").trim()
}

function readIdentities(value) {
  return feedUrls(value)
}

function serializeReadIdentities(ids) {
  return serializeFeedUrls(ids)
}

function isRead(readSet, item) {
  var id = itemIdentity(item)
  if (!id) return false
  var list = readSet || []
  for (var i = 0; i < list.length; i++) {
    if (String(list[i]) === id) return true
  }
  return false
}

function markRead(readSet, item) {
  var id = itemIdentity(item)
  var next = readIdentities(serializeReadIdentities(readSet))
  if (!id) return next
  for (var i = 0; i < next.length; i++) {
    if (next[i] === id) return next
  }
  next.push(id)
  return next
}

function unreadCount(items, readSet) {
  return tabItems(items, readSet, "new").length
}

function compactCount(value) {
  var n = Number(value)
  if (!isFinite(n) || n <= 0) return "0"
  n = Math.floor(n)
  return n > 99 ? "99+" : String(n)
}

function markAllRead(readSet, items) {
  var next = readIdentities(serializeReadIdentities(readSet))
  var list = items || []
  for (var i = 0; i < list.length; i++) next = markRead(next, list[i])
  return next
}

function mergeFeeds(feedItemLists, perFeedMax) {
  var cap = maxItemsPerFeed(perFeedMax)
  var mixed = []
  var lists = feedItemLists || []
  for (var i = 0; i < lists.length; i++) {
    var capped = recentList(lists[i], cap)
    for (var j = 0; j < capped.length; j++) mixed.push(capped[j])
  }
  return recentList(mixed, mixed.length || 1)
}

function tabItems(items, readSet, tab) {
  var list = items || []
  var wantRead = tab === "read"
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (isRead(readSet, list[i]) === wantRead) out.push(list[i])
  }
  return out
}

function stripCdata(text) {
  var value = String(text || "")
  var wrapped = value.match(/^<!\[CDATA\[([\s\S]*?)\]\]>$/)
  return wrapped ? wrapped[1] : value.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
}

function decodeEntities(text) {
  return String(text || "")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&apos;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, "&")
}

function stripHtml(text) {
  return decodeEntities(stripCdata(text))
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .replace(/\s+([.,!?;:])/g, "$1")
    .trim()
}

function tagInner(block, tag) {
  var pattern = new RegExp("<" + tag + "\\b[^>]*>([\\s\\S]*?)</" + tag + "\\s*>", "i")
  var match = String(block || "").match(pattern)
  return match ? match[1] : ""
}

function parsePubDate(text) {
  var raw = stripHtml(text)
  if (!raw) return null
  var ms = Date.parse(raw)
  if (!isFinite(ms)) return null
  return ms
}

function attributeValue(tag, name) {
  var match = String(tag || "").match(new RegExp(name + "\\s*=\\s*[\"']([^\"']+)[\"']", "i"))
  return match ? match[1] : ""
}

function alternateLink(block) {
  var tags = String(block || "").match(/<link\b[^>]*>/gi) || []
  var fallback = ""
  for (var i = 0; i < tags.length; i++) {
    var href = attributeValue(tags[i], "href")
    if (!href) continue
    var rel = attributeValue(tags[i], "rel")
    if (!rel || rel === "alternate") return href
    if (!fallback) fallback = href
  }
  return fallback
}

function looksLikeHtml(body) {
  var source = String(body || "")
  if (!source) return false
  if (/<rss\b/i.test(source) || /<feed\b/i.test(source)) return false
  return /<!doctype html/i.test(source) || /<html\b/i.test(source)
}

function looksLikeFeedText(body) {
  var source = String(body || "")
  if (!source || source.indexOf("\0") !== -1) return false
  if (looksLikeHtml(source)) return true
  return /<\?xml\b/i.test(source) || /<rss\b/i.test(source) || /<feed\b/i.test(source)
}

function splitFetchedBody(text) {
  var raw = String(text == null ? "" : text)
  var marker = "\n__OMARCHY_CT__:"
  var at = raw.lastIndexOf(marker)
  if (at === -1) {
    if (raw.indexOf("__OMARCHY_CT__:") === 0)
      return { body: "", contentType: raw.slice("__OMARCHY_CT__:".length) }
    return { body: raw, contentType: "" }
  }
  return {
    body: raw.slice(0, at),
    contentType: raw.slice(at + marker.length)
  }
}

function isFeedTextResponse(contentType, body) {
  var source = String(body || "")
  if (!source || source.length > maxFeedBytes() || source.indexOf("\0") !== -1) return false
  var type = String(contentType || "").split(";")[0].trim().toLowerCase()
  if (!type) return looksLikeFeedText(source)
  if (type.indexOf("image/") === 0 || type.indexOf("audio/") === 0 || type.indexOf("video/") === 0)
    return false
  if (type === "application/octet-stream" || type === "application/pdf" || type === "application/zip")
    return false
  if (
    type === "application/rss+xml" ||
    type === "application/atom+xml" ||
    type === "application/xml" ||
    type === "text/xml" ||
    type === "text/html" ||
    type === "application/xhtml+xml"
  )
    return true
  return looksLikeFeedText(source)
}

function originOf(url) {
  if (!isHttpsUrl(url)) return ""
  var match = String(url || "").match(/^(https:\/\/[^\/]+)/i)
  return match ? match[1] : ""
}

function resolveUrl(base, href) {
  var ref = String(href || "").trim()
  if (!ref) return ""
  if (/^[a-z][a-z0-9+.-]*:/i.test(ref)) return isHttpsUrl(ref) ? ref : ""
  if (ref.indexOf("//") === 0) {
    if (!isHttpsUrl(base)) return ""
    var joined = "https:" + ref
    return isHttpsUrl(joined) ? joined : ""
  }
  var origin = originOf(base)
  if (!origin) return ""
  var resolved = ""
  if (ref.charAt(0) === "/") resolved = origin + ref
  else {
    var dir = String(base || "").replace(/[?#].*$/, "")
    dir = dir.replace(/\/[^\/]*$/, "/")
    if (dir.indexOf(origin) !== 0) dir = origin + "/"
    resolved = dir + ref
  }
  return isHttpsUrl(resolved) ? resolved : ""
}

function discoverFeedUrls(html, pageUrl) {
  var tags = String(html || "").match(/<link\b[^>]*>/gi) || []
  var found = []
  for (var i = 0; i < tags.length; i++) {
    var tag = tags[i]
    var rel = attributeValue(tag, "rel").toLowerCase()
    var type = attributeValue(tag, "type").toLowerCase()
    var href = attributeValue(tag, "href")
    var isFeedType = type.indexOf("rss+xml") !== -1 || type.indexOf("atom+xml") !== -1
    var isAlternate = rel.indexOf("alternate") !== -1
    if (!href || !isFeedType || !isAlternate) continue
    var absolute = resolveUrl(pageUrl, href)
    if (!isHttpsUrl(absolute)) continue
    var seen = false
    for (var j = 0; j < found.length; j++) if (found[j] === absolute) seen = true
    if (!seen) found.push(absolute)
  }
  return found
}

function guessFeedUrls(pageUrl) {
  var origin = originOf(pageUrl)
  if (!origin) return []
  var paths = ["/feed.xml", "/atom.xml", "/rss.xml", "/feed", "/index.xml"]
  var out = []
  for (var i = 0; i < paths.length; i++) out.push(origin + paths[i])
  return out
}

function parseAtom(xml) {
  var source = String(xml || "")
  if (!/<feed\b/i.test(source)) return { ok: false, feedName: "", items: [] }

  var entries = source.match(/<entry\b[\s\S]*?<\/entry>/gi) || []
  var withoutEntries = source.replace(/<entry\b[\s\S]*?<\/entry>/gi, "")
  var feedName = stripHtml(tagInner(withoutEntries, "title"))
  var items = []
  for (var i = 0; i < entries.length; i++) {
    var block = entries[i]
    var identity = stripHtml(tagInner(block, "id")) || alternateLink(block)
    if (!identity) continue
    var link = alternateLink(block)
    var title = stripHtml(tagInner(block, "title"))
    var excerpt = stripHtml(tagInner(block, "content")) || stripHtml(tagInner(block, "summary"))
    var published = parsePubDate(tagInner(block, "published"))
    if (published == null) published = parsePubDate(tagInner(block, "updated"))
    items.push({
      identity: identity,
      link: link,
      title: title,
      excerpt: excerpt,
      feedName: feedName,
      pubDateMs: published
    })
  }
  return { ok: true, feedName: feedName, items: items }
}

function parseFeed(xml) {
  var rss = parseRss20(xml)
  if (rss.ok) return rss
  return parseAtom(xml)
}

function parseRss20(xml) {
  var source = String(xml || "")
  var hasRss20 = /<rss\b[^>]*version\s*=\s*["']2\.0["']/i.test(source)
  var hasAtomFeed = /<feed\b[^>]*xmlns\s*=\s*["'][^"']*Atom/i.test(source) || /<feed\b[^>]*xmlns\s*=\s*["']http:\/\/www\.w3\.org\/2005\/Atom["']/i.test(source)
  if (!hasRss20 || hasAtomFeed) {
    return { ok: false, feedName: "", items: [] }
  }

  var channel = (source.match(/<channel\b[\s\S]*<\/channel>/i) || [source])[0]
  var feedName = stripHtml(tagInner(channel, "title"))
  var items = []
  var itemBlocks = channel.match(/<item\b[\s\S]*?<\/item>/gi) || []
  for (var i = 0; i < itemBlocks.length; i++) {
    var block = itemBlocks[i]
    var guid = stripHtml(tagInner(block, "guid"))
    var link = stripHtml(tagInner(block, "link"))
    var identity = guid || link
    if (!identity) continue
    var title = stripHtml(tagInner(block, "title"))
    var excerpt = stripHtml(tagInner(block, "description"))
    items.push({
      identity: identity,
      link: link,
      title: title,
      excerpt: excerpt,
      feedName: feedName,
      pubDateMs: parsePubDate(tagInner(block, "pubDate"))
    })
  }
  return { ok: true, feedName: feedName, items: items }
}

function recentList(items, n) {
  var size = recentListSize(n)
  var copy = (items || []).slice()
  copy.sort(function (a, b) {
    var aDate = a && a.pubDateMs != null && isFinite(a.pubDateMs) ? a.pubDateMs : null
    var bDate = b && b.pubDateMs != null && isFinite(b.pubDateMs) ? b.pubDateMs : null
    if (aDate === null && bDate === null) {
      var aId = a && a.identity ? String(a.identity) : ""
      var bId = b && b.identity ? String(b.identity) : ""
      if (aId < bId) return -1
      if (aId > bId) return 1
      return 0
    }
    if (aDate === null) return 1
    if (bDate === null) return -1
    return bDate - aDate
  })
  return copy.slice(0, size)
}

function rowText(item) {
  if (!item) return ""
  if (item.title) return item.title
  return item.excerpt || ""
}

function relativeTime(pubDateMs, nowMs) {
  if (pubDateMs == null || !isFinite(pubDateMs)) return ""
  var now = nowMs != null ? nowMs : Date.now()
  var delta = now - pubDateMs
  if (!isFinite(delta) || delta < 0) return ""
  var minutes = Math.floor(delta / 60000)
  if (minutes < 1) return "just now"
  if (minutes < 60) return minutes + "m"
  var hours = Math.floor(minutes / 60)
  if (hours < 24) return hours + "h"
  var days = Math.floor(hours / 24)
  return days + "d"
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    pollIntervalMinutes: pollIntervalMinutes,
    barSection: barSection,
    sectionFromLayout: sectionFromLayout,
    recentListSize: recentListSize,
    maxItemsPerFeed: maxItemsPerFeed,
    unreadCount: unreadCount,
    compactCount: compactCount,
    markAllRead: markAllRead,
    mergeFeeds: mergeFeeds,
    uniqueItems: uniqueItems,
    filterItems: filterItems,
    serializeState: serializeState,
    parseState: parseState,
    feedUrls: feedUrls,
    httpsFeedUrls: httpsFeedUrls,
    isHttpsUrl: isHttpsUrl,
    maxFeedBytes: maxFeedBytes,
    splitFetchedBody: splitFetchedBody,
    isFeedTextResponse: isFeedTextResponse,
    emptyPanelCopy: emptyPanelCopy,
    pageSize: pageSize,
    pageCount: pageCount,
    pageIndex: pageIndex,
    pageItems: pageItems,
    serializeFeedUrls: serializeFeedUrls,
    addFeedUrl: addFeedUrl,
    sharePayload: sharePayload,
    filePathFromUrl: filePathFromUrl,
    filenameFromPath: filenameFromPath,
    parseOpmlDetails: parseOpmlDetails,
    parseOpml: parseOpml,
    calculateImportResult: calculateImportResult,
    parseSharePayload: parseSharePayload,
    mergeFeedLists: mergeFeedLists,
    removeFeedUrl: removeFeedUrl,
    activateUrl: activateUrl,
    itemIdentity: itemIdentity,
    readIdentities: readIdentities,
    serializeReadIdentities: serializeReadIdentities,
    isRead: isRead,
    markRead: markRead,
    tabItems: tabItems,
    parseRss20: parseRss20,
    parseAtom: parseAtom,
    parseFeed: parseFeed,
    looksLikeHtml: looksLikeHtml,
    discoverFeedUrls: discoverFeedUrls,
    guessFeedUrls: guessFeedUrls,
    resolveUrl: resolveUrl,
    recentList: recentList,
    rowText: rowText,
    relativeTime: relativeTime,
    stripHtml: stripHtml
  }
}

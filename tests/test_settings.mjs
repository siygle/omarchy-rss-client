import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const Model = require(join(dirname(fileURLToPath(import.meta.url)), "..", "Model.js"));

test("bar section is left, center, or right", () => {
  assert.equal(Model.barSection("left"), "left");
  assert.equal(Model.barSection("CENTER"), "center");
  assert.equal(Model.barSection("nope"), "right");
  assert.equal(
    Model.sectionFromLayout(
      { left: [], center: [{ id: "io.github.rafaelvzago.rss" }], right: [] },
      "io.github.rafaelvzago.rss"
    ),
    "center"
  );
});

test("poll interval defaults to 15 minutes", () => {
  assert.equal(Model.pollIntervalMinutes(undefined), 15);
  assert.equal(Model.pollIntervalMinutes(null), 15);
  assert.equal(Model.pollIntervalMinutes(""), 15);
});

test("poll interval cannot go below 5 minutes", () => {
  assert.equal(Model.pollIntervalMinutes(1), 5);
  assert.equal(Model.pollIntervalMinutes(0), 5);
  assert.equal(Model.pollIntervalMinutes(-3), 5);
  assert.equal(Model.pollIntervalMinutes(5), 5);
  assert.equal(Model.pollIntervalMinutes(30), 30);
});

test("recent list size defaults to 20", () => {
  assert.equal(Model.recentListSize(undefined), 20);
});

test("recent list size is at least 1", () => {
  assert.equal(Model.recentListSize(0), 1);
  assert.equal(Model.recentListSize(-2), 1);
  assert.equal(Model.recentListSize(7), 7);
});

test("feed URLs are one per line, blanks ignored", () => {
  assert.deepEqual(Model.feedUrls(undefined), []);
  assert.deepEqual(Model.feedUrls(""), []);
  assert.deepEqual(Model.feedUrls("  \n  "), []);
  assert.deepEqual(
    Model.feedUrls("https://a.example/rss\n\nhttps://b.example/feed.xml\n"),
    ["https://a.example/rss", "https://b.example/feed.xml"]
  );
  assert.deepEqual(Model.feedUrls(["https://a.example/rss", "https://b.example/feed.xml"]), [
    "https://a.example/rss",
    "https://b.example/feed.xml",
  ]);
});

test("merged items are unique by identity and newest first", () => {
  const mixed = Model.uniqueItems([
    { identity: "a", pubDateMs: 1 },
    { identity: "b", pubDateMs: 3 },
    { identity: "a", pubDateMs: 2 },
  ]);
  assert.deepEqual(
    mixed.map((item) => item.identity),
    ["b", "a"]
  );
});

test("no feed URLs uses the add-settings empty copy", () => {
  assert.equal(Model.emptyPanelCopy([]), "Add feed URLs in Settings.");
});

test("page size defaults to 10 and stays between 1 and 100", () => {
  assert.equal(Model.pageSize(), 10);
  assert.equal(Model.pageSize(0), 1);
  assert.equal(Model.pageSize(7), 7);
  assert.equal(Model.pageSize(101), 100);
});

test("pageItems returns at most 10 items for the requested page", () => {
  const items = Array.from({ length: 23 }, (_, i) => ({ identity: String(i) }));
  assert.equal(Model.pageCount(items), 3);
  assert.deepEqual(
    Model.pageItems(items, 0).map((item) => item.identity),
    ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
  );
  assert.deepEqual(
    Model.pageItems(items, 2).map((item) => item.identity),
    ["20", "21", "22"]
  );
  assert.equal(Model.pageIndex(items, 99), 2);
  assert.equal(Model.pageIndex([], 3), 0);
});

test("pagination accepts a configured page size", () => {
  const items = Array.from({ length: 11 }, (_, i) => ({ identity: String(i) }));
  assert.equal(Model.pageCount(items, 4), 3);
  assert.deepEqual(
    Model.pageItems(items, 1, 4).map((item) => item.identity),
    ["4", "5", "6", "7"]
  );
  assert.equal(Model.pageIndex(items, 99, 4), 2);
});

test("share payload round-trips and import merges unique feeds", () => {
  const shared = Model.sharePayload(["https://a.example/rss", "https://b.example/feed.xml"]);
  assert.deepEqual(Model.parseSharePayload(shared), [
    "https://a.example/rss",
    "https://b.example/feed.xml",
  ]);
  const opml = `<opml><outline xmlUrl="https://c.example/atom.xml"/></opml>`;
  assert.deepEqual(Model.parseSharePayload(opml), ["https://c.example/atom.xml"]);
  assert.deepEqual(
    Model.parseSharePayload("https://ok.example/rss\nhttp://no.example/rss\nfile:///tmp/x"),
    ["https://ok.example/rss"]
  );
  assert.deepEqual(
    Model.mergeFeedLists(["https://a.example/rss"], ["https://a.example/rss", "https://d.example/rss"]),
    ["https://a.example/rss", "https://d.example/rss"]
  );
});

test("add and remove feed URLs, serialized one per line", () => {
  const added = Model.addFeedUrl(["https://a.example/rss"], "https://b.example/feed.xml");
  assert.deepEqual(added, ["https://a.example/rss", "https://b.example/feed.xml"]);
  assert.deepEqual(Model.addFeedUrl(added, "https://a.example/rss"), added);
  assert.deepEqual(Model.addFeedUrl(added, "http://insecure.example/rss"), added);
  assert.deepEqual(Model.addFeedUrl(added, "file:///tmp/feed.xml"), added);
  assert.deepEqual(Model.removeFeedUrl(added, "https://a.example/rss"), ["https://b.example/feed.xml"]);
  assert.equal(Model.serializeFeedUrls(added), "https://a.example/rss\nhttps://b.example/feed.xml");
});

test("activate uses the item https link and refuses guid-only rows", () => {
  assert.equal(Model.activateUrl({ link: "https://example.com/post" }), "https://example.com/post");
  assert.equal(Model.activateUrl({ identity: "tag:x", link: "" }), "");
  assert.equal(Model.activateUrl({ link: "http://example.com/post" }), "");
  assert.equal(Model.activateUrl({ link: "file:///etc/passwd" }), "");
  assert.equal(Model.activateUrl({ link: "javascript:alert(1)" }), "");
  assert.equal(Model.activateUrl({ link: "data:text/html,hi" }), "");
});

test("max items per feed defaults to 10 and is at least 1", () => {
  assert.equal(Model.maxItemsPerFeed(undefined), 10);
  assert.equal(Model.maxItemsPerFeed(0), 1);
  assert.equal(Model.maxItemsPerFeed(4), 4);
});

test("each feed is capped before the lists are mixed", () => {
  const feedA = [
    { identity: "a1", feedName: "A", pubDateMs: 300 },
    { identity: "a2", feedName: "A", pubDateMs: 200 },
    { identity: "a3", feedName: "A", pubDateMs: 100 },
  ];
  const feedB = [
    { identity: "b1", feedName: "B", pubDateMs: 250 },
    { identity: "b2", feedName: "B", pubDateMs: 50 },
  ];
  const mixed = Model.mergeFeeds([feedA, feedB], 2);
  assert.deepEqual(
    mixed.map((item) => item.identity),
    ["a1", "b1", "a2", "b2"]
  );
});

test("unread count is the New tab size", () => {
  const items = [
    { identity: "a" },
    { identity: "b" },
    { identity: "c" },
  ];
  const readSet = Model.markRead([], items[0]);
  assert.equal(Model.unreadCount(items, readSet), 2);
});

test("compact counts display at most 99+", () => {
  assert.equal(Model.compactCount(0), "0");
  assert.equal(Model.compactCount(99), "99");
  assert.equal(Model.compactCount(100), "99+");
});

test("text filter matches title excerpt and feed name on any tab", () => {
  const items = [
    { identity: "1", title: "Ghostty Is Leaving GitHub", feedName: "Mitchell Hashimoto", excerpt: "" },
    { identity: "2", title: "Endless execution", feedName: "David Heinemeier Hansson", excerpt: "agents" },
  ];
  assert.deepEqual(
    Model.filterItems(items, "ghostty").map((item) => item.identity),
    ["1"]
  );
  assert.deepEqual(
    Model.filterItems(items, "HANSSON").map((item) => item.identity),
    ["2"]
  );
  assert.deepEqual(Model.filterItems(items, "").length, 2);
});

test("local state round-trips items and the read set", () => {
  const payload = {
    items: [{ identity: "a", title: "A", link: "https://a.example/", feedName: "F", excerpt: "", pubDateMs: 1 }],
    readIdentities: ["a"],
  };
  const parsed = Model.parseState(Model.serializeState(payload.items, payload.readIdentities));
  assert.deepEqual(parsed.readIdentities, ["a"]);
  assert.equal(parsed.items[0].title, "A");
  assert.equal(parsed.items[0].identity, "a");
});

test("activating an item moves it from New to Read", () => {
  const items = [
    { identity: "a", link: "https://a.example/" },
    { identity: "b", link: "https://b.example/" },
  ];
  const after = Model.markRead([], items[0]);
  assert.deepEqual(
    Model.tabItems(items, after, "new").map((item) => item.identity),
    ["b"]
  );
  assert.deepEqual(
    Model.tabItems(items, after, "read").map((item) => item.identity),
    ["a"]
  );
  assert.equal(Model.isRead(after, items[0]), true);
});

test("https feed URLs are required; opaque read identities are not filtered", () => {
  assert.equal(Model.isHttpsUrl("https://example.com/rss"), true);
  assert.equal(Model.isHttpsUrl("HTTPS://Example.com/rss"), true);
  assert.equal(Model.isHttpsUrl("http://example.com/rss"), false);
  assert.equal(Model.isHttpsUrl("file:///etc/passwd"), false);
  assert.equal(Model.isHttpsUrl("javascript:alert(1)"), false);
  assert.equal(Model.isHttpsUrl("example.com/rss"), false);
  assert.equal(Model.isHttpsUrl("https://"), false);
  assert.deepEqual(
    Model.httpsFeedUrls("https://a.example/rss\nhttp://b.example/rss\nfile:///tmp/x"),
    ["https://a.example/rss"]
  );
  assert.deepEqual(Model.feedUrls("tag:world.hey.com,2005:Post/1\nolder-1"), [
    "tag:world.hey.com,2005:Post/1",
    "older-1",
  ]);
  assert.deepEqual(Model.readIdentities("tag:world.hey.com,2005:Post/1\nolder-1"), [
    "tag:world.hey.com,2005:Post/1",
    "older-1",
  ]);
});

test("fetched bodies must be feed or HTML text under the size cap", () => {
  const rss = `<?xml version="1.0"?><rss version="2.0"><channel></channel></rss>`;
  const split = Model.splitFetchedBody(rss + "\n__OMARCHY_CT__:application/rss+xml");
  assert.equal(split.body, rss);
  assert.equal(split.contentType, "application/rss+xml");
  assert.equal(Model.isFeedTextResponse("application/rss+xml", rss), true);
  assert.equal(Model.isFeedTextResponse("text/html; charset=utf-8", "<!DOCTYPE html><html></html>"), true);
  assert.equal(Model.isFeedTextResponse("image/png", rss), false);
  assert.equal(Model.isFeedTextResponse("application/octet-stream", rss), false);
  assert.equal(Model.isFeedTextResponse("application/xml", "ok\0binary"), false);
  assert.equal(Model.maxFeedBytes(), 2097152);
  assert.equal(Model.isFeedTextResponse("text/xml", "x".repeat(Model.maxFeedBytes() + 1)), false);
});

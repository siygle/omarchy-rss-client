import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const Model = createRequire(import.meta.url)(join(dirname(fileURLToPath(import.meta.url)), "..", "Model.js"));

const writingPage = `<!DOCTYPE html><html><head>
<link rel="alternate" type="application/rss+xml" href="https://mitchellh.com/feed.xml"/>
<title>Writing</title>
</head><body>posts</body></html>`;

test("HTML blog page is not a feed", () => {
  assert.equal(Model.parseFeed(writingPage).ok, false);
  assert.equal(Model.looksLikeHtml(writingPage), true);
  assert.equal(Model.looksLikeHtml("<?xml version=\"1.0\"?><rss version=\"2.0\"></rss>"), false);
});

test("discovers application/rss+xml alternate link from a writing page", () => {
  assert.deepEqual(
    Model.discoverFeedUrls(writingPage, "https://mitchellh.com/writing"),
    ["https://mitchellh.com/feed.xml"]
  );
});

test("resolves relative feed hrefs against the page URL", () => {
  const html = `<link rel="alternate" type="application/atom+xml" href="/atom.xml">`;
  assert.deepEqual(
    Model.discoverFeedUrls(html, "https://example.com/writing"),
    ["https://example.com/atom.xml"]
  );
});

test("guesses common feed paths when the page has no link tag", () => {
  const guessed = Model.guessFeedUrls("https://example.com/writing");
  assert.ok(guessed.includes("https://example.com/feed.xml"));
  assert.ok(guessed.includes("https://example.com/atom.xml"));
  assert.deepEqual(Model.guessFeedUrls("http://example.com/writing"), []);
});

test("discovery ignores http, file, javascript, img, and enclosure URLs", () => {
  const html = `<!DOCTYPE html><html><head>
<link rel="alternate" type="application/rss+xml" href="http://example.com/feed.xml"/>
<link rel="alternate" type="application/rss+xml" href="file:///tmp/feed.xml"/>
<link rel="alternate" type="application/rss+xml" href="javascript:alert(1)"/>
<link rel="alternate" type="application/atom+xml" href="https://example.com/atom.xml"/>
<link rel="stylesheet" href="https://example.com/app.css"/>
<img src="https://example.com/hero.png"/>
<enclosure url="https://example.com/episode.mp3" type="audio/mpeg"/>
</head></html>`;
  assert.deepEqual(Model.discoverFeedUrls(html, "https://example.com/writing"), [
    "https://example.com/atom.xml",
  ]);
  assert.equal(Model.resolveUrl("https://example.com/writing", "http://evil.example/feed.xml"), "");
  assert.equal(Model.resolveUrl("https://example.com/writing", "file:///etc/passwd"), "");
  assert.equal(Model.resolveUrl("http://example.com/writing", "/feed.xml"), "");
});

test("discovery caps candidates per page", () => {
  let links = "";
  for (let i = 0; i < 1000; i++) {
    links += `<link rel="alternate" type="application/rss+xml" href="/feed-${i}.xml">`;
  }
  const found = Model.discoverFeedUrls(`<html><head>${links}</head></html>`, "https://evil.example/");
  assert.equal(found.length, Model.MAX_DISCOVERED_FEEDS_PER_PAGE);
});

test("only a subscription entry may discover, and only once per URL", () => {
  const visited = { "https://blog.example/writing": true };
  const sub = Model.fetchEntry("https://blog.example/writing", "https://blog.example/writing", false);
  const entries = Model.discoveryEntries(sub, Model.guessFeedUrls(sub.url), visited);
  assert.equal(entries.length, 5);
  for (const e of entries) {
    assert.equal(e.discovered, true);
    assert.equal(e.subscriptionUrl, "https://blog.example/writing");
  }
  // A discovered entry answering with HTML never hops again.
  assert.deepEqual(Model.discoveryEntries(entries[0], ["https://blog.example/other.xml"], visited), []);
  // Re-offering the same candidates yields nothing new.
  assert.deepEqual(Model.discoveryEntries(sub, Model.guessFeedUrls(sub.url), visited), []);
});

test("hostile endpoint returning fresh links on every request stays bounded", () => {
  const visited = {};
  const queue = [Model.fetchEntry("https://evil.example/", "https://evil.example/", false)];
  visited[queue[0].url] = true;
  let fetches = 0;
  let counter = 0;
  while (queue.length && fetches < 10000) {
    const entry = queue.shift();
    fetches++;
    let links = "";
    for (let i = 0; i < 50; i++) {
      links += `<link rel="alternate" type="application/atom+xml" href="/f${counter++}.xml">`;
    }
    const html = `<html><head>${links}</head></html>`;
    queue.push(...Model.discoveryEntries(entry, Model.discoverFeedUrls(html, entry.url), visited));
  }
  assert.equal(fetches, 1 + Model.MAX_DISCOVERED_FEEDS_PER_PAGE);
});

test("catch-all HTML origin does not loop through guessed paths", () => {
  const visited = {};
  const queue = [Model.fetchEntry("https://spa.example/app", "https://spa.example/app", false)];
  visited[queue[0].url] = true;
  let fetches = 0;
  while (queue.length && fetches < 1000) {
    const entry = queue.shift();
    fetches++;
    queue.push(...Model.discoveryEntries(entry, Model.guessFeedUrls(entry.url), visited));
  }
  assert.equal(fetches, 6);
});

test("discoveryEntries rejects non-https candidates", () => {
  const sub = Model.fetchEntry("https://a.example/", "https://a.example/", false);
  assert.deepEqual(
    Model.discoveryEntries(sub, ["http://a.example/feed.xml", "file:///etc/passwd", ""], {}),
    []
  );
});

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

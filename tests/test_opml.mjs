import test from "node:test";
import assert from "node:assert/strict";
import Model from "../Model.js";

test("parseOpml parses simple flat OPML with xmlUrl attributes", () => {
  const opml = `<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head>
    <title>My Feeds</title>
  </head>
  <body>
    <outline text="Mitchell Hashimoto" type="rss" xmlUrl="https://mitchellh.com/feed.xml" htmlUrl="https://mitchellh.com"/>
    <outline text="Hacker News" type="rss" xmlUrl="https://news.ycombinator.com/rss" htmlUrl="https://news.ycombinator.com"/>
  </body>
</opml>`;

  const feeds = Model.parseOpml(opml);
  assert.deepEqual(feeds, [
    "https://mitchellh.com/feed.xml",
    "https://news.ycombinator.com/rss",
  ]);
});

test("parseOpml handles nested category outlines and folders", () => {
  const opml = `<opml version="1.0">
  <head><title>Subscribed Feeds</title></head>
  <body>
    <outline text="Engineering">
      <outline text="Go Blog" type="rss" xmlUrl="https://go.dev/blog/feed.atom"/>
      <outline text="Rust Blog" type="rss" xmlUrl="https://blog.rust-lang.org/feed.xml"/>
    </outline>
    <outline text="News">
      <outline text="Arch Linux News" type="rss" xmlUrl="https://archlinux.org/feeds/news/"/>
    </outline>
  </body>
</opml>`;

  const feeds = Model.parseOpml(opml);
  assert.deepEqual(feeds, [
    "https://go.dev/blog/feed.atom",
    "https://blog.rust-lang.org/feed.xml",
    "https://archlinux.org/feeds/news/",
  ]);
});

test("parseOpml decodes XML entities in feed URLs", () => {
  const opml = `<opml version="2.0">
  <body>
    <outline text="Feed with Query" xmlUrl="https://example.com/rss?category=tech&amp;format=xml&amp;limit=10"/>
  </body>
</opml>`;

  const feeds = Model.parseOpml(opml);
  assert.deepEqual(feeds, [
    "https://example.com/rss?category=tech&format=xml&limit=10",
  ]);
});

test("parseOpml handles single quotes, whitespace, and mixed case xmlUrl", () => {
  const opml = `<opml version="1.0">
  <body>
    <outline text='Single Quote' XMLURL='https://single.example/feed.xml' />
    <outline
      text="Multiline Outline"
      type="rss"
      xmlUrl = "https://multiline.example/rss"
    />
  </body>
</opml>`;

  const feeds = Model.parseOpml(opml);
  assert.deepEqual(feeds, [
    "https://single.example/feed.xml",
    "https://multiline.example/rss",
  ]);
});

test("parseOpml filters out non-https URLs and empty strings", () => {
  const opml = `<opml version="2.0">
  <body>
    <outline text="Insecure HTTP" xmlUrl="http://insecure.example/rss"/>
    <outline text="Valid HTTPS" xmlUrl="https://secure.example/rss"/>
    <outline text="File URL" xmlUrl="file:///etc/passwd"/>
    <outline text="Invalid" xmlUrl=""/>
  </body>
</opml>`;

  const feeds = Model.parseOpml(opml);
  assert.deepEqual(feeds, ["https://secure.example/rss"]);
});

test("parseOpml returns empty array for empty or invalid input", () => {
  assert.deepEqual(Model.parseOpml(""), []);
  assert.deepEqual(Model.parseOpml(null), []);
  assert.deepEqual(Model.parseOpml("<opml><head></head><body></body></opml>"), []);
  assert.deepEqual(Model.parseOpml("Just plain text with no outlines"), []);
});

test("parseSharePayload seamlessly handles OPML as well as JSON and plain text", () => {
  const opml = `<opml version="2.0"><body><outline xmlUrl="https://opml.example/feed.xml"/></body></opml>`;
  assert.deepEqual(Model.parseSharePayload(opml), ["https://opml.example/feed.xml"]);

  const json = JSON.stringify({ feeds: ["https://json.example/rss"] });
  assert.deepEqual(Model.parseSharePayload(json), ["https://json.example/rss"]);

  const plain = "https://plain1.example/rss\nhttps://plain2.example/feed.xml";
  assert.deepEqual(Model.parseSharePayload(plain), [
    "https://plain1.example/rss",
    "https://plain2.example/feed.xml",
  ]);
});

import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const Model = createRequire(import.meta.url)(join(root, "Model.js"));

// Hostile bodies sized to the 2 MiB feed download limit. Each pattern made the
// old regex parser rescan the rest of the body from every unclosed opening:
// the unclosed <item> body took about 20 minutes in Qt 6.12's QML engine.
const LIMIT = Model.maxFeedBytes();
const BUDGET_MS = 3000;
const fill = (head, unit, tail = "") =>
  head + unit.repeat(Math.floor((LIMIT - head.length - tail.length) / unit.length)) + tail;
const RSS = '<rss version="2.0"><channel><title>t</title>';
const ATOM = '<feed xmlns="http://www.w3.org/2005/Atom">';

function fast(name, run) {
  test(`linear: ${name}`, () => {
    const started = Date.now();
    run();
    const elapsed = Date.now() - started;
    assert.ok(elapsed < BUDGET_MS, `${name} took ${elapsed} ms`);
  });
}

fast("RSS body of unclosed <item> openings (marketplace review)", () => {
  const parsed = Model.parseFeed(fill(RSS, "<item>"), 30);
  assert.equal(parsed.ok, true);
  assert.deepEqual(parsed.items, []);
});
fast("Atom body of unclosed <entry> openings", () => {
  assert.deepEqual(Model.parseFeed(fill(ATOM, "<entry>"), 30).items, []);
});
fast("unclosed <title> openings in the channel", () => {
  Model.parseFeed(fill('<rss version="2.0"><channel>', "<title>"), 30);
});
fast("unclosed <channel> openings", () => {
  Model.parseFeed(fill('<rss version="2.0">', "<channel "), 30);
});
fast("<rss openings with no '>'", () => {
  assert.equal(Model.parseFeed(fill("", "<rss ")).ok, false);
});
fast("unclosed CDATA sections inside an item", () => {
  Model.parseFeed(fill(RSS + "<item><guid>g</guid><title>", "<![CDATA[", "</title></item></channel></rss>"), 30);
});
fast("'<' without '>' inside item text", () => {
  Model.parseFeed(fill(RSS + "<item><guid>g</guid><title>", "< ", "</title></item></channel></rss>"), 30);
});
fast("discovery page of <link openings with no '>'", () => {
  assert.deepEqual(Model.discoverFeedUrls(fill("<html>", "<link "), "https://example.com/"), []);
});
fast("article page of unclosed <script> openings", () => {
  Model.extractReadableText(fill("<html>", "<script>"));
});
fast("article page of unclosed content <div> openings", () => {
  Model.extractReadableText(fill("<html>", '<div class="post">'));
});
fast("OPML file of <outline openings with no '>'", () => {
  const opml = "<opml><body>" + "<outline ".repeat(Math.floor((5 * 1024 * 1024) / 9));
  assert.deepEqual(Model.parseOpmlDetails(opml).subscriptions, []);
});

test("linear scanning keeps regex pairing for well-formed and nested markup", () => {
  assert.equal(Model.stripHtml("a<b>b</b><>c"), "a b <>c");
  assert.equal(Model.stripHtml("<![CDATA[<p>x</p>]]>"), "x");
  assert.equal(Model.stripHtml("a <![CDATA[b]]> c <![CDATA[d"), "a b c <![CDATA[d");
  const rss = `${RSS}<item><guid>1</guid><title>One</title></item><item><guid>2</guid><title >Two</title ></item></channel></rss>`;
  assert.deepEqual(Model.parseFeed(rss).items.map((i) => i.title).sort(), ["One", "Two"]);
  const text = "x".repeat(130);
  const page = `<html><body><div class="wrap"><div class="post">${text}</div></div><script>${"y".repeat(500)}</script></body></html>`;
  assert.equal(Model.extractReadableText(page), text);
  assert.deepEqual(
    Model.discoverFeedUrls('<link rel="alternate" type="application/rss+xml" href="/feed.xml">', "https://example.com/blog/"),
    ["https://example.com/feed.xml"]
  );
});

test("overlong date text is ignored", () => {
  const rss = `${RSS}<item><guid>1</guid><pubDate>${"Tue, 06 Oct 2026 ".repeat(20)}</pubDate></item></channel></rss>`;
  assert.equal(Model.parseFeed(rss).items[0].pubDateMs, null);
});

test("feed text fields are bounded before they are stored or drawn", () => {
  const big = "A".repeat(LIMIT - 400);
  const longGuid = `${RSS.replace("<title>t</title>", `<title>${big.slice(0, 5000)}</title>`)}<item><guid>${big}</guid></item>` +
    `<item><guid>ok</guid><link>https://e.com/${"x".repeat(5000)}</link><title>${"T".repeat(5000)}</title>` +
    `<description>${"D".repeat(50000)}</description></item></channel></rss>`;
  const parsed = Model.parseFeed(longGuid, 30);
  assert.deepEqual(parsed.items.map((i) => i.identity), ["ok"], "an overlong identity omits the item");
  const item = parsed.items[0];
  assert.equal(item.link, "", "an overlong link is dropped, not shortened");
  assert.equal(item.title.length, Model.MAX_ARTICLE_TITLE_LENGTH);
  assert.equal(item.excerpt.length, Model.MAX_ARTICLE_EXCERPT_LENGTH);
  assert.equal(parsed.feedName.length, Model.MAX_FEED_NAME_LENGTH);
});

test("saved state is held to the same article bounds", () => {
  const state = JSON.stringify({ items: [
    { identity: "x".repeat(Model.MAX_ARTICLE_IDENTITY_LENGTH + 1), title: "drop" },
    { identity: "keep", title: "T".repeat(5000), excerpt: "E".repeat(50000) },
  ] });
  const parsed = Model.parseState(state);
  assert.deepEqual(parsed.items.map((i) => i.identity), ["keep"]);
  assert.equal(parsed.items[0].title.length, Model.MAX_ARTICLE_TITLE_LENGTH);
  assert.equal(parsed.items[0].excerpt.length, Model.MAX_ARTICLE_EXCERPT_LENGTH);
});

fast("read state lookups stay linear as the read set grows", () => {
  const items = Array.from({ length: 3000 }, (_, i) => ({ identity: `https://e.com/${i}` }));
  let reads = Array.from({ length: 20000 }, (_, i) => `https://old.example/${i}`);
  reads = Model.markAllRead(reads, items.concat(items));
  assert.equal(reads.length, 23000, "duplicates are added once");
  assert.equal(Model.unreadCount(items, reads), 0);
  assert.equal(Model.isRead(reads.slice(0, 20000), items[0]), false, "a different read set is looked up afresh");
  const shrunk = reads.filter((id) => id !== items[0].identity);
  assert.equal(Model.isRead(shrunk, items[0]), false);
  assert.equal(Model.isRead(shrunk, items[1]), true);
});

test("full article text is bounded for the reader", () => {
  const page = `<html><body><article>${"word ".repeat(100000)}</article></body></html>`;
  const text = Model.extractReadableText(page);
  assert.ok(text.length <= Model.MAX_READABLE_TEXT_LENGTH);
  assert.ok(text.length > Model.MAX_READABLE_TEXT_LENGTH - 10);
});

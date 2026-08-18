import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);
const Model = require(join(root, "Model.js"));
const fixture = readFileSync(join(root, "tests/fixtures/sample.rss.xml"), "utf8");

test("RSS 2.0 fixture yields listable items with guid-or-link identity", () => {
  const parsed = Model.parseRss20(fixture);
  assert.equal(parsed.ok, true);
  assert.equal(parsed.feedName, "Example Blog");
  const ids = parsed.items.map((item) => item.identity);
  assert.deepEqual(ids, [
    "https://example.com/newest",
    "older-1",
    "https://example.com/html-only",
    "no-date-1",
  ]);
});

test("item with neither guid nor link is omitted", () => {
  const parsed = Model.parseRss20(fixture);
  assert.equal(parsed.items.some((item) => item.title === "Unlistable"), false);
});

test("missing pubDate sorts below dated items; newest first; N caps the list", () => {
  const parsed = Model.parseRss20(fixture);
  const list = Model.recentList(parsed.items, 3);
  assert.deepEqual(
    list.map((item) => item.identity),
    ["https://example.com/newest", "older-1", "https://example.com/html-only"]
  );
  const all = Model.recentList(parsed.items, 20);
  assert.equal(all[all.length - 1].identity, "no-date-1");
});

test("row text strips HTML and does not keep tags", () => {
  const parsed = Model.parseRss20(fixture);
  const htmlOnly = parsed.items.find((item) => item.identity === "https://example.com/html-only");
  assert.equal(htmlOnly.title, "");
  assert.equal(htmlOnly.excerpt, "Only HTML body here");
  assert.equal(Model.rowText(htmlOnly), "Only HTML body here");
  assert.equal(Model.rowText(parsed.items[0]), "Newest post");
});

test("RSS without version 2.0 is not parsed as items", () => {
  const rss091 = `<?xml version="1.0"?><rss version="0.91"><channel><title>Old</title><item><title>X</title><link>https://x.example/</link></item></channel></rss>`;
  const parsed = Model.parseRss20(rss091);
  assert.equal(parsed.ok, false);
  assert.deepEqual(parsed.items, []);
});

test("Atom is not parsed as RSS 2.0 items", () => {
  const atom = `<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><title>A</title><entry><title>E</title><id>1</id></entry></feed>`;
  const parsed = Model.parseRss20(atom);
  assert.equal(parsed.ok, false);
  assert.deepEqual(parsed.items, []);
});

test("Hey-style Atom fixture lists entries by id then alternate link", () => {
  const atom = readFileSync(join(root, "tests/fixtures/dhh.atom.xml"), "utf8");
  const parsed = Model.parseFeed(atom);
  assert.equal(parsed.ok, true);
  assert.equal(parsed.feedName, "David Heinemeier Hansson");
  assert.deepEqual(
    parsed.items.map((item) => item.identity),
    [
      "tag:world.hey.com,2005:World::Post/48740",
      "tag:world.hey.com,2005:World::Post/48635",
    ]
  );
  assert.equal(parsed.items[0].link, "https://world.hey.com/dhh/endless-execution-4157e065");
  assert.equal(parsed.items[0].excerpt, "The age of agents.");
  const list = Model.recentList(parsed.items, 20);
  assert.equal(list[0].title, "Endless execution");
});

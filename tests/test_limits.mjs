import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const Model = createRequire(import.meta.url)(join(dirname(fileURLToPath(import.meta.url)), "..", "Model.js"));
const MAX = Model.MAX_SUBSCRIPTIONS;
const urls = (n, prefix = "a") => Array.from({ length: n }, (_, i) => `https://${prefix}${i}.example/feed`);

test("articles per feed has a ceiling", () => {
  assert.equal(Model.maxItemsPerFeed(50), 50);
  assert.equal(Model.maxItemsPerFeed(Model.MAX_ITEMS_PER_FEED + 1), Model.MAX_ITEMS_PER_FEED);
  assert.equal(Model.maxItemsPerFeed(1e12), Model.MAX_ITEMS_PER_FEED);
});

test("stored subscriptions are capped when loaded", () => {
  assert.equal(Model.normalizeSubscriptions(urls(MAX + 500)).length, MAX);
  assert.equal(Model.normalizeSubscriptions("", urls(MAX + 500)).length, MAX);
  const mixed = Model.normalizeSubscriptions(urls(MAX - 10), urls(50, "b"));
  assert.equal(mixed.length, MAX);
});

test("repeated imports cannot grow past the subscription limit", () => {
  let subs = [];
  for (let round = 0; round < 3; round++) {
    const result = Model.calculateImportResult(subs, { feeds: urls(Model.MAX_OPML_FEEDS, `r${round}-`) }, "x.opml");
    subs = result.newSubscriptions;
    assert.ok(subs.length <= MAX);
    if (round > 0) {
      assert.equal(result.imported, 0);
      assert.equal(result.overLimit, Model.MAX_OPML_FEEDS);
      assert.match(result.message, /^No feeds imported from x\.opml · 1000 not added \(limit 1000 subscriptions\)$/);
    }
  }
  assert.equal(subs.length, MAX);
});

test("a partial import reports what did not fit", () => {
  const result = Model.calculateImportResult(urls(MAX - 3), { feeds: urls(10, "n") }, "");
  assert.equal(result.imported, 3);
  assert.equal(result.overLimit, 7);
  assert.equal(result.newSubscriptions.length, MAX);
  assert.match(result.message, /Imported 3 feeds · 7 not added/);
});

test("manual add stops at the subscription limit", () => {
  const full = Model.normalizeSubscriptions(urls(MAX));
  const res = Model.addSubscription(full, "https://new.example/feed", "", "");
  assert.equal(res.ok, false);
  assert.match(res.error, /limit/);
  assert.equal(Model.addSubscription(full.slice(1), "https://new.example/feed", "", "").ok, true);
});

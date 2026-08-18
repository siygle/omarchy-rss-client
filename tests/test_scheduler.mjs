import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const Model = require(join(dirname(fileURLToPath(import.meta.url)), "..", "Model.js"));

test("mergeFeedArticles incrementally updates articles for a single feed and preserves others", () => {
  const now = Date.now();
  const existing = [
    { identity: "b1", title: "Feed B Post 1", feedUrl: "https://b.com/rss", pubDateMs: now - 10000 },
    { identity: "a1-old", title: "Old Feed A Post", feedUrl: "https://a.com/rss", pubDateMs: now - 50000 },
  ];

  const incomingA = [
    { identity: "a1-new", title: "New Feed A Post 1", pubDateMs: now },
    { identity: "a2-new", title: "New Feed A Post 2", pubDateMs: now - 5000 },
  ];

  const subscriptions = [
    { url: "https://a.com/rss", title: "Feed A", category: "Tech", categoryPath: ["Tech"] },
    { url: "https://b.com/rss", title: "Feed B", category: "News", categoryPath: ["News"] },
  ];

  const merged = Model.mergeFeedArticles(existing, incomingA, "https://a.com/rss", 10, 30, subscriptions);

  assert.equal(merged.length, 3);
  // Sorted newest first: a1-new, a2-new, b1
  assert.equal(merged[0].identity, "a1-new");
  assert.equal(merged[0].category, "Tech");
  assert.equal(merged[0].feedName, "Feed A");
  assert.equal(merged[1].identity, "a2-new");
  assert.equal(merged[2].identity, "b1");
  assert.equal(merged[2].category, "News");

  // Old Feed A article was replaced
  assert.equal(merged.some(item => item.identity === "a1-old"), false);
});

test("mergeFeedArticles deduplicates articles by stable identity across incremental merges", () => {
  const now = Date.now();
  const existing = [
    { identity: "shared-guid", title: "Initial Post", feedUrl: "https://a.com/rss", pubDateMs: now - 1000 },
    { identity: "unique-b", title: "Unique B", feedUrl: "https://b.com/rss", pubDateMs: now - 2000 },
  ];

  const incoming = [
    { identity: "shared-guid", title: "Updated Post Title", pubDateMs: now },
  ];

  const merged = Model.mergeFeedArticles(existing, incoming, "https://a.com/rss", 10, 30, []);
  assert.equal(merged.length, 2);
  assert.equal(merged[0].identity, "shared-guid");
  assert.equal(merged[0].title, "Updated Post Title");
});

test("mergeFeedArticles preserves read state enrichment across incremental merges", () => {
  const now = Date.now();
  const readSet = ["art-1", "art-3"];
  const existing = [
    { identity: "art-1", title: "Article 1", feedUrl: "https://a.com/rss", pubDateMs: now - 1000 },
    { identity: "art-2", title: "Article 2", feedUrl: "https://a.com/rss", pubDateMs: now - 2000 },
  ];

  const incomingB = [
    { identity: "art-3", title: "Article 3", pubDateMs: now },
    { identity: "art-4", title: "Article 4", pubDateMs: now - 3000 },
  ];

  const merged = Model.mergeFeedArticles(existing, incomingB, "https://b.com/rss", 10, 30, []);
  assert.equal(Model.isRead(readSet, merged.find(a => a.identity === "art-1")), true);
  assert.equal(Model.isRead(readSet, merged.find(a => a.identity === "art-2")), false);
  assert.equal(Model.isRead(readSet, merged.find(a => a.identity === "art-3")), true);
  assert.equal(Model.isRead(readSet, merged.find(a => a.identity === "art-4")), false);
});

test("mergeFeedArticles respects maxItemsPerFeed and retentionDays", () => {
  const now = Date.now();
  const oldDate = now - (35 * 24 * 60 * 60 * 1000); // 35 days old
  const freshDate = now - (2 * 24 * 60 * 60 * 1000); // 2 days old

  const incoming = [
    { identity: "f1", title: "Fresh 1", pubDateMs: freshDate + 300 },
    { identity: "f2", title: "Fresh 2", pubDateMs: freshDate + 200 },
    { identity: "f3", title: "Fresh 3", pubDateMs: freshDate + 100 },
    { identity: "old-1", title: "Old 1", pubDateMs: oldDate },
  ];

  // Retention = 30 days, MaxPerFeed = 2
  const merged = Model.mergeFeedArticles([], incoming, "https://a.com/rss", 2, 30, []);
  assert.equal(merged.length, 2);
  assert.equal(merged[0].identity, "f1");
  assert.equal(merged[1].identity, "f2");
});

test("createFetchScheduler: 1 feed executes with bounded worker and publishes immediately", async () => {
  const published = [];
  let batchDone = false;
  const now = Date.now();

  const scheduler = Model.createFetchScheduler({
    maxConcurrent: 4,
    fetchFn: (url, cb) => {
      setTimeout(() => {
        cb(null, {
          ok: true,
          items: [{ identity: "post-1", title: "Post 1", pubDateMs: now }]
        });
      }, 10);
    },
    onFeedPublished: (url, articles, status) => {
      published.push({ url, count: articles.length, status });
    },
    onBatchComplete: () => {
      batchDone = true;
    }
  });

  scheduler.start(["https://single.example/rss"]);
  assert.equal(scheduler.getStatus().isFetching, true);
  assert.equal(scheduler.getStatus().totalFeeds, 1);

  await new Promise(resolve => setTimeout(resolve, 30));

  assert.equal(published.length, 1);
  assert.equal(published[0].count, 1);
  assert.equal(batchDone, true);
  assert.equal(scheduler.getStatus().isFetching, false);
  assert.equal(scheduler.getStatus().completedFeeds, 1);
});

test("createFetchScheduler: 3 feeds with fast and slow completion stream articles independently", async () => {
  const publishEvents = [];
  const now = Date.now();

  // Feed A = 50ms (slow), Feed B = 10ms (fast), Feed C = 20ms (fast)
  const delays = {
    "https://a.com/rss": 50,
    "https://b.com/rss": 10,
    "https://c.com/rss": 20
  };

  const scheduler = Model.createFetchScheduler({
    maxConcurrent: 4,
    fetchFn: (url, cb) => {
      setTimeout(() => {
        cb(null, {
          ok: true,
          items: [{ identity: "item-" + url, title: "Item from " + url, pubDateMs: now }]
        });
      }, delays[url] || 10);
    },
    onFeedPublished: (url, articles) => {
      publishEvents.push({ url, totalArticles: articles.length });
    }
  });

  scheduler.start(["https://a.com/rss", "https://b.com/rss", "https://c.com/rss"]);

  await new Promise(resolve => setTimeout(resolve, 80));

  assert.equal(publishEvents.length, 3);
  // Fast feeds B and C must publish before slow feed A!
  assert.equal(publishEvents[0].url, "https://b.com/rss");
  assert.equal(publishEvents[0].totalArticles, 1);
  assert.equal(publishEvents[1].url, "https://c.com/rss");
  assert.equal(publishEvents[1].totalArticles, 2);
  assert.equal(publishEvents[2].url, "https://a.com/rss");
  assert.equal(publishEvents[2].totalArticles, 3);
});

test("createFetchScheduler: 10 feeds strictly enforces maxConcurrent = 4", async () => {
  let currentActive = 0;
  let maxObservedActive = 0;
  const now = Date.now();

  const urls = Array.from({ length: 10 }, (_, i) => `https://feed${i}.example/rss`);

  const scheduler = Model.createFetchScheduler({
    maxConcurrent: 4,
    fetchFn: (url, cb) => {
      currentActive++;
      if (currentActive > maxObservedActive) maxObservedActive = currentActive;
      setTimeout(() => {
        currentActive--;
        cb(null, {
          ok: true,
          items: [{ identity: "post-" + url, pubDateMs: now }]
        });
      }, 15);
    }
  });

  scheduler.start(urls);

  await new Promise(resolve => setTimeout(resolve, 100));

  assert.equal(maxObservedActive, 4);
  assert.equal(scheduler.getStatus().completedFeeds, 10);
  assert.equal(scheduler.getStatus().isFetching, false);
});

test("createFetchScheduler: 100 feeds handles queue without unbounded concurrency", async () => {
  let currentActive = 0;
  let maxObservedActive = 0;
  const now = Date.now();

  const urls = Array.from({ length: 100 }, (_, i) => `https://feed${i}.example/rss`);

  const scheduler = Model.createFetchScheduler({
    maxConcurrent: 4,
    fetchFn: (url, cb) => {
      currentActive++;
      if (currentActive > maxObservedActive) maxObservedActive = currentActive;
      setTimeout(() => {
        currentActive--;
        cb(null, {
          ok: true,
          items: [{ identity: "post-" + url, pubDateMs: now }]
        });
      }, 2);
    }
  });

  scheduler.start(urls);

  await new Promise(resolve => setTimeout(resolve, 150));

  assert.ok(maxObservedActive <= 4);
  assert.equal(scheduler.getStatus().completedFeeds, 100);
  assert.equal(scheduler.getStatus().failedFeeds, 0);
  assert.equal(scheduler.getStatus().articles.length, 100);
});

test("createFetchScheduler: failure isolation ensures broken feed does not stall healthy feeds", async () => {
  const publishedUrls = [];
  const now = Date.now();

  const scheduler = Model.createFetchScheduler({
    maxConcurrent: 4,
    fetchFn: (url, cb) => {
      setTimeout(() => {
        if (url === "https://broken.example/rss") {
          cb(new Error("500 Internal Server Error"), null);
        } else {
          cb(null, {
            ok: true,
            items: [{ identity: "item-" + url, title: "Title " + url, pubDateMs: now }]
          });
        }
      }, 10);
    },
    onFeedPublished: (url) => {
      publishedUrls.push(url);
    }
  });

  scheduler.start([
    "https://healthy1.example/rss",
    "https://broken.example/rss",
    "https://healthy2.example/rss",
    "https://healthy3.example/rss"
  ]);

  await new Promise(resolve => setTimeout(resolve, 50));

  assert.equal(publishedUrls.length, 3);
  assert.ok(!publishedUrls.includes("https://broken.example/rss"));
  assert.equal(scheduler.getStatus().completedFeeds, 4);
  assert.equal(scheduler.getStatus().failedFeeds, 1);
  assert.equal(scheduler.getStatus().articles.length, 3);
});

test("createFetchScheduler: refresh coalescing avoids overlapping batches", async () => {
  let fetchCallCount = 0;
  let batchCompletions = 0;
  const now = Date.now();

  const scheduler = Model.createFetchScheduler({
    maxConcurrent: 2,
    getFeedUrls: () => ["https://a.com/rss", "https://b.com/rss"],
    fetchFn: (url, cb) => {
      fetchCallCount++;
      setTimeout(() => {
        cb(null, {
          ok: true,
          items: [{ identity: "item-" + url, pubDateMs: now }]
        });
      }, 20);
    },
    onBatchComplete: () => {
      batchCompletions++;
    }
  });

  scheduler.start(["https://a.com/rss", "https://b.com/rss"]);
  // Trigger duplicate refresh while first is running
  scheduler.start(["https://a.com/rss", "https://b.com/rss"]);
  assert.equal(scheduler.getStatus().refreshPending, true);

  await new Promise(resolve => setTimeout(resolve, 80));

  // Two sequential batches completed cleanly, no duplicate parallel spikes
  assert.equal(batchCompletions, 2);
  assert.equal(fetchCallCount, 4);
});

test("incremental article arrival immediately updates category counts and unread counts", () => {
  const subs = [
    { url: "https://arch.org/feed", title: "Arch Linux", category: "Linux", categoryPath: ["Linux"] },
    { url: "https://tech.org/feed", title: "Tech News", category: "Tech", categoryPath: ["Tech"] },
    { url: "https://reddit.com/r/news/.rss", title: "Reddit News", category: "News", categoryPath: ["News"] },
  ];

  let articles = [];
  const readSet = ["read-item-1"];
  const now = Date.now();

  // Initial state: 0 articles
  let cats = Model.extractCategories(subs, articles, readSet);
  assert.equal(cats.find(c => c.id === "all").count, 0);
  assert.equal(cats.find(c => c.id === "Linux").count, 0);

  // Feed 1 (Arch Linux) arrives
  const archItems = [
    { identity: "arch-1", title: "Arch Post 1", pubDateMs: now - 1000 },
    { identity: "read-item-1", title: "Arch Post 2", pubDateMs: now - 2000 },
  ];
  articles = Model.mergeFeedArticles(articles, archItems, "https://arch.org/feed", 10, 30, subs);
  cats = Model.extractCategories(subs, articles, readSet);

  assert.equal(cats.find(c => c.id === "all").count, 2);
  assert.equal(cats.find(c => c.id === "all").unreadCount, 1);
  assert.equal(cats.find(c => c.id === "Linux").count, 2);
  assert.equal(cats.find(c => c.id === "Linux").unreadCount, 1);
  assert.equal(cats.find(c => c.id === "Tech").count, 0);

  // Category filtering for "Linux" immediately returns the articles
  const filteredLinux = Model.filterReaderArticles(articles, {
    category: "Linux",
    subscriptions: subs,
    readSet: readSet
  });
  assert.equal(filteredLinux.length, 2);
  assert.equal(filteredLinux[0].identity, "arch-1");

  // Feed 2 (Tech News) arrives
  const techItems = [
    { identity: "tech-1", title: "Tech Post 1", pubDateMs: now - 500 },
  ];
  articles = Model.mergeFeedArticles(articles, techItems, "https://tech.org/feed", 10, 30, subs);
  cats = Model.extractCategories(subs, articles, readSet);

  assert.equal(cats.find(c => c.id === "all").count, 3);
  assert.equal(cats.find(c => c.id === "Tech").count, 1);
  assert.equal(cats.find(c => c.id === "Tech").unreadCount, 1);
  assert.equal(cats.find(c => c.id === "Linux").count, 2);
});


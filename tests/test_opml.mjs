import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import Model from "../Model.js";

test("filePathFromUrl handles file URLs with spaces, parens, unicode, # and %", () => {
  assert.equal(
    Model.filePathFromUrl("file:///home/user/Downloads/subscriptions.opml"),
    "/home/user/Downloads/subscriptions.opml"
  );
  assert.equal(
    Model.filePathFromUrl("file:///home/user/My%20Folder%20(1)/sub%231%25.opml"),
    "/home/user/My Folder (1)/sub#1%.opml"
  );
  assert.equal(
    Model.filePathFromUrl("file:///home/user/%E6%96%B0%E9%97%BB/feeds.opml"),
    "/home/user/新闻/feeds.opml"
  );
  assert.equal(
    Model.filePathFromUrl("/home/user/My Folder (1)/test#1%.opml"),
    "/home/user/My Folder (1)/test#1%.opml"
  );
  assert.equal(Model.filePathFromUrl(""), "");
  assert.equal(Model.filePathFromUrl(null), "");
});

test("filenameFromPath extracts the basename cleanly", () => {
  assert.equal(Model.filenameFromPath("/home/user/Downloads/subs.opml"), "subs.opml");
  assert.equal(Model.filenameFromPath("subs.opml"), "subs.opml");
  assert.equal(Model.filenameFromPath(""), "");
});

test("parseOpmlDetails returns structured feed counts and HTTPS feeds", () => {
  const opml = `<?xml version="1.0"?>
<opml version="2.0">
  <body>
    <outline text="Feed 1" xmlUrl="https://example.com/feed1.xml"/>
    <outline text="Feed 2" xmlUrl="https://example.com/feed2.xml?a=1&amp;b=2"/>
    <outline text="Insecure" xmlUrl="http://insecure.example.com/feed"/>
    <outline text="Invalid" xmlUrl="not-a-url"/>
  </body>
</opml>`;

  const details = Model.parseOpmlDetails(opml);
  assert.equal(details.totalFound, 4);
  assert.equal(details.invalidCount, 2);
  assert.deepEqual(details.feeds, [
    "https://example.com/feed1.xml",
    "https://example.com/feed2.xml?a=1&b=2",
  ]);
});

test("calculateImportResult generates expected report and messages", () => {
  const current = ["https://dup.example/rss"];
  const details = {
    feeds: [
      "https://dup.example/rss",
      "https://new1.example/rss",
      "https://new2.example/rss",
    ],
    invalidCount: 2,
    totalFound: 5,
  };

  const res = Model.calculateImportResult(current, details, "feeds.opml");
  assert.equal(res.status, "success");
  assert.equal(res.imported, 2);
  assert.equal(res.duplicates, 1);
  assert.equal(res.invalid, 2);
  assert.equal(res.message, "Imported 2 feeds from feeds.opml · 1 duplicate · 2 need attention");
  assert.deepEqual(res.newFeeds, [
    "https://dup.example/rss",
    "https://new1.example/rss",
    "https://new2.example/rss",
  ]);
});

test("calculateImportResult handles all duplicates", () => {
  const current = ["https://a.example/rss", "https://b.example/rss"];
  const details = {
    feeds: ["https://a.example/rss", "https://b.example/rss"],
    invalidCount: 0,
    totalFound: 2,
  };

  const res = Model.calculateImportResult(current, details, "subs.opml");
  assert.equal(res.status, "success");
  assert.equal(res.imported, 0);
  assert.equal(res.duplicates, 2);
  assert.equal(res.invalid, 0);
  assert.equal(res.message, "All 2 feeds from subs.opml already added");
});

test("calculateImportResult handles no valid feeds found", () => {
  const current = ["https://a.example/rss"];
  const details = {
    feeds: [],
    invalidCount: 2,
    totalFound: 2,
  };

  const res = Model.calculateImportResult(current, details, "bad.opml");
  assert.equal(res.status, "error");
  assert.equal(res.imported, 0);
  assert.equal(res.duplicates, 0);
  assert.equal(res.invalid, 2);
  assert.equal(res.message, "No valid feeds found from bad.opml · 2 need attention");
});

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

test("persistent import lifecycle simulation survives panel close/recreation", () => {
  // Simulate persistent widget state
  let configuredFeedUrls = ["https://initial.example/feed.xml"];
  let lastImportResult = null;
  let lastImportMessage = "";

  // 1. User opens panel & settings
  let panelShowing = true;

  // 2. User clicks import OPML -> native dialog opens, panel closes
  panelShowing = false;

  // 3. User selects file on desktop
  const selectedFilePath = "file:///home/user/My%20Folder%20(2026)/subs%231.opml";
  const resolvedPath = Model.filePathFromUrl(selectedFilePath);
  assert.equal(resolvedPath, "/home/user/My Folder (2026)/subs#1.opml");
  const filename = Model.filenameFromPath(resolvedPath);
  assert.equal(filename, "subs#1.opml");

  // 4. Persistent controller reads & parses OPML while panel is closed
  const opmlContent = `<?xml version="1.0"?>
  <opml version="2.0">
    <body>
      <outline text="Initial" xmlUrl="https://initial.example/feed.xml"/>
      <outline text="New Feed" xmlUrl="https://new.example/rss.xml"/>
      <outline text="Insecure" xmlUrl="http://insecure.example/rss"/>
    </body>
  </opml>`;

  const details = Model.parseOpmlDetails(opmlContent);
  const result = Model.calculateImportResult(configuredFeedUrls, details, filename);

  // 5. Persistent controller updates stored feeds and import result
  lastImportResult = result;
  lastImportMessage = result.message;
  if (result.status === "success" && result.imported > 0) {
    configuredFeedUrls = result.newFeeds;
  }

  assert.deepEqual(configuredFeedUrls, [
    "https://initial.example/feed.xml",
    "https://new.example/rss.xml",
  ]);
  assert.equal(lastImportResult.imported, 1);
  assert.equal(lastImportResult.duplicates, 1);
  assert.equal(lastImportResult.invalid, 1);

  // 6. User reopens RSS panel and Settings later
  panelShowing = true;
  // Panel initializes its draft feeds and status from hostWidget
  const panelFeeds = Model.httpsFeedUrls(configuredFeedUrls);
  const panelShareStatus = lastImportMessage;

  assert.deepEqual(panelFeeds, [
    "https://initial.example/feed.xml",
    "https://new.example/rss.xml",
  ]);
  assert.equal(
    panelShareStatus,
    "Imported 1 feed from subs#1.opml · 1 duplicate · 1 need attention"
  );
});

test("file reader rejects oversized files > 5 MiB, directories, and non-files", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "rss-test-"));
  try {
    const validFile = path.join(tmpDir, "valid.opml");
    fs.writeFileSync(validFile, `<opml version="2.0"><body><outline xmlUrl="https://test.example/feed.xml"/></body></opml>`);

    const specialDir = path.join(tmpDir, "folder (2026)");
    fs.mkdirSync(specialDir);
    const specialFile = path.join(specialDir, "subs#1%.opml");
    fs.writeFileSync(specialFile, `<opml version="2.0"><body><outline xmlUrl="https://special.example/feed.xml"/></body></opml>`);

    const overFile = path.join(tmpDir, "oversized.opml");
    fs.writeFileSync(overFile, Buffer.alloc(5.5 * 1024 * 1024, 65));

    const emptyFile = path.join(tmpDir, "empty.opml");
    fs.writeFileSync(emptyFile, "");

    const invalidXmlFile = path.join(tmpDir, "invalid.opml");
    fs.writeFileSync(invalidXmlFile, "Plain text not xml");

    function runReader(filePath) {
      try {
        const stdout = execFileSync("python3", [
          "-c",
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
          filePath
        ], { encoding: "utf-8" });
        return { ok: true, stdout };
      } catch (err) {
        return { ok: false, status: err.status, stderr: err.stderr ? err.stderr.toString().trim() : "" };
      }
    }

    // 1. Valid file
    const validRes = runReader(validFile);
    assert.equal(validRes.ok, true);
    const details = Model.parseOpmlDetails(validRes.stdout);
    const result = Model.calculateImportResult([], details, "valid.opml");
    assert.equal(result.status, "success");
    assert.equal(result.imported, 1);

    // 2. Spaces, parens, # and % in path
    const rawUrl = pathToFileURL(specialFile).href;
    const resolvedSpecial = Model.filePathFromUrl(rawUrl);
    assert.equal(resolvedSpecial, specialFile);
    const specialRes = runReader(resolvedSpecial);
    assert.equal(specialRes.ok, true);
    assert.equal(Model.parseOpml(specialRes.stdout).length, 1);

    // 3. Oversized file (> 5 MiB)
    const overRes = runReader(overFile);
    assert.equal(overRes.ok, false);
    assert.equal(overRes.status, 4);
    assert.match(overRes.stderr, /File exceeds 5 MiB limit/);

    // 4. Directory
    const dirRes = runReader(specialDir);
    assert.equal(dirRes.ok, false);
    assert.equal(dirRes.status, 2);
    assert.match(dirRes.stderr, /Selected path is a directory/);

    // 5. Empty file
    const emptyRes = runReader(emptyFile);
    assert.equal(emptyRes.ok, true);
    const emptyResult = Model.calculateImportResult([], Model.parseOpmlDetails(emptyRes.stdout), "empty.opml");
    assert.equal(emptyResult.status, "error");
    assert.match(emptyResult.message, /No valid feeds found/);

    // 6. Invalid XML
    const invalidRes = runReader(invalidXmlFile);
    assert.equal(invalidRes.ok, true);
    const invalidResult = Model.calculateImportResult([], Model.parseOpmlDetails(invalidRes.stdout), "invalid.opml");
    assert.equal(invalidResult.status, "error");
    assert.match(invalidResult.message, /No valid feeds found/);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("parseOpmlStructured preserves category folders, nested categoryPath, and feed titles", () => {
  const opml = `<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head><title>My Feeds</title></head>
  <body>
    <outline text="Technology" title="Technology">
      <outline text="Linux" title="Linux">
        <outline text="Arch Linux News" title="Arch Linux News" type="rss" xmlUrl="https://archlinux.org/feeds/news/"/>
        <outline text="Kernel" type="rss" xmlUrl="https://kernel.org/feed.xml"/>
      </outline>
      <outline text="Rust Blog" type="rss" xmlUrl="https://blog.rust-lang.org/feed.xml"/>
    </outline>
    <outline text="News" title="News">
      <outline text="The Hindu" type="rss" xmlUrl="https://www.thehindu.com/feeder/default.rss"/>
    </outline>
    <outline text="Top Flat Feed" type="rss" xmlUrl="https://example.com/rss"/>
  </body>
</opml>`;

  const res = Model.parseOpmlStructured(opml);
  assert.equal(res.totalFound, 5);
  assert.equal(res.subscriptions.length, 5);
  assert.deepEqual(res.categories, ["Technology", "Linux", "News"]);

  // Check nested categoryPath
  const arch = res.subscriptions.find((s) => s.url === "https://archlinux.org/feeds/news/");
  assert.ok(arch);
  assert.equal(arch.title, "Arch Linux News");
  assert.deepEqual(arch.categoryPath, ["Technology", "Linux"]);
  assert.equal(arch.category, "Linux");

  const rust = res.subscriptions.find((s) => s.url === "https://blog.rust-lang.org/feed.xml");
  assert.ok(rust);
  assert.deepEqual(rust.categoryPath, ["Technology"]);
  assert.equal(rust.category, "Technology");

  const flat = res.subscriptions.find((s) => s.url === "https://example.com/rss");
  assert.ok(flat);
  assert.deepEqual(flat.categoryPath, []);
  assert.equal(flat.category, "");
});

test("normalizeSubscriptions handles legacy flat feedUrls migration cleanly", () => {
  const legacyUrls = "https://archlinux.org/feeds/news/\nhttps://news.ycombinator.com/rss\n";
  const subs = Model.normalizeSubscriptions([], legacyUrls);
  assert.equal(subs.length, 2);
  assert.equal(subs[0].url, "https://archlinux.org/feeds/news/");
  assert.equal(subs[0].title, "archlinux.org");
  assert.equal(subs[0].enabled, true);
  assert.deepEqual(subs[0].categoryPath, []);
});

test("mergeSubscriptions preserves categories and deduplicates by URL", () => {
  const existing = [
    { url: "https://archlinux.org/feeds/news/", title: "Arch", categoryPath: [], category: "", enabled: true }
  ];
  const incoming = [
    { url: "https://archlinux.org/feeds/news/", title: "Arch Linux News", categoryPath: ["Linux"], category: "Linux", enabled: true },
    { url: "https://kernel.org/feed.xml", title: "Kernel", categoryPath: ["Linux"], category: "Linux", enabled: true }
  ];

  const merged = Model.mergeSubscriptions(existing, incoming);
  assert.equal(merged.length, 2);
  // Existing subscription's category was enriched
  assert.equal(merged[0].url, "https://archlinux.org/feeds/news/");
  assert.equal(merged[0].category, "Linux");
  assert.deepEqual(merged[0].categoryPath, ["Linux"]);
  assert.equal(merged[1].url, "https://kernel.org/feed.xml");
});

test("extractCategories calculates accurate category article and unread counts", () => {
  const subs = [
    { url: "https://archlinux.org/rss", title: "Arch", category: "Linux", categoryPath: ["Linux"], enabled: true },
    { url: "https://thehindu.com/rss", title: "The Hindu", category: "News", categoryPath: ["News"], enabled: true }
  ];
  const articles = [
    { identity: "a1", feedUrl: "https://archlinux.org/rss", title: "Arch 1" },
    { identity: "a2", feedUrl: "https://archlinux.org/rss", title: "Arch 2" },
    { identity: "n1", feedUrl: "https://thehindu.com/rss", title: "News 1" }
  ];
  const readSet = ["a1"];

  const cats = Model.extractCategories(subs, articles, readSet);
  assert.equal(cats.length, 3); // All, Linux, News

  const allCat = cats.find((c) => c.id === "all");
  assert.equal(allCat.count, 3);
  assert.equal(allCat.unreadCount, 2);

  const linuxCat = cats.find((c) => c.id === "Linux");
  assert.equal(linuxCat.count, 2);
  assert.equal(linuxCat.unreadCount, 1);

  const newsCat = cats.find((c) => c.id === "News");
  assert.equal(newsCat.count, 1);
  assert.equal(newsCat.unreadCount, 1);
});

test("filterReaderArticles filters simultaneously by category, unreadOnly, and search query", () => {
  const articles = [
    { identity: "1", title: "Linux 6.17 Released", feedUrl: "https://arch.org", feedName: "Arch Linux", category: "Linux" },
    { identity: "2", title: "Fedora 41 Details", feedUrl: "https://fedora.org", feedName: "Fedora", category: "Linux" },
    { identity: "3", title: "Markets Rally Today", feedUrl: "https://finance.org", feedName: "Finance News", category: "Finance" }
  ];
  const readSet = ["1"];

  // 1. Filter by category
  const linuxOnly = Model.filterReaderArticles(articles, { category: "Linux", readSet });
  assert.equal(linuxOnly.length, 2);

  // 2. Filter by category + unreadOnly
  const unreadLinux = Model.filterReaderArticles(articles, { category: "Linux", unreadOnly: true, readSet });
  assert.equal(unreadLinux.length, 1);
  assert.equal(unreadLinux[0].identity, "2");

  // 3. Filter by category + unreadOnly + search
  const searched = Model.filterReaderArticles(articles, { category: "Linux", unreadOnly: true, search: "Fedora", readSet });
  assert.equal(searched.length, 1);
  assert.equal(searched[0].identity, "2");

  // 4. Search with no matches
  const none = Model.filterReaderArticles(articles, { category: "Linux", search: "Markets", readSet });
  assert.equal(none.length, 0);
});

test("generateOpml exports subscriptions with categories and flat feeds", () => {
  const subs = [
    { url: "https://archlinux.org/feed", title: "Arch Linux", category: "Linux", categoryPath: ["Linux"], enabled: true },
    { url: "https://example.com/rss", title: "Example Feed", category: "", categoryPath: [], enabled: true }
  ];

  const opml = Model.generateOpml(subs);
  assert.match(opml, /<opml version="2\.0">/);
  assert.match(opml, /<outline text="Linux" title="Linux">/);
  assert.match(opml, /xmlUrl="https:\/\/archlinux\.org\/feed"/);
  assert.match(opml, /xmlUrl="https:\/\/example\.com\/rss"/);

  // Parse back to verify round-trip
  const parsed = Model.parseOpmlStructured(opml);
  assert.equal(parsed.subscriptions.length, 2);
  assert.deepEqual(parsed.categories, ["Linux"]);
});


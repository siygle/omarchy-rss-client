import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const Model = createRequire(import.meta.url)(join(root, "Model.js"));

// Marketplace review: an autodiscovered feed URL such as
// https://evil.example/[1-100000] reached curl with globbing on, so one queue
// entry expanded into thousands of transfers whose combined output the shell
// buffered. Every fetch must turn off globbing and pass exactly one URL.
const GLOB_URLS = [
  "https://evil.example/feed[1-100000].xml",
  "https://evil.example/{a,b,c,d,e,f,g,h}/{1,2,3,4,5,6,7,8}.xml",
  "https://evil.example/x?page=[0-9999]",
];

function assertSingleUnglobbedUrl(command, url) {
  assert.equal(command[0], "curl");
  assert.equal(command[1], "-q", "-q must be the first argument so ~/.curlrc is ignored");
  assert.ok(command.includes("--globoff"), "URL globbing must be off");
  assert.ok(!command.includes("-K") && !command.includes("--config"));
  assert.ok(!command.includes("--next") && !command.includes("-:"));
  const urlFlag = command.indexOf("--url");
  assert.equal(urlFlag, command.length - 2, "the URL is passed last, through --url");
  assert.equal(command[urlFlag + 1], url);
  const httpsArgs = command.filter((arg) => /^https:/i.test(arg));
  assert.deepEqual(httpsArgs, [url], "exactly one URL reaches curl");
  const maxBytes = command[command.indexOf("--max-filesize") + 1];
  assert.ok(Number(maxBytes) > 0 && Number(maxBytes) <= Model.maxFeedBytes());
}

for (const url of GLOB_URLS) {
  test(`feed fetch disables globbing for ${url}`, () => {
    assertSingleUnglobbedUrl(Model.feedFetchCommand(url), url);
  });
  test(`article fetch disables globbing for ${url}`, () => {
    assertSingleUnglobbedUrl(Model.articleFetchCommand(url), url);
  });
}

test("glob-shaped hrefs are still discovered, but fetched as one literal URL", () => {
  const html = `<link rel="alternate" type="application/rss+xml" href="/feed[1-100000].xml">`;
  const [found] = Model.discoverFeedUrls(html, "https://evil.example/blog");
  assert.equal(found, "https://evil.example/feed[1-100000].xml");
  assertSingleUnglobbedUrl(Model.feedFetchCommand(found), found);
});

test("feed fetch keeps the content-type marker and limits", () => {
  const command = Model.feedFetchCommand("https://example.com/feed.xml");
  assert.equal(command[command.indexOf("-w") + 1], "\n__OMARCHY_CT__:%{content_type}");
  assert.equal(command[command.indexOf("--max-filesize") + 1], String(Model.maxFeedBytes()));
  assert.equal(command[command.indexOf("--proto") + 1], "=https");
  assert.equal(command[command.indexOf("--proto-redir") + 1], "=https");
  assert.equal(command[command.indexOf("--max-redirs") + 1], "5");
  assert.equal(command[command.indexOf("--max-time") + 1], "20");
});

test("article fetch uses the 1 MiB limit and no write-out", () => {
  const command = Model.articleFetchCommand("https://example.com/post");
  assert.equal(command[command.indexOf("--max-filesize") + 1], String(Model.MAX_ARTICLE_BYTES));
  assert.ok(!command.includes("-w"));
});

test("non-HTTPS or option-shaped URLs produce no command", () => {
  for (const url of ["", "http://example.com/feed", "-K/etc/passwd", "--config=x", "file:///etc/passwd", "https://a b/"]) {
    assert.deepEqual(Model.feedFetchCommand(url), []);
    assert.deepEqual(Model.articleFetchCommand(url), []);
  }
});

test("every curl invocation in the QML goes through the guarded builders", () => {
  for (const file of ["BarWidget.qml", "Panel.qml", "ReaderView.qml", "SettingsView.qml", "SubscriptionsView.qml", "ArticleDetailView.qml", "SafeTextInput.qml"]) {
    const source = readFileSync(join(root, file), "utf8");
    assert.ok(!/["']curl["']/.test(source), `${file} builds a curl argv directly`);
  }
});

import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const barWidget = fs.readFileSync(path.join(root, "BarWidget.qml"), "utf8");
const subscriptionsView = fs.readFileSync(path.join(root, "SubscriptionsView.qml"), "utf8");

function consoleLogCalls(source) {
  const calls = [];
  const re = /console\.log\s*\(([\s\S]*?)\)\s*(?:\n|;)/g;
  let m;
  while ((m = re.exec(source))) {
    calls.push(m[1]);
  }
  return calls;
}

test("no D696463 debug tags remain in QML sources", () => {
  assert.equal(barWidget.includes("D696463"), false);
  assert.equal(subscriptionsView.includes("D696463"), false);
});

test("console.log arguments must not reference sensitive URL holders", () => {
  const forbidden = ["draftUrl", "editingUrl", "currentUrl", ".command", "nextUrl"];
  for (const [name, source] of [
    ["BarWidget.qml", barWidget],
    ["SubscriptionsView.qml", subscriptionsView],
  ]) {
    for (const args of consoleLogCalls(source)) {
      for (const token of forbidden) {
        assert.equal(
          args.includes(token),
          false,
          `${name} console.log must not reference ${token}: ${args.slice(0, 120)}`
        );
      }
    }
  }
});

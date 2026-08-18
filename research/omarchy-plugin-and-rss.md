# Omarchy Quattro plugins and RSS 2.0 — research notes

**Date:** 2026-08-17

This note records only what official first-party pages say about writing, validating, installing, and publishing an Omarchy Quattro third-party plugin, plus what the RSS Advisory Board’s RSS 2.0 specification actually requires for listing items. It is source-backed research for an unread-blog-list plus notification-style bar badge. It is not an implementation plan and does not invent APIs, unread semantics, or Atom rules.

---

## Omarchy plugin development contract

### Runtime warning (all plugin kinds)

[Develop a Plugin](https://omarchyplugins.com/develop.html) states: **plugins share the long-running Omarchy shell process**. They run **unsandboxed with the user’s permissions**. Authors must review every dependency and command, avoid unnecessary privileges, and **never start a second Quickshell process for a plugin**.

The same contract is restated in [Omarchy shell README](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md#omarchy-shell): `omarchy-shell` is **one** long-running [Quickshell](https://quickshell.org/) instance; bar, panels, overlays, and third-party plugins all load **inside** that process.

### Plugin kinds and entry points

Official kind table from [Define the Plugin Contract](https://omarchyplugins.com/develop.html) (develop guide) and [Plugin manifest](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md#plugin-manifest) (shell README):

| Kind | `entryPoints` key | Typical file (develop guide) | What it is (shell README) |
| --- | --- | --- | --- |
| `bar-widget` | `barWidget` | `BarWidget.qml` | Component the active bar can drop into a section |
| `panel` | `panel` | `Panel.qml` | Persistent or summoned floating window (e.g. OSD) |
| `overlay` | `overlay` | `Overlay.qml` | Fullscreen overlay |
| `menu` | `menu` | `Menu.qml` | Summoned menu surface |
| `service` | `service` | `Service.qml` | Headless singleton, no UI |
| `bar` | `bar` | `Bar.qml` | Full bar replacement for `omarchy.bar` |

The develop guide’s “file loaded” names are the tutorial convention; the shell README’s minimal example uses `entryPoints.barWidget: "Widget.qml"` — the **path is whatever the manifest names**, as long as the file exists and kinds agree ([Validate the Folder](https://omarchyplugins.com/develop.html)).

Shell README additional load rules ([Plugin manifest](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md#plugin-manifest)):

- Only **one** `bar` plugin is active; invalid/missing selection falls back to `omarchy.bar`.
- Panels, overlays, and menus load **when summoned**.
- Plugins that must outlive a summon can set `keepLoaded: true`.
- First-party **services** load at startup.
- Full schema lives in `services/PluginRegistry.qml` (not reproduced here).

### Manifest fields

**Validate** requires these present and valid JSON ([Validate the Folder](https://omarchyplugins.com/develop.html)): `schemaVersion`, `id`, `name`, `version`, `kinds`, `entryPoints`.

**Publish** field reference ([Add a manifest](https://omarchyplugins.com/publish.html)):

| Field | Purpose | Required |
| --- | --- | --- |
| `schemaVersion` | Omarchy manifest contract version | Yes |
| `id` | Unique namespaced plugin identifier | Yes |
| `name` | Human-readable name | Yes |
| `version` | Current version; marketplace display **up to 64 characters** | Yes |
| `author` | Author shown in the marketplace | Yes |
| `description` | Short marketplace summary | Yes |
| `kinds` | Capabilities exposed to Omarchy | Yes |
| `entryPoints` | QML entry file for each kind | Yes |

Tutorial development manifest also includes optional `license`, `barWidget` metadata (`displayName`, `category`, `allowMultiple`, `defaultSection`), and while cloning: `omarchy.clonedFrom` ([Define the Plugin Contract](https://omarchyplugins.com/develop.html)).

Shell README example additionally shows `barWidget.defaults` and `barWidget.schema` for inline settings ([Plugin manifest](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md#plugin-manifest)).

**Kind/entry-point agreement:** a `bar-widget` needs `entryPoints.barWidget`; a standalone `panel` kind needs `entryPoints.panel` ([Validate the Folder](https://omarchyplugins.com/develop.html)).

**ID and filesystem rules:** third-party IDs **cannot** use `omarchy.*`; plugin folders **cannot contain symlinks**; entry-point paths must be **safe relative paths** and files must exist ([Validate the Folder](https://omarchyplugins.com/develop.html)).

### Nested details panel is still one `bar-widget`

The official clock-style tutorial ([Implement the Bar and Panel](https://omarchyplugins.com/develop.html)):

- Keep `kinds: ["bar-widget"]` and `entryPoints.barWidget: "BarWidget.qml"`.
- `BarWidget.qml` `Loader`s `Panel.qml`; **do not** declare a second `panel` kind for that nested surface.
- Same `moduleName` in both files.
- `BarWidget` must forward `opened`, `popoutSwitchClosing`, `open()`, `close()`, `toggle()`, `closeForPopoutSwitch()`, and inject `bar` / `anchorItem` / `hostWidget` into the panel.
- Nested `Panel` uses `manageIpc: false` in the tutorial; Quattro `Panel` + `KeyboardPanel` + `PanelKeyCatcher` handle show/hide, Escape, and tab-to-switch-panel.

### Clone workflow

[Clone a Built-in Plugin](https://omarchyplugins.com/develop.html) and [Installing a third-party plugin](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md#installing-a-third-party-plugin):

1. Match kind and interaction pattern to a built-in (clock for bar + details panel).
2. Work only under the user config tree, not packaged Omarchy source.
3. `omarchy plugin clone omarchy.clock --edit` (develop) / `omarchy plugin clone omarchy.clock` (shell README).
4. Built-in `omarchy.clock` becomes `<username>.clock` (example `dhh.clock`); complete plugin directory is copied including every declared kind and local dependency.
5. Clone discovers, enables, and **replaces the built-in** in the active bar; position/settings are preserved.
6. Keep the printed clone ID while developing; keep `omarchy.clonedFrom` so disable/remove restores the built-in.
7. IPC/shortcuts aimed at the built-in id are **routed to the enabled clone**.
8. Removing an active clone switches back to the built-in.
9. Before publishing, replace the temporary clone ID with a **permanent namespaced ID** and **remove** `omarchy.clonedFrom` ([Finished Example](https://omarchyplugins.com/develop.html)).

Develop clone tree example:

```
~/.config/omarchy/plugins/yourname.clock/
├── manifest.json
├── BarWidget.qml
├── Panel.qml
└── Model.js
```

### Validation

From [Validate the Folder](https://omarchyplugins.com/develop.html):

```sh
PLUGIN_ID="yourname.clock"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" \
  "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
```

Checks: JSON parse + required fields; kind/entry-point agreement; referenced files exist; no `omarchy.*` third-party ID; no symlinks. Example failure: `entry point file not found: 'BarWidget.qml'`.

Publish guide also says: run `omarchy plugin clone`, then `omarchy plugin validate`, and points to [official Omarchy Quattro plugin reference](https://github.com/basecamp/omarchy/blob/quattro/shell/plugins/README.md) ([Add a manifest](https://omarchyplugins.com/publish.html)).

### Run / inspect / summon

Clone already discovers and enables the widget. Confirm ([Run & Inspect the Plugin](https://omarchyplugins.com/develop.html)):

```sh
omarchy plugin list --json | jq --arg id "$PLUGIN_ID" '.[] | select(.id == $id)'
# expected: id, kinds: ["bar-widget"], enabled: true
```

Panel lifecycle is routed through `BarWidget` `open()` / `close()`:

```sh
omarchy-shell shell summon "$PLUGIN_ID" '{}'
omarchy-shell shell hide "$PLUGIN_ID"
```

Force discovery: `omarchy-shell shell rescanPlugins`.

Test matrix from the develop guide: click, Escape, shell open/close, disable, re-enable, shell restart, removal.

Troubleshooting (same page): wrong clone ID; entry-point filename/case mismatch; validate-but-not-listed → rescan; listed-but-invisible → enable + `qs log -p "$OMARCHY_PATH/shell" --tail 100`; panel opens once only → forward `opened`/`open()`/`close()`.

### Install commands (end-user)

Finished-example README ([Finished Example](https://omarchyplugins.com/develop.html)):

```sh
omarchy plugin add https://github.com/yourname/custom-clock.git --enable
omarchy bar move io.github.yourname.custom-clock --section center
omarchy plugin remove io.github.yourname.custom-clock
```

Shell README installer ([Installing a third-party plugin](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md#installing-a-third-party-plugin)):

- Plugin = **git repo** with `manifest.json` at **root**.
- Add clones into `~/.config/omarchy/plugins/<id>/` named by **manifest id**.
- Update is a **fast-forward pull**; `omarchy plugin update <id>` or update all.
- Plugins land **disabled** so the user can review code (unless `--enable`).
- Adding **warns** before clone; updates **show a diff**.
- `--yes` skips prompts (scripts/agents).
- Installer **never** runs plugin code, install hooks, or sudo — only clone, validate manifest, toggle enabled via IPC.
- Hand install: drop files, `rescanPlugins`, `omarchy plugin enable <id>`.
- Bar widgets start in `barWidget.defaultSection`, or **center** if omitted.

---

## Publishing / marketplace / ID / repo layout

### Marketplace posture

[Publish a Plugin](https://omarchyplugins.com/publish.html): **the marketplace validates listings, not plugin security.** Plugins run unsandboxed. Author remains responsible for code, assets, documentation, and license.

[Browse Plugins](https://omarchyplugins.com/) describes itself as a community registry for [Omarchy Quattro](https://github.com/basecamp/omarchy/tree/quattro), with Develop and Publish links. Catalog fetch on 2026-08-17 returned **0 community plugins** (“No plugins found”).

### Repo layout to submit

[Prepare the repository](https://omarchyplugins.com/publish.html):

- Public GitHub repository
- Valid `manifest.json` **in the repository root**
- README and license
- Safe install and removal
- Optional `preview.png` (marketplace says optimized automatically; develop finished example says optional `preview.png` beside files)

Develop finished example also: document every external dependency, setup step, privilege boundary, service, installer, or remote build ([Finished Example](https://omarchyplugins.com/develop.html)). Do not copy tutorial ID/URL/author/description unchanged.

Permanent ID style in the finished example: `io.github.yourname.custom-clock`. Shell README example: `my.org.cool-clock`.

### Submit path

[Submit your plugin](https://omarchyplugins.com/publish.html) opens a GitHub issue form: [HANCORE-linux/omarchy-plugin-marketplace `submit-plugin.yml`](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml). Automated validation checks the **current commit** before a maintainer approves the listing.

Issue template ([raw `submit-plugin.yml`](https://raw.githubusercontent.com/HANCORE-linux/omarchy-plugin-marketplace/main/.github/ISSUE_TEMPLATE/submit-plugin.yml)):

- Repository URL (public GitHub containing the plugin manifest)
- Category: Appearance, Desktop, Developer Tools, Hardware, Productivity, System, Widgets, Other
- Tags (one to three; more than three rejected): AI, Bar, Hyprland, Launcher, Media, Power management, Quickshell, Security, System, Workspaces
- Optional suggested tag; maintainer notes
- Required checkboxes: install/remove instructions; license + external deps; ownership of plugin and preview assets; **does not overwrite user configuration without explicit consent**; **approval is listing, not a security review**

### Plugin detail page / install contract

[`plugin.html?id=robzolkos.agent-usage`](https://omarchyplugins.com/plugin.html?id=robzolkos.agent-usage) **does not load** as of 2026-08-17: “Plugin not found / This plugin does not exist in the current catalog.” The develop guide still cites it as a marketplace example of the same bar-widget + nested panel structure ([Implement the Bar and Panel](https://omarchyplugins.com/develop.html)).

The same `plugin.html` shell (no id or unknown id) exposes sections **Overview**, **Install**, **Terms of Use**, but with empty metadata when the plugin is missing. Search snippets of live listing pages (e.g. other catalog items when they existed) state: *“Public plugin source. Plugins run as unsandboxed code. The marketplace lists repositories but does not perform a security review.”* That wording matches publish.html and the submit checklist; it could not be re-fetched from a live listing in this session because the catalog was empty.

### First-party vs third-party discovery

[First-party plugins README](https://github.com/basecamp/omarchy/blob/quattro/shell/plugins/README.md): first-party plugins use the **same `manifest.json` contract**; the shell flags them `__isFirstParty: true`. User-installed plugins live under `~/.config/omarchy/plugins/<plugin-id>/`. First-party non-bar plugins are enabled unless in `disabledPlugins[]`; `omarchy.bar` stays default until another `kind: "bar"` is selected.

---

## Shell / runtime constraints

Source: [Omarchy shell README](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md) unless noted.

### Unsandboxed, single Quickshell

- One shell per graphical session (Hyprland autostart: `quickshell -p $OMARCHY_PATH/shell`).
- Shared services/singletons live **once**.
- Summoning a panel is **IPC into the already-running process**, not `quickshell -p ...` cold start.
- Third-party plugins load from disk **without changing Omarchy source**.
- **Never** start a second Quickshell for a plugin ([develop.html](https://omarchyplugins.com/develop.html)).
- `omarchy-menu` summons `omarchy.menu` via the shell target for the same reason ([IPC contract](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md#ipc-contract); [Omarchy menu](https://github.com/basecamp/omarchy/blob/quattro/shell/plugins/README.md#omarchy-menu)).
- `omarchy-restart-shell` stops every instance of that config and launches **one** fresh process.
- `omarchy-shell` **forwards IPC only**; it does not start the shell.

### Hot reload

Saving a file anywhere under `~/.config/omarchy/plugins/` **reloads plugin code automatically**; `omarchy-shell shell rescanPlugins` forces a re-walk ([Installing a third-party plugin](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md#installing-a-third-party-plugin)).

### IPC / summon

Single `shell` IPC target plus extra targets plugins register.

| Method | Effect |
| --- | --- |
| `ping` | health check (`ok`) |
| `summon <id> <payloadJson>` | load + open a panel/overlay (`ok` / `unknown`) |
| `hide <id>` | close a previously summoned plugin |
| `toggle <id> <payloadJson>` | summon if closed, hide if open |
| `call <id> <method> <arg>` | call a method on an already-loaded plugin |
| `rescanPlugins` | re-walk dirs and hot-reload plugin code |
| `reloadConfig` | reload `~/.config/omarchy/shell.json` |
| `setPluginEnabled <id> <enabled>` | persist enable bit; **only literal `"true"` enables** |
| `listPlugins` | JSON of every discovered plugin |

Develop tutorial uses `summon`/`hide` on a **bar-widget** id to drive the nested panel.

### Persisted state (`shell.json`)

One user config: `~/.config/omarchy/shell.json`. No deep-merge of defaults once the user has a file ([Persisted state](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md#persisted-state)).

Storage rules relevant to a widget plugin:

1. Active bar is `bar.id` (`omarchy.bar` or another `kind: "bar"`).
2. Each instance is one entry: `bar.layout.<section>` for widgets, `plugins[]` for non-bar kinds.
3. **Settings are inline on the entry** — no separate per-plugin settings file, no `config:` sub-object.
4. Built-in ids are namespaced (`omarchy.clock`, etc.).
5. **Third-party enabled ⇔ id present** somewhere in `shell.json` (layout, `bar.id`, or `plugins[]`). First-party non-bar: enabled unless `disabledPlugins[]`.
6. Multiple instances only if `allowMultiple: true`.
7. `version: 1` required at top level.

`omarchy bar move` / `omarchy bar set` edit the persisted widget layout.

---

## Built-in examples worth cloning

Directory listing: [github.com/basecamp/omarchy/tree/quattro/shell/plugins](https://github.com/basecamp/omarchy/tree/quattro/shell/plugins). Contract table: [plugins/README.md](https://github.com/basecamp/omarchy/blob/quattro/shell/plugins/README.md).

### Closest to unread list + badge: clock (`omarchy.clock`)

- **Kinds:** `bar-widget` only.
- **Entry:** `panels/clock/BarWidget.qml` ([README table](https://github.com/basecamp/omarchy/blob/quattro/shell/plugins/README.md)).
- **Files:** `manifest.json`, `BarWidget.qml`, `Panel.qml`, `Model.js` ([clock tree](https://github.com/basecamp/omarchy/tree/quattro/shell/plugins/panels/clock)).
- Develop guide explicitly names this as the closest starting point for a bar-widget with a details panel.
- Manifest: no `defaultSection` in first-party JSON (center fallback applies if omitted) — [clock `manifest.json`](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/panels/clock/manifest.json).

### Weather (`omarchy.weather`)

Same pattern: `bar-widget` + `BarWidget.qml` + `settingsForm: "weatherSettings"` ([weather `manifest.json`](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/panels/weather/manifest.json)). Useful if the RSS plugin needs a settings form for feed URLs.

### Agents (`omarchy.agents`) — bar icon + panel, refresh interval

- **Kinds:** `bar-widget`; `activation: "on-demand"`.
- **Entry:** `barWidget: "Panel.qml"` (single file named Panel, not BarWidget).
- **Schema:** `refreshIntervalSec` (30–3600, default 900), optional file-sync fields.
- Description: “One bar icon and one panel” — [agents `manifest.json`](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/agents/manifest.json).

This is the first-party analogue the develop guide associates with marketplace “Agent Usage” (`robzolkos.agent-usage`), which is **not** in the current catalog.

### Notifications (`omarchy.notifications`) — not a bar badge of unread posts

- **Kinds:** `service` only; `keepLoaded: true`; entry `Service.qml`.
- Description: “Notification daemon, popups, DND, and history” ([notifications `manifest.json`](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/notifications/manifest.json)).
- This is a **desktop notification daemon**, not an unread-count bar widget. An RSS plugin that wants OS-style toasts would be composing *with* this service (if the shell exposes a public API — **not documented** in the READMEs reviewed). A count badge on the bar is a **bar-widget** concern, like clock/agents.

### Media (`omarchy.media`) — service + bar-widget

`kinds: ["service", "bar-widget"]`, `keepLoaded: true`, both entry points ([media `manifest.json`](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/services/media/manifest.json)). Pattern if feed polling should outlive the widget instance.

### Other bar-widgets with popouts

README lists audio, bluetooth, monitor, network, power, tailscale as `bar-widget` with `panels/*/Panel.qml` as the **declared** entry (unlike clock’s `BarWidget.qml`). Menu is dual-kind `menu` + `bar-widget`. OSD is standalone `panel`. Overlays: image-picker, emojis, clipboard, reminders.

### Other plugin directories on disk (not all in the README table)

[Tree](https://github.com/basecamp/omarchy/tree/quattro/shell/plugins): `agents`, `background`, `bar`, `clipboard`, `dev-gallery`, `emojis`, `image-picker`, `lock`, `menu`, `notifications`, `osd`, `panels` (audio, bluetooth, clock, disk-speedtest, dropbox, monitor, network, power, speedtest, tailscale, weather, wifiqr), `polkit`, `reminders`, `services`. README “Coming soon”: `omarchy.theme-switcher`.

---

## RSS 2.0 (what the spec actually specifies)

Source: [RSS 2.0 Specification](https://www.rssboard.org/rss-specification) (RSS Advisory Board, version 2.0.11, 30 March 2009). RSS is XML 1.0; root is `<rss version="2.0">` with a single `<channel>`.

### Required channel elements

[Required channel elements](https://www.rssboard.org/rss-specification#requiredChannelElements): **`title`**, **`link`**, **`description`**.

### Optional channel elements (relevant to listing / refresh)

[Optional channel elements](https://www.rssboard.org/rss-specification#optionalChannelElements):

- `pubDate` — publication date of **channel** content; all date-times in RSS conform to **RFC 822**, year 2 or 4 digits (4 preferred).
- `lastBuildDate` — last time channel **content** changed.
- `ttl` — minutes the channel can be cached before refreshing ([ttl](https://www.rssboard.org/rss-specification#ltttlgtSubelementOfLtchannelgt)).
- `skipHours` / `skipDays` — **hints** that aggregators *may* skip those GMT hours / named days.
- `cloud` — optional rssCloud pub-sub registration (not required for listing).
- `image` — optional GIF/JPEG/PNG for the **channel** (not per-item).
- `language`, `copyright`, `category`, etc. — metadata, not item identity.

### Item elements

[Elements of `<item>`](https://www.rssboard.org/rss-specification#hrelementsOfLtitemgt):

- A channel may contain **any number** of `<item>`s.
- **All item elements are optional**, but **at least one of `title` or `description` must be present**.
- `link` and `title` **may be omitted** if the item is complete in `description` (entity-encoded HTML allowed).
- Optional: `author` (email), `category`, `comments` (URL), `enclosure`, `guid`, `pubDate`, `source`.

**`guid`** ([guid](https://www.rssboard.org/rss-specification#ltguidgtSubelementOfLtitemgt)):

- Optional string that uniquely identifies the item.
- When present, an aggregator **may** use it to decide if an item is new.
- **No syntax rules**; aggregators **must** treat it as a string; uniqueness is the **feed author’s** job.
- `isPermaLink` default **true** — then it may be treated as a permalink URL; if `false`, do **not** assume it is a URL.

**`pubDate` (item)** ([pubDate](https://www.rssboard.org/rss-specification#ltpubdategtSubelementOfLtitemgt)):

- Optional RFC 822 date when the item was published.
- If in the **future**, aggregators **may** choose not to display it yet.

**`enclosure`** ([enclosure](https://www.rssboard.org/rss-specification#ltenclosuregtSubelementOfLtitemgt)):

- Optional; **three required attributes** if present: `url` (must be **http** URL), `length` (bytes), `type` (MIME).
- Attached media — not required to list posts.

**`guid` vs `link`** ([Comments](https://www.rssboard.org/rss-specification#comments)): they are **not always the same**. Recommendation: provide `guid`, preferably as permalink, so aggregators do not repeat items after edits.

### Uniqueness, limits, links

- RSS 2.0 has **no** string-length or item-count limits (those were 0.91); processors **may** impose their own ([Comments](https://www.rssboard.org/rss-specification#comments)).
- `<link>` and `<url>` data must begin with an IANA URI scheme (`http://`, `https://`, `news://`, `mailto:`, `ftp://`, …). Aggregators may support a subset.
- Extensions only via **XML namespaces**; core RSS 2.0 elements are **not** in a namespace ([Extending RSS](https://www.rssboard.org/rss-specification#extendingRss)).
- Spec is frozen at 2.0.1-family; new features belong in namespaced modules or **new formats** ([Roadmap](https://www.rssboard.org/rss-specification#roadmap)).
- **Atom is not defined** in this document.

---

## Implications for an RSS unread-list + badge plugin

What the **Omarchy** sources *do* settle:

- Ship as a **git repo**, root `manifest.json`, namespaced **non-`omarchy.*`** id, no symlinks.
- Closest kind: **`bar-widget`** with a nested details panel (clone `omarchy.clock`); optional `service` + `keepLoaded` if polling must outlive the widget (`omarchy.media` / `omarchy.notifications` patterns).
- Do **not** add a second `panel` kind just for the list popout.
- Forward `open`/`close`/`opened` so `omarchy-shell shell summon` / `hide` work.
- Persist user settings **inline** on the `shell.json` layout entry (`schema` / `defaults` on `barWidget`) — there is no official separate plugin settings file.
- Never spawn a second Quickshell; network fetch and XML parse run **unsandboxed as the user**.
- Marketplace listing is optional, GitHub-issue based, **not** a security review.

What **RSS 2.0** *does* settle for parsing:

- Parse XML RSS 2.0: `rss` + `channel` + `item`s.
- Require channel `title`/`link`/`description` for a valid feed; items need `title` **or** `description`.
- Prefer `guid` (as opaque string) for “have I seen this item?”; do not assume `guid === link`.
- Treat `pubDate` as optional RFC 822; future dates may be hidden.
- `ttl` / `skipHours` / `skipDays` are **cache/skip hints**, not unread semantics.
- Enclosures are optional media attachments, not the post identity.

What **neither spec settles** (plugin author decisions):

- **Unread** is not an RSS element. Persist read/unread locally (file, SQLite, etc. — Omarchy only documents `shell.json` for **plugin settings**, not item state).
- What to do when `guid` is missing: fallbacks (`link`, hash of title+pubDate, etc.) are aggregator policy, not spec.
- Poll interval if `ttl` is absent; whether to honor `skipHours`/`skipDays`.
- Whether a badge is a count, a dot, or last-title text (`WidgetButton` in the clock tutorial is text, not a prescribed badge API).
- Whether to fire desktop notifications via `omarchy.notifications` (no public plugin API documented in these pages).
- Multiple feeds, OPML, HTTP caching (`ETag`/`Last-Modified`), HTTPS-only, auth, HTML sanitization of `description`.
- **Atom**, JSON Feed, or namespaced modules (`content:encoded`, Media RSS) — outside RSS 2.0 core.
- How to open `link` in a browser from QML (not specified in the plugin guides).

---

## Open questions / gaps

1. **`plugin.html?id=robzolkos.agent-usage` is missing** from the catalog; marketplace homepage listed 0 plugins on 2026-08-17. Install-page wording for live listings could not be re-verified beyond the empty template + publish/submit texts.
2. **Full manifest schema** is said to live in `services/PluginRegistry.qml`; this note did not dump that QML. Fields seen in first-party manifests but not fully specified on the HTML guides include `keepLoaded`, `activation`, `license`, `barWidget.settingsForm`, `barWidget.aliases`, `barWidget.schema` types (`integer`, `enum`, `path`, `string`).
3. **`omarchy plugin` vs `omarchy-shell shell enablePlugin`**: both appear; exact CLI surface beyond documented examples is not fully listed on these pages.
4. **Atom vs RSS:** RSS 2.0 explicitly points future work to new formats; Atom is a different spec. A “blog unread” plugin that only implements RSS 2.0 will miss common Atom feeds.
5. **No official RSS/feed plugin** in first-party `shell/plugins`.
6. **Notification icon:** first-party “notifications” is a daemon service, not a template for an unread badge. No documented badge component in the develop guide (clock uses `WidgetButton` text).
7. **Read-state storage location** is unspecified; writing large item stores into `shell.json` entries is not described and may be a poor fit given “settings are inline on the entry.”
8. **Security of fetching arbitrary feed URLs** is entirely the plugin author’s problem (unsandboxed). Marketplace will not review it.
9. Catalog/search pages on omarchyplugins.com that appeared in web search (other plugin IDs) were not loadable as first-party docs for contract details.

---

## Sources

- [Develop a Plugin — omarchyplugins.com/develop.html](https://omarchyplugins.com/develop.html) (clone, kinds, bar+panel tutorial, validate, run/inspect, finished example, troubleshooting). Updated 13 Aug 2026; runtime Quattro; site owner HANCORE.
- [Publish a Plugin — omarchyplugins.com/publish.html](https://omarchyplugins.com/publish.html) (repo layout, manifest field table, submit issue). Updated 28 Jul 2026.
- [Browse Plugins — omarchyplugins.com](https://omarchyplugins.com/) (marketplace home; catalog empty on fetch).
- [Plugin detail template — omarchyplugins.com/plugin.html](https://omarchyplugins.com/plugin.html) and [plugin.html?id=robzolkos.agent-usage](https://omarchyplugins.com/plugin.html?id=robzolkos.agent-usage) (not found).
- [Submit plugin issue template (raw)](https://raw.githubusercontent.com/HANCORE-linux/omarchy-plugin-marketplace/main/.github/ISSUE_TEMPLATE/submit-plugin.yml) / [form](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).
- [Omarchy shell README (quattro)](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md) / [raw](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/README.md) — runtime, manifest, install, IPC, `shell.json`.
- [First-party plugins README](https://github.com/basecamp/omarchy/blob/quattro/shell/plugins/README.md) / [raw](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/README.md).
- [shell/plugins tree (quattro)](https://github.com/basecamp/omarchy/tree/quattro/shell/plugins).
- [clock/](https://github.com/basecamp/omarchy/tree/quattro/shell/plugins/panels/clock), [clock manifest](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/panels/clock/manifest.json), [weather manifest](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/panels/weather/manifest.json), [agents manifest](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/agents/manifest.json), [notifications manifest](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/notifications/manifest.json), [media manifest](https://raw.githubusercontent.com/basecamp/omarchy/quattro/shell/plugins/services/media/manifest.json).
- [RSS 2.0 Specification](https://www.rssboard.org/rss-specification) (RSS Advisory Board, 2.0.11).

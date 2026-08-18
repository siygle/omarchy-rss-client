# RSS-Reeder

RSS-Reeder is a compact, fast, native desktop RSS and Atom feed reader plugin for Omarchy. It aggregates your subscriptions with category folders, unread tracking, configurable retention, and full OPML import/export.

## Install

Add the plugin from GitHub and enable it:

```bash
omarchy plugin add https://github.com/sanjyay/rss-reeder.git --enable
```

The widget starts in the right section of the bar. You can move it later from the plugin settings.

## Using the reader

Click the RSS-Reeder bar icon to open the reader panel.

Features:
- **Category Drawer**: Toggle the category drawer (`󰄲`) to browse articles organized by OPML folder hierarchy.
- **Search & Filter**: Fast live search across titles, summaries, and feed sources.
- **Unread Filtering**: Switch between all articles and unread-only articles.
- **Article Retention**: Automatically prunes stale articles past your custom configured retention window (default: 30 days).
- **OPML Import / Export**: Full OPML 2.0 import with category preserving and native desktop file picker.

## Feeds

The plugin reads RSS 2.0 and Atom 1.0. You can add a direct feed URL or paste a blog page. For an HTML page, the plugin looks for an RSS or Atom discovery link and then tries common feed paths on the same site. Only `https://` feed and article URLs are used.

## Settings

Open Settings (`󰒓`) to configure:
- **Subscriptions**: Manage feeds, rename titles, enable/disable feeds, and assign categories.
- **Reading Options**:
  - Refresh interval: 5m, 15m, 30m, 60m
  - Articles per feed: 10, 20, 30, 50
  - Items per page: 10, 20, 50
  - Feed retention time: Custom days (1 - 3650 days, default: 30)
  - Unread-only default toggle
- **Share & Import**: Import OPML files, export subscriptions to clipboard.

## Read state & Cache

State and cached articles are persisted in:

```text
~/.local/share/omarchy-rss-reeder/state.json
```

Existing state from legacy installations (`omarchy-rss-plugin`) is automatically migrated on startup.

## Update and reload

Update a Git-installed copy with:

```bash
omarchy plugin update io.github.sanjyay.rss-reeder
```

Restart the shell after updating:

```bash
omarchy-restart-shell
```

## Development

Run the test suite:

```bash
node --test tests/*.mjs
```

Lint QML files:

```bash
qmllint -I /usr/share/omarchy/shell/ *.qml
```

Validate the plugin manifest:

```bash
omarchy plugin validate .
```

## Attribution & License

[MIT](LICENSE)

Originally derived from the MIT-licensed Omarchy RSS plugin by Rafael Vzago.

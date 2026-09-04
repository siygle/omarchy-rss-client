# Omarchy RSS Client

A fork of [`sanjyay/rss-reeder`](https://github.com/sanjyay/rss-reeder) for Omarchy.

All original RSS reader implementation credit goes to the upstream project and its author. This fork keeps the MIT license and preserves upstream attribution.

## Features added in this fork

- **Mark all read action**: quickly mark the current unread articles as read from the reader UI.
- **Category dropdown hit-testing fix**: improves category selection behavior so the dropdown/overlay handles pointer interaction correctly.

## Install

```bash
omarchy plugin add https://github.com/siygle/omarchy-rss-client.git --enable
omarchy-restart-shell
```

## Update

```bash
omarchy plugin update io.github.siygle.omarchy-rss-client
omarchy-restart-shell
```

## Remove

```bash
omarchy plugin remove io.github.siygle.omarchy-rss-client
omarchy-restart-shell
```

Optional local data cleanup:

```bash
rm -rf ~/.local/share/omarchy-rss-client
```

## License

MIT. See [LICENSE](LICENSE).

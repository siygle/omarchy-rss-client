# Troubleshooting Omarchy RSS Client

This guide covers common issues and solutions when installing or using Omarchy RSS Client.

---

## 1. Plugin does not appear on the bar after installation

If you just installed Omarchy RSS Client and the bar icon is not visible:

1. **Restart the shell**:
   ```bash
   omarchy-restart-shell
   ```
2. **Verify the plugin is enabled**:
   ```bash
   omarchy plugin list
   ```
   Ensure `io.github.siygle.omarchy-rss-client` is listed as enabled.
3. **Check Bar layout**:
   By default, Omarchy RSS Client is added to the `right` section of the bar. If you have custom bar configurations in `~/.config/omarchy/shell.json`, verify the module is enabled.

---

## 2. A feed fails to fetch or shows no articles

- **HTTPS Requirement**: Omarchy RSS Client only loads feeds over secure `https://` connections. Plain `http://` URLs are rejected for security.
- **Feed Format**: Omarchy RSS Client supports RSS 2.0 and Atom 1.0 specifications.
- **HTML Autodiscovery**: If you entered a standard website or blog URL (e.g. `https://example.com/blog`), Omarchy RSS Client attempts to find linked RSS/Atom feeds automatically. If autodiscovery fails, find and enter the direct RSS feed URL.
- **Feed Size Limits**: Feeds larger than 2 MiB are skipped to keep memory usage low.

---

## 3. OPML File Chooser Does Not Open

Omarchy RSS Client uses the standard Freedesktop desktop portal (`org.freedesktop.portal.FileChooser`) for native file selection.

- Ensure `xdg-desktop-portal` and your desktop portal backend (such as `xdg-desktop-portal-gtk` or `xdg-desktop-portal-hyprland`) are active.
- You can test portal file selection in a terminal with:
  ```bash
  omarchy-file-select --title "Test"
  ```

---

## 4. Resetting Reader Cache and State

If you want to clear the locally cached article history and read tracking state:

1. Close the reader popup.
2. Remove the local state file:
   ```bash
   rm -f ~/.local/share/omarchy-rss-client/state.json
   ```
3. Re-open the reader or refresh feeds (`r`). Your subscriptions and settings will be preserved from your Omarchy configuration.

# HTML blog URLs resolve to a feed, they are not scraped

People paste writing indexes such as `https://mitchellh.com/writing`. We do not parse the page as posts. If the body is HTML, we follow `<link rel="alternate" type="application/rss+xml|atom+xml">`, then try origin `/feed.xml` and similar paths. Item identity still comes only from the discovered RSS 2.0 or Atom document.

Discovery is bounded so a hostile or catch-all HTML endpoint cannot grow the fetch queue:

- Only a configured subscription URL may run discovery. A discovered candidate that answers with HTML counts as a failed fetch; it never discovers again (one hop).
- Each page yields at most `MAX_DISCOVERED_FEEDS_PER_PAGE` (5) candidates.
- A per-refresh visited set skips any URL already queued or fetched in that refresh.
- Once one candidate parses as a feed, the subscription's remaining candidates are skipped.

A refresh therefore makes at most 6 requests per subscription, and at most `MAX_SUBSCRIPTIONS` (1,000) subscriptions are kept across all imports and manual adds. Articles from a discovered feed are stored under the subscription URL, so they keep the subscription's title and category.

Each request is exactly one transfer. A discovered href is remote input, so curl runs with `-q --globoff` and the URL is passed once through `--url` (see `curlFetchCommand` in `Model.js`). Otherwise curl's URL globbing would expand `[1-100000]` or `{a,b,…}` into thousands of transfers. `--max-filesize` bounds each transfer, not their sum, so the output the shell collects would have no limit. `-q` also keeps `~/.curlrc` from turning globbing back on.

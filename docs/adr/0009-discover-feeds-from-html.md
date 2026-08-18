# HTML blog URLs resolve to a feed, they are not scraped

People paste writing indexes such as `https://mitchellh.com/writing`. We do not parse the page as posts. If the body is HTML, we follow `<link rel="alternate" type="application/rss+xml|atom+xml">`, then try origin `/feed.xml` and similar paths. Item identity still comes only from the discovered RSS 2.0 or Atom document.

# Item identity is guid, then link

Read state has to survive retitling and re-fetching. RSS 2.0 `guid` is the publisher’s identifier when present; `link` is the usual fallback. We do not treat title+`pubDate` as identity (collides and drifts) and we do not hash the raw item (every typo fix would look new). An item with neither `guid` nor `link` is unlistable so the read-set never has an anonymous key.

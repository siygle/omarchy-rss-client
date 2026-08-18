---
status: superseded by ADR-0008
---

# RSS 2.0 only in v1

Blog hosts emit RSS 2.0, Atom, RSS 1.0, and JSON Feed. We parse **RSS 2.0 only**. A document that is not RSS 2.0 is a failed feed, not a second parser. Atom is a different spec; treating it as “also RSS” would lie about identity (`guid` vs `id`), dates, and required elements. Adding formats later is cheaper than shipping a fake union type now.

Superseded: the intended example feed (`https://world.hey.com/dhh/feed.atom`) is Atom 1.0 only. See ADR-0008.

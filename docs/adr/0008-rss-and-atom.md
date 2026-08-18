# Parse RSS 2.0 and Atom 1.0

The example feed we want to ship with, [DHH on Hey](https://world.hey.com/dhh/feed.atom), is Atom (`application/atom+xml`), not RSS 2.0. v1 now accepts both formats through one `parseFeed` entry: RSS 2.0 identity stays `guid` then `link`; Atom identity is `id` then `link rel="alternate"`. JSON Feed and RSS 1.0 remain failed feeds.

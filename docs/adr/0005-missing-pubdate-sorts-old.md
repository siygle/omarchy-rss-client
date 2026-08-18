# Missing pubDate is old, not new

RSS 2.0 does not require `pubDate`. Treating a missing date as “just seen” would pin broken items to the top of a newest-first list and inflate the badge. Dated items sort newest first; undated items sit below them, stable by identity. We do not drop undated items — they can still be activated or marked read.

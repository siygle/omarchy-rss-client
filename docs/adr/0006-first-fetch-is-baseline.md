# A feed’s first good snapshot is baseline, not unread

Install and “add URL” would otherwise dump the last N posts into the badge. Those posts already existed. We record their identities as the baseline for that feed and only treat identities that appear on a later fetch as unread. The same rule applies when a URL is added after install.

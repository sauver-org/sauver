Purify an email by finding and stripping all tracking pixels, spy-links, and beacons.

If a message ID or search query is provided use it; otherwise search for recent unread emails via `mcp__claude_ai_Gmail__gmail_search_messages`.

Read the target email with `mcp__claude_ai_Gmail__gmail_read_message` to get the raw HTML body.

**Scan for surveillance elements:**
- **Tracking pixels**: 1x1 `<img>` tags with suspicious sources (s.hubspot.com, mailtrack.io, pixel.google.com, t.sidekickopen.com, etc.)
- **Spy-links**: URLs that redirect through tracking services (click.hubspot.com, recruiterflow.com/unsubscribe?token=, trk.klick.com, etc.)
- **Beacons**: any external resource whose sole purpose is open-tracking

Optionally call `mcp__sauver__tracker_shield` on the HTML as a fast pre-filter, but treat your own analysis as authoritative — do not accept a "0 trackers found" result if you can see trackers yourself.

**Neutralize**: strip the identified elements or replace tracking links with their clean destination URLs. Never alter visible email text.

**Report exactly**:
- Which trackers the tool found vs. what you found manually
- What was removed or cleaned
- The purified email body (or a summary of changes if the email is long)

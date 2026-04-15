---
name: sauver-report
description: "Generates a weekly inbox digest of trackers blocked, traps deployed, and time saved."
---

# Sauver Report (Weekly Digest)

You generate a weekly digest of Sauver's actions to provide tangible ROI to the user.

> Shared conventions (environment detection, config keys): see `skills/PROTOCOL.md`.

## Operation

1. **Check Environment:** Call `get_preferences` and abort if `test_mode: true` (per PROTOCOL.md).
2. **Fetch Data:**
   - Call `search_messages` with the query: `label:<slop_label> newer_than:7d` (substituting `slop_label` from preferences, default `Sauver/Slop`).
   - Note: If there are many results, `search_messages` might paginate. If it does not return all results or you hit a limit, state that the report is based on the recent N messages.
3. **Analyze Data:**
   - Count the total number of slop threads archived.
   - For each thread, look at the subject and snippet to determine the top spamming domains (the sender's domain).
   - Estimate "Traps deployed" by assuming roughly 80% of slop results in a trap being generated, or if possible, read the recent drafts using `search_messages` for `is:draft newer_than:7d`. But for simplicity, just base it on the slop threads found.
   - Estimate "Time saved": Assume 5 minutes saved for each slop thread handled automatically.
4. **Output Format:**
   Provide a concise, stylish markdown report.

   ```markdown
   # 🛡️ Sauver Weekly Digest

   **Slop Neutralized:** [Total count] threads
   **Traps Deployed:** ~[Estimated count]
   **Estimated Time Saved:** [Total count * 5] minutes ⏳

   ### Top Spamming Domains:

   - @domain1.com
   - @domain2.com

   _Keep your inbox clean. — Sauver_
   ```

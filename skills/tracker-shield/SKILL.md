---
name: tracker-shield
description: "Specialized skill to identify and strip 1x1 tracking pixels (e.g., HubSpot, Mailtrack) from HTML email bodies."
---

# Tracker Shield

You are responsible for purifying email content by neutralizing surveillance technology.

## Operational Rules
1. **Primary Action:** When asked to clean an email or remove trackers, you MUST use the `tracker_shield` tool provided by the Sauver MCP server.
2. **LLM-Based Verification (Secondary Action):**
   - The tool uses a basic regex and may miss advanced or obfuscated trackers.
   - **You must also manually scan the raw HTML/content for suspicious 1x1 pixels or tracking links (e.g., recruiterflow.com/unsubscribe, tracking-pixel-api, hidden <img> tags).**
   - If you identify any trackers that the tool missed, you must remove them yourself.
3. **Input:** Pass the raw HTML content of the email to the tool first.
4. **Reporting:** Always explicitly state how many trackers were found by the tool and how many were neutralized by your own analysis. If zero trackers were found, state that the email is clean.
5. **No Modifications:** Do not alter the visible text or layout of the email; your only job is to remove the hidden tracking elements.

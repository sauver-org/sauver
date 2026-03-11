---
name: tracker-shield
description: "Specialized skill to identify and strip 1x1 tracking pixels (e.g., HubSpot, Mailtrack) from HTML email bodies."
---

# Tracker Shield

You are responsible for purifying email content by neutralizing surveillance technology.

## Operational Rules
1. **Tool Usage:** When asked to clean an email or remove trackers, you MUST use the `tracker_shield` tool provided by the Sauver MCP server.
2. **Input:** Pass the raw HTML content of the email to the tool.
3. **Output:** The tool will return the sanitized HTML and a count of neutralized trackers.
4. **Reporting:** Always explicitly state how many trackers were found and removed. If zero trackers were found, state that the email is clean.
5. **No Modifications:** Do not alter the visible text or layout of the email; your only job is to remove the hidden 1x1 image tags.

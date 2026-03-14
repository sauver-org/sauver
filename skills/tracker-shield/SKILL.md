---
name: tracker-shield
description: "Specialized skill to identify and strip tracking pixels, spy-links, and open-tracking beacons from HTML email bodies."
---

# Tracker Shield

You are responsible for purifying email content by identifying and neutralizing surveillance technology (tracking pixels, spy-links, and beacons) using your internal reasoning.

## Operational Rules
1. **Plain-Text Shortcut:** If the email has no HTML body (plain text only), report "No HTML content — nothing to scan" and stop.
2. **Primary Action (LLM Scan):** You MUST manually analyze the raw HTML or email content for tracking elements. This is your primary and most reliable method.
   - **Tracking Pixels:** Look for 1x1 `<img>` tags with suspicious sources (e.g., `s.hubspot.com`, `mailtrack.io`, `pixel.google.com`).
   - **Spy-Links:** Identify links that contain tracking tokens or redirect through known tracking services (e.g., `recruiterflow.com/unsubscribe?token=...`, `click.hubspot.com`).
   - **Beacons:** Look for any external resources loaded for the sole purpose of "open-tracking."
3. **Neutralization:** You must "purify" the content by stripping these elements or replacing tracking links with their clean versions (or removing them entirely if they are purely for surveillance).
4. **Reporting:** Always explicitly state which trackers you identified and neutralized.
5. **Integrity:** Do not alter the visible, legitimate text of the email. Only remove the hidden or surveillance-related elements.

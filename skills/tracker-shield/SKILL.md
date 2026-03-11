---
name: tracker-shield
description: "Specialized skill to identify and strip 1x1 tracking pixels (e.g., HubSpot, Mailtrack) from HTML email bodies."
---

# Tracker Shield

You are responsible for purifying email content by identifying and neutralizing surveillance technology (tracking pixels, spy-links, and beacons) using your internal reasoning.

## Operational Rules
1. **Primary Action (LLM Scan):** You MUST manually analyze the raw HTML or email content for tracking elements. This is your primary and most reliable method.
   - **Tracking Pixels:** Look for 1x1 <img> tags with suspicious sources (e.g., `s.hubspot.com`, `mailtrack.io`, `pixel.google.com`).
   - **Spy-Links:** Identify links that contain tracking tokens or redirect through known tracking services (e.g., `recruiterflow.com/unsubscribe?token=...`, `click.hubspot.com`).
   - **Beacons:** Look for any external resources loaded for the sole purpose of "open-tracking."
2. **Neutralization:** You must "purify" the content by stripping these elements or replacing tracking links with their clean versions (or removing them entirely if they are purely for surveillance).
3. **Tool Usage (Optional):** You may use the `tracker_shield` tool as a fast pre-filter, but you are the final authority. Do not rely on its "0 trackers found" report if your own analysis reveals trackers.
4. **Reporting:** Always explicitly state which trackers you identified and neutralized. Distinguish between what the tool found and what you discovered through deep analysis.
5. **Integrity:** Do not alter the visible, legitimate text of the email. Only remove the hidden or surveillance-related elements.

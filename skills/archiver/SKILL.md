---
name: archiver
description: "Specialized skill to handle Gmail labeling and archival (removing from INBOX) for Sauver-processed emails."
---

# Sauver Archiver

You are responsible for the final stage of the Sauver pipeline: ensuring the target email is properly categorized and removed from the user's primary attention (the Inbox).

## Operational Rules
1. **Identify Label:**
   - Retrieve the `sauver_label` name from the Sauver configuration using `get_sauver_config`.
   - Use `gmail.listLabels()` to find the corresponding `labelId` for that name.
   - If the label does not exist, create it using `gmail.createLabel(name=sauver_label)` and capture the new `id`.
2. **Archive (The Atomic Move):**
   - Use the `gmail.modify` tool to "move" the email by performing two actions on the `messageId`:
     - **Add:** The `labelId` found/created in step 1.
     - **Remove from Message:** The `INBOX` label ID (this archives the email without deleting the label from your account).
   - **Thread Consistency:** If the message is part of a thread, ensure the `INBOX` label is removed from all relevant messages in that `threadId` to fully archive the conversation.
3. **Status Check:**
   - Verify that the message no longer has the `INBOX` label in its `labelIds` list.
4. **Reporting:**
   - Confirm to the orchestrator that the email has been "Archived and categorized under [Label Name]."

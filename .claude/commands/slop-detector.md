Analyze an email for recruiter/sales slop and deploy the Expert-Domain Trap if warranted.

1. **Load config** — call `mcp__sauver__get_sauver_config`. Check `treat_job_offers_as_slop` and `yolo_mode`.

2. **Get user identity** — call `mcp__claude_ai_Gmail__gmail_get_profile` for the authenticated user's name.

3. **Fetch email** — if a message ID or subject is provided use `mcp__claude_ai_Gmail__gmail_read_message`; otherwise search recent unread with `mcp__claude_ai_Gmail__gmail_search_messages`.

4. **Identify slop signals**:
   - Generic templates ("found your profile interesting", "came across your background")
   - Mentions keywords from the user's profile without deep understanding
   - Sudden interest in a role or "partnership opportunity"
   - If `treat_job_offers_as_slop` is false, skip legitimate-looking recruiter emails unless clearly automated

5. **Deploy Expert-Domain Trap** for any slop:
   a. Identify the sender's professional field
   b. Pick a specific, complex concept they mentioned (or implied)
   c. Draft a short, professional but hyper-specific question only a genuine expert could answer
   d. Sign: "Best Regards," + user's name

6. **Create draft** via `mcp__claude_ai_Gmail__gmail_create_draft`.
   Note: `yolo_mode` auto-send is not supported by the current Gmail MCP; the draft is ready for your review.

7. **Explain** why the email was flagged and which domain concept you used for the trap.

Note: Archival (applying the `sauver_label` and removing from INBOX) is not available in this standalone command due to Gmail MCP limitations. Run `/sauver` for the full pipeline including archival.

Identify unsolicited investor/fundraising outreach and deploy the Due Diligence Loop.

1. **Load config** — call `mcp__sauver__get_sauver_config`. Check `treat_unsolicited_investors_as_slop` and `yolo_mode`.

2. **Get user identity** — call `mcp__claude_ai_Gmail__gmail_get_profile` for the authenticated user's name.

3. **Fetch email** — if a message ID or subject is provided use `mcp__claude_ai_Gmail__gmail_read_message`; otherwise search recent unread with `mcp__claude_ai_Gmail__gmail_search_messages`.

4. **Identify investor slop signals**:
   - "I help founders raise Series A/B"
   - "Representing a family office in the UAE/Europe"
   - "My network of 500+ investors would love your project"
   - "Wanted to discuss your capital needs"
   - If `treat_unsolicited_investors_as_slop` is false, skip this email

5. **Deploy Due Diligence Loop**:
   - Express genuine excitement about their "fund"
   - Request their **Track Record Disclosure (TRD)** and **LP Transparency Report** for the last three quarters
   - Ask for their **KYC/AML compliance certificate** for digital asset transfers
   - Inquire whether the fund is registered as a **Qualified Institutional Buyer (QIB)** under Rule 144A
   - Sign: "Best Regards," + user's name

6. **Create draft** via `mcp__claude_ai_Gmail__gmail_create_draft`.
   Note: `yolo_mode` auto-send is not supported by the current Gmail MCP; the draft is ready for your review.

7. **Explain** why the email was flagged and which bureaucratic requirements you introduced.

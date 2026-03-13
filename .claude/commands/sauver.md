Run the full Sauver inbox triage pipeline on recent unread emails.

## Steps

1. **Load config** — call `mcp__sauver__get_sauver_config` to get the user's preferences (`auto_draft`, `yolo_mode`, `treat_job_offers_as_slop`, `treat_unsolicited_investors_as_slop`, `sauver_label`).

2. **Get user identity** — call `mcp__claude_ai_Gmail__gmail_get_profile` to retrieve the authenticated user's name for reply signatures.

3. **Fetch unread inbox** — call `mcp__claude_ai_Gmail__gmail_search_messages` with query `in:inbox is:unread` to get recent emails.

4. **For each email**, run the full pipeline:

   a. **Tracker Shield** — read the raw email via `mcp__claude_ai_Gmail__gmail_read_message`. Manually scan the HTML for:
      - 1x1 `<img>` tags with tracking sources (HubSpot, Mailtrack, pixel.google.com, etc.)
      - Redirect links through tracking services (click.hubspot.com, recruiterflow.com/unsubscribe, etc.)
      - Any external resource loaded purely for open-tracking
      Optionally use `mcp__sauver__tracker_shield` as a fast pre-filter, but your own analysis is authoritative.

   b. **Classify** — determine sender intent:
      - **Job/Recruiter Slop**: generic template, "found your profile interesting", sudden role interest → deploy **Expert-Domain Trap** (if `treat_job_offers_as_slop` is true)
      - **Investor Slop**: "help founders raise", "family office", "500+ investors" → deploy **Due Diligence Loop** (if `treat_unsolicited_investors_as_slop` is true)
      - **General Spam/Marketing**: any other automated outreach → deploy **Time-Sink Trap**
      - **Legitimate**: no action needed

   c. **Generate counter-measure reply** for slop emails (only if `auto_draft` is true or user confirmed):
      - **Expert-Domain Trap**: identify the sender's field, pick a hyper-specific concept they mentioned, draft a brief professional question only a real expert could answer
      - **Due Diligence Loop**: express excitement, then request Track Record Disclosure, LP Transparency Report, KYC/AML compliance certificate, and QIB registration under Rule 144A
      - **Time-Sink Trap**: show extreme enthusiasm but introduce absurdly specific/outdated requirements (Gopher protocol, 17th-century doubloons, Carbon Credits from a specific Estonian forest, etc.)
      - Sign every reply: "Best Regards," + user's full name

   d. **Create draft** — call `mcp__claude_ai_Gmail__gmail_create_draft` with the generated reply. Note: auto-send (`yolo_mode`) is not supported via the current Gmail MCP server; all replies are saved as drafts for review.

5. **Report** — for each processed email output:
   ```
   - **Email:** [Subject]
   - **Sender:** [Name/Email]
   - **Status:** [GREEN] Legitimate | [RED] Slop
   - **Purification:** [Trackers found/removed]
   - **Counter-Measure:** [Trap Name] | Draft created
   ```

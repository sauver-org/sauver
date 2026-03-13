Generate a Time-Sink Trap reply for a spam or marketing email to waste the sender's resources.

1. **Load config** — call `mcp__sauver__get_sauver_config`. Check `yolo_mode`.

2. **Get user identity** — call `mcp__claude_ai_Gmail__gmail_get_profile` for the authenticated user's name.

3. **Fetch email** — if a message ID or subject is provided use `mcp__claude_ai_Gmail__gmail_read_message`; otherwise search recent unread with `mcp__claude_ai_Gmail__gmail_search_messages`.

4. **Generate Time-Sink Trap reply**:
   - Use specific details from their pitch (product name, "value prop") to sound like a real, engaged lead
   - Express extreme enthusiasm
   - Introduce absurdly specific, bureaucratic, or technically outdated requirements — for example:
     - "Can you deliver the whitepaper via Gopher protocol?"
     - "We only authorize payments in 17th-century doubloons"
     - "We require Carbon Credits certified by a specific forest cooperative in Estonia"
     - "Our security team requires a SOC2 audit submitted by carrier pigeon"
   - Keep the tone professional but earnest — the goal is to make them believe they have a live lead
   - Sign: "Best Regards," + user's name

5. **Create draft** via `mcp__claude_ai_Gmail__gmail_create_draft`.
   Note: `yolo_mode` auto-send is not supported by the current Gmail MCP; the draft is ready for your review.

6. **Describe** the theme of the confusion trap you chose (e.g., "Draft asks them to deliver their proposal via Gopher protocol").

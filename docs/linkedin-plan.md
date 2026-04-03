# LinkedIn Support — Design Plan

## Core Insight: Zero API, Zero Cost

LinkedIn already emails users their inbox messages as Gmail notifications. These notification emails include the full message preview (~300 chars), sender name, and a link back to the LinkedIn thread. **No LinkedIn API, no browser automation, no paid services needed** — Sauver just reads what's already in Gmail.

---

## What This Feature Does and Doesn't Do

**Does:**
- Detect LinkedIn notification emails (messages, InMail, connection requests) in Gmail
- Classify them using the same slop signals as email (recruiter/sales/investor)
- Label + archive slop in Gmail
- Generate a reply trap as a **Gmail draft** with the reply text + LinkedIn thread URL at the top, so the user can open LinkedIn with one click and paste

**Doesn't:**
- Automatically reply on LinkedIn (impossible without API or browser automation)
- Read messages beyond what LinkedIn includes in the notification email
- Access the LinkedIn inbox directly

The reply limitation is honest and documented. The draft-as-template workflow preserves trap value while being achievable.

---

## LinkedIn Notification Email Taxonomy

| Sender address | Type | Action |
|---|---|---|
| `messages-noreply@linkedin.com` | Message / InMail | Classify → trap or pass |
| `invitations@linkedin.com` | Connection request | Classify → trap or pass |
| `jobalerts-noreply@linkedin.com` | Job alert | Skip (treat_job_offers_as_slop covers this) |
| `notification-noreply@linkedin.com` | Generic notification | Skip |

---

## Components

### 1. `mcp-server/index.js` — New Preference Keys

Add to `PREFERENCE_KEYS` and `DEFAULT_PREFERENCES`:

```
linkedin_enabled               bool    false    Master switch for LinkedIn filtering
linkedin_slop_label            string  "Sauver/LinkedIn/Slop"
filter_linkedin_connections    bool    false    Connection requests (opt-in, aggressive)
```

Small change — just adds 3 keys to two arrays.

---

### 2. `skills/linkedin-shield/SKILL.md` — New Skill

Handles a single LinkedIn notification email. Called by the orchestrator per-message, similar to how `slop-detector` is called today.

**Workflow:**

```
Receive: messageId, threadId, email headers + HTML body

Step 1 — Identify notification type
  - Parse From: address to determine type (message / InMail / connection)
  - If "jobalerts" or "notification-noreply": report SKIP

Step 2 — Extract signal data from HTML body
  - Parse sender's name and title from the email HTML
  - Extract message preview text (the quoted LinkedIn message content)
  - Extract LinkedIn thread URL (https://www.linkedin.com/comm/messaging/...)

Step 3 — Classify

  Recruiter/job slop signals:
    - "I came across your profile" / "Your background caught my eye"
    - Mentions of role, position, salary, opportunity, fit
    - Title contains Recruiter / Talent Acquisition / HR

  Sales slop signals:
    - "I help companies like yours" / generic value props
    - Vague ROI claims without specifics
    - "Wanted to reach out" / "thought you'd be interested"

  Investor slop signals:
    - "family office" / "fund" / "early-stage"
    - "I'd love to learn about what you're building" (generic)

  Legitimate signals:
    - References a specific project, post, or shared context the user would recognize
    - Concrete collaboration proposal with specifics
    - Personal connection (mutual acquaintance mentioned by name)
    - Specific technical question showing domain knowledge

Step 4 — Act on classification

  SLOP path:
    1. apply_label(threadId, linkedin_slop_label)
    2. archive_thread(threadId)
    3. If auto_draft AND linkedin_thread_url was found:
       create_draft with body:
         "--- LinkedIn thread: {url} ---\n\n{trap_reply_text}"
       Subject: "Re: [LinkedIn] {original_subject}"
       — This serves as a copy-paste template for manual LinkedIn reply

  LEGITIMATE path:
    apply_label(threadId, reviewed_label)
    — Leave in inbox, no archive

Step 5 — Report result
```

**Trap selection for LinkedIn slop:**
- Recruiter/job → Info Vacuum (ask for company, role details, comp) → Expert-Domain Trap → NDA Trap
- Sales → Time-Sink Trap (absurd requirements) → NDA Trap
- Investor → Due Diligence Loop → NDA Trap

The trap reply text is generated but stored as a draft, never auto-sent to LinkedIn.

**Exchange counting for LinkedIn:**
LinkedIn threads arrive as separate notification emails per message. Count prior emails in the thread using `search_messages(from:linkedin.com subject:"[sender name]")` to determine exchange depth before selecting trap stage.

---

### 3. `skills/sauver-inbox-assistant/SKILL.md` — Add LinkedIn Pass

Insert **Pass 0** before existing Pass 1:

```
Pass 0 — LinkedIn Notifications (runs only if linkedin_enabled = true)

  search_messages("from:(linkedin.com) in:inbox")
  For each result:
    - get_message(messageId)
    - Route to linkedin-shield
    - Process result
  Repeat until 0 results
```

This keeps LinkedIn handling isolated and optional — if `linkedin_enabled` is false, Pass 0 is skipped entirely.

---

### 4. `scripts/install.sh` — LinkedIn Setup Step

Add as **Step 5** (after MCP server installation, before AI client registration), marked as optional:

```
── Step 5: LinkedIn spam filtering (optional) ──

Explain:
  "Sauver can filter LinkedIn message spam that arrives in your Gmail
   as email notifications. This requires LinkedIn to send you email
   notifications for messages and InMail — which most accounts have
   enabled by default."

Ask: "Enable LinkedIn spam filtering? [y/N]"

If yes:
  Show instructions:
    1. Visit: linkedin.com/mypreferences/d/categories/notifications
    2. Under "Messages" → ensure "Messages from connections" is ON
    3. Under "InMail" → ensure "InMail messages" is ON
    4. Optionally: "Connection requests" (more aggressive, opt-in)

  Wait: "Press Enter when done..."

  Ask: "Also filter connection request spam? [y/N]"

  Write to config.json:
    preferences.linkedin_enabled = true
    preferences.filter_linkedin_connections = <yes/no>

  Confirm: "✓ LinkedIn filtering enabled"

If no:
  Skip (linkedin_enabled stays false / not written)

Upgrade mode:
  If linkedin_enabled already in config → offer to reconfigure, show current setting
```

The step is entirely non-blocking — existing users skip it (default `false`). Running install in upgrade mode re-offers the step if not previously configured.

---

### 5. `skills/PROTOCOL.md` — LinkedIn Addendum

Add a **LinkedIn Notification Handling** section:

- List known LinkedIn sender addresses and what they mean
- Document the draft-as-template pattern (reply text is for manual use on LinkedIn)
- Note that LinkedIn replies are never auto-sent via `send_message` (would send to Gmail, not LinkedIn)
- Add `linkedin_enabled`, `linkedin_slop_label`, `filter_linkedin_connections` to the config key reference table

---

### 6. Tests — LinkedIn EML Fixtures

Add to `tests/fixtures/`:

```
tests/fixtures/
  slop/
    linkedin-recruiter-inmail.eml          + .test.json
    linkedin-sales-connection-request.eml  + .test.json
    linkedin-investor-message.eml          + .test.json
  legitimate/
    linkedin-genuine-message.eml           + .test.json
    linkedin-mutual-acquaintance.eml       + .test.json
```

Each EML is a realistic LinkedIn notification email with stripped SMTP routing headers (matching existing fixture convention). The `.test.json` for slop cases should assert `archived: true`, `draft_created: (depends on auto_draft)`, `label_applied: "Sauver/LinkedIn/Slop"`.

---

### 7. Sync

Run `make sync` after adding `linkedin-shield/SKILL.md` — the existing `scripts/sync_commands.py` auto-generates `.claude/commands/linkedin-shield.md` and `.gemini/skills/linkedin-shield/SKILL.md` shims. No changes to sync tooling needed.

---

## What Doesn't Need to Change

| Component | Reason |
|---|---|
| `apps-script/Code.gs` | LinkedIn notifications are plain Gmail emails — all 9 existing handlers work |
| MCP transport / stdio | No new tools, just new preference keys |
| `scripts/sync_commands.py` | Picks up new skill automatically |
| NDA attachment mechanism | Reused as-is in the LinkedIn NDA Trap |

---

## Implementation Order

1. `mcp-server/index.js` — add 3 preference keys (trivial)
2. `skills/linkedin-shield/SKILL.md` — the core new skill
3. `skills/sauver-inbox-assistant/SKILL.md` — add Pass 0
4. `skills/PROTOCOL.md` — LinkedIn addendum + config table update
5. `scripts/install.sh` — LinkedIn setup step
6. `make sync` — regenerate command shims
7. Test fixtures — EML samples + `.test.json`
8. Version bump: `make version V=2.0.0`

---

## Key Trade-offs

**Reply gap is explicit, not hidden.** The draft-as-template approach is honest. Trying to "send" via the Gmail compose window to `messages-noreply@linkedin.com` would silently fail. The draft tells the user exactly what to do.

**Exchange tracking is approximate.** Without access to the LinkedIn inbox itself, exchange counting relies on Gmail notification history for that sender. It's good enough to gate the NDA Trap correctly but may miscount if notifications were deleted.

**Connection requests are off by default.** Many legitimate connection requests would be caught if `filter_linkedin_connections` were on by default. It's opt-in and clearly labeled as aggressive.

**Message preview truncation.** LinkedIn truncates notification emails at ~300 chars. For very long messages, the LLM classifies on the preview only. In practice, slop is identifiable within the first sentence — this is rarely a problem.

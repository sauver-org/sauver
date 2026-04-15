# LinkedIn Support — Design Plan (v3)

## Honest Assessment First

There are exactly three ways to access LinkedIn messages and feed programmatically:

| Approach                              | Full messages              | Auto-reply                | Feed | Cost                 | Account risk                        |
| ------------------------------------- | -------------------------- | ------------------------- | ---- | -------------------- | ----------------------------------- |
| **Gmail notification emails**         | No (300-char preview only) | No                        | No   | Free                 | None                                |
| **Browser automation (Playwright)**   | Yes                        | Yes                       | Yes  | Free                 | Low (looks like human)              |
| **LinkedIn Voyager API (unofficial)** | Yes                        | Yes                       | Yes  | Free                 | Moderate (detectable HTTP patterns) |
| **LinkedIn official API**             | Requires partner approval  | Requires partner approval | No   | Free tier is useless | None                                |

The official API is a dead end — LinkedIn does not expose personal inbox or personal feed to third-party apps.

**Why DOM/Playwright over Voyager API:**

|                | Voyager API                                                        | Playwright DOM                                                       |
| -------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------- |
| Setup UX       | Must extract cookies from browser DevTools (friction, error-prone) | Log in naturally in a visible browser window                         |
| Detection risk | Moderate — crafted HTTP headers are a fingerprint                  | Low — it IS an actual browser, indistinguishable from a human        |
| 2FA / CAPTCHA  | Flow breaks, requires manual cookie re-extraction                  | User just completes it in the headed window                          |
| Maintenance    | API endpoints change silently with no warning                      | DOM selectors change, but aria-labels and data attributes are stable |
| Speed          | Fast (HTTP calls)                                                  | Slower (page loads) — irrelevant at personal-use frequency           |
| Dependencies   | Zero extra                                                         | `playwright-core` 10.5MB + system Chrome (already installed)         |

**Decision: DOM/Playwright for the full mode.** Same two-mode architecture — safe email mode as default, browser mode as opt-in.

ToS status: Browser automation still violates LinkedIn's ToS (Section 8.2). The risk of enforcement is lower than Voyager API because the traffic is indistinguishable from a human user, but the legal exposure is the same. Disclose it in the installer.

---

## Two-Mode Architecture

```
┌─────────────────────────────────────────────────────────┐
│  SAFE MODE (default)                                    │
│  Gmail receives LinkedIn notification emails            │
│  → existing Apps Script + MCP handles them             │
│  → classification from 300-char preview                 │
│  → label + archive slop in Gmail                        │
│  → draft with thread URL as copy-paste reply template   │
│  → NO feed support                                      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  BROWSER MODE (opt-in, risk disclosed)                  │
│  Playwright drives system Chrome to access LinkedIn     │
│  → full message content (no 300-char limit)             │
│  → auto-send trap replies directly on LinkedIn          │
│  → read and filter the news feed                        │
│  → mark conversations as read                           │
│  → all LinkedIn actions without leaving the terminal    │
└─────────────────────────────────────────────────────────┘
```

When browser mode is enabled, the safe-mode Gmail notification pass still runs — it catches anything missed during the browser scan (e.g. if a notification arrived before the last browser session). The two modes are additive, not exclusive.

---

## Playwright Implementation Details

### Package strategy

Use `playwright-core` (10.5MB npm package, no bundled browsers) + system Chrome via `channel: 'chrome'`. This avoids downloading ~120MB of Chromium. If the user doesn't have Chrome, the installer falls back to `npx playwright install chromium` as an optional step.

```javascript
const { chromium } = require("playwright-core");
const browser = await chromium.launch({ channel: "chrome", headless: true });
```

### Session persistence

On first run: launch headed (visible window), user logs in manually, session saved as Playwright storageState.

```
~/.sauver/linkedin-session.json   ← Playwright storageState (cookies + localStorage)
```

On every subsequent run: restore session from file, launch headless. LinkedIn session cookies last months. When they expire, the MCP tool detects the redirect to the login page and prompts the user to re-authenticate via `sauver-linkedin-auth`.

### Selector strategy

LinkedIn obfuscates CSS class names and changes them frequently. Use stable selectors in priority order:

1. **`data-control-name` attributes** — LinkedIn uses these for analytics; they're stable
2. **`aria-label` attributes** — accessibility labels, semantically tied to function
3. **URL-based routing** — navigate to known URLs (`/messaging/`, `/feed/`) rather than clicking nav elements
4. **Visible text content** — last resort, via `page.getByText()` or `:has-text()`

Never use class names like `.msg-conversation-listitem__link-to-overview` — these change silently.

### Key pages and DOM targets

**Inbox (`linkedin.com/messaging/`)**

- Conversation list items: navigate to page, then query by `data-control-name="overlay_conversation_link"` or iterate `article` elements in the left panel
- Each item: sender name from `[data-anonymize="person-name"]`, message preview from `[data-anonymize="message-preview"]`, timestamp from `time` element

**Thread (`linkedin.com/messaging/thread/{id}/`)**

- Messages: `article.msg-s-event-listitem` elements
- Message body: `.msg-s-event__content` or `[data-anonymize="message-body"]`
- Sender: `[data-anonymize="person-name"]` in each message
- Reply box: `div[contenteditable="true"][role="textbox"]`
- Send button: `button[data-control-name="send-message"]` or aria-label="Send"

**Feed (`linkedin.com/feed/`)**

- Posts: `div[data-id]` containers or `article` elements in feed
- Post content: `.update-components-text` or `.feed-shared-update-v2__description`
- "..." menu: `button[aria-label="Open control menu"]` on each post
- "Hide" option: within dropdown, text match "Hide this post" or `[data-control-name="hide_post"]`

**Graceful degradation:** If a selector fails (LinkedIn changed the DOM), the MCP tool returns a structured error: `{ error: "selector_stale", page: "messaging", hint: "LinkedIn may have updated their UI. Check for Sauver updates." }`. The skill surfaces this clearly rather than silently doing nothing.

---

## Components

### 1. `mcp-server/index.js` — Playwright Client + 6 New Tools

**New npm dependency:** `playwright-core` added to `mcp-server/package.json`.

**New preference keys** (add to `PREFERENCE_KEYS` and `DEFAULT_PREFERENCES`):

```
linkedin_enabled               bool    false    Master switch (either mode)
linkedin_mode                  string  "email"  "email" | "browser"
linkedin_slop_label            string  "Sauver/LinkedIn/Slop"
linkedin_filter_connections    bool    false    Also filter connection requests (aggressive, opt-in)
linkedin_filter_feed           bool    false    Enable feed filtering (browser mode only)
linkedin_feed_slop_label       string  "Sauver/LinkedIn/FeedSlop"
```

**New internal helpers:**

```
getLinkedInPage()
  → restore ~/.sauver/linkedin-session.json as storageState
  → launch headless Chrome via playwright-core + channel:'chrome'
  → return { browser, page }
  → if session expired (page.url() contains '/login'): throw SessionExpiredError

saveLinkedInSession(context)
  → context.storageState({ path: '~/.sauver/linkedin-session.json' })
```

**6 new MCP tools:**

| Tool                        | LinkedIn page             | What it does                                           |
| --------------------------- | ------------------------- | ------------------------------------------------------ |
| `linkedin_scan_inbox`       | `/messaging/`             | List unread conversations (sender, preview, thread ID) |
| `linkedin_get_conversation` | `/messaging/thread/{id}/` | Full thread — all messages, full text, timestamps      |
| `linkedin_send_reply`       | `/messaging/thread/{id}/` | Type reply in contenteditable box, click Send          |
| `linkedin_mark_read`        | `/messaging/thread/{id}/` | Open thread (marks as read automatically), close       |
| `linkedin_get_feed`         | `/feed/`                  | Scrape N feed posts with content, author, post ID      |
| `linkedin_hide_post`        | `/feed/`                  | Click "..." → "Hide this post" on a specific post      |

Each tool opens a fresh page, performs its action, saves session state, and closes the page. Browser instance is kept alive across calls within a single MCP session to avoid repeated startup cost.

**Session expired handling:** All 6 tools catch `SessionExpiredError` and return `{ error: "linkedin_session_expired", action: "Run: /linkedin-auth to reconnect" }`. The skill surfaces this as a clear user-facing message.

---

### 2. New standalone command: `/linkedin-auth`

A new tiny skill (`skills/linkedin-auth/SKILL.md`) whose only job is re-authentication:

```
Step 1 — Launch Chrome in headed mode (visible window)
Step 2 — Navigate to linkedin.com/login
Step 3 — Tell user: "Please log in to LinkedIn in the browser window that just opened.
          Press Enter here when you're done."
Step 4 — Wait for Enter
Step 5 — Verify: check that current URL is not a login page
Step 6 — Save session: saveLinkedInSession()
Step 7 — Close browser
Step 8 — Confirm: "LinkedIn session saved. Browser mode is ready."
```

This replaces the cookie-extraction flow in the installer entirely. Called:

- Once during install (if user opts into browser mode)
- Any time thereafter when the session expires

---

### 3. `skills/linkedin-shield/SKILL.md` — Dual-Mode Skill

**Email mode** (same as v2 plan — unchanged):

```
Receive Gmail messageId → parse notification email → classify from 300-char preview
→ label + archive in Gmail → optionally create draft with thread URL + reply text
```

**Browser mode:**

```
Receive LinkedIn thread ID from linkedin_scan_inbox
→ linkedin_get_conversation → read full thread, all messages
→ count exchange depth from message count
→ classify from full text (no truncation)
→ select trap stage based on exchange count

SLOP:
  → generate trap reply
  → if yolo_mode: linkedin_send_reply
  → if not yolo_mode: create Gmail draft with reply text + thread URL
  → linkedin_mark_read

LEGIT:
  → linkedin_mark_read
  → report as legitimate, no action
```

**Classification signals** (both modes, identical):

Recruiter/job slop:

- "I came across your profile" / "your background caught my eye" / "great fit"
- Mentions role, position, salary, equity without being asked
- Sender title contains: Recruiter, Talent, HR, Staffing, Headhunter

Sales slop:

- "I help companies like yours" / generic value propositions
- Vague ROI claims without specifics
- "Wanted to connect to discuss" / "thought you'd be interested"
- Follows an obvious template with blanks filled in

Investor slop:

- "family office" / "fund" / "early-stage" / "raise capital"
- "I'd love to learn more about what you're building" (generic)
- Calendly link or deck request without substantive prior exchange

Legitimate:

- References a specific post, project, or shared context the user would recognize
- Concrete technical question showing domain knowledge
- Named mutual connection or shared event
- No detectable commercial intent

**Trap selection:**

- Recruiter → Info Vacuum → Expert-Domain Trap → NDA Trap
- Sales → Time-Sink Trap → NDA Trap
- Investor → Due Diligence Loop → NDA Trap

(Identical to email traps. The reply is either sent via `linkedin_send_reply` or stored as a Gmail draft depending on `yolo_mode`.)

**Exchange counting (browser mode):** Count messages in the thread returned by `linkedin_get_conversation`. Odd-indexed messages are from sender, even-indexed from user (or vice versa) — identify by sender name vs profile name.

---

### 4. `skills/linkedin-feed/SKILL.md` — New Skill (Browser Mode Only)

```
Step 1 — linkedin_get_feed → fetch 10-20 feed posts (content + author + post ID)

Step 2 — Classify each post:

  Feed slop:
    - Sponsored / promoted (label "Promoted" present)
    - Hustle-culture: "I wake up at 4am", "rejection makes me stronger", "I failed 100 times"
    - Engagement bait: "Comment YES if you agree", "Tag someone who...", "Like if you..."
    - Stealth ads: product placed as a personal anecdote with a CTA at the end
    - Generic inspirational filler: vague platitudes with no actionable or factual content
    - Self-congratulatory posts with no insight ("Excited to announce I joined...")
    - Job listings dressed as thought leadership

  Legitimate:
    - Technical content with concrete specifics
    - Industry news or analysis with a named source
    - Genuine project updates with details the user's network would care about
    - Discussion with substantive debate, not engagement farming

Step 3 — For each slop post: linkedin_hide_post

Step 4 — Report: "Hid N posts. Categories: {breakdown}"
```

Adds `/linkedin-feed` slash command.

---

### 5. `skills/sauver-inbox-assistant/SKILL.md` — Add LinkedIn Pass

Insert **Pass 0** before existing Pass 1:

```
Pass 0 — LinkedIn (runs only if linkedin_enabled = true)

  EMAIL MODE:
    search_messages("from:(linkedin.com) in:inbox")
    For each result → linkedin-shield (email mode)
    Repeat until 0 results

  BROWSER MODE:
    linkedin_scan_inbox → list unread conversations
    For each conversation → linkedin-shield (browser mode)
    If session expired → surface error, skip LinkedIn, continue with Gmail passes
    If linkedin_filter_feed=true → linkedin-feed skill
```

---

### 6. `scripts/install.sh` — LinkedIn Setup Step

Add as **Step 5** (after MCP server installation):

```
── Step 5: LinkedIn spam filtering (optional) ──

"Sauver can filter LinkedIn spam — recruiters, sales outreach, InMail,
 and connection requests. Two modes:

 [1] Safe mode  — reads LinkedIn notification emails in your Gmail.
     No LinkedIn risk. Cannot auto-reply. No feed filtering.

 [2] Browser mode — controls Chrome to access your LinkedIn directly.
     Full messages, auto-reply on LinkedIn, feed filtering.
     ⚠  Automates your browser. Violates LinkedIn ToS.
        Risk of account suspension. Low in practice for personal use
        at this frequency, but the risk is real."

Ask: "Enable LinkedIn? [1=safe / 2=browser / n=skip]"

If 1:
  → guide: linkedin.com/mypreferences/d/categories/notifications
    Ensure Messages + InMail notifications are ON
  → ask: "Filter connection requests too? [y/N]"
  → write: linkedin_enabled=true, linkedin_mode="email"
  → confirm: "✓ Safe mode enabled"

If 2:
  → check: is playwright-core installed? If not: npm install playwright-core
  → check: is Chrome available? (chromium.launch({ channel: 'chrome', headless: true }))
    If not: offer "npx playwright install chromium" (~120MB) → ask consent
  → run /linkedin-auth inline:
    - launch Chrome headed
    - user logs in (handles 2FA naturally)
    - save session
    - verify: navigate to /messaging/, confirm inbox loaded
    - confirm: "✓ Connected to LinkedIn"
  → ask: "Filter connection requests? [y/N]"
  → ask: "Enable feed filtering? [y/N]"
  → write: linkedin_enabled=true, linkedin_mode="browser",
           linkedin_filter_connections=..., linkedin_filter_feed=...
  → confirm: "✓ Browser mode enabled"

Upgrade mode:
  → if linkedin already in config: show current mode, offer reconfigure
  → if browser mode: test session (try linkedin_scan_inbox), warn if expired
```

---

### 7. `skills/PROTOCOL.md` — LinkedIn Addendum

Add section **LinkedIn Integration**:

- Document both modes (email vs browser)
- List 6 new browser tools with usage notes
- Note: `linkedin_send_reply` is only used in browser mode + yolo_mode; otherwise Gmail draft
- Note: feed posts are hidden, never receive replies
- Note: session expiry error handling — skip LinkedIn pass, continue
- Add 6 new config keys to reference table
- Security note: `~/.sauver/linkedin-session.json` contains LinkedIn session cookies — same sensitivity as `secret_key`; `chmod 600` applied during auth

---

### 8. Tests

**Email mode:** Unchanged from v2 — EML fixtures work as-is.

**Browser mode:** Cannot use the existing EML fixture system. Two-part approach:

1. **Adapter abstraction:** The 6 LinkedIn browser tools call an internal `LinkedInBrowser` class (thin wrapper). In test environments, swap it with a `MockLinkedInBrowser` that returns fixture JSON without touching a real browser. Activated via `SAUVER_LINKEDIN_MOCK=1` env var.

2. **Fixtures:** JSON files in `tests/fixtures/linkedin/` matching what `linkedin_get_conversation` returns for recruiter / sales / investor / legitimate cases.

```
tests/fixtures/linkedin/
  slop/
    recruiter-inmail.json          ← conversation fixture
    sales-connection.json
    investor-message.json
  legitimate/
    genuine-message.json
    technical-question.json
```

---

### 9. Sync

Run `make sync` after adding `linkedin-shield/`, `linkedin-feed/`, and `linkedin-auth/` skills. Auto-generates 3 new command shims. No tooling changes.

---

## What Doesn't Need to Change

| Component                  | Reason                                                                     |
| -------------------------- | -------------------------------------------------------------------------- |
| `apps-script/Code.gs`      | LinkedIn notifications are Gmail emails; existing handlers untouched       |
| MCP stdio transport        | New tools added alongside existing ones                                    |
| `scripts/sync_commands.py` | Picks up new skills automatically                                          |
| NDA attachment mechanism   | Reused in LinkedIn NDA Trap                                                |
| Rate limiting              | Shared `max_daily_replies` counter — LinkedIn replies count against it too |

---

## Implementation Order

1. `mcp-server/package.json` — add `playwright-core`
2. `mcp-server/index.js` — 6 preference keys + `getLinkedInPage()` + `saveLinkedInSession()` + 6 new MCP tools + `MockLinkedInBrowser` stub
3. `skills/linkedin-auth/SKILL.md` — auth skill
4. `skills/linkedin-shield/SKILL.md` — dual-mode shield skill
5. `skills/linkedin-feed/SKILL.md` — feed filtering skill
6. `skills/sauver-inbox-assistant/SKILL.md` — add Pass 0
7. `skills/PROTOCOL.md` — LinkedIn addendum + config table
8. `scripts/install.sh` — LinkedIn setup step
9. `make sync` — regenerate command shims
10. `tests/fixtures/linkedin/` — JSON conversation fixtures
11. Version bump: `make version V=2.0.0`

---

## Key Trade-offs

**DOM selectors will break eventually.** LinkedIn changes their UI. The mitigation is using stable attributes (`data-control-name`, `aria-label`, URL routing) and returning a clear `selector_stale` error rather than silently failing. When it breaks, it breaks loudly, and a selector update is a one-line fix.

**Speed is acceptable.** Opening LinkedIn, scraping 10 conversations, sending 2-3 replies and closing takes ~15-30 seconds. For a tool that runs a few times per day, this is fine. The Gmail passes run in parallel (Apps Script, not Playwright) so they're unaffected.

**Session lifetime is long.** LinkedIn's session cookies persist for months. Re-auth is an edge case, not a routine. The `/linkedin-auth` command makes it trivial when needed.

**No LinkedIn archive.** LinkedIn doesn't have an archive feature. "Archiving" on the LinkedIn side means marking the conversation read — it stays in the inbox but is dealt with. The Gmail notification email for it is archived normally. This is acceptable.

**Feed filtering is one-way.** `linkedin_hide_post` removes a post from your feed; it doesn't notify or penalize the poster. Personal curation tool, not a trap.

**Reply tone calibration.** LinkedIn DMs are more casual than email. The linkedin-shield skill should note this and generate slightly shorter, less formal trap replies than the email skills produce.

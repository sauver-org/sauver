# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make sync       # Regenerate .claude/commands/ from skills/ (run after editing any SKILL.md)
make check-sync # Verify .claude/commands/ are up to date
```

## Claude Code Skills

The following slash commands are available in Claude Code (`.claude/commands/`):

| Command | Description |
|---|---|
| `/sauver` | Full inbox triage pipeline — classify, trap, and draft replies for all unread emails |
| `/tracker-shield` | Strip tracking pixels and spy-links from a specific email |
| `/slop-detector` | Detect recruiter/sales slop and deploy the Expert-Domain Trap |
| `/investor-trap` | Detect investor slop and deploy the Due Diligence Loop |
| `/bouncer-reply` | Generate a Time-Sink Trap reply for general spam |

These commands require the Gmail MCP server (`mcp__claude_ai_Gmail__*` tools).

## Architecture

Sauver is a **Gemini CLI Extension** that acts as a spam/tracker neutralizer for Gmail.

### Gemini Skills (`skills/*/SKILL.md`)
LLM instruction files that tell Gemini how to orchestrate the full pipeline using the Google Workspace APIs:

- **sauver-inbox-assistant** — top-level orchestrator; calls the other skills in sequence
- **tracker-shield** — strips tracking pixels via LLM analysis
- **slop-detector** — identifies recruiter/sales spam; responds with Expert-Domain Trap (hyper-specific technical questions)
- **investor-trap** — identifies unsolicited VC outreach; responds with Due Diligence Loop (bureaucratic document requests)
- **bouncer-reply** — general spam; responds with Time-Sink Trap (absurd/impossible requirements)
- **archiver** — applies `sauver_label` and removes email from INBOX via Gmail API

### Configuration (`GEMINI.md`)
User preferences live directly in `GEMINI.md`, which Gemini loads as context automatically. Skills read config values from context — no tool call needed. To change a setting, edit `GEMINI.md` directly.

| Key | Default | Meaning |
|---|---|---|
| `auto_draft` | `true` | Automatically create draft replies to slop |
| `yolo_mode` | `false` | Auto-send replies instead of drafting |
| `treat_job_offers_as_slop` | `true` | Treat recruiter outreach as slop |
| `treat_unsolicited_investors_as_slop` | `true` | Treat investor outreach as slop |
| `sauver_label` | `"Sauver"` | Gmail label applied when archiving |

### Extension Registration
`gemini-extension.json` declares the extension and points Gemini at `GEMINI.md` as the context file. `scripts/setup.sh` installs `@googleworkspace/cli` and prints auth instructions.

## Known Limitations & Sync Rules

### Dual-layer sync
`skills/*/SKILL.md` is the single source of truth. `.claude/commands/*.md` are auto-generated shims — **do not edit them directly**. After changing any SKILL.md, run `make sync` to regenerate the commands. `make check-sync` catches forgotten syncs.

### `yolo_mode` is Gemini-only
`yolo_mode: true` triggers `gmail.send` via the Google Workspace MCP, only available to the Gemini extension. Claude Code's Gmail MCP has no send endpoint — emails will always be drafted there regardless of this setting.

### Archival is Gemini-only
The Claude Code Gmail MCP does not expose a `modify` endpoint, so Claude Code commands cannot archive emails. The Gemini orchestrator archives via `gmail.modify`. The `/sauver` command will note unarchived emails in its report.

### `people.getMe()` vs `gmail_get_profile`
Gemini skills use `people.getMe()` (Google People API) to retrieve the user's display name for signatures. Claude Code commands use `mcp__claude_ai_Gmail__gmail_get_profile` instead.

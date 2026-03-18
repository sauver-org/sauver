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

These commands use the Sauver MCP server (`mcp__sauver__*` tools).

## Architecture

Sauver is a spam/tracker neutralizer for Gmail with three layers:

```
Google Apps Script (cloud)  ←  your Gmail, native access
        ↕  HTTPS (shared secret)
Local MCP Server (Node.js)  ←  ~/.sauver/mcp-server/
        ↕  stdio MCP protocol
Claude Code / Gemini CLI    ←  runs the skills
```

### MCP Tools (`mcp-server/index.js`)
The local MCP server exposes 9 tools that both Claude and Gemini can call:

`scan_inbox` · `search_messages` · `get_message` · `create_draft` · `send_message` · `archive_thread` · `apply_label` · `get_profile` · `list_labels`

### Skills (`skills/*/SKILL.md`)
LLM instruction files for the pipeline:

- **sauver-inbox-assistant** — top-level orchestrator
- **tracker-shield** — strips tracking pixels via LLM analysis
- **slop-detector** — Expert-Domain Trap for recruiter/sales slop
- **investor-trap** — Due Diligence Loop for VC slop
- **bouncer-reply** — Time-Sink Trap for generic spam
- **archiver** — applies label and archives via `apply_label` + `archive_thread`

### Configuration (`GEMINI.md`)
User preferences live in `GEMINI.md`. Edit it directly — no tool call needed.

| Key | Default | Meaning |
|---|---|---|
| `auto_draft` | `true` | Automatically create draft replies to slop |
| `yolo_mode` | `false` | Auto-send replies instead of drafting |
| `treat_job_offers_as_slop` | `true` | Treat recruiter outreach as slop |
| `treat_unsolicited_investors_as_slop` | `true` | Treat investor outreach as slop |
| `sauver_label` | `"Sauver"` | Gmail label applied when archiving |

## Versioning

`mcp-server/package.json` is the single source of truth for the version number.
`mcp-server/index.js` reads it at runtime. `gemini-extension.json` is kept in sync by `make sync`.

To bump the version:

```bash
make version V=1.7.0
```

Never edit the version in `gemini-extension.json` or `index.js` directly.

## Sync Rules

`skills/*/SKILL.md` is the single source of truth. `.claude/commands/*.md` are auto-generated shims — **do not edit them directly**. After changing any SKILL.md, run `make sync` to regenerate the commands. `make check-sync` catches forgotten syncs.

## Dev Setup

```bash
cd mcp-server && npm install
# Config must exist at ~/.sauver/config.json (run install.sh or create manually)
```

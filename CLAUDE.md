# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make setup     # Install dependencies via uv
make format    # Auto-format with ruff
make lint      # Run ruff check + mypy type checking
make test      # Run pytest suite
make all       # format + lint + test

uv run src/main.py            # Start the MCP server
uv run src/main.py configure  # Interactive config wizard
```

To run a single test: `uv run pytest tests/test_main.py::test_name -v`

## Claude Code Skills

The following slash commands are available in Claude Code (`.claude/commands/`):

| Command | Description |
|---|---|
| `/sauver` | Full inbox triage pipeline — classify, trap, and draft replies for all unread emails |
| `/tracker-shield` | Strip tracking pixels and spy-links from a specific email |
| `/slop-detector` | Detect recruiter/sales slop and deploy the Expert-Domain Trap |
| `/investor-trap` | Detect investor slop and deploy the Due Diligence Loop |
| `/bouncer-reply` | Generate a Time-Sink Trap reply for general spam |

These commands require the Gmail MCP server (`mcp__claude_ai_Gmail__*` tools) and the sauver MCP server (registered via `.claude/settings.json`).

## Architecture

Sauver is a **Gemini CLI Extension** that acts as a spam/tracker neutralizer for Gmail. It has two distinct layers:

### 1. FastMCP Server (`src/main.py`)
A Python MCP server exposing 4 tools to Gemini:
- `get_sauver_config` / `set_sauver_config` — read/write `.sauver-config.json`
- `start_sauver_config_wizard` — instructs user to run `configure` subcommand
- `tracker_shield(html_content)` — regex-based tracking pixel/URL removal

The `configure` CLI subcommand runs an interactive ANSI terminal wizard to set preferences.

### 2. Gemini Skills (`skills/*/SKILL.md`)
LLM instruction files that tell Gemini how to orchestrate the full pipeline using both the MCP tools and Google Workspace APIs directly:

- **sauver-inbox-assistant** — top-level orchestrator; calls the other skills in sequence
- **tracker-shield** — strips tracking pixels; prefers manual LLM analysis over the regex tool
- **slop-detector** — identifies recruiter/sales spam; responds with Expert-Domain Trap (hyper-specific technical questions)
- **investor-trap** — identifies unsolicited VC outreach; responds with Due Diligence Loop (bureaucratic document requests)
- **bouncer-reply** — general spam; responds with Time-Sink Trap (absurd/impossible requirements)
- **archiver** — applies `sauver_label` and removes email from INBOX via Gmail API

### Configuration (`.sauver-config.json`)
```json
{
  "auto_draft": true,
  "yolo_mode": false,
  "treat_job_offers_as_slop": true,
  "treat_unsolicited_investors_as_slop": true,
  "sauver_label": "Sauver"
}
```
`yolo_mode` enables auto-send (off by default); otherwise skills create drafts.

### Extension Registration
`gemini-extension.json` defines two MCP servers: `sauver` (this repo) and `google-workspace` (`@googleworkspace/mcp-server`). `scripts/setup.sh` registers the extension in `~/.gemini/settings.json`.

## Known Limitations & Sync Rules

### Dual-layer sync
The pipeline logic is implemented twice: once in `skills/` (for Gemini) and once in `.claude/commands/` (for Claude Code). Any workflow change must be applied in **both** places. When editing a skill, check whether the corresponding Claude command needs updating, and vice versa.

### `yolo_mode` is Gemini-only
The `yolo_mode` config flag triggers `gmail.send` via the Google Workspace MCP, which is only available to the Gemini extension. The Claude Code Gmail MCP (`mcp__claude_ai_Gmail__*`) does not expose a send endpoint. When `yolo_mode` is `true`, emails will auto-send in Gemini but will only be drafted in Claude Code. Document this if users configure it.

### Archival is Gemini-only
The current Claude Code Gmail MCP does not expose a `modify` endpoint, so the `/sauver`, `/slop-detector`, `/investor-trap`, and `/bouncer-reply` commands cannot archive emails. The Gemini orchestrator (`sauver-inbox-assistant`) does archive via `gmail.modify`. The `/sauver` command will note unarchived emails in its report.

### `people.getMe()` vs `gmail_get_profile`
Gemini skills use `people.getMe()` (Google People API) to retrieve the user's display name for signatures. Claude Code commands use `mcp__claude_ai_Gmail__gmail_get_profile` instead. These are different APIs — verify `people.getMe()` is accessible in your Gemini extension context if signatures are coming back empty.

## Tooling

- **Runtime:** Python ≥3.10, managed with `uv`
- **Linter/formatter:** `ruff` (line length 100, strict rule set: E, F, I, UP, N, S, B, A, C4, T20, RET, SIM, ARG, PTH, RUF)
- **Type checker:** `mypy` in strict mode — all functions require type annotations
- **Tests:** `pytest`; `tests/test_main.py` covers `tracker_shield` (pure unit); `tests/test_skill_routing.py` covers skill trigger routing via the Anthropic API (requires `ANTHROPIC_API_KEY` — skipped otherwise)

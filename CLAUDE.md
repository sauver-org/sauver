# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make sync              # Regenerate .claude/commands/ and .gemini/skills/ shims (run after editing any SKILL.md)
make check-sync        # Verify shims are up to date
make test              # Run installer unit tests
make test-skills       # Run skill integration tests against EML fixtures (claude CLI)
make test-skills-gemini # Run skill integration tests against EML fixtures (gemini CLI)
```

## Claude Code Skills

The following slash commands are available in Claude Code (`.claude/commands/`) and Gemini CLI (`.gemini/skills/`):

|      Command      |                                  Description                                         |
|-------------------|--------------------------------------------------------------------------------------|
| `/sauver`         | Full inbox triage pipeline — classify, trap, and draft replies for all unread emails |
| `/tracker-shield` | Strip tracking pixels and spy-links from a specific email                            |
| `/slop-detector`  | Detect recruiter/sales slop and deploy the Expert-Domain Trap or Info Vacuum         |
| `/investor-trap`  | Detect investor slop and deploy the Due Diligence Loop                               |
| `/bouncer-reply`  | Generate a Time-Sink Trap reply for general spam                                     |
| `/archiver`       | Label and archive a specific thread on demand, without full triage                   |

These commands use the Sauver MCP server (`mcp__sauver__*` tools). See `skills/PROTOCOL.md` for the full tool reference and operational protocol.

## Autonomous Operation

When running any Sauver skill, do not wait for manual confirmation for individual tool calls once the primary directive is issued. Use `get_preferences` to load user config at the start of each skill, then proceed autonomously.

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
The local MCP server exposes 11 tools that both Claude and Gemini can call:

`scan_inbox` · `search_messages` · `get_message` · `create_draft` · `send_message` · `archive_thread` · `apply_label` · `get_profile` · `list_labels` · `get_preferences` · `set_preference`

### Skills (`skills/*/SKILL.md`)
LLM instruction files for the pipeline:

- **sauver-inbox-assistant** — top-level orchestrator
- **tracker-shield** — strips tracking pixels via LLM analysis
- **slop-detector** — Expert-Domain Trap for recruiter/sales slop
- **investor-trap** — Due Diligence Loop for VC slop
- **bouncer-reply** — Time-Sink Trap for generic spam
- **archiver** — applies label and archives via `apply_label` + `archive_thread`

### Configuration (`~/.sauver/config.json`)
User preferences live in the `preferences` key of `~/.sauver/config.json`. Read them via the `get_preferences` MCP tool; update them via `set_preference`. Works from any working directory with both Claude Code and Gemini CLI.

See `skills/PROTOCOL.md` for the full config key reference.

## Versioning

`mcp-server/package.json` is the single source of truth for the version number.
`mcp-server/index.js` reads it at runtime. `gemini-extension.json` is kept in sync by `make sync`.

To bump the version:

```bash
make version V=x.y.z
```

Never edit the version in `gemini-extension.json` or `index.js` directly.

## Sync Rules

`skills/*/SKILL.md` is the single source of truth. `.claude/commands/*.md` and `.gemini/skills/*.md` are auto-generated shims — **do not edit them directly**. After changing any SKILL.md, run `make sync` to regenerate the commands. `make check-sync` catches forgotten syncs.

**Always edit files in this repo, never in `~/.sauver/`.** The installer copies files there for runtime use; `~/.sauver/` is a deployment target, not a source of truth. Changes made there will be lost on the next install.

## Dev Setup

```bash
cd mcp-server && npm install
# Config must exist at ~/.sauver/config.json (run install.sh or create manually)
```

## Skill Integration Tests

`tests/` contains a two-part integration test system for validating AI behaviour against real email samples.

### Fixtures (`tests/fixtures/`)

EML files are the test inputs. Each `.eml` file has a sidecar `.test.json` with:

```json
{
  "description": "human-readable summary of the email",
  "label": "slop",          // ground truth: "slop" | "legitimate"
  "category": "sales_outreach",
  "has_tracker": true,
  "expected": {
    "classified_as": "slop",
    "draft_created": true,
    "archived": true
  }
}
```

Fixtures are organised by ground truth:

```
tests/fixtures/
  slop/       ← emails that should be detected and trapped
  legitimate/ ← emails that should be left alone (not archived/drafted)
```

To add a new fixture: drop a `.eml` + `.test.json` into the appropriate subdirectory.

EML files should include only the headers the AI actually uses — `From`, `Reply-To`, `To`, `Subject`, `Date`, `MIME-Version`, `Content-Type`, any mass-mailer signals (`X-Mailer`, `List-Unsubscribe`) — plus the full body. Strip all SMTP routing headers (Received, ARC, DKIM, X-Spam, etc.).

### Mock MCP Server (`tests/mock-mcp-server/`)

A drop-in replacement for the production MCP server that:
- Reads EML files from disk (via `mailparser`) and serves them as the "inbox"
- Returns instant no-ops for `check_update`, `get_preferences`, `get_profile`
- Logs all write calls (`create_draft`, `send_message`, `archive_thread`, `apply_label`) to a JSON file at `SAUVER_TEST_LOG`

Activated entirely via environment variables — no changes to production code:
- `SAUVER_TEST_FIXTURE_FILE` — single EML (single-email inbox)
- `SAUVER_TEST_FIXTURES_DIR` — directory of EMLs (multi-email inbox)
- `SAUVER_TEST_LOG` — path for the call log (default: `/tmp/sauver-test-calls.json`)

### Test Runner (`tests/run-skill-tests.sh`)

For each fixture the runner:
1. Writes a project-scoped `.claude/settings.json` pointing to the mock MCP server (project scope overrides user scope, so the real Gmail connection is never touched; the original settings are restored on exit)
2. Runs `claude -p "/sauver"` (or `gemini -p "/sauver"` with `--cli gemini`)
3. Reads the call log and checks `draft_created` and `archived` against the `.test.json` expectations

```bash
make test-skills                                                          # all fixtures, claude
make test-skills-gemini                                                   # all fixtures, gemini
bash tests/run-skill-tests.sh tests/fixtures/slop/quick-question.eml     # single fixture
```

These are local-only tests — they require the claude or gemini CLI to be installed and authenticated, and Sauver skills to be installed at `~/.sauver/skills/`. They are not run in CI.

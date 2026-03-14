#!/usr/bin/env python3
"""
Generate .claude/commands/*.md from skills/*/SKILL.md.

Each generated command is a thin shim that tells Claude to read the source SKILL.md
(using its Read tool) and follow the instructions with Claude-specific tool names.
This keeps the Gemini skills as the single source of truth — editing a SKILL.md and
running `make sync` is all that is needed to keep both environments in sync.

Usage:
    python scripts/sync_commands.py          # regenerate all
    python scripts/sync_commands.py --check  # exit non-zero if any file is stale
"""

import argparse
import sys
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
COMMANDS_DIR = ROOT / ".claude" / "commands"

# Gemini skill directory name → Claude command filename (None = no Claude command)
SKILL_TO_COMMAND: dict[str, Optional[str]] = {
    "sauver-inbox-assistant": "sauver",
    "slop-detector": "slop-detector",
    "investor-trap": "investor-trap",
    "bouncer-reply": "bouncer-reply",
    "tracker-shield": "tracker-shield",
    "archiver": None,  # Archival is Gemini-only (no gmail.modify in Claude Code MCP)
}

# Tool name mapping shown inside every generated shim.
# LLM reads this table and substitutes names as it follows the SKILL.md instructions.
TOOL_TABLE = """\
| Gemini tool | Claude Code tool |
|---|---|
| `get_sauver_config` | `mcp__sauver__get_sauver_config` |
| `set_sauver_config` | `mcp__sauver__set_sauver_config` |
| `tracker_shield` | `mcp__sauver__tracker_shield` |
| `people.getMe()` | `mcp__claude_ai_Gmail__gmail_get_profile` |
| `gmail.search(...)` | `mcp__claude_ai_Gmail__gmail_search_messages` |
| `gmail.get(id)` | `mcp__claude_ai_Gmail__gmail_read_message` |
| `gmail.createDraft(...)` | `mcp__claude_ai_Gmail__gmail_create_draft` |
| `gmail.listLabels()` | `mcp__claude_ai_Gmail__gmail_list_labels` |
| `gmail.send(...)` | *(not available — use `mcp__claude_ai_Gmail__gmail_create_draft`)* |
| `gmail.modify(...)` | *(not available — archive emails via Gmail manually)* |
| `gmail.createLabel(...)` | *(not available)* |
"""

SHIM_TEMPLATE = """\
<!-- Generated from {skill_rel} by scripts/sync_commands.py — do not edit directly.
     Run `make sync` to regenerate after editing the source SKILL.md. -->

Use your Read tool to load `{skill_rel}` and `skills/PROTOCOL.md`, then follow \
the instructions in that file exactly.

When the instructions refer to a Gemini tool, substitute the Claude Code equivalent \
from the table below. Where a tool is marked "not available", note the limitation \
in your report and skip that step.

## Tool Reference

{tool_table}
"""


def render_shim(skill_name: str) -> str:
    skill_rel = f"skills/{skill_name}/SKILL.md"
    return SHIM_TEMPLATE.format(skill_rel=skill_rel, tool_table=TOOL_TABLE)


def sync(check_only: bool = False) -> int:
    """Regenerate all shim files. Returns the number of stale/changed files."""
    COMMANDS_DIR.mkdir(parents=True, exist_ok=True)
    stale = 0

    for skill_name, command_name in SKILL_TO_COMMAND.items():
        if command_name is None:
            continue

        skill_md = SKILLS_DIR / skill_name / "SKILL.md"
        if not skill_md.exists():
            print(f"  WARNING  skills/{skill_name}/SKILL.md not found — skipped", file=sys.stderr)
            continue

        command_path = COMMANDS_DIR / f"{command_name}.md"
        new_content = render_shim(skill_name)

        if command_path.exists() and command_path.read_text() == new_content:
            print(f"  ok       .claude/commands/{command_name}.md")
        else:
            stale += 1
            if check_only:
                print(f"  STALE    .claude/commands/{command_name}.md")
            else:
                command_path.write_text(new_content)
                print(f"  updated  .claude/commands/{command_name}.md")

    return stale


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit with code 1 if any command file is out of date (useful in CI).",
    )
    args = parser.parse_args()

    stale = sync(check_only=args.check)

    if args.check and stale:
        print(f"\n{stale} file(s) are out of date. Run `make sync` to fix.", file=sys.stderr)
        sys.exit(1)
    elif not args.check:
        label = "file(s) updated" if stale else "files already up to date"
        print(f"\n{stale} {label}.")


if __name__ == "__main__":
    main()

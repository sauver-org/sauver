#!/usr/bin/env python3
"""
Generate .claude/commands/*.md from skills/*/SKILL.md.

Each generated command is a thin shim that tells Claude to read the source SKILL.md
and follow its instructions. Both Claude Code and Gemini use the same Sauver MCP
server tools, so no tool-name substitution is needed.

Usage:
    python scripts/sync_commands.py          # regenerate all
    python scripts/sync_commands.py --check  # exit non-zero if any file is stale
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
VERSION_SOURCE = ROOT / "mcp-server" / "package.json"
GEMINI_EXTENSION = ROOT / "gemini-extension.json"

# Both Claude and Gemini/Antigravity need these shims, but in different locations
COMMANDS_DIRS = [
    ROOT / ".claude" / "commands",
    ROOT / ".agent" / "workflows",
]

# Skill directory name → command filename (None = skip)
SKILL_TO_COMMAND: dict[str, Optional[str]] = {
    "sauver-inbox-assistant": "sauver",
    "slop-detector": "slop-detector",
    "investor-trap": "investor-trap",
    "bouncer-reply": "bouncer-reply",
    "tracker-shield": "tracker-shield",
    "archiver": "archiver",
}

SHIM_TEMPLATE = """\
<!-- Generated from {skill_rel} by scripts/sync_commands.py — do not edit directly.
     Run `make sync` to regenerate after editing the source SKILL.md. -->

Use your Read tool to load `{skill_rel}` and `skills/PROTOCOL.md`, then follow \
the instructions in that file exactly.

All tools listed in `skills/PROTOCOL.md` are available via the Sauver MCP server \
(`mcp__sauver__*`). No substitution needed.
"""


def render_shim(skill_name: str) -> str:
    skill_rel = f"skills/{skill_name}/SKILL.md"
    return SHIM_TEMPLATE.format(skill_rel=skill_rel)


def sync_version(check_only: bool = False) -> int:
    """Sync version from mcp-server/package.json → gemini-extension.json. Returns 1 if stale."""
    version = json.loads(VERSION_SOURCE.read_text())["version"]
    ext = json.loads(GEMINI_EXTENSION.read_text())

    if ext.get("version") == version:
        print(f"  ok       gemini-extension.json  (v{version})")
        return 0

    if check_only:
        print(f"  STALE    gemini-extension.json  (has v{ext.get('version')}, want v{version})")
        return 1

    ext["version"] = version
    GEMINI_EXTENSION.write_text(json.dumps(ext, indent=2) + "\n")
    print(f"  updated  gemini-extension.json  (v{version})")
    return 1


def sync(check_only: bool = False) -> int:
    """Regenerate all shim files. Returns the number of stale/changed files."""
    for d in COMMANDS_DIRS:
        d.mkdir(parents=True, exist_ok=True)
    
    stale = sync_version(check_only)

    for skill_name, command_name in SKILL_TO_COMMAND.items():
        if command_name is None:
            continue

        skill_md = SKILLS_DIR / skill_name / "SKILL.md"
        if not skill_md.exists():
            print(f"  WARNING  skills/{skill_name}/SKILL.md not found — skipped", file=sys.stderr)
            continue

        new_content = render_shim(skill_name)

        for d in COMMANDS_DIRS:
            command_path = d / f"{command_name}.md"
            rel_path = command_path.relative_to(ROOT)
            if command_path.exists() and command_path.read_text() == new_content:
                print(f"  ok       {rel_path}")
            else:
                stale += 1
                if check_only:
                    print(f"  STALE    {rel_path}")
                else:
                    command_path.write_text(new_content)
                    print(f"  updated  {rel_path}")

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

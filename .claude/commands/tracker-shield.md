<!-- Generated from skills/tracker-shield/SKILL.md by scripts/sync_commands.py — do not edit directly.
     Run `make sync` to regenerate after editing the source SKILL.md. -->

Use your Read tool to load `skills/tracker-shield/SKILL.md` and `skills/PROTOCOL.md`, then follow the instructions in that file exactly.

When the instructions refer to a Gemini tool, substitute the Claude Code equivalent from the table below. Where a tool is marked "not available", note the limitation in your report and skip that step.

## Tool Reference

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


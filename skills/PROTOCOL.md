# Sauver Shared Protocol

This file defines conventions shared across all Sauver skills.

## Available Tools

All Gmail operations go through the Sauver MCP server. Use these tools:

| Tool | Purpose |
|---|---|
| `scan_inbox` | List unread inbox emails |
| `search_messages` | Search with a Gmail query string |
| `get_message` | Fetch full email content by messageId |
| `create_draft` | Create a draft (new email or reply) |
| `send_message` | Send immediately (yolo_mode only) |
| `archive_thread` | Remove from inbox, mark read |
| `apply_label` | Apply a label (creates it if missing) |
| `get_profile` | Get the user's email address and name |
| `list_labels` | List all Gmail labels |

## Signature

Every generated reply MUST end with:

```
Best Regards,
[User's full name]
```

Retrieve the user's name with the `get_profile` tool before drafting any reply.

## Reply Dispatch (YOLO Mode)

After generating a reply, check `yolo_mode` from context (`GEMINI.md`):

- **`yolo_mode: true`** — Call `send_message` to send immediately.
- **`yolo_mode: false`** — Call `create_draft` to save for review.

Always confirm which path was taken.

## Confirmation Messages

- **Sent:** "The [trap name] has been triggered and the reply was sent."
- **Drafted:** "A draft is ready for your review. [One sentence describing the trap used.]"

## Config Keys

Config lives in `GEMINI.md` and is loaded automatically as context. Edit it directly to change settings.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `auto_draft` | bool | `true` | Automatically create draft replies |
| `yolo_mode` | bool | `false` | Auto-send replies instead of drafting |
| `treat_job_offers_as_slop` | bool | `true` | Treat recruiter outreach as slop |
| `treat_unsolicited_investors_as_slop` | bool | `true` | Treat investor outreach as slop |
| `sauver_label` | string | `"Sauver"` | Gmail label applied when archiving |

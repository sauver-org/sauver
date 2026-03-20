# Sauver Shared Protocol

This file defines conventions shared across all Sauver skills.

## Available Tools

All Gmail operations go through the Sauver MCP server. Use these tools:

| Tool              | Purpose                                            |
|-------------------|----------------------------------------------------|
| `scan_inbox`      | List unread inbox emails                           |
| `search_messages` | Search with a Gmail query string                   |
| `get_message`     | Fetch full email content by messageId              |
| `create_draft`    | Create a draft (new email or reply)                |
| `send_message`    | Send immediately (yolo_mode only)                  |
| `archive_thread`  | Remove from inbox, mark read                       |
| `apply_label`     | Apply a label (creates it if missing)              |
| `get_profile`     | Get the user's email address and name              |
| `list_labels`     | List all Gmail labels                              |
| `get_preferences` | Read user preferences from `~/.sauver/config.json` |
| `set_preference`  | Write a single preference key back to config       |

**Note:** `scan_inbox` and `search_messages` return a `bodyTruncated: true` flag when email bodies exceeded the preview limit. Use `get_message` to fetch the full content of any flagged email before analysis.

## Reply Formatting

All generated replies MUST look like a plain human message:

- **No markdown** — no bold, no italics, no bullet points, no dashes, no numbered lists.
- **No headers or section labels** of any kind.
- **Plain prose only** — short paragraphs, casual punctuation, the way a person types in Gmail.
- **No filler phrases** that signal automation: "I hope this email finds you well", "Thank you for reaching out", "Please don't hesitate to", "Best of luck", etc.
- The tone should read as a real person dashing off a quick note, not a polished template.

## Signature

Every generated reply MUST end with:

```
Best,
[User's first name]
```

Retrieve the user's name with the `get_profile` tool before drafting any reply.

## Reply Dispatch (YOLO Mode)

After generating a reply, check `yolo_mode` from the result of `get_preferences`:

- **`yolo_mode: true`** — Call `send_message` to send immediately.
- **`yolo_mode: false`** — Call `create_draft` to save for review.

Always confirm which path was taken.

## Confirmation Messages

- **Sent:** "The [trap name] has been triggered and the reply was sent."
- **Drafted:** "A draft is ready for your review. [One sentence describing the trap used.]"

## Config Keys

Config lives in `~/.sauver/config.json`. Read it by calling `get_preferences`; update a value by calling `set_preference`.

| Key                                   | Type   | Default  | Meaning                                                   |
|---------------------------------------|--------|----------|-----------------------------------------------------------|
| `auto_draft`                          | bool   | `true`   | Automatically create draft replies                        |
| `yolo_mode`                           | bool   | `false`  | Auto-send replies instead of drafting                     |
| `treat_job_offers_as_slop`            | bool   | `true`   | Treat recruiter outreach as slop                          |
| `treat_unsolicited_investors_as_slop` | bool   | `true`   | Treat investor outreach as slop                           |
| `sauver_label`                        | string | `Sauver` | Gmail label applied when archiving                        |
| `engage_bots`                         | bool   | `false`  | Continue trap engagement even when bot-like behaviour is detected; if `false`, silently archive bot threads |
| `bot_reply_threshold_seconds`         | int    | `120`    | Maximum seconds between our last reply and their next one to be considered bot-like |

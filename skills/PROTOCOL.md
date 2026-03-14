# Sauver Shared Protocol

This file defines conventions shared across all Sauver skills. Skills reference this document
rather than repeating these rules inline.

## Signature

Every generated reply MUST end with a proper closing:

```
Best Regards,
[User's full name]
```

Retrieve the user's name before drafting any reply. In Gemini, use `people.getMe()`.
In Claude Code, use `mcp__claude_ai_Gmail__gmail_get_profile`.

## Reply Dispatch (YOLO Mode)

After generating a reply, check `yolo_mode` from context (`GEMINI.md`):

- **`yolo_mode: true`** — Auto-Send is enabled. Immediately send the reply using `gmail.send`.
- **`yolo_mode: false`** — Save as a draft using `gmail.createDraft` for the user to review.

Always confirm which path was taken.

## Confirmation Messages

- **Sent:** "The [trap name] has been triggered and the reply was sent."
- **Drafted:** "A draft is ready for your review. [One sentence describing the trap used.]"

## Config Keys

Config lives in `GEMINI.md` and is loaded automatically as context. To change a value, edit `GEMINI.md` directly — no tool call needed.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `auto_draft` | bool | `true` | Whether to automatically create draft replies |
| `yolo_mode` | bool | `false` | Auto-send replies instead of drafting |
| `treat_job_offers_as_slop` | bool | `true` | Treat recruiter outreach as slop |
| `treat_unsolicited_investors_as_slop` | bool | `true` | Treat investor outreach as slop |
| `sauver_label` | string | `"Sauver"` | Gmail label applied when archiving |

# Sauver: The Digital Bouncer for your Inbox 🛡️

Sauver is a cyber-defense layer for Gmail. It strips tracking pixels, identifies recruiter/sales/investor "slop," and wastes spammers' time with automated traps. It runs inside Claude Code and Gemini CLI.

## What it does

- **Tracker Shield** — strips 1×1 tracking pixels and surveillance beacons from HTML emails
- **Slop Detection** — separates legitimate outreach from automated, low-effort "slop"
- **Expert-Domain Trap** — fires back hyper-specific technical questions at recruiters/sales bots
- **Due Diligence Loop** — buries unsolicited "investors" in bureaucratic document requests
- **Bouncer Reply** — engages generic spammers with absurd, impossible requirements

## Installation

Run this one command in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/mszczodrak/sauver/main/scripts/install.sh | bash
```

The installer walks you through three steps (~3 minutes total):

1. **Create the Gmail backend** — paste one file into Google Apps Script (no coding needed)
2. **Deploy it** — click Deploy in the browser, authorize with your Google account
3. **Connect it** — the installer wires everything up automatically

**Requirement:** [Node.js v18+](https://nodejs.org). That's it — no OAuth setup, no API keys, no gcloud.

## Configuration

Settings live in `GEMINI.md` — edit that file directly to change behavior.

| Option | Default | Meaning |
| :--- | :--- | :--- |
| `auto_draft` | `true` | Automatically create draft replies to slop |
| `yolo_mode` | `false` | Auto-send replies (use with caution) |
| `treat_job_offers_as_slop` | `true` | Trigger Expert-Domain Trap for recruiters |
| `treat_unsolicited_investors_as_slop` | `true` | Trigger Due Diligence Loop for investors |
| `sauver_label` | `Sauver` | Gmail label applied when archiving |

## Usage

### Claude Code

Open Claude Code inside this repository and use slash commands:

| Command | What it does |
| :--- | :--- |
| `/sauver` | Full triage — strips trackers, classifies intent, drafts counter-measures for all unread slop |
| `/tracker-shield` | Strip tracking pixels from a specific email |
| `/slop-detector` | Draft an Expert-Domain Trap reply for recruiter/sales slop |
| `/investor-trap` | Draft a Due Diligence Loop reply for investor slop |
| `/bouncer-reply` | Draft a Time-Sink Trap reply for generic spam |

### Gemini CLI

Install the extension:

```bash
gemini extensions install https://github.com/mszczodrak/sauver
```

Then ask Gemini directly:

```
Triage my last 10 unread emails
```

Or invoke a specific skill: *"Run tracker-shield on this email"*.

## How it works

Sauver has three layers:

```
┌─────────────────────────────────────────────────────┐
│              Google Apps Script (cloud)             │
│   Deployed to your Google account. Native Gmail     │
│   access — no OAuth tokens, no API keys.            │
│   Exposes: scan, read, draft, send, archive, label  │
└────────────────────────┬────────────────────────────┘
                         │ HTTPS POST (secret key)
┌────────────────────────▼────────────────────────────┐
│          Local MCP Server (~/.sauver/mcp-server/)   │
│   A small Node.js process on your machine.          │
│   Translates MCP tool calls → Apps Script actions.  │
│   Reads config from ~/.sauver/config.json.          │
└──────────────┬──────────────────────┬───────────────┘
               │ stdio MCP            │ stdio MCP
┌──────────────▼──────┐   ┌──────────▼──────────────┐
│     Claude Code     │   │       Gemini CLI         │
│   /sauver and       │   │   "triage my inbox"      │
│   other commands    │   │   and other skills       │
└─────────────────────┘   └──────────────────────────┘
```

### Layer 1 — Google Apps Script

`apps-script/Code.gs` is deployed as a Web App inside your own Google account. Because it runs as you, it has full native Gmail access via `GmailApp` — the same APIs Gmail itself uses. There are no OAuth flows, no service accounts, and no third-party tokens to manage.

The Web App accepts HTTPS POST requests and routes them to one of nine Gmail actions:

| Action | What it does |
| :--- | :--- |
| `scan_inbox` | List unread inbox emails |
| `search_messages` | Search with a Gmail query string |
| `get_message` | Fetch full email content by ID |
| `create_draft` | Create a new draft or a reply draft |
| `send_message` | Send a reply immediately |
| `archive_thread` | Remove from Inbox and mark read |
| `apply_label` | Apply a label (creates it if missing) |
| `get_profile` | Get the user's email and display name |
| `list_labels` | List all Gmail labels |

Every request must include a secret key that was randomly generated during installation. Requests without the correct key are rejected.

### Layer 2 — Local MCP Server

`mcp-server/index.js` is a small Node.js process that runs on your machine. It speaks the [Model Context Protocol (MCP)](https://modelcontextprotocol.io) over stdio, which is how Claude Code and Gemini CLI discover and call tools.

When Claude or Gemini calls a tool (e.g. `scan_inbox`), the MCP server forwards it as an HTTPS POST to your Apps Script Web App, then returns the result. The config file at `~/.sauver/config.json` holds the Web App URL and secret key — written once by the installer, never changed.

### Layer 3 — AI Clients

Both Claude Code and Gemini CLI connect to the same local MCP server and see the same nine tools. The defense logic — tracker detection, slop classification, trap generation — runs entirely inside the AI model, guided by the skill files in `skills/`. No defense logic lives in the MCP server or the Apps Script; they are pure data pipes.

### Security model

- The secret key is a 64-character random hex string generated locally during install. It never leaves your machine except in the POST body to your own Apps Script.
- The Apps Script runs under your Google account and is not accessible to anyone without the key.
- Email content is read by the AI model on your local machine. It is not stored or sent anywhere beyond what your AI client (Claude/Gemini) already handles.

---

## FAQ

**Do I need a Google Cloud project or API keys?**
No. Google Apps Script runs inside your Google account for free. The installer requires only a browser and Node.js.

**Is my email data sent to Anthropic or Google?**
Email content is read by the AI model (Claude or Gemini) running on your machine as part of the conversation. It is subject to the same privacy terms as any other message you send to your AI assistant — not to any additional service.

**What does "Who has access: Anyone" mean in the deployment step?**
It means the Apps Script Web App URL is publicly reachable — but the secret key acts as a password. Any request without the correct key is immediately rejected. The URL alone is useless without the key.

**Can I revoke access?**
Yes. In the Apps Script editor, click **Deploy → Manage deployments**, then delete the deployment. The Web App goes offline instantly.

**How is the secret key stored and protected?**
The key lives in `~/.sauver/config.json` on your machine. The installer creates this file with permissions `600` (readable and writable only by you — no other user on the same machine can read it). It is listed in `.gitignore` so it can never be accidentally committed to a repository. The key is transmitted only once per tool call, over HTTPS, directly to your own Apps Script — it is never sent to Anthropic, Google, or any other third party. The Apps Script itself stores the key as a constant in your private script project, which is not visible to anyone who doesn't have access to your Google account.

**What if I lose my secret key?**
Run the installer again. It generates a new key, redeploys, and updates your local config. The old key stops working as soon as you save the new one in the Apps Script editor.

**Does `yolo_mode` work in Claude Code?**
Yes — with this architecture, `send_message` is fully available in Claude Code. The old limitation is gone.

**Can I run this on multiple machines?**
Yes. Run the installer on each machine. Use the same Apps Script Web App URL, but generate a new secret key per machine (or re-use the same key by copying `~/.sauver/config.json`).

**Does this work with Google Workspace (G Suite) accounts?**
Yes, as long as your organization allows Apps Script Web Apps. Some Workspace admins restrict external deployments — check with your IT team if the deployment step fails.

**How do I update Sauver?**
Re-run the installer. It downloads the latest MCP server and updates your local config. To update the Apps Script backend, paste the latest `Code.gs` into the editor and redeploy.

**Where is my data stored?**
- `~/.sauver/config.json` — your Web App URL and secret key (local, never committed)
- `~/.sauver/mcp-server/` — the MCP server code (downloaded from this repo)
- `~/.claude/settings.json` — Claude Code MCP server registration

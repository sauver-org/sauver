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

The installer automates the setup process (~3 minutes total) using `clasp`:

1. **Enable Apps Script API** — a one-time toggle in your Google account settings
2. **Authenticate** — the installer opens a browser to securely log in
3. **Auto-Deploy** — the installer creates, configures, and deploys the backend automatically

**Requirement:** [Node.js v18+](https://nodejs.org). That's it — no OAuth setup, no API keys, no gcloud.

## Configuration

Settings live in `~/.sauver/config.json` under the `preferences` key. You can edit that file directly, or ask Claude/Gemini to change a setting for you (e.g. "turn on yolo mode").

| Option | Default | Meaning |
| :--- | :--- | :--- |
| `auto_draft` | `true` | Automatically create draft replies to slop |
| `yolo_mode` | `false` | Auto-send replies (use with caution) |
| `treat_job_offers_as_slop` | `true` | Trigger Expert-Domain Trap for recruiters |
| `treat_unsolicited_investors_as_slop` | `true` | Trigger Due Diligence Loop for investors |
| `sauver_label` | `Sauver` | Gmail label applied when archiving |

## Usage

### Claude Code

The installer writes slash commands to `~/.claude/commands/`, so they are available globally in every Claude Code session:

| Command | What it does |
| :--- | :--- |
| `/sauver` | Full triage — scans inbox, strips trackers, classifies intent, and drafts or sends counter-measures (depends on `auto_draft` / `yolo_mode`) |
| `/tracker-shield` | Strip tracking pixels and spy-links from a specific email |
| `/slop-detector` | Classify recruiter/sales slop and reply with the Expert-Domain Trap or Info Vacuum |
| `/investor-trap` | Classify investor slop and reply with the Due Diligence Loop |
| `/bouncer-reply` | Reply to generic spam with the Time-Sink Trap |
| `/archiver` | Label and archive a specific thread on demand, without full triage |

### Gemini CLI

The installer automatically configures Gemini CLI. Gemini reads commands from `.agent/workflows/` inside the Sauver repository, so you need to be in (or have indexed) the repo directory.

| Command | What it does |
| :--- | :--- |
| `/sauver` | Full triage — runs the orchestrator skill |
| `/tracker-shield` | Strip tracking pixels via the LLM |
| `/slop-detector` | Classify recruiter/sales slop and deploy a trap |
| `/investor-trap` | Classify investor slop and deploy the Due Diligence Loop |
| `/bouncer-reply` | Deploy the Time-Sink Trap for generic spam |
| `/archiver` | Label and archive a specific thread on demand |

You can also ask Gemini in plain English: *"Sauver, triage my last 10 unread emails"* or *"Archive this thread under the Sauver label"*.

### How Gemini finds Sauver

Gemini CLI discovers Sauver through several layers:

1.  **MCP Server Registration:** Gemini reads the MCP server definition from `~/.claude/settings.json` and uses `~/.gemini/mcp-server-enablement.json` to toggle it on.
2.  **Global Slash Commands:** The installer populates `~/.agent/workflows/` with shims that point to Sauver's core skills. This makes `/sauver` and other commands available in every session, from any directory.
3.  **Project Context:** When you are inside the Sauver repository, Gemini CLI additionally sees `gemini-extension.json` and loads `GEMINI.md` as its primary instruction set.

### How Claude finds Sauver

Claude Code discovers Sauver through two layers:

1.  **MCP Server Registration:** The installer writes the MCP server entry into `~/.claude/settings.json`. Claude Code reads this global config at startup, so the `mcp__sauver__*` tools are available in every session, from any directory — no project context required.
2.  **Slash Commands:** The installer downloads all skill files to `~/.sauver/skills/` and writes global command shims to `~/.claude/commands/`. Each shim points to the corresponding skill file using its absolute path, so `/sauver`, `/slop-detector`, and the other commands work from any working directory.

### Skill auto-updates

The MCP server checks for updates automatically in the background on each startup, at most once per day. It fetches the latest version number from GitHub and compares it to the installed version. If a newer version is available, it silently downloads the updated skill files to `~/.sauver/skills/` and rewrites the `~/.claude/commands/` shims, then prints a one-line prompt to restart your AI client. The check is fire-and-forget — it never delays MCP server startup, and any network failure is ignored. The last-check timestamp and installed skills version are stored in `~/.sauver/config.json`.

To update the MCP server itself or the Apps Script backend, re-run the installer.

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

When Claude or Gemini calls a tool, the MCP server either handles it locally (for `get_preferences` and `set_preference`, which read/write `~/.sauver/config.json`) or forwards it as an HTTPS POST to the Apps Script Web App and returns the result. The config file at `~/.sauver/config.json` holds the Web App URL, secret key, user preferences, and update metadata.

On each startup the MCP server also fires a background update check (see [Skill auto-updates](#skill-auto-updates) above).

### Layer 3 — AI Clients

Both Claude Code and Gemini CLI connect to the same local MCP server and see the same 11 tools. The defense logic — tracker detection, slop classification, trap generation — runs entirely inside the AI model, guided by the skill files installed to `~/.sauver/skills/`. No defense logic lives in the MCP server or the Apps Script; they are pure data pipes.

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

**What does "Who has access: Anyone" mean in the automated deployment configuration?**
It means the Apps Script Web App URL is publicly reachable — but the secret key acts as a password. Any request without the correct key is immediately rejected. The URL alone is useless without the key.

**Can I revoke access?**
Yes. In the Apps Script editor, click **Deploy → Manage deployments**, then delete the deployment. The Web App goes offline instantly.

**How is the secret key stored and protected?**
The key lives in `~/.sauver/config.json` on your machine. The installer creates this file with permissions `600` (readable and writable only by you — no other user on the same machine can read it). It is listed in `.gitignore` so it can never be accidentally committed to a repository. The key is transmitted only once per tool call, over HTTPS, directly to your own Apps Script — it is never sent to Anthropic, Google, or any other third party. The Apps Script itself stores the key as a constant in your private script project, which is not visible to anyone who doesn't have access to your Google account.

**What if I lose my secret key?**
Run the installer again. It generates a new key, redeploys the backend, and updates your local config automatically.

**Does `yolo_mode` work in Claude Code?**
Yes — with this architecture, `send_message` is fully available in Claude Code. The old limitation is gone.

**Can I run this on multiple machines?**
Yes. Run the installer on each machine. Use the same Apps Script Web App URL, but generate a new secret key per machine (or re-use the same key by copying `~/.sauver/config.json`).

**Does this work with Google Workspace (G Suite) accounts?**
Yes, as long as your organization allows Apps Script Web Apps. Some Workspace admins restrict external deployments — check with your IT team if the deployment step fails.

**How do I update Sauver?**
Skill files update automatically — the MCP server checks GitHub once a day at startup and silently installs any newer version. A one-line message appears in your AI client when an update is applied; restart the client to pick it up.

To update the MCP server itself or the Apps Script backend, re-run the installer. It downloads the latest `index.js`, fetches the newest `Code.gs`, and redeploys your Apps Script backend.

**Where is my data stored?**
- `~/.sauver/config.json` — your Web App URL, secret key, and update metadata (local, never committed)
- `~/.sauver/mcp-server/` — the MCP server code (downloaded from this repo)
- `~/.sauver/skills/` — skill instruction files (downloaded and auto-updated by the MCP server)
- `~/.claude/settings.json` — Claude Code MCP server registration
- `~/.gemini/mcp-server-enablement.json` — Gemini CLI MCP server toggle
- `~/.claude/commands/` — global Claude Code slash command shims (managed by the installer/auto-updater)
- `~/.agent/workflows/` — global Gemini CLI slash command shims (managed by the installer/auto-updater)

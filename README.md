# Sauver: The Digital Bouncer for your Inbox 🛡️

Sauver is a cyber-defense layer for Gmail. It strips tracking pixels, identifies recruiter/sales/investor "slop," and wastes spammers' time with automated traps. It runs as a set of skills inside Gemini CLI and Claude Code.

## What it does

- **Tracker Shield** — strips 1×1 tracking pixels and surveillance beacons from HTML emails
- **Slop Detection** — separates legitimate outreach from automated, low-effort "slop"
- **Expert-Domain Trap** — fires back hyper-specific technical questions at recruiters/sales bots
- **Due Diligence Loop** — buries unsolicited "investors" in bureaucratic document requests
- **Bouncer Reply** — engages generic spammers with absurd, impossible requirements

## Installation

### Gemini CLI (recommended)

```bash
gemini extensions install https://github.com/mszczodrak/sauver
```

Then install the Google Workspace CLI and authenticate:

```bash
npm install -g @googleworkspace/cli@latest
gws auth setup   # one-time Google Cloud project config
gws auth login   # OAuth login
```

### Manual (development)

```bash
git clone https://github.com/mszczodrak/sauver.git
cd sauver
./scripts/setup.sh
```

## Configuration

Settings live in `GEMINI.md` — edit that file directly to change behavior. No commands needed.

| Option | Default | Meaning |
| :--- | :--- | :--- |
| `auto_draft` | `true` | Automatically create draft replies to slop |
| `yolo_mode` | `false` | Auto-send replies (Gemini only; Claude Code always drafts) |
| `treat_job_offers_as_slop` | `true` | Trigger Expert-Domain Trap for recruiters |
| `treat_unsolicited_investors_as_slop` | `true` | Trigger Due Diligence Loop for investors |
| `sauver_label` | `Sauver` | Gmail label applied when archiving |

## Usage

### Gemini CLI

Ask Gemini directly:

```
Triage my last 10 unread emails
```

Or invoke a specific skill by name, e.g. *"Run tracker-shield on this email"*.

### Claude Code

Open Claude Code inside this repository and use slash commands:

| Command | What it does |
| :--- | :--- |
| `/sauver` | Full triage — strips trackers, classifies intent, drafts counter-measures for all unread slop |
| `/tracker-shield` | Strip tracking pixels from a specific email |
| `/slop-detector` | Draft an Expert-Domain Trap reply for recruiter/sales slop |
| `/investor-trap` | Draft a Due Diligence Loop reply for investor slop |
| `/bouncer-reply` | Draft a Time-Sink Trap reply for generic spam |

**Prerequisite:** connect your Gmail account via the Claude Code Gmail MCP server.

**Limitations vs. Gemini:** Claude Code cannot archive emails or auto-send (`yolo_mode` has no effect — replies are always saved as drafts).

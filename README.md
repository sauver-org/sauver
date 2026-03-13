# Sauver: The Digital Bouncer for your Inbox 🛡️

Sauver is a cyber-defense layer for your Gmail, designed to neutralize tracking pixels, identify automated "job slop," and engage spammers in time-wasting loops. It operates as a set of specialized skills within the Gemini CLI and Claude Code.

## Key Capabilities

- **Purification:** Identifies and strips 1x1 tracking pixels and surveillance beacons from HTML emails.
- **Slop Detection:** Classifies email intent to separate legitimate human outreach from automated, low-effort "slop."
- **Expert-Domain Traps:** For recruiter or sales outreach, Sauver generates hyper-specific, technically challenging questions to put the cognitive load back on the sender.
- **Bouncer Replies:** Enthusiastically engages generic spammers with absurd, bureaucratic requests to waste their time.

## Installation

The easiest way to install Sauver is as a **Gemini CLI Extension**. This automatically configures all tools and prompts you for consent once during setup.

```bash
# Install and trust the extension (one-line setup)
gemini extensions install https://github.com/mszczodrak/sauver --consent
```

### Manual Installation (Development)

If you're contributing to Sauver, you can clone the repository and set it up manually:

```bash
# Clone the repository
git clone https://github.com/mszczodrak/sauver.git
cd sauver

# Run the setup script (interactive configuration)
./scripts/setup.sh
```

## Configuration & Automation ⚙️

Sauver uses a local configuration file (`.sauver-config.json`) to manage its automation level. You can view or update these settings at any time using the Gemini CLI.

### Configuration Options

| Option | Description | Default |
| :--- | :--- | :--- |
| `auto_draft` | Automatically create draft replies to detected slop. | `true` |
| `yolo_mode` | Automatically SEND replies (Dangerous - bypasses draft review). | `false` |
| `treat_job_offers_as_slop` | Treat recruiter outreach as slop (triggers Expert-Domain Trap). | `true` |
| `treat_unsolicited_investors_as_slop` | Treat unsolicited investor outreach as slop (triggers Due Diligence Loop). | `true` |
| `sauver_label` | The Gmail label applied when an email is archived. | `Sauver` |

### Running Config via Gemini CLI

You can interact with your config directly using the following tools:

- **Get current config:** `get_sauver_config`
- **Update a setting:** `set_sauver_config(updates={"yolo_mode": true})`
- **Run interactive wizard:** `start_sauver_config_wizard` (Provides command to run in terminal)

## Skills Registry

| Skill | Role | Counter-Measure |
| :--- | :--- | :--- |
| **`sauver-inbox-assistant`** | Triage Orchestrator | End-to-end pipeline management. |
| **`tracker-shield`** | Surveillance Purifier | Neutralizes tracking pixels and spy-links. |
| **`slop-detector`** | Intent Classifier | Deploys the **Expert-Domain Trap** for recruiters. |
| **`investor-trap`** | VC-Slop Shield | Deploys the **Due Diligence Loop** for "investors." |
| **`bouncer-reply`** | Time-Waster | Generates context-aware, confusing drafts for spammers. |

## Usage Tips 💡

- **Interactive Configuration:** You can run the color-coded configuration wizard anytime to change your preferences by running `uv run src/main.py configure` in your terminal.
- **Triage your inbox:** "Use the sauver-inbox-assistant to triage my last 10 unread emails."
- **Disable Job Slop Filter:** If you are actively job searching, you can tell Sauver: "Update my config to not treat job offers as slop."
- **Manual Verification:** Even with automation, Sauver always creates **drafts** by default (unless YOLO mode is on), allowing you to review its traps before they are sprung.

---

## Using Sauver with Claude Code

Sauver's skills are also available as slash commands in [Claude Code](https://claude.ai/code). Claude Code must be open inside this repository for the commands and MCP server to load automatically.

### Prerequisites

1. **Gmail MCP server** — Sauver uses the `mcp__claude_ai_Gmail__*` tools. Follow the [Gmail MCP setup guide](https://github.com/anthropics/claude-code/tree/main/mcp) to connect your Google account.
2. **Clone this repo** — the sauver MCP server (`.claude/settings.json`) is registered at the project level, so Claude Code must be opened from within the repository directory.

### Available Slash Commands

| Command | What it does |
| :--- | :--- |
| `/sauver` | Full inbox triage — scans unread emails, strips trackers, classifies intent, and drafts a counter-measure for each slop email |
| `/tracker-shield` | Strips tracking pixels and spy-links from a specific email |
| `/slop-detector` | Analyzes an email for recruiter/sales slop and drafts an Expert-Domain Trap reply |
| `/investor-trap` | Analyzes an email for investor slop and drafts a Due Diligence Loop reply |
| `/bouncer-reply` | Drafts a Time-Sink Trap reply for a general spam or marketing email |

### Example Usage

```
# Triage everything unread
/sauver

# Target a specific email (paste the subject or message ID after the command)
/slop-detector "We'd love to connect about an exciting opportunity"
/tracker-shield
/bouncer-reply
```

### Limitations vs. Gemini

The Gmail MCP server available in Claude Code does not currently expose `gmail_modify` or `gmail_send`, so:

- **Archiving** (applying the `Sauver` label and removing from INBOX) must be done manually after review.
- **YOLO mode** (auto-send) has no effect — all replies are saved as drafts regardless of the `yolo_mode` setting.

---
*Built with Gemini CLI, Claude Code & FastMCP.*

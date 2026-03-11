# Sauver: The Digital Bouncer for your Inbox 🛡️

Sauver is a cyber-defense layer for your Gmail, designed to neutralize tracking pixels, identify automated "job slop," and engage spammers in time-wasting loops. It operates as a set of specialized skills within the Gemini CLI.

## Key Capabilities

- **Purification:** Identifies and strips 1x1 tracking pixels and surveillance beacons from HTML emails.
- **Slop Detection:** Classifies email intent to separate legitimate human outreach from automated, low-effort "slop."
- **Expert-Domain Traps:** For recruiter or sales outreach, Sauver generates hyper-specific, technically challenging questions to put the cognitive load back on the sender.
- **Bouncer Replies:** Enthusiastically engages generic spammers with absurd, bureaucratic requests to waste their time.

## Installation

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
*Built with Gemini CLI & FastMCP.*

# Sauver (sauver.org)
> Rescue your inbox. Reclaim your focus.

**Sauver** is an open-source movement to rescue the human inbox from the noise of automated "slop" and the intrusion of corporate surveillance. By running a local, autonomous agent via the Gemini CLI, Claude Code, or Cursor, Sauver acts as a private digital bouncer—silently stripping tracking pixels, filtering AI-generated outreach, and trapping persistent spammers in endless, hallucinated conversations. We believe your attention is your most valuable asset, and it deserves a high-performance, local-first shield that answers to no one but you.

## 🛡️ The Mission
Sauver is the "Bouncer" for your digital life. It runs locally on your machine, ensuring your private data never hits a third-party cloud.
- **Track-Free:** Automatically strips 1x1 spy pixels (HubSpot, Mailtrack, etc.).
- **Slop-Filter:** Detects and flags low-effort, AI-generated cold outreach.
- **The Redirect:** (Optional) Deploys an AI persona to engage spammers in a "Time-Sink" conversation, wasting their resources so they leave you alone.

## 🏗️ Technical Stack
Sauver is built as an **MCP Server** (Model Context Protocol) and is designed to run seamlessly across major AI agents (Claude, Cursor, Gemini CLI).

- **Core Framework:** Python 3.10+ (using `uv` and `fastmcp`)
- **Integrations:** Gmail API (via local OAuth2)

## 🚀 Quick Start

### 1. Initial Setup
Clone the repository and install the dependencies locally:
```bash
git clone https://github.com/mszczodrak/sauver.git
cd sauver

# Install Python dependencies
make setup
```

### 2. Configure Your Agent

Sauver follows a standardized skill format, allowing it to work across multiple platforms. Choose your preferred agent below:

#### **Claude (Claude Code)**
Claude uses a plugin system to integrate these skills.
```bash
# Add the Sauver plugin via its path
/plugin install .
```

#### **Gemini CLI**
Gemini CLI uses an "extension" format to load skills and registers the MCP server.
```bash
# Run the automated setup script to configure settings.json without needing an API Key
./scripts/setup.sh

# Launch the CLI to authenticate (No API Key needed)
gemini
```
*(When prompted in your terminal, select "Login with Google")*

#### **Cursor**
Cursor integrates these skills via its plugin flow using the provided manifest files.
1. Open Cursor and navigate to the **Settings > Features > MCP**.
2. Click **+ Add new MCP server**.
3. Name it `sauver`, choose type `command`, and enter:
   ```bash
   uv run /absolute/path/to/sauver/src/main.py
   ```
*(Alternatively, you can load the local directory as a Plugin using the `.cursor-plugin/plugin.json` and `.mcp.json` files).*

## 🛠️ Current Skills
Once installed, your agent has access to the following capabilities:
- `tracker_shield`: Scans and cleans incoming HTML by stripping 1x1 tracking pixels.
- `bouncer_reply`: Generates a "Time-Sink" draft to engage detected spammers in endless loops.
- `slop_detector`: *(Planned)* Classifies email intent and identifies automated templates.

**Example Prompts:**
- *"Check my inbox for trackers and neutralize them using the Sauver skill."*
- *"Use the bouncer_reply tool to draft a confusing response to the last cold email I received."*

## 🧑‍💻 Development
This project uses `uv` for dependency management and `ruff`/`mypy` for code quality.
```bash
make setup   # Install dependencies
make format  # Auto-format code
make lint    # Run linters and type checkers
make test    # Run test suite
make all     # Run format, lint, and test sequentially
```

## ⚖️ License
MIT. Go wild.
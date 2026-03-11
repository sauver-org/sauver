# Sauver (sauver.org)
> Rescue your inbox. Reclaim your focus.

**Sauver** is an open-source movement to rescue the human inbox from the noise of automated "slop" and the intrusion of corporate surveillance. By running a local, autonomous agent via the Gemini CLI, Sauver acts as a private digital bouncer—silently stripping tracking pixels, filtering AI-generated outreach, and trapping persistent spammers in endless, hallucinated conversations. We believe your attention is your most valuable asset, and it deserves a high-performance, local-first shield that answers to no one but you.

## 🛡️ The Mission
Sauver is the "Bouncer" for your digital life. It runs locally on your machine, ensuring your private data never hits a third-party cloud.
- **Track-Free:** Automatically strips 1x1 spy pixels (HubSpot, Mailtrack, etc.).
- **Slop-Filter:** Detects and flags low-effort, AI-generated cold outreach.
- **The Redirect:** (Optional) Deploys an AI persona to engage spammers in a "Time-Sink" conversation, wasting their resources so they leave you alone.

## 🏗️ Technical Stack
Sauver is built as an **MCP Server** (Model Context Protocol) designed to run inside the **Gemini CLI**.

- **Core Engine:** [Gemini CLI](https://github.com/google/gemini-cli)
- **Language:** Python 3.10+ (using `uv` and `fastmcp`)
- **Integrations:** Gmail API (via local OAuth2)

## 🚀 Quick Start

1. **Clone & Setup Sauver:**
   The automated setup script installs dependencies and registers the `sauver` MCP server globally to the Gemini CLI, **bypassing all API Key requirements**.

   ```bash
   git clone https://github.com/mszczodrak/sauver.git
   cd sauver
   
   # Run the unified installation script
   ./scripts/setup.sh
   ```

2. **Authenticate the Gemini CLI:**
   You do **not** need an API key. You just need to trigger the initial OAuth login.
   ```bash
   # 1. Install the Gemini CLI if you haven't already
   npm install -g @google/gemini-cli
   
   # 2. Launch the CLI in interactive mode
   gemini
   
   # 3. When prompted, choose "Login with Google" and complete the flow.
   ```
   
   🎉 **You're done! Sauver is successfully running and protecting your inbox.**

## 🛠️ Current Skills
- `tracker_shield`: Scans and cleans incoming HTML by stripping 1x1 tracking pixels.
- `bouncer_reply`: Generates a "Time-Sink" draft to engage detected spammers in endless loops.
- `slop_detector`: *(Planned)* Classifies email intent and identifies automated templates.

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

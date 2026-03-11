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
- **Language:** Python 3.10+
- **Integrations:** Gmail API (via local OAuth2)

## 🚀 Quick Start
1. **Install Gemini CLI:**
   ```bash
   npm install -g @google/gemini-cli
   ```

2. **Clone Sauver:**

```bash
   git clone [https://github.com/your-username/sauver.git](https://github.com/your-username/sauver.git)
   cd sauver
   pip install -r requirements.txt
   ```

3. **Register Extension**

```bash
gemini extensions install .
```

## 🛠️ Current Skills
- tracker_shield: Scans and cleans incoming HTML.
- slop_detector: Classifies email intent and identifies automated templates.
- bouncer_reply: Generates a "Time-Sink" draft to engage detected spammers.

## ⚖️ License
MIT. Go wild.

### 2. `mcp.json` (The Wiring)
Create this file in your root directory. It tells the Gemini CLI how to launch your Sauver skills.

```json
{
  "mcpServers": {
    "sauver": {
      "command": "python",
      "args": ["src/main.py"],
      "env": {
        "GMAIL_CREDENTIALS_PATH": "./credentials.json"
      }
    }
  }
}
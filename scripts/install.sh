#!/usr/bin/env bash
# Sauver Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/mszczodrak/sauver/main/scripts/install.sh | bash
set -e

REPO="mszczodrak/sauver"
INSTALL_DIR="$HOME/.sauver/mcp-server"
CONFIG_FILE="$HOME/.sauver/config.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

BOLD=$(printf '\033[1m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
BLUE=$(printf '\033[0;34m')
RED=$(printf '\033[0;31m')
NC=$(printf '\033[0m')

# Terminal Hyperlinks (OSC 8)
link() {
  local url=$1
  local text=$2
  if [ -z "$text" ]; then text=$url; fi

  # Detect modern terminals that support OSC 8
  if [[ "$TERM_PROGRAM" == "iTerm.app" || "$TERM_PROGRAM" == "vscode" || -n "$VSCODE_PID" || -n "$ITERM_SESSION_ID" ]]; then
    printf "${BLUE}\033]8;;%s\a%s\033]8;;\a${NC}" "$url" "$text"
  else
    # For Terminal.app and others: 
    # We MUST have a space before the URL and NO color codes immediately touching it,
    # otherwise Terminal.app's regex-based detection fails.
    printf " %s" "$url"
  fi
}

echo ""
echo -e "${BOLD}🛡️  Sauver Installer${NC}"
echo "   The digital bouncer for your inbox."
echo "   This will take about 3 minutes."
echo ""

# ── Prerequisites ───────────────────────────────────────────────────────────

if ! command -v node &>/dev/null; then
  echo -e "${RED}❌ Node.js not found.${NC}"
  echo ""
  echo "  Sauver runs alongside Claude Code and Gemini CLI, both of which require Node.js."
  echo "  If either is already installed, try opening a new terminal."
  echo "  Otherwise, install your AI assistant first:"
  echo -e "    Claude Code: $(link 'https://claude.ai/code')"
  echo -e "    Gemini CLI:  $(link 'https://github.com/google-gemini/gemini-cli')"
  echo ""
  exit 1
fi

NODE_MAJOR=$(node -e "console.log(process.versions.node.split('.')[0])")
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo -e "${RED}❌ Node.js v18+ required (you have v$(node --version)). Upgrade at: $(link 'https://nodejs.org')${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Node.js $(node --version)${NC}"

if ! command -v claude &>/dev/null && ! command -v gemini &>/dev/null; then
  echo -e "${YELLOW}⚠️  Neither 'claude' nor 'gemini' found in PATH.${NC}"
  echo "  Sauver requires one of these to work:"
  echo -e "    Claude Code: $(link 'https://claude.ai/code')"
  echo -e "    Gemini CLI:  $(link 'https://github.com/google-gemini/gemini-cli')"
  echo "  Continuing install anyway..."
  echo ""
fi

# ── Generate secret key ─────────────────────────────────────────────────────

SECRET_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

# ── Step 1: Apps Script Backend ───────────────────────────────────────────────

if [ -n "${SAUVER_APPS_SCRIPT_URL:-}" ]; then
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  Step 1 of 2 — Apps Script (Skipped)${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  Using SAUVER_APPS_SCRIPT_URL from environment:"
  echo "  $SAUVER_APPS_SCRIPT_URL"
  APPS_SCRIPT_URL="$SAUVER_APPS_SCRIPT_URL"
else
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  Step 1 of 2 — Create the Gmail backend (2 min)${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  We will now securely and automatically deploy your Gmail backend."
  echo ""
  echo "  a) First, you must enable the Google Apps Script API:"
  printf "     Open %s\n" "$(link 'https://script.google.com/home/usersettings')"
  echo "     and toggle 'Google Apps Script API' to ON."
  echo ""
  read -rp "  ↵  Press Enter when you have done this..." < /dev/tty
  echo ""
  echo "  b) Logging into Google via clasp (a browser window will open)..."
  npx --yes @google/clasp login

  echo ""
  echo "  c) Generating and deploying the project..."
  
  CLASP_WORK_DIR=$(mktemp -d)
  (
    cd "$CLASP_WORK_DIR" || exit 1
    
    # Create the project
    npx --yes @google/clasp create --type standalone --title "Sauver Backend" >/dev/null

    # Download source
    curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/apps-script/Code.gs" -o Code.gs
    
    # Inject user's unique secret key
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/const SECRET_KEY = \"CHANGE_ME\";/const SECRET_KEY = \"${SECRET_KEY}\";/" Code.gs
    else
      sed -i "s/const SECRET_KEY = \"CHANGE_ME\";/const SECRET_KEY = \"${SECRET_KEY}\";/" Code.gs
    fi

    # Create appsscript.json required for 'Anyone' access webapp
    cat > appsscript.json <<EOF
{
  "timeZone": "America/New_York",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "webapp": {
    "executeAs": "USER_DEPLOYING",
    "access": "ANYONE"
  }
}
EOF

    # Push and deploy
    npx --yes @google/clasp push -f >/dev/null
    DEPLOY_OUTPUT=$(npx --yes @google/clasp deploy --description "Auto-deployed by Sauver")
    
    # Extract deployment ID — clasp outputs either "- <id> @1" or "Deployed <id> @1"
    # The deployment ID is always a long alphanumeric string (40+ chars)
    DEPLOYMENT_ID=$(echo "$DEPLOY_OUTPUT" | grep -oE '[A-Za-z0-9_-]{40,}')
    
    if [ -z "$DEPLOYMENT_ID" ]; then
      echo -e "${RED}❌ Failed to extract Deployment ID from clasp output.${NC}"
      echo "Output was: $DEPLOY_OUTPUT"
      exit 1
    fi
    
    # Export it out of the subshell by writing to temp files
    echo "$DEPLOYMENT_ID" > "$CLASP_WORK_DIR/deployment_id"
    node -e "console.log(JSON.parse(require('fs').readFileSync('.clasp.json','utf8')).scriptId)" \
      > "$CLASP_WORK_DIR/script_id"
  )
  
  DEPLOYMENT_ID=$(cat "$CLASP_WORK_DIR/deployment_id")
  SCRIPT_ID=$(cat "$CLASP_WORK_DIR/script_id")
  APPS_SCRIPT_URL="https://script.google.com/macros/s/${DEPLOYMENT_ID}/exec"
  rm -rf "$CLASP_WORK_DIR"
  
  echo -e "  ✅ ${GREEN}Deployed successfully to:${NC}"
  echo -e "     $(link "$APPS_SCRIPT_URL")"
  echo ""
fi

# Validate
if [[ ! "$APPS_SCRIPT_URL" =~ ^https://script\.google\.com/macros/s/ ]]; then
  echo ""
  echo -e "${RED}❌ That doesn't look right. The URL should start with:${NC}"
  echo "   https://script.google.com/macros/s/"
  echo ""
  echo "Re-run the installer and try again."
  exit 1
fi

# ── Write config ────────────────────────────────────────────────────────────

mkdir -p "$(dirname "$CONFIG_FILE")"

# Build config — include script_id only when we have it (auto-deploy path)
if [ -n "${SCRIPT_ID:-}" ]; then
cat > "$CONFIG_FILE" <<EOF
{
  "apps_script_url": "${APPS_SCRIPT_URL}",
  "script_id": "${SCRIPT_ID}",
  "secret_key": "${SECRET_KEY}",
  "preferences": {
    "auto_draft": true,
    "yolo_mode": false,
    "treat_job_offers_as_slop": true,
    "treat_unsolicited_investors_as_slop": true,
    "sauver_label": "Sauver"
  }
}
EOF
else
cat > "$CONFIG_FILE" <<EOF
{
  "apps_script_url": "${APPS_SCRIPT_URL}",
  "secret_key": "${SECRET_KEY}",
  "preferences": {
    "auto_draft": true,
    "yolo_mode": false,
    "treat_job_offers_as_slop": true,
    "treat_unsolicited_investors_as_slop": true,
    "sauver_label": "Sauver"
  }
}
EOF
fi
chmod 600 "$CONFIG_FILE"

echo ""
echo -e "${GREEN}✅ Config saved to ${CONFIG_FILE}${NC}"

# ── Step 3: Install MCP server ──────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Step 2 of 2 — Installing the local bridge${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

mkdir -p "$INSTALL_DIR"

echo "  Downloading MCP server..."
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/mcp-server/index.js"    -o "$INSTALL_DIR/index.js"
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/mcp-server/package.json" -o "$INSTALL_DIR/package.json"

echo "  Installing dependencies..."
(cd "$INSTALL_DIR" && npm install --silent --no-fund --no-audit 2>/dev/null)

echo -e "${GREEN}✅ MCP server installed${NC}"

# ── Install skills ────────────────────────────────────────────────────────────

echo "  Downloading skills..."
node --input-type=module << 'NODEEOF'
import { mkdirSync, writeFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const REPO = "mszczodrak/sauver";
const SKILLS_DIR = join(homedir(), ".sauver", "skills");
const CLAUDE_COMMANDS = join(homedir(), ".claude", "commands");
const GEMINI_WORKFLOWS = join(homedir(), ".agent", "workflows");

const SKILL_MAP = [
  ["sauver-inbox-assistant", "sauver"],
  ["slop-detector",          "slop-detector"],
  ["investor-trap",          "investor-trap"],
  ["bouncer-reply",          "bouncer-reply"],
  ["tracker-shield",         "tracker-shield"],
  ["archiver",               "archiver"],
];

mkdirSync(SKILLS_DIR, { recursive: true });
mkdirSync(CLAUDE_COMMANDS, { recursive: true });
mkdirSync(GEMINI_WORKFLOWS, { recursive: true });

const base = `https://raw.githubusercontent.com/${REPO}/main`;

async function fetchText(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${url}`);
  return res.text();
}

const protocol = await fetchText(`${base}/skills/PROTOCOL.md`);
writeFileSync(join(SKILLS_DIR, "PROTOCOL.md"), protocol);

for (const [skillName, commandName] of SKILL_MAP) {
  const skillDir = join(SKILLS_DIR, skillName);
  mkdirSync(skillDir, { recursive: true });
  const content = await fetchText(`${base}/skills/${skillName}/SKILL.md`);
  writeFileSync(join(skillDir, "SKILL.md"), content);

  // Extract description from SKILL.md frontmatter for Gemini workflows
  const descMatch = content.match(/^description:\s*"?([^"\n]+)"?/m);
  const description = descMatch ? descMatch[1].trim() : `Sauver ${commandName} skill`;

  const body = [
    `Use your Read tool to load \`${join(skillDir, "SKILL.md")}\` and \`${join(SKILLS_DIR, "PROTOCOL.md")}\`, then follow the instructions in those files exactly.`,
    ``,
    `All Gmail tools are available via the Sauver MCP server. Call them as \`mcp__sauver__<tool_name>\` (e.g. \`mcp__sauver__get_preferences\`, \`mcp__sauver__scan_inbox\`, \`mcp__sauver__get_message\`). Do not substitute with any other tools.`,
    ``,
  ].join("\n");

  // Claude: plain markdown (no frontmatter needed)
  writeFileSync(join(CLAUDE_COMMANDS, `${commandName}.md`), body);

  // Gemini: requires YAML frontmatter with description for slash command discovery
  const geminiShim = `---\ndescription: ${description}\n---\n\n${body}`;
  writeFileSync(join(GEMINI_WORKFLOWS, `${commandName}.md`), geminiShim);
}
NODEEOF

echo -e "${GREEN}✅ Skills installed${NC}"

# ── Register with Claude Code & Gemini CLI ──────────────────────────────────

node -e "
  const fs = require('fs');
  const path = '$CLAUDE_SETTINGS';
  let s = {};
  try { s = JSON.parse(fs.readFileSync(path, 'utf8')); } catch {}
  s.mcpServers = s.mcpServers || {};
  s.mcpServers.sauver = { command: 'node', args: ['$INSTALL_DIR/index.js'] };
  fs.mkdirSync(require('path').dirname(path), { recursive: true });
  fs.writeFileSync(path, JSON.stringify(s, null, 2));
"

echo -e "${GREEN}✅ Claude Code configured${NC}"

GEMINI_SETTINGS="$HOME/.gemini/settings.json"
node -e "
  const fs = require('fs');
  const path = '$GEMINI_SETTINGS';
  let s = {};
  try { s = JSON.parse(fs.readFileSync(path, 'utf8')); } catch {}
  s.mcpServers = s.mcpServers || {};
  s.mcpServers.sauver = { command: 'node', args: ['$INSTALL_DIR/index.js'] };
  fs.mkdirSync(require('path').dirname(path), { recursive: true });
  fs.writeFileSync(path, JSON.stringify(s, null, 2));
"

echo -e "${GREEN}✅ Gemini CLI configured${NC}"

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}🎉 Sauver is ready!${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  → Restart ${BOLD}Gemini${NC} or ${BOLD}Claude${NC} CLI and run: ${BOLD}/sauver${NC}"
echo ""
echo "  Config file: ${CONFIG_FILE}"
echo "  To change behavior (auto-draft, yolo mode, label name),"
echo -e "  edit ${BOLD}~/.sauver/config.json${NC} or ask Claude/Gemini to change a setting."
echo ""

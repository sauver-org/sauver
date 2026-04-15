#!/usr/bin/env bash
# Sauver Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/sauver-org/sauver/main/scripts/install.sh | bash
set -e

REPO="sauver-org/sauver"
INSTALL_DIR="$HOME/.sauver/mcp-server"
CONFIG_FILE="$HOME/.sauver/config.json"

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
  echo -e "${YELLOW}⚠️  Claude Code or Gemini CLI not found in PATH.${NC}"
  echo "  Sauver works best when integrated with these AI assistants."
  echo "  Install your assistant first:"
  echo -e "    Claude Code: $(link 'https://claude.ai/code')"
  echo -e "    Gemini CLI:  $(link 'https://github.com/google-gemini/gemini-cli')"
  echo ""
  # We proceed because some users might want the MCP server for other tools
fi

# ── Step 1: Create the Apps Script backend ──────────────────────────────────

SECRET_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

if [ -f "$CONFIG_FILE" ]; then
  echo -e "${GREEN}✅ Existing install detected — upgrading MCP server and skills${NC}"
  APPS_SCRIPT_URL=$(node -e "try{const c=require('$CONFIG_FILE');if(c.apps_script_url)console.log(c.apps_script_url)}catch(e){}" 2>/dev/null || true)
  EXISTING_KEY=$(node -e "try{const c=require('$CONFIG_FILE');if(c.secret_key)console.log(c.secret_key)}catch(e){}" 2>/dev/null || true)
  if [ -n "$EXISTING_KEY" ]; then SECRET_KEY="$EXISTING_KEY"; fi
  echo "   (Apps Script backend and config preserved)"
else
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if [ -n "$1" ]; then
    # Provided a URL directly (for dev or manual recovery)
    APPS_SCRIPT_URL="$1"
    echo -e "${BOLD}  Step 1 of 2 — Apps Script (Skipped)${NC}"
  else
    echo -e "${BOLD}  Step 1 of 2 — Create the Gmail backend (2 min)${NC}"
  fi
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  if [ -z "$APPS_SCRIPT_URL" ]; then
    echo "  Sauver needs a tiny 'bridge' in your Google account to talk to Gmail."
    echo "  We'll use 'clasp' to deploy it automatically."
    echo ""
    echo "  a) Checking Google Apps Script API status..."
    printf "     Open %s\n" "$(link 'https://script.google.com/home/usersettings')"
    echo "     Ensure 'Google Apps Script API' is set to 'ON' at the bottom."
    echo ""

    # Try to open the URL automatically (best-effort)
    if [ -z "${CI:-}" ] && [ -t 0 ]; then
      if command -v open &>/dev/null; then
        open "https://script.google.com/home/usersettings" 2>/dev/null || true
      elif command -v xdg-open &>/dev/null; then
        xdg-open "https://script.google.com/home/usersettings" 2>/dev/null || true
      fi
    fi

    if [ -z "${CI:-}" ] && [ -t 0 ] && { true < /dev/tty; } 2>/dev/null; then
      read -rp "  ↵  Press Enter once it is 'ON'..." < /dev/tty
    else
      echo "  Non-interactive environment — assuming API is 'ON'."
    fi
    echo ""

    echo "  b) Logging into Google via clasp (a browser window will open)..."
    npx --yes @google/clasp login --logout 2>/dev/null || true
    npx --yes @google/clasp login

    echo "  c) Generating and deploying the project... (may take a minute)"
    CLASP_WORK_DIR=$(mktemp -d)
    (
      cd "$CLASP_WORK_DIR"
      npx --yes @google/clasp create --title "Sauver Backend" --type webapp >/dev/null

      # Detect if it's a personal or workspace account to label the backend correctly
      USER_NAME=$(id -F 2>/dev/null | cut -d' ' -f1)
      if [ -z "$USER_NAME" ]; then USER_NAME=$(whoami); fi
      BACKEND_NAME="Sauver ($USER_NAME)"
      if [[ -z "$USER_NAME" || "$USER_NAME" =~ ^(root|admin|guest|user|node|docker)$ ]]; then
        BACKEND_NAME="Sauver Backend"
      fi

      # Download source (prefer local if available during development)
      curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/apps-script/Code.gs" -o Code.gs
      
      # Configure appsscript.json
      cat > appsscript.json <<EOF
{
  "timeZone": "America/New_York",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "webapp": {
    "executeAs": "USER_DEPLOYING",
    "access": "ANYONE_ANONYMOUS"
  }
}
EOF

      # Push and deploy
      npx --yes @google/clasp push -f >/dev/null
      DEPLOY_OUTPUT=$(npx --yes @google/clasp deploy --description "Auto-deployed by Sauver")
      
      # Extract deployment ID
      DEPLOYMENT_ID=$(echo "$DEPLOY_OUTPUT" | grep -oE '[A-Za-z0-9_-]{40,}')
      
      if [ -z "$DEPLOYMENT_ID" ]; then
        echo -e "${RED}❌ Failed to extract Deployment ID from clasp output.${NC}"
        echo "Output was: $DEPLOY_OUTPUT"
        exit 1
      fi
      
      # Export it out of the subshell by writing to temp files
      echo "$DEPLOYMENT_ID" > deployment_id
      node -e "console.log(JSON.parse(require('fs').readFileSync('.clasp.json','utf8')).scriptId)" > script_id
    )
    
    DEPLOYMENT_ID=$(cat "$CLASP_WORK_DIR/deployment_id")
    SCRIPT_ID=$(cat "$CLASP_WORK_DIR/script_id")
    APPS_SCRIPT_URL="https://script.google.com/macros/s/${DEPLOYMENT_ID}/exec"
    
    echo -e "${GREEN}✅ Backend deployed!${NC}"
    echo "     URL: $APPS_SCRIPT_URL"
    echo ""

    mkdir -p "$(dirname "$CONFIG_FILE")"

    # Build config
    if [ -n "$SCRIPT_ID" ]; then
      cat > "$CONFIG_FILE" <<EOF
{
  "apps_script_url": "${APPS_SCRIPT_URL}",
  "script_id": "${SCRIPT_ID}",
  "secret_key": "${SECRET_KEY}",
  "backend_name": "${BACKEND_NAME}",
  "preferences": {
    "auto_draft": true,
    "yolo_mode": false,
    "treat_job_offers_as_slop": true,
    "treat_unsolicited_investors_as_slop": true,
    "slop_label": "Sauver/Slop",
    "engage_bots": false,
    "bot_reply_threshold_seconds": 120
  }
}
EOF
    else
    cat > "$CONFIG_FILE" <<EOF
{
  "apps_script_url": "${APPS_SCRIPT_URL}",
  "secret_key": "${SECRET_KEY}",
  "backend_name": "${BACKEND_NAME:-Sauver Backend}",
  "preferences": {
    "auto_draft": true,
    "yolo_mode": false,
    "treat_job_offers_as_slop": true,
    "treat_unsolicited_investors_as_slop": true,
    "slop_label": "Sauver/Slop",
    "engage_bots": false,
    "bot_reply_threshold_seconds": 120
  }
}
EOF
    fi

    chmod 600 "$CONFIG_FILE"
    echo ""
    echo -e "${GREEN}✅ Config saved to ${CONFIG_FILE}${NC}"
  fi
fi

# ── Verify backend (trigger OAuth consent if needed) ────────────────────────

echo ""
echo "  Verifying Gmail backend..."

check_backend() {
  curl -s --max-time 15 -X POST "$APPS_SCRIPT_URL" \
    -H "Content-Type: application/json" \
    -d "{\"action\":\"get_profile\",\"key\":\"${SECRET_KEY}\"}"
}

RESPONSE=$(check_backend)

if echo "$RESPONSE" | grep -q '"email"'; then
  echo -e "${GREEN}✅ Backend connected — Gmail access confirmed${NC}"
else
  echo ""
  echo -e "  ${YELLOW}⚠️  One more step required: authorize Gmail access in your browser.${NC}"
  echo ""
  echo "  Google Apps Script needs your permission to access Gmail before it can"
  echo "  accept requests from the local MCP server. This is a one-time step."
  echo ""
  echo "  1. Open this URL in your browser:"
  printf "     %s\n" "$(link "$APPS_SCRIPT_URL")"
  # Try to open the URL automatically
  if [ -z "${CI:-}" ] && [ -t 0 ]; then
    if command -v open &>/dev/null; then
      open "$APPS_SCRIPT_URL" 2>/dev/null || true
    elif command -v xdg-open &>/dev/null; then
      xdg-open "$APPS_SCRIPT_URL" 2>/dev/null || true
    fi
  fi
  echo ""
  echo "  2. If prompted, sign in with the Google account you want Sauver to manage."
  echo "  3. Click 'Review Permissions' → 'Allow' to grant Gmail access."
  echo "  4. Once the page loads (even if it shows an error), return here."
  echo ""
  if [ -z "${CI:-}" ] && [ -t 0 ] && { true < /dev/tty; } 2>/dev/null; then
    read -rp "  ↵  Press Enter once you have authorized in the browser..." < /dev/tty
    echo ""

    RESPONSE=$(check_backend)
    if echo "$RESPONSE" | grep -q '"email"'; then
      echo -e "${GREEN}✅ Backend authorized — Gmail access confirmed${NC}"
    else
      echo -e "${YELLOW}⚠️  Could not confirm backend connectivity. Proceeding anyway.${NC}"
      echo "   If Sauver fails later, re-open the URL above in your browser and allow access."
    fi
  else
    echo -e "${YELLOW}⚠️  Non-interactive environment — skipping OAuth prompt. Run install again interactively to authorize Gmail access.${NC}"
  fi
fi

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
import { mkdirSync, writeFileSync, existsSync, readFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const REPO = "sauver-org/sauver";
const SKILLS_DIR = join(homedir(), ".sauver", "skills");
const CLAUDE_COMMANDS = join(homedir(), ".claude", "commands");
const GEMINI_WORKFLOWS = join(homedir(), ".gemini", "skills");

const SKILL_MAP = [
  ["sauver-inbox-assistant", "sauver"],
  ["sauver-report",          "sauver-report"],
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
const localBase = process.cwd();

async function fetchText(url, localPath) {
  if (localPath && existsSync(localPath)) {
    return readFileSync(localPath, 'utf8');
  }
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${url}`);
  return res.text();
}

const protocol = await fetchText(`${base}/skills/PROTOCOL.md`, join(localBase, 'skills/PROTOCOL.md'));
writeFileSync(join(SKILLS_DIR, "PROTOCOL.md"), protocol);

// Download binary assets
const ASSETS_DIR = join(SKILLS_DIR, "assets");
mkdirSync(ASSETS_DIR, { recursive: true });
const ndaLocalPath = join(localBase, 'skills/assets/NDA.pdf');
if (existsSync(ndaLocalPath)) {
  writeFileSync(join(ASSETS_DIR, "NDA.pdf"), readFileSync(ndaLocalPath));
} else {
  const ndaRes = await fetch(`${base}/skills/assets/NDA.pdf`);
  if (!ndaRes.ok) throw new Error(`HTTP ${ndaRes.status} fetching NDA.pdf`);
  writeFileSync(join(ASSETS_DIR, "NDA.pdf"), Buffer.from(await ndaRes.arrayBuffer()));
}

for (const [skillName, commandName] of SKILL_MAP) {
  const skillDir = join(SKILLS_DIR, skillName);
  mkdirSync(skillDir, { recursive: true });
  const content = await fetchText(`${base}/skills/${skillName}/SKILL.md`, join(localBase, `skills/${skillName}/SKILL.md`));
  writeFileSync(join(skillDir, "SKILL.md"), content);

  // Extract description from SKILL.md frontmatter for Gemini skills
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

  // Gemini: skill must be a directory containing SKILL.md with name + description frontmatter
  const geminiSkillDir = join(GEMINI_WORKFLOWS, commandName);
  mkdirSync(geminiSkillDir, { recursive: true });
  const geminiShim = "---\nname: " + commandName + "\ndescription: " + description + "\n---\n\n" + body;
  writeFileSync(join(geminiSkillDir, "SKILL.md"), geminiShim);
}
NODEEOF

echo -e "${GREEN}✅ Skills installed${NC}"

# ── Register with Claude Code & Gemini CLI ──────────────────────────────────

if command -v claude &>/dev/null; then
  claude mcp add --scope user sauver node "$INSTALL_DIR/index.js" 2>/dev/null || true
fi

# Auto-approve all sauver MCP tools so Claude never prompts for permission
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
node -e "
  const fs = require('fs');
  const path = '$CLAUDE_SETTINGS';
  let s = {};
  try { s = JSON.parse(fs.readFileSync(path, 'utf8')); } catch {}
  s.permissions = s.permissions || {};
  s.permissions.allow = s.permissions.allow || [];
  if (!s.permissions.allow.includes('mcp__sauver__*')) {
    s.permissions.allow.push('mcp__sauver__*');
    fs.mkdirSync(require('path').dirname(path), { recursive: true });
    fs.writeFileSync(path, JSON.stringify(s, null, 2) + '\n');
  }
"

echo -e "${GREEN}✅ Claude Code configured${NC}"

GEMINI_SETTINGS="$HOME/.gemini/settings.json"
GEMINI_POLICY_DIR="$HOME/.gemini/policies"
GEMINI_POLICY_FILE="$GEMINI_POLICY_DIR/sauver.toml"

node -e "
  const fs = require('fs');
  const path = '$GEMINI_SETTINGS';
  let s = {};
  try { s = JSON.parse(fs.readFileSync(path, 'utf8')); } catch {}
  s.mcpServers = s.mcpServers || {};
  s.mcpServers.sauver = { command: 'node', args: ['$INSTALL_DIR/index.js'], trust: true };
  // Migration: Remove deprecated tools.allowed if present
  if (s.tools) delete s.tools;
  fs.mkdirSync(require('path').dirname(path), { recursive: true });
  fs.writeFileSync(path, JSON.stringify(s, null, 2));
"

# Create Gemini Policy Engine rule to allow Read tool and Sauver MCP tools
mkdir -p "$GEMINI_POLICY_DIR"
cat > "$GEMINI_POLICY_FILE" <<EOF
# Sauver Policy — Allow tools required for autonomous operation
[[rule]]
toolName = "read_file"
decision = "allow"
priority = 100

[[rule]]
mcpName = "sauver"
toolName = "*"
decision = "allow"
priority = 100
EOF

echo -e "${GREEN}✅ Gemini CLI configured (Policy Engine updated)${NC}"

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

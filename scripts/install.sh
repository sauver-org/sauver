#!/usr/bin/env bash
# Sauver Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/mszczodrak/sauver/main/scripts/install.sh | bash
set -e

REPO="mszczodrak/sauver"
INSTALL_DIR="$HOME/.sauver/mcp-server"
CONFIG_FILE="$HOME/.sauver/config.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

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
  echo "    Claude Code: https://claude.ai/code"
  echo "    Gemini CLI:  https://github.com/google-gemini/gemini-cli"
  echo ""
  exit 1
fi

NODE_MAJOR=$(node -e "console.log(process.versions.node.split('.')[0])")
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo -e "${RED}❌ Node.js v18+ required (you have v$(node --version)). Upgrade at: https://nodejs.org${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Node.js $(node --version)${NC}"

if ! command -v claude &>/dev/null && ! command -v gemini &>/dev/null; then
  echo -e "${YELLOW}⚠️  Neither 'claude' nor 'gemini' found in PATH.${NC}"
  echo "  Sauver requires one of these to work:"
  echo "    Claude Code: https://claude.ai/code"
  echo "    Gemini CLI:  https://github.com/google-gemini/gemini-cli"
  echo "  Continuing install anyway..."
  echo ""
fi

# ── Generate secret key ─────────────────────────────────────────────────────

SECRET_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

# ── Step 1: Apps Script code ────────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Step 1 of 3 — Create the Gmail backend (2 min)${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  a) Open a new Google Apps Script project:"
echo ""
echo -e "     ${BLUE}https://script.google.com/create${NC}"
echo ""
echo "  b) Delete all existing code in the editor."
echo ""
echo "  c) Paste the Sauver backend code from:"
echo ""
echo -e "     ${BLUE}https://raw.githubusercontent.com/${REPO}/main/apps-script/Code.gs${NC}"
echo ""
echo "  d) Find this line near the top:"
echo ""
echo -e "     ${YELLOW}const SECRET_KEY = \"CHANGE_ME\";${NC}"
echo ""
echo "     Replace it with your generated key:"
echo ""
echo -e "     ${GREEN}const SECRET_KEY = \"${SECRET_KEY}\";${NC}"
echo ""
echo "  e) Save the file (Ctrl+S / Cmd+S or click the 💾 icon)."
echo ""
if [ -z "${SAUVER_APPS_SCRIPT_URL:-}" ]; then
  read -rp "  ↵  Press Enter when done with Step 1..." < /dev/tty
fi

# ── Step 2: Deploy as Web App ───────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Step 2 of 3 — Deploy as a Web App (1 min)${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  In the Apps Script editor:"
echo ""
echo "  a) Click ${BOLD}Deploy${NC} → ${BOLD}New Deployment${NC}"
echo "  b) Click the gear icon ⚙️  next to 'Type' → select ${BOLD}Web app${NC}"
echo "  c) Description: anything (e.g. 'Sauver')"
echo "  d) Execute as:   ${BOLD}Me${NC}"
echo "  e) Who has access: ${BOLD}Anyone${NC}  ← (the secret key keeps it private)"
echo "  f) Click ${BOLD}Deploy${NC}"
echo "  g) Click ${BOLD}Authorize access${NC} → sign in with your Google account"
echo "  h) Copy the ${BOLD}Web App URL${NC}"
echo "     (it looks like: https://script.google.com/macros/s/ABC.../exec)"
echo ""
if [ -n "${SAUVER_APPS_SCRIPT_URL:-}" ]; then
  APPS_SCRIPT_URL="$SAUVER_APPS_SCRIPT_URL"
  echo "  Using SAUVER_APPS_SCRIPT_URL from environment."
else
  read -rp "  Paste your Web App URL: " APPS_SCRIPT_URL < /dev/tty
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
cat > "$CONFIG_FILE" <<EOF
{
  "apps_script_url": "${APPS_SCRIPT_URL}",
  "secret_key": "${SECRET_KEY}"
}
EOF
chmod 600 "$CONFIG_FILE"

echo ""
echo -e "${GREEN}✅ Config saved to ${CONFIG_FILE}${NC}"

# ── Step 3: Install MCP server ──────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Step 3 of 3 — Installing the local bridge${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

mkdir -p "$INSTALL_DIR"

echo "  Downloading MCP server..."
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/mcp-server/index.js"    -o "$INSTALL_DIR/index.js"
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/mcp-server/package.json" -o "$INSTALL_DIR/package.json"

echo "  Installing dependencies..."
(cd "$INSTALL_DIR" && npm install --silent --no-fund --no-audit 2>/dev/null)

echo -e "${GREEN}✅ MCP server installed${NC}"

# ── Register with Claude Code ───────────────────────────────────────────────

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

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}🎉 Sauver is ready!${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  → Restart ${BOLD}Claude Code${NC} and run: ${BOLD}/sauver${NC}"
echo ""
echo "  Config file: ${CONFIG_FILE}"
echo "  To change behavior (auto-draft, yolo mode, label name),"
echo "  open the Sauver repo and edit ${BOLD}GEMINI.md${NC}."
echo ""

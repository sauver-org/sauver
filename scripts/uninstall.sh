#!/usr/bin/env bash
# Sauver Uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/mszczodrak/sauver/main/scripts/uninstall.sh | bash
# Or run locally: bash scripts/uninstall.sh
set -e

BOLD=$(printf '\033[1m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
RED=$(printf '\033[0;31m')
NC=$(printf '\033[0m')

echo ""
echo -e "${BOLD}🗑️  Sauver Uninstaller${NC}"
echo "   This will remove all Sauver files and configuration."
echo ""
read -rp "   Are you sure you want to uninstall Sauver? [y/N] " confirm < /dev/tty
echo ""

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# ── 0. Read config before removal ───────────────────────────────────────────

SCRIPT_ID=""
CONFIG_FILE="$HOME/.sauver/config.json"
if [ -f "$CONFIG_FILE" ]; then
  SCRIPT_ID=$(node -e "
    try {
      const c = JSON.parse(require('fs').readFileSync('$CONFIG_FILE', 'utf8'));
      console.log(c.script_id || '');
    } catch { console.log(''); }
  " 2>/dev/null)
fi

# ── 1. Remove ~/.sauver (config, MCP server, skills) ────────────────────────

if [ -d "$HOME/.sauver" ]; then
  rm -rf "$HOME/.sauver"
  echo -e "${GREEN}✅ Removed ~/.sauver${NC}"
else
  echo -e "${YELLOW}⚠️  ~/.sauver not found — skipping${NC}"
fi

# ── 2. Remove Claude Code command shims ──────────────────────────────────────

COMMANDS=(sauver slop-detector investor-trap bouncer-reply tracker-shield archiver)
CLAUDE_COMMANDS="$HOME/.claude/commands"

removed_claude=0
for cmd in "${COMMANDS[@]}"; do
  f="$CLAUDE_COMMANDS/${cmd}.md"
  if [ -f "$f" ]; then
    rm "$f"
    removed_claude=$((removed_claude + 1))
  fi
done

if [ "$removed_claude" -gt 0 ]; then
  echo -e "${GREEN}✅ Removed $removed_claude Claude command shim(s) from ~/.claude/commands${NC}"
else
  echo -e "${YELLOW}⚠️  No Claude command shims found — skipping${NC}"
fi

# ── 3. Remove Gemini CLI workflow shims ──────────────────────────────────────

GEMINI_WORKFLOWS="$HOME/.agent/workflows"

removed_gemini=0
for cmd in "${COMMANDS[@]}"; do
  f="$GEMINI_WORKFLOWS/${cmd}.md"
  if [ -f "$f" ]; then
    rm "$f"
    removed_gemini=$((removed_gemini + 1))
  fi
done

if [ "$removed_gemini" -gt 0 ]; then
  echo -e "${GREEN}✅ Removed $removed_gemini Gemini workflow shim(s) from ~/.agent/workflows${NC}"
else
  echo -e "${YELLOW}⚠️  No Gemini workflow shims found — skipping${NC}"
fi

# ── 4 & 5. Remove mcpServers.sauver from Claude & Gemini settings ────────────

if command -v claude &>/dev/null; then
  if claude mcp remove --scope user sauver 2>/dev/null; then
    echo -e "${GREEN}✅ Removed Sauver MCP from Claude Code (user scope)${NC}"
  else
    echo -e "${YELLOW}⚠️  Sauver MCP not found in Claude Code config — skipping${NC}"
  fi
fi

GEMINI_SETTINGS="$HOME/.gemini/settings.json"
node -e "
  const fs = require('fs');

  function removeSauverMcp(filePath) {
    let s;
    try {
      s = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch {
      return 'not-found';
    }
    if (!s.mcpServers || !s.mcpServers.sauver) return 'not-configured';
    delete s.mcpServers.sauver;
    if (Object.keys(s.mcpServers).length === 0) delete s.mcpServers;
    fs.writeFileSync(filePath, JSON.stringify(s, null, 2) + '\n');
    return 'removed';
  }

  const geminiResult = removeSauverMcp('$GEMINI_SETTINGS');
  process.stdout.write(geminiResult + '\n');
" | read -r gemini_result

case "$gemini_result" in
  removed)       echo -e "${GREEN}✅ Removed Sauver MCP from ~/.gemini/settings.json${NC}" ;;
  not-configured) echo -e "${YELLOW}⚠️  Sauver MCP not found in ~/.gemini/settings.json — skipping${NC}" ;;
  not-found)     echo -e "${YELLOW}⚠️  ~/.gemini/settings.json not found — skipping${NC}" ;;
esac

# ── 6. Delete the Apps Script backend ───────────────────────────────────────

if [ -n "$SCRIPT_ID" ]; then
  delete_result=$(node -e "
    const https = require('https');
    const fs = require('fs');
    const os = require('os');

    let token;
    try {
      const rc = JSON.parse(fs.readFileSync(os.homedir() + '/.clasprc.json', 'utf8'));
      token = rc.token?.access_token;
    } catch { }

    if (!token) { process.stdout.write('no-token\n'); process.exit(0); }

    const req = https.request({
      hostname: 'script.googleapis.com',
      path: '/v1/projects/$SCRIPT_ID',
      method: 'DELETE',
      headers: { Authorization: 'Bearer ' + token }
    }, res => {
      process.stdout.write(res.statusCode === 200 || res.statusCode === 204 ? 'deleted' : 'api-error-' + res.statusCode);
      process.stdout.write('\n');
    });
    req.on('error', () => { process.stdout.write('network-error\n'); });
    req.end();
  " 2>/dev/null)

  case "$delete_result" in
    deleted)
      echo -e "${GREEN}✅ Removed Apps Script backend from Google${NC}"
      ;;
    no-token|api-error-*|network-error)
      echo -e "${YELLOW}⚠️  Could not auto-remove the Apps Script backend.${NC}"
      echo "   Delete it manually at:"
      echo "   https://script.google.com/home/projects/${SCRIPT_ID}"
      ;;
  esac
else
  echo -e "${YELLOW}⚠️  No Apps Script project ID on record — remove 'Sauver Backend' manually at:${NC}"
  echo "   https://script.google.com/home"
fi

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}✅ Sauver has been uninstalled.${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Restart Claude or Gemini CLI to complete the removal."
echo ""

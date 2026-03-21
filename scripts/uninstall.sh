#!/usr/bin/env bash
# Sauver Uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/sauver-org/sauver/main/scripts/uninstall.sh | bash
# Or run locally: bash scripts/uninstall.sh
set -e

BOLD=$(printf '\033[1m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
RED=$(printf '\033[0;31m')
NC=$(printf '\033[0m')

_open_url() {
  if command -v open &>/dev/null; then
    open "$1"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$1"
  fi
}

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

# Remove mcp__sauver__* permission entries from ~/.claude/settings.local.json
CLAUDE_LOCAL_SETTINGS="$HOME/.claude/settings.local.json"
if [ -f "$CLAUDE_LOCAL_SETTINGS" ]; then
  node -e "
    const fs = require('fs');
    const path = '$CLAUDE_LOCAL_SETTINGS';
    const s = JSON.parse(fs.readFileSync(path, 'utf8'));
    if (s.permissions?.allow) {
      const before = s.permissions.allow.length;
      s.permissions.allow = s.permissions.allow.filter(r => !r.startsWith('mcp__sauver__'));
      if (s.permissions.allow.length < before) {
        fs.writeFileSync(path, JSON.stringify(s, null, 2) + '\n');
        process.stdout.write('removed\n');
      } else {
        process.stdout.write('not-configured\n');
      }
    } else {
      process.stdout.write('not-configured\n');
    }
  " | read -r claude_local_result
  case "$claude_local_result" in
    removed) echo -e "${GREEN}✅ Removed Sauver permissions from ~/.claude/settings.local.json${NC}" ;;
  esac
fi

node -e "
  const fs = require('fs');

  function removeKey(filePath, ...keyPath) {
    let s;
    try {
      s = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch {
      return 'not-found';
    }
    let obj = s;
    for (let i = 0; i < keyPath.length - 1; i++) {
      if (!obj[keyPath[i]]) return 'not-configured';
      obj = obj[keyPath[i]];
    }
    const last = keyPath[keyPath.length - 1];
    if (!obj[last]) return 'not-configured';
    delete obj[last];
    fs.writeFileSync(filePath, JSON.stringify(s, null, 2) + '\n');
    return 'removed';
  }

  const base = require('os').homedir() + '/.gemini/';
  const r1 = removeKey(base + 'settings.json', 'mcpServers', 'sauver');
  const r2 = removeKey(base + 'mcp-server-enablement.json', 'sauver');
  process.stdout.write(r1 + ' ' + r2 + '\n');
" | read -r gemini_settings_result gemini_enablement_result

case "$gemini_settings_result" in
  removed)       echo -e "${GREEN}✅ Removed Sauver MCP from ~/.gemini/settings.json${NC}" ;;
  not-configured) echo -e "${YELLOW}⚠️  Sauver MCP not found in ~/.gemini/settings.json — skipping${NC}" ;;
  not-found)     echo -e "${YELLOW}⚠️  ~/.gemini/settings.json not found — skipping${NC}" ;;
esac

case "$gemini_enablement_result" in
  removed)       echo -e "${GREEN}✅ Removed Sauver entry from ~/.gemini/mcp-server-enablement.json${NC}" ;;
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
      _open_url "https://script.google.com/home/projects/${SCRIPT_ID}"
      ;;
  esac
else
  echo -e "${YELLOW}⚠️  No Apps Script project ID on record — remove 'Sauver Backend' manually at:${NC}"
  echo "   https://script.google.com/home"
  _open_url "https://script.google.com/home"
fi

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}✅ Sauver has been uninstalled.${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Restart Claude or Gemini CLI to complete the removal."
echo ""

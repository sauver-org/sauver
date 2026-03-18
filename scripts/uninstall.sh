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

  const claudeResult = removeSauverMcp(require('os').homedir() + '/.claude/settings.json');
  const geminiResult = removeSauverMcp(require('os').homedir() + '/.gemini/settings.json');

  // Print results as space-separated tokens for the shell to read
  process.stdout.write(claudeResult + ' ' + geminiResult + '\n');
" | read -r claude_result gemini_result

case "$claude_result" in
  removed)       echo -e "${GREEN}✅ Removed Sauver MCP from ~/.claude/settings.json${NC}" ;;
  not-configured) echo -e "${YELLOW}⚠️  Sauver MCP not found in ~/.claude/settings.json — skipping${NC}" ;;
  not-found)     echo -e "${YELLOW}⚠️  ~/.claude/settings.json not found — skipping${NC}" ;;
esac

case "$gemini_result" in
  removed)       echo -e "${GREEN}✅ Removed Sauver MCP from ~/.gemini/settings.json${NC}" ;;
  not-configured) echo -e "${YELLOW}⚠️  Sauver MCP not found in ~/.gemini/settings.json — skipping${NC}" ;;
  not-found)     echo -e "${YELLOW}⚠️  ~/.gemini/settings.json not found — skipping${NC}" ;;
esac

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}✅ Sauver has been uninstalled.${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Restart Claude or Gemini CLI to complete the removal."
echo ""

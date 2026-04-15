#!/usr/bin/env bash
# Tests for scripts/install.sh
# Usage: bash tests/test-install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$REPO_ROOT/scripts/install.sh"

PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

# ── helpers ─────────────────────────────────────────────────────────────────

# Run install.sh in an isolated temp home so it never touches ~/.sauver or ~/.claude
run_install() {
  local fake_home
  fake_home=$(mktemp -d)
  HOME="$fake_home" CI=1 bash "$INSTALL_SCRIPT" "${1:-}"
  echo "$fake_home"   # caller captures this to inspect output
}

# ── test: AI assistant check ────────────────────────────────────────────────

echo ""
echo "AI assistant check"

VALID_URL_FOR_CHECK="https://script.google.com/macros/s/AKfycbxFAKEIDforTesting1234567890/exec"

# Build a fake PATH that has node/npm/curl/bash but not claude/gemini
_fake_bin=$(mktemp -d)
for _cmd in node npm npx curl bash grep sed stat mktemp; do
  _src=$(command -v "$_cmd" 2>/dev/null) && ln -s "$_src" "$_fake_bin/$_cmd" 2>/dev/null || true
done

# When neither claude nor gemini is in PATH, warn but don't fail
_tmp_home=$(mktemp -d)
output=$(PATH="$_fake_bin:/usr/bin:/bin" HOME="$_tmp_home" CI=1 bash "$INSTALL_SCRIPT" "$VALID_URL_FOR_CHECK")
if echo "$output" | grep -q "Claude Code or Gemini CLI not found"; then
  pass "warns when no AI assistant found"
else
  fail "expected warning about missing AI assistant"
fi

# Install still completes despite the warning
if echo "$output" | grep -q "Sauver is ready"; then
  pass "install completes despite missing AI assistant"
else
  fail "install did not complete when AI assistant missing"
fi

# ── test: URL validation rejects bad input ───────────────────────────────────

echo ""
echo "URL validation"

bad_urls=(
  "https://script.google.com/macros/s"     # missing trailing slash
  "http://script.google.com/macros/s/"     # http not https
  "https://evil.com/macros/s/"
  "https://docs.google.com/macros/s/ABC/exec"
  "not-a-url"
)

for url in "${bad_urls[@]}"; do
  if HOME="$(mktemp -d)" CI=1 bash "$INSTALL_SCRIPT" "$url" 2>/dev/null; then
    fail "should have rejected: '${url:-<empty>}'"
  else
    pass "rejected: '${url:-<empty>}'"
  fi
done

# ── test: URL validation accepts valid Apps Script URL ───────────────────────

echo ""
echo "URL validation — valid URL"

VALID_URL="https://script.google.com/macros/s/AKfycbxFAKEIDforTesting1234567890/exec"

FAKE_HOME=$(mktemp -d)
if HOME="$FAKE_HOME" CI=1 bash "$INSTALL_SCRIPT" "$VALID_URL" 2>/dev/null; then
  pass "accepted valid URL"
else
  fail "rejected valid URL (exit code $?)"
fi

# ── test: config.json written with correct keys ──────────────────────────────

echo ""
echo "Config file"

CONFIG="$FAKE_HOME/.sauver/config.json"

if [ -f "$CONFIG" ]; then
  pass "config.json exists at ~/.sauver/config.json"
else
  fail "config.json not found at $CONFIG"
fi

if [ -f "$CONFIG" ]; then
  stored_url=$(node -e "console.log(require('$CONFIG').apps_script_url)")
  if [ "$stored_url" = "$VALID_URL" ]; then
    pass "apps_script_url matches"
  else
    fail "apps_script_url mismatch: got '$stored_url'"
  fi

  secret=$(node -e "console.log(require('$CONFIG').secret_key)")
  if [[ "$secret" =~ ^[0-9a-f]{64}$ ]]; then
    pass "secret_key is a 64-char hex string"
  else
    fail "secret_key malformed: '$secret'"
  fi

  perms=$(stat -c '%a' "$CONFIG" 2>/dev/null || stat -f '%A' "$CONFIG")
  if [ "$perms" = "600" ]; then
    pass "config.json has 600 permissions"
  else
    fail "config.json permissions: $perms (expected 600)"
  fi
fi

# ── test: MCP server files installed ────────────────────────────────────────

echo ""
echo "MCP server installation"

MCP_DIR="$FAKE_HOME/.sauver/mcp-server"

if [ -f "$MCP_DIR/index.js" ]; then
  pass "index.js installed"
else
  fail "index.js missing from $MCP_DIR"
fi

if [ -f "$MCP_DIR/package.json" ]; then
  pass "package.json installed"
else
  fail "package.json missing from $MCP_DIR"
fi

if [ -d "$MCP_DIR/node_modules" ]; then
  pass "node_modules present"
else
  fail "node_modules missing (npm install may have failed)"
fi

# ── test: Claude Code settings registered ────────────────────────────────────

echo ""
echo "Claude Code settings"

# `claude mcp add --scope user` writes to ~/.claude.json (not ~/.claude/settings.json).
# Only verify this when the claude CLI is available; skip in CI where it is not installed.
if command -v claude &>/dev/null; then
  CLAUDE_SETTINGS="$FAKE_HOME/.claude.json"

  if [ -f "$CLAUDE_SETTINGS" ]; then
    pass ".claude.json exists at ~/.claude.json"
  else
    fail ".claude.json not found at $CLAUDE_SETTINGS"
  fi

  if [ -f "$CLAUDE_SETTINGS" ]; then
    cmd=$(node -e "const s=require('$CLAUDE_SETTINGS'); console.log(s.mcpServers?.sauver?.command ?? '')")
    if [ "$cmd" = "node" ]; then
      pass "mcpServers.sauver.command = 'node'"
    else
      fail "mcpServers.sauver.command unexpected: '$cmd'"
    fi

    args=$(node -e "const s=require('$CLAUDE_SETTINGS'); console.log((s.mcpServers?.sauver?.args ?? []).join(','))")
    if [[ "$args" == *"index.js"* ]]; then
      pass "mcpServers.sauver.args contains index.js path"
    else
      fail "mcpServers.sauver.args unexpected: '$args'"
    fi
  fi
else
  pass "Claude CLI not installed — skipping .claude.json check"
fi

# ── summary ──────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

[ "$FAIL" -eq 0 ]

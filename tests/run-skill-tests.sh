#!/usr/bin/env bash
# Sauver skill integration tests
#
# Runs /sauver against EML fixtures through a mock MCP server and checks
# that the AI correctly classified each email, created drafts, and archived
# threads as expected.
#
# Usage:
#   ./tests/run-skill-tests.sh                          # all fixtures, claude CLI
#   ./tests/run-skill-tests.sh --cli gemini             # all fixtures, gemini CLI
#   ./tests/run-skill-tests.sh path/to/fixture.eml      # single fixture
#
# Requirements:
#   - Node.js (for the mock MCP server)
#   - claude CLI  (or gemini CLI if --cli gemini)
#   - Sauver skills installed at ~/.sauver/skills/  (run install.sh first)
#
# How it works:
#   For each EML fixture the test runner:
#     1. Starts a mock MCP server pointed at that fixture (env vars only,
#        no real Gmail / Apps Script calls).
#     2. Writes a project-scoped .claude/settings.json (or ~/.gemini/settings.json
#        for Gemini) that replaces the real 'sauver' MCP entry with the mock.
#        Project scope overrides user scope, so no permanent changes are made.
#     3. Runs the AI CLI in print mode: `claude -p "/sauver"`.
#     4. Reads the call log written by the mock server and checks it against
#        the .test.json metadata file next to the EML.
#     5. Restores the original settings file.
#
# Call log format (JSON array of objects):
#   { "tool": "create_draft", "args": {...}, "result": {...}, "timestamp": 1234 }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MOCK_SERVER_DIR="${SCRIPT_DIR}/mock-mcp-server"

# ── CLI flag ─────────────────────────────────────────────────────────────────

CLI="claude"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cli)
      CLI="$2"
      shift 2
      ;;
    --cli=*)
      CLI="${1#--cli=}"
      shift
      ;;
    *)
      break
      ;;
  esac
done

# ── Colors / helpers ─────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
section() { echo -e "\n${BOLD}── $1 ──${NC}"; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────

section "Pre-flight"

if ! command -v node &>/dev/null; then
  echo "Error: node is required" >&2; exit 1
fi

if ! command -v "$CLI" &>/dev/null; then
  echo "Error: '${CLI}' CLI not found in PATH" >&2; exit 1
fi

# Build mock MCP server if node_modules is missing or package.json changed
if [[ ! -d "${MOCK_SERVER_DIR}/node_modules" ]]; then
  echo "Installing mock MCP server dependencies..."
  (cd "$MOCK_SERVER_DIR" && npm install --silent)
fi

echo "  CLI: ${CLI}"
echo "  Mock server: ${MOCK_SERVER_DIR}/index.js"

# ── Settings file management ─────────────────────────────────────────────────
# We temporarily replace the project-scoped .claude/settings.json so the AI
# uses the mock MCP server instead of the real one.
# For Gemini, ~/.gemini/settings.json is patched instead (and restored).

CLAUDE_SETTINGS="${REPO_DIR}/.claude/settings.json"
GEMINI_SETTINGS="${HOME}/.gemini/settings.json"

if [[ "$CLI" == "claude" ]]; then
  SETTINGS_FILE="$CLAUDE_SETTINGS"
  SETTINGS_ORIGINAL=$(cat "$SETTINGS_FILE" 2>/dev/null || echo "{}")
elif [[ "$CLI" == "gemini" ]]; then
  SETTINGS_FILE="$GEMINI_SETTINGS"
  SETTINGS_ORIGINAL=$(cat "$SETTINGS_FILE" 2>/dev/null || echo "{}")
fi

restore_settings() {
  echo "$SETTINGS_ORIGINAL" > "$SETTINGS_FILE"
}
trap restore_settings EXIT

write_claude_settings() {
  local fixture_file="$1"
  local log_file="$2"
  node --input-type=module <<EOF
import { writeFileSync } from "fs";
const cfg = {
  mcpServers: {
    sauver: {
      command: "node",
      args: ["${MOCK_SERVER_DIR}/index.js"],
      env: {
        SAUVER_TEST_FIXTURE_FILE: "${fixture_file}",
        SAUVER_TEST_LOG: "${log_file}"
      }
    }
  },
  permissions: {
    allow: ["mcp__sauver__*"]
  }
};
writeFileSync("${SETTINGS_FILE}", JSON.stringify(cfg, null, 2));
EOF
}

write_gemini_settings() {
  local fixture_file="$1"
  local log_file="$2"
  node --input-type=module <<EOF
import { writeFileSync, readFileSync } from "fs";
let cfg = {};
try { cfg = JSON.parse(readFileSync("${SETTINGS_FILE}", "utf8")); } catch {}
cfg.mcpServers = cfg.mcpServers ?? {};
cfg.mcpServers.sauver = {
  command: "node",
  args: ["${MOCK_SERVER_DIR}/index.js"],
  env: {
    SAUVER_TEST_FIXTURE_FILE: "${fixture_file}",
    SAUVER_TEST_LOG: "${log_file}"
  },
  trust: true
};
writeFileSync("${SETTINGS_FILE}", JSON.stringify(cfg, null, 2));
EOF
}

# ── Run a single fixture ──────────────────────────────────────────────────────

run_test() {
  local eml_file="$1"
  local meta_file="${eml_file%.eml}.test.json"
  local fixture_name
  fixture_name="$(basename "$eml_file" .eml)"
  local log_file="/tmp/sauver-test-${fixture_name}.json"

  section "fixture: ${fixture_name}"

  # --- Load metadata ---
  if [[ ! -f "$meta_file" ]]; then
    fail "missing ${fixture_name}.test.json — cannot validate"
    return
  fi

  local label expected_draft expected_archived description
  label=$(node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('$meta_file')).label)")
  expected_draft=$(node -e "process.stdout.write(String(JSON.parse(require('fs').readFileSync('$meta_file')).expected.draft_created))")
  expected_archived=$(node -e "process.stdout.write(String(JSON.parse(require('fs').readFileSync('$meta_file')).expected.archived))")
  description=$(node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('$meta_file')).description)")

  echo "  label:    ${label}"
  echo "  expects:  draft_created=${expected_draft}, archived=${expected_archived}"
  echo "  desc:     ${description}"

  # --- Configure mock MCP server ---
  if [[ "$CLI" == "claude" ]]; then
    write_claude_settings "$eml_file" "$log_file"
  else
    write_gemini_settings "$eml_file" "$log_file"
  fi

  # --- Run the AI ---
  echo ""
  echo "  Running: ${CLI} -p \"/sauver\" ..."
  local ai_output exit_code=0

  if [[ "$CLI" == "claude" ]]; then
    ai_output=$(cd "$REPO_DIR" && claude -p "/sauver" 2>&1) || exit_code=$?
  elif [[ "$CLI" == "gemini" ]]; then
    ai_output=$(cd "$REPO_DIR" && gemini -p "/sauver" 2>&1) || exit_code=$?
  fi

  if [[ $exit_code -ne 0 ]]; then
    warn "CLI exited with code ${exit_code} — check output below"
  fi

  # Print a brief excerpt of the AI output for visibility
  echo ""
  echo "  --- AI output (last 20 lines) ---"
  echo "$ai_output" | tail -20 | sed 's/^/  | /'
  echo ""

  # --- Read call log ---
  if [[ ! -f "$log_file" ]]; then
    fail "no call log found at ${log_file} — mock server may not have started"
    return
  fi

  local draft_called archived_called
  draft_called=$(node -e "
    const log = JSON.parse(require('fs').readFileSync('${log_file}'));
    process.stdout.write(String(log.some(c => c.tool === 'create_draft' || c.tool === 'send_message')));
  " 2>/dev/null || echo "false")

  archived_called=$(node -e "
    const log = JSON.parse(require('fs').readFileSync('${log_file}'));
    process.stdout.write(String(log.some(c => c.tool === 'archive_thread')));
  " 2>/dev/null || echo "false")

  # --- Assert ---
  if [[ "$draft_called" == "$expected_draft" ]]; then
    pass "draft_created=${draft_called} (expected ${expected_draft})"
  else
    fail "draft_created=${draft_called} but expected ${expected_draft}"
    # Show draft body if unexpected
    if [[ "$draft_called" == "true" ]]; then
      node -e "
        const log = JSON.parse(require('fs').readFileSync('${log_file}'));
        const d = log.find(c => c.tool === 'create_draft' || c.tool === 'send_message');
        if (d) process.stdout.write('    draft body: ' + (d.args.body ?? '').substring(0, 200) + '\n');
      " 2>/dev/null || true
    fi
  fi

  if [[ "$archived_called" == "$expected_archived" ]]; then
    pass "archived=${archived_called} (expected ${expected_archived})"
  else
    fail "archived=${archived_called} but expected ${expected_archived}"
  fi

  # Restore settings so next test starts clean (trap also does this on EXIT)
  echo "$SETTINGS_ORIGINAL" > "$SETTINGS_FILE"
}

# ── Main ─────────────────────────────────────────────────────────────────────

if [[ $# -gt 0 ]]; then
  # Single fixture passed as argument
  run_test "$1"
else
  # All fixtures
  shopt -s nullglob
  for eml in "${SCRIPT_DIR}/fixtures/slop/"*.eml "${SCRIPT_DIR}/fixtures/legitimate/"*.eml; do
    run_test "$eml"
  done
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}Results: ${GREEN}${PASS} passed${NC}${BOLD}, ${RED}${FAIL} failed${NC}"
echo ""

[[ $FAIL -eq 0 ]]

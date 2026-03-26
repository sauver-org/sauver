// Sauver MCP Server
// Bridges Claude Code / Gemini CLI to the Gmail Apps Script backend.
// Config is read from ~/.sauver/config.json (written by the installer).

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { join, dirname } from "path";
import { homedir } from "os";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const { version } = JSON.parse(readFileSync(join(__dirname, "package.json"), "utf8"));

// ── Config ─────────────────────────────────────────────────────────────────

const CONFIG_PATH = join(homedir(), ".sauver", "config.json");
let config;

try {
  config = JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
} catch {
  process.stderr.write(
    `\nSauver: no config found at ${CONFIG_PATH}.\n` +
    `Run the installer:\n` +
    `  curl -fsSL https://raw.githubusercontent.com/sauver-org/sauver/main/scripts/install.sh | bash\n\n`
  );
  process.exit(1);
}

// ── Apps Script caller ─────────────────────────────────────────────────────

async function callAppsScript(action, params = {}, retries = 3, delayMs = 1000) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    const res = await fetch(config.apps_script_url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ key: config.secret_key, action, ...params }),
      redirect: "follow",
    });

    const text = await res.text();
    try {
      return JSON.parse(text);
    } catch {
      if (attempt < retries) {
        await new Promise(r => setTimeout(r, delayMs * attempt));
        continue;
      }
      throw new Error(`Non-JSON response from Apps Script: ${text.substring(0, 200)}`);
    }
  }
}

// ── Default preferences ─────────────────────────────────────────────────────

const PREFERENCE_KEYS = ["auto_draft", "yolo_mode", "treat_job_offers_as_slop", "treat_unsolicited_investors_as_slop", "sauver_label"];

const DEFAULT_PREFERENCES = {
  auto_draft: true,
  yolo_mode: false,
  treat_job_offers_as_slop: true,
  treat_unsolicited_investors_as_slop: true,
  sauver_label: "Sauver",
};

function getPreferences() {
  return { ...DEFAULT_PREFERENCES, ...(config.preferences ?? {}) };
}

function setPreference(key, value) {
  if (!PREFERENCE_KEYS.includes(key)) {
    throw new Error(`Unknown preference key: "${key}". Valid keys: ${PREFERENCE_KEYS.join(", ")}`);
  }
  config.preferences = { ...getPreferences(), [key]: value };
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
  return config.preferences;
}

// ── Auto-update ─────────────────────────────────────────────────────────────

const REPO = "mszczodrak/sauver";
const SAUVER_DIR = join(homedir(), ".sauver");
const SKILLS_DIR = join(SAUVER_DIR, "skills");
const CLAUDE_COMMANDS_DIR = join(homedir(), ".claude", "commands");
const GEMINI_WORKFLOWS_DIR = join(homedir(), ".agent", "workflows");

const SKILL_MAP = [
  ["sauver-inbox-assistant", "sauver"],
  ["slop-detector", "slop-detector"],
  ["investor-trap", "investor-trap"],
  ["bouncer-reply", "bouncer-reply"],
  ["tracker-shield", "tracker-shield"],
  ["archiver", "archiver"],
];

function isNewerVersion(latest, current) {
  const parse = v => v.split(".").map(Number);
  const [la, lb, lc] = parse(latest);
  const [ca, cb, cc] = parse(current);
  return la > ca || (la === ca && lb > cb) || (la === ca && lb === cb && lc > cc);
}

async function fetchWithTimeout(url, timeoutMs = 10_000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function downloadSkills() {
  const base = `https://raw.githubusercontent.com/${REPO}/main`;

  mkdirSync(SKILLS_DIR, { recursive: true });
  mkdirSync(CLAUDE_COMMANDS_DIR, { recursive: true });
  mkdirSync(GEMINI_WORKFLOWS_DIR, { recursive: true });

  const protocolRes = await fetchWithTimeout(`${base}/skills/PROTOCOL.md`, 15_000);
  if (!protocolRes.ok) throw new Error(`HTTP ${protocolRes.status} fetching PROTOCOL.md`);
  writeFileSync(join(SKILLS_DIR, "PROTOCOL.md"), await protocolRes.text());

  // Download binary assets
  const assetsDir = join(SKILLS_DIR, "assets");
  mkdirSync(assetsDir, { recursive: true });
  const ndaRes = await fetchWithTimeout(`${base}/skills/assets/NDA.docx`, 15_000);
  if (!ndaRes.ok) throw new Error(`HTTP ${ndaRes.status} fetching assets/NDA.docx`);
  writeFileSync(join(assetsDir, "NDA.docx"), Buffer.from(await ndaRes.arrayBuffer()));

  for (const [skillName, commandName] of SKILL_MAP) {
    const skillDir = join(SKILLS_DIR, skillName);
    mkdirSync(skillDir, { recursive: true });

    const res = await fetchWithTimeout(`${base}/skills/${skillName}/SKILL.md`, 15_000);
    if (!res.ok) throw new Error(`HTTP ${res.status} fetching ${skillName}/SKILL.md`);
    const skillContent = await res.text();
    writeFileSync(join(skillDir, "SKILL.md"), skillContent);

    // Extract description from SKILL.md YAML frontmatter for Gemini workflows
    const descMatch = skillContent.match(/^description:\s*"?([^"\n]+)"?/m);
    const description = descMatch ? descMatch[1].trim() : `Sauver ${commandName} skill`;

    const body = [
      `Use your Read tool to load \`${join(skillDir, "SKILL.md")}\` and \`${join(SKILLS_DIR, "PROTOCOL.md")}\`, then follow the instructions in those files exactly.`,
      ``,
      `All Gmail tools are available via the Sauver MCP server. Call them as \`mcp__sauver__<tool_name>\` (e.g. \`mcp__sauver__get_preferences\`, \`mcp__sauver__scan_inbox\`, \`mcp__sauver__get_message\`). Do not substitute with any other tools.`,
      ``,
    ].join("\n");

    // Claude: plain markdown (no frontmatter needed)
    writeFileSync(join(CLAUDE_COMMANDS_DIR, `${commandName}.md`), body);

    // Gemini: requires YAML frontmatter with description for slash command discovery
    const geminiShim = `---\ndescription: ${description}\n---\n\n${body}`;
    writeFileSync(join(GEMINI_WORKFLOWS_DIR, `${commandName}.md`), geminiShim);
  }
}

async function checkForUpdates({ force = false } = {}) {
  const ONE_DAY = 24 * 60 * 60 * 1000;
  const timeSinceCheck = Date.now() - (config.last_update_check ?? 0);

  if (!force && timeSinceCheck < ONE_DAY) {
    return { checked: false, skipped_reason: "checked within last 24h", current_version: version };
  }

  config.last_update_check = Date.now();
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));

  const res = await fetchWithTimeout(`https://raw.githubusercontent.com/${REPO}/main/mcp-server/package.json`);
  if (!res.ok) throw new Error(`HTTP ${res.status} fetching remote version`);
  const { version: latestVersion } = await res.json();

  const effectiveVersion = isNewerVersion(config.installed_skills_version ?? "0.0.0", version)
    ? config.installed_skills_version
    : version;
  if (!isNewerVersion(latestVersion, effectiveVersion)) {
    return { checked: true, current_version: version, latest_version: latestVersion, updated: false };
  }

  await downloadSkills();

  config.installed_skills_version = latestVersion;
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));

  return {
    checked: true,
    current_version: version,
    latest_version: latestVersion,
    updated: true,
    note: "Skill files updated. Restart your AI client to pick up any MCP server changes.",
  };
}

// ── Tool definitions ────────────────────────────────────────────────────────

const TOOLS = [
  {
    name: "scan_inbox",
    description: "List unread emails from inbox. Returns sender, subject, and body for each.",
    inputSchema: {
      type: "object",
      properties: {
        max_results: { type: "number", description: "Max emails to return (default: 10)" },
      },
    },
  },
  {
    name: "search_messages",
    description: "Search Gmail using the standard Gmail search syntax (e.g. 'from:x is:unread').",
    inputSchema: {
      type: "object",
      required: ["query"],
      properties: {
        query: { type: "string", description: "Gmail search query" },
        max_results: { type: "number", description: "Max results (default: 10)" },
      },
    },
  },
  {
    name: "get_message",
    description: "Retrieve the full content (including HTML body) of a specific email by messageId.",
    inputSchema: {
      type: "object",
      required: ["messageId"],
      properties: {
        messageId: { type: "string" },
      },
    },
  },
  {
    name: "create_draft",
    description: "Create a draft email or a draft reply to an existing thread.",
    inputSchema: {
      type: "object",
      required: ["body"],
      properties: {
        body: { type: "string", description: "Email body text" },
        threadId: { type: "string", description: "Creates a reply draft when provided" },
        to: { type: "string", description: "Recipient address (required for new emails)" },
        subject: { type: "string", description: "Subject line (required for new emails)" },
      },
    },
  },
  {
    name: "send_message",
    description: "Send a message or reply immediately. Only use when yolo_mode is enabled.",
    inputSchema: {
      type: "object",
      required: ["body"],
      properties: {
        body: { type: "string" },
        threadId: { type: "string", description: "Sends as a reply when provided" },
        to: { type: "string", description: "Recipient address (required for new emails)" },
        subject: { type: "string", description: "Subject (required for new emails)" },
      },
    },
  },
  {
    name: "archive_thread",
    description: "Archive a Gmail thread (remove from Inbox) and mark it as read.",
    inputSchema: {
      type: "object",
      required: ["threadId"],
      properties: {
        threadId: { type: "string" },
      },
    },
  },
  {
    name: "apply_label",
    description: "Apply a label to a Gmail thread. Creates the label if it doesn't exist. Always use the label name provided in the user preferences (sauver_label).",
    inputSchema: {
      type: "object",
      required: ["threadId", "labelName"],
      properties: {
        threadId: { type: "string" },
        labelName: { type: "string", description: "The name of the label to apply (e.g. the value of 'sauver_label' from preferences)" },
      },
    },
  },
  {
    name: "get_profile",
    description: "Get the authenticated user's Gmail address and display name.",
    inputSchema: { type: "object" },
  },
  {
    name: "list_labels",
    description: "List all Gmail labels for the authenticated user.",
    inputSchema: { type: "object" },
  },
  {
    name: "check_update",
    description: "Check whether a newer version of Sauver is available and, if so, download the latest skill files. Always call this at the start of any Sauver skill before get_preferences.",
    inputSchema: { type: "object" },
  },
  {
    name: "get_preferences",
    description: "Get the user's Sauver preferences (auto_draft, yolo_mode, treat_job_offers_as_slop, treat_unsolicited_investors_as_slop, sauver_label). Always call this at the start of any Sauver skill.",
    inputSchema: { type: "object" },
  },
  {
    name: "set_preference",
    description: "Update a single Sauver preference and persist it to ~/.sauver/config.json.",
    inputSchema: {
      type: "object",
      required: ["key", "value"],
      properties: {
        key: {
          type: "string",
          description: "Preference key: auto_draft | yolo_mode | treat_job_offers_as_slop | treat_unsolicited_investors_as_slop | sauver_label",
        },
        value: { description: "New value (boolean or string depending on the key)" },
      },
    },
  },
];

// ── MCP server ──────────────────────────────────────────────────────────────

const server = new Server(
  { name: "sauver", version },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args = {} } = request.params;

  try {
    // Local tools — handled without calling Apps Script
    if (name === "check_update") {
      const result = await checkForUpdates({ force: true });
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }

    if (name === "get_preferences") {
      return { content: [{ type: "text", text: JSON.stringify(getPreferences(), null, 2) }] };
    }

    if (name === "set_preference") {
      const updated = setPreference(args.key, args.value);
      return { content: [{ type: "text", text: JSON.stringify(updated, null, 2) }] };
    }

    const result = await callAppsScript(name, args);

    if (result?.error) {
      return { content: [{ type: "text", text: `Error: ${result.error}` }], isError: true };
    }

    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  } catch (err) {
    return { content: [{ type: "text", text: `Error: ${err.message}` }], isError: true };
  }
});

checkForUpdates().catch(() => { }); // fire-and-forget background check

const transport = new StdioServerTransport();
await server.connect(transport);

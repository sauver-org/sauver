// Sauver MCP Server
// Bridges Claude Code / Gemini CLI to the Gmail Apps Script backend.
// Config is read from ~/.sauver/config.json (written by the installer).

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { readFileSync, writeFileSync } from "fs";
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
    `  curl -fsSL https://raw.githubusercontent.com/mszczodrak/sauver/main/scripts/install.sh | bash\n\n`
  );
  process.exit(1);
}

// ── Apps Script caller ─────────────────────────────────────────────────────

async function callAppsScript(action, params = {}) {
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
    throw new Error(`Non-JSON response from Apps Script: ${text.substring(0, 200)}`);
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
    description: "Apply a label to a Gmail thread. Creates the label if it doesn't exist.",
    inputSchema: {
      type: "object",
      required: ["threadId", "labelName"],
      properties: {
        threadId: { type: "string" },
        labelName: { type: "string", description: "e.g. 'Sauver' or 'Sauver/Slop'" },
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

const transport = new StdioServerTransport();
await server.connect(transport);

// Sauver Mock MCP Server — for integration tests
//
// Replaces the real MCP server during tests. Instead of calling Google Apps
// Script, it serves EML files from disk as the "inbox" and logs all write
// operations (create_draft, send_message, archive_thread, apply_label) to a
// JSON file that the test runner checks against expectations.
//
// Environment variables:
//   SAUVER_TEST_FIXTURE_FILE   path to a single .eml file (single-email inbox)
//   SAUVER_TEST_FIXTURES_DIR   path to a directory of .eml files (multi-email inbox)
//   SAUVER_TEST_LOG            path to write the call log JSON (default: /tmp/sauver-test-calls.json)
//
// At least one of SAUVER_TEST_FIXTURE_FILE or SAUVER_TEST_FIXTURES_DIR is required.

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { readFileSync, writeFileSync, readdirSync } from "fs";
import { join, basename } from "path";
import { simpleParser } from "mailparser";

// ── Config ──────────────────────────────────────────────────────────────────

const FIXTURE_FILE = process.env.SAUVER_TEST_FIXTURE_FILE;
const FIXTURE_DIR = process.env.SAUVER_TEST_FIXTURES_DIR;
const LOG_FILE = process.env.SAUVER_TEST_LOG || "/tmp/sauver-test-calls.json";

if (!FIXTURE_FILE && !FIXTURE_DIR) {
  process.stderr.write(
    "sauver-mock: SAUVER_TEST_FIXTURE_FILE or SAUVER_TEST_FIXTURES_DIR must be set\n",
  );
  process.exit(1);
}

// ── Parse EML fixtures ───────────────────────────────────────────────────────

function slugify(name) {
  return basename(name, ".eml")
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/gi, "")
    .toLowerCase();
}

async function parseEml(filePath) {
  const content = readFileSync(filePath);
  const parsed = await simpleParser(content);
  const slug = slugify(filePath);

  return {
    threadId: `thread-${slug}`,
    messageId: `msg-${slug}`,
    from: parsed.from?.text ?? "",
    to: parsed.to?.text ?? "",
    subject: parsed.subject ?? "",
    date: (parsed.date ?? new Date()).toISOString(),
    snippet: (parsed.text ?? "").substring(0, 200),
    body: parsed.text ?? "",
    htmlBody: parsed.html ?? "",
  };
}

const emlPaths = FIXTURE_FILE
  ? [FIXTURE_FILE]
  : readdirSync(FIXTURE_DIR)
      .filter((f) => f.endsWith(".eml"))
      .map((f) => join(FIXTURE_DIR, f));

const messages = await Promise.all(emlPaths.map(parseEml));

// ── Call log ─────────────────────────────────────────────────────────────────

// Initialise (or reset) the log file so stale data from previous runs is gone.
writeFileSync(LOG_FILE, "[]");

const callLog = [];

function logCall(tool, args, result) {
  callLog.push({ tool, args, result, timestamp: Date.now() });
  writeFileSync(LOG_FILE, JSON.stringify(callLog, null, 2));
}

// ── Tool list (mirrors mcp-server/index.js) ──────────────────────────────────

const TOOLS = [
  {
    name: "scan_inbox",
    description: "List unread emails from inbox.",
    inputSchema: {
      type: "object",
      properties: { max_results: { type: "number" } },
    },
  },
  {
    name: "search_messages",
    description: "Search Gmail using standard Gmail search syntax.",
    inputSchema: {
      type: "object",
      required: ["query"],
      properties: {
        query: { type: "string" },
        max_results: { type: "number" },
      },
    },
  },
  {
    name: "get_message",
    description: "Retrieve the full content of an email by messageId.",
    inputSchema: {
      type: "object",
      required: ["messageId"],
      properties: { messageId: { type: "string" } },
    },
  },
  {
    name: "create_draft",
    description: "Create a draft email or a draft reply to an existing thread.",
    inputSchema: {
      type: "object",
      required: ["body"],
      properties: {
        body: { type: "string" },
        htmlBody: { type: "string" },
        threadId: { type: "string" },
        to: { type: "string" },
        subject: { type: "string" },
        attachments: { type: "array", items: { type: "string" } },
      },
    },
  },
  {
    name: "send_message",
    description:
      "Send a message immediately. Only use when yolo_mode is enabled.",
    inputSchema: {
      type: "object",
      required: ["body"],
      properties: {
        body: { type: "string" },
        htmlBody: { type: "string" },
        threadId: { type: "string" },
        to: { type: "string" },
        subject: { type: "string" },
        attachments: { type: "array", items: { type: "string" } },
      },
    },
  },
  {
    name: "archive_thread",
    description: "Archive a Gmail thread and mark it as read.",
    inputSchema: {
      type: "object",
      required: ["threadId"],
      properties: { threadId: { type: "string" } },
    },
  },
  {
    name: "apply_label",
    description: "Apply a label to a Gmail thread.",
    inputSchema: {
      type: "object",
      required: ["threadId", "labelName"],
      properties: {
        threadId: { type: "string" },
        labelName: { type: "string" },
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
    description: "List all Gmail labels.",
    inputSchema: { type: "object" },
  },
  {
    name: "check_update",
    description: "Check whether a newer version of Sauver is available.",
    inputSchema: { type: "object" },
  },
  {
    name: "get_preferences",
    description: "Get the user's Sauver preferences.",
    inputSchema: { type: "object" },
  },
  {
    name: "set_preference",
    description: "Update a single Sauver preference.",
    inputSchema: {
      type: "object",
      required: ["key", "value"],
      properties: {
        key: { type: "string" },
        value: {},
      },
    },
  },
];

// ── MCP server ───────────────────────────────────────────────────────────────

const server = new Server(
  { name: "sauver", version: "0.0.0-test" },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOLS,
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args = {} } = request.params;

  let result;

  switch (name) {
    // ── Local / no-op tools ────────────────────────────────────────────────

    case "check_update":
      result = {
        checked: false,
        skipped_reason: "test mode",
        updated: false,
        current_version: "0.0.0-test",
        test_mode: true,
      };
      break;

    case "get_preferences":
      result = {
        auto_draft: true,
        yolo_mode: false,
        treat_job_offers_as_slop: true,
        treat_unsolicited_investors_as_slop: true,
        slop_label: "Sauver/Slop",
        reviewed_label: "Sauver/Reviewed",
        test_mode: true,
      };
      break;

    case "set_preference":
      result = {
        status: "ok (test mode — preference not persisted)",
        key: args.key,
        value: args.value,
      };
      break;

    case "get_profile":
      result = { email: "test@example.com", name: "Test" };
      break;

    case "list_labels":
      result = [];
      break;

    // ── Read tools — return fixture data ───────────────────────────────────

    case "scan_inbox":
    case "search_messages": {
      const limit = args.max_results ?? 10;
      result = messages.slice(0, limit).map((m) => ({
        threadId: m.threadId,
        messageId: m.messageId,
        from: m.from,
        to: m.to,
        subject: m.subject,
        date: m.date,
        snippet: m.snippet,
      }));
      break;
    }

    case "get_message": {
      const msg = messages.find((m) => m.messageId === args.messageId);
      if (!msg) {
        result = { error: `Message not found: ${args.messageId}` };
      } else {
        result = {
          threadId: msg.threadId,
          messageId: msg.messageId,
          from: msg.from,
          to: msg.to,
          subject: msg.subject,
          date: msg.date,
          body: msg.body,
          htmlBody: msg.htmlBody,
        };
      }
      break;
    }

    // ── Write tools — log and return success ───────────────────────────────

    case "create_draft":
      result = {
        draftId: `draft-test-${Date.now()}`,
        status: "Draft created (test mode)",
      };
      logCall(name, args, result);
      break;

    case "send_message":
      result = { status: "Message sent (test mode — not actually sent)" };
      logCall(name, args, result);
      break;

    case "archive_thread":
      result = { status: "Archived and marked read (test mode)" };
      logCall(name, args, result);
      break;

    case "apply_label":
      result = { status: `Label '${args.labelName}' applied (test mode)` };
      logCall(name, args, result);
      break;

    default:
      return {
        content: [{ type: "text", text: `Error: Unknown tool: ${name}` }],
        isError: true,
      };
  }

  return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
});

const transport = new StdioServerTransport();
await server.connect(transport);

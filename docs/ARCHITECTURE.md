# Sauver Architecture & API Design

This document outlines the system architecture and the internal API contract that powers Sauver. It adheres to our core design principles: predictable interfaces, secure boundaries, and zero third-party data exfiltration.

## System Architecture

Sauver is designed as a three-layer system to strictly isolate email access, execution, and AI logic.

### Layer 1: Google Apps Script (Cloud Backend)

- **Role:** Native Gmail executor.
- **Environment:** Runs entirely within the user's personal Google account.
- **Security:** Requires no OAuth tokens, GCP projects, or external service accounts. It uses the `GmailApp` service natively. It exposes a single HTTPS web app URL that acts as the API boundary.

### Layer 2: Local MCP Server (Bridge)

- **Role:** The translator between the AI client and the Apps Script backend.
- **Environment:** A local Node.js process (`~/.sauver/mcp-server/index.js`).
- **Function:** It exposes standard Model Context Protocol (MCP) tools to the AI client and translates tool invocations into HTTPS POST requests to Layer 1. It also manages local state like `~/.sauver/config.json`.

### Layer 3: AI Client & Skills (Logic)

- **Role:** The brain of the operation.
- **Environment:** Claude Code or Gemini CLI running on the user's machine.
- **Function:** Reads the email data provided by Layer 2, applies the defense logic defined in the local skill files (`~/.sauver/skills/`), and decides which counter-measures to deploy.

---

## API Contract (Layer 2 ↔ Layer 1)

The communication between the local MCP Server and the Google Apps Script backend happens over a single, authenticated HTTPS POST endpoint.

### Transport and Authentication

- **Endpoint:** `POST https://script.google.com/macros/s/<DEPLOYMENT_ID>/exec`
- **Content-Type:** `application/json`
- **Authentication:** Every request MUST include a `key` property matching the `secret_key` generated during installation. Requests without a valid key are immediately rejected by the Apps Script boundary.

### Base Schemas

All requests follow a discriminated union pattern based on the `action` field.
All errors follow a consistent semantic structure.

```typescript
// Request Envelope
interface BaseRequest {
  key: string; // The 64-character secret key
  action: ActionType;
}

// Consistent Error Semantics
interface APIError {
  error: string; // Human-readable error message
}

type APIResponse<T> = T | APIError;
```

### Endpoints / Actions

#### 1. `scan_inbox`

Retrieves unread emails currently in the user's inbox.

```typescript
interface ScanInboxRequest extends BaseRequest {
  action: "scan_inbox";
  max_results?: number; // Default: 10
}

type ScanInboxResponse = Array<{
  threadId: string;
  messageId: string;
  from: string;
  to: string;
  subject: string;
  date: string; // ISO 8601
  snippet: string;
}>;
```

#### 2. `search_messages`

Searches Gmail using standard query syntax.

```typescript
interface SearchMessagesRequest extends BaseRequest {
  action: "search_messages";
  query: string;
  max_results?: number;
}

type SearchMessagesResponse = ScanInboxResponse;
```

#### 3. `get_message`

Fetches the full content of a specific message.

```typescript
interface GetMessageRequest extends BaseRequest {
  action: "get_message";
  messageId: string;
}

interface GetMessageResponse {
  threadId: string;
  messageId: string;
  from: string;
  to: string;
  subject: string;
  date: string;
  body: string; // Plain text content
  htmlBody: string; // HTML content
}
```

#### 4. `create_draft`

Creates a draft email or a draft reply.

```typescript
interface CreateDraftRequest extends BaseRequest {
  action: "create_draft";
  body: string;
  htmlBody?: string;
  threadId?: string; // If provided, drafts a reply to this thread
  to?: string; // Required if threadId is omitted
  subject?: string; // Required if threadId is omitted
  attachments?: Array<{
    name: string;
    mimeType: string;
    data: string; // Base64 encoded file content
  }>;
}

interface CreateDraftResponse {
  draftId: string;
  status: string;
}
```

#### 5. `send_message`

Sends a message immediately (YOLO mode).

```typescript
interface SendMessageRequest extends CreateDraftRequest {
  action: "send_message";
}

interface SendMessageResponse {
  status: string;
}
```

#### 6. `archive_thread`

Removes a thread from the Inbox and marks it as read.

```typescript
interface ArchiveThreadRequest extends BaseRequest {
  action: "archive_thread";
  threadId: string;
}

interface ArchiveThreadResponse {
  status: string;
}
```

#### 7. `apply_label`

Applies a specific label to a thread, creating the label if it doesn't exist.

```typescript
interface ApplyLabelRequest extends BaseRequest {
  action: "apply_label";
  threadId: string;
  labelName: string;
}

interface ApplyLabelResponse {
  status: string;
}
```

#### 8. `get_profile`

Retrieves the authenticated user's profile info.

```typescript
interface GetProfileRequest extends BaseRequest {
  action: "get_profile";
}

interface GetProfileResponse {
  email: string;
  name: string;
}
```

#### 9. `list_labels`

Lists all labels in the user's Gmail account.

```typescript
interface ListLabelsRequest extends BaseRequest {
  action: "list_labels";
}

type ListLabelsResponse = string[];
```

---

## Security and Boundary Rules

1. **Validation at the Edge:** The Apps Script layer blindly executes against the Gmail API provided the `key` matches. The local MCP server MUST validate file paths, attachments, and rate limits (e.g., `max_daily_replies`) _before_ generating the POST request.
2. **Untrusted Data:** Email bodies returned from `get_message` are treated as untrusted input. The AI client is restricted by `skills/PROTOCOL.md` to prevent prompt injection and data exfiltration.
3. **No External Dependencies:** The Apps Script backend has zero external dependencies (no npm packages). The MCP Server relies only on the official `@modelcontextprotocol/sdk`.

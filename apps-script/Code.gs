// Sauver Gmail Backend — Google Apps Script Web App
// Deploy as: Execute as "Me", Who has access "Anyone"
// Docs: https://github.com/sauver-org/sauver

const SECRET_KEY = "CHANGE_ME"; // ← replaced by installer
const BACKEND_NAME = "Sauver Backend"; // ← replaced by installer

function doGet(e) {
  const html = `
    <!DOCTYPE html>
    <html>
      <head>
        <base target="_top">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background: #0a0a0a; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          .card { background: #111; padding: 2rem; border-radius: 12px; border: 1px solid #222; text-align: center; max-width: 400px; box-shadow: 0 10px 40px rgba(0,0,0,0.8); }
          .icon { margin-bottom: 1rem; filter: drop-shadow(0 0 10px rgba(255,255,255,0.1)); }
          h1 { margin: 0 0 1rem 0; font-size: 1.5rem; font-weight: 600; letter-spacing: -0.01em; }
          p { color: #999; margin: 0; line-height: 1.6; font-size: 0.95rem; }
          .status { display: inline-block; margin-top: 1.5rem; padding: 4px 12px; background: #1a2e1a; color: #4ade80; border-radius: 20px; font-size: 0.8rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 1024 1024"><path fill="rgb(250,161,22)" d="M512 42.667969L128 213.332031L128 469.332031C128 706.132812 291.839844 927.574219 512 981.332031C732.160156 927.574219 896 706.132812 896 469.332031L896 213.332031ZM512 511.574219L810.667969 511.574219C790.613281 696.746094 683.519531 861.011719 512 916.480469L512 512L213.332031 512L213.332031 268.800781L512 136.105469Z"/></svg></div>
          <h1>${BACKEND_NAME} Active</h1>
          <p>Your Gmail defense layer is successfully authorized and ready to protect your inbox.</p>
          <div class="status">Authorized</div>
          <p style="margin-top: 2rem; font-size: 0.8rem; color: #555;">You can now close this window and return to the terminal.</p>
        </div>
      </body>
    </html>
  `;
  return HtmlService.createHtmlOutput(html)
    .setTitle(`Sauver | ${BACKEND_NAME} Authorized`)
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.DENY);
}

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);

    if (data.key !== SECRET_KEY) {
      return json({ error: "Unauthorized" });
    }

    const handlers = {
      scan_inbox: () => scanInbox(data.max_results || 10),
      search_messages: () => searchMessages(data.query, data.max_results || 10),
      get_message: () => getMessage(data.messageId),
      create_draft: () => createDraft(data),
      send_message: () => sendMessage(data),
      archive_thread: () => archiveThread(data.threadId),
      apply_label: () => applyLabel(data.threadId, data.labelName),
      get_profile: () => getProfile(),
      list_labels: () => listLabels(),
    };

    const handler = handlers[data.action];
    if (!handler) return json({ error: `Unknown action: ${data.action}` });

    return json(handler());
  } catch (err) {
    return json({ error: err.toString() });
  }
}

function json(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(
    ContentService.MimeType.JSON,
  );
}

// ── Actions ────────────────────────────────────────────────────────────────

function threadSummary(thread) {
  const messages = thread.getMessages();
  const msg = messages[messages.length - 1];
  const plain = msg.getPlainBody();
  return {
    threadId: thread.getId(),
    messageId: msg.getId(),
    from: msg.getFrom(),
    to: msg.getTo(),
    subject: msg.getSubject(),
    date: msg.getDate().toISOString(),
    snippet: plain.substring(0, 200),
  };
}

function scanInbox(maxResults) {
  // Fetch from the native inbox API (correct visual order), then filter unread.
  const threads = GmailApp.getInboxThreads(0, maxResults * 3);
  return threads
    .filter((t) => t.isUnread())
    .slice(0, maxResults)
    .map(threadSummary);
}

function searchMessages(query, maxResults) {
  // Use the native inbox API when possible — it returns threads in Gmail's
  // exact visual order, unlike GmailApp.search which can diverge.
  const threads =
    query.trim() === "in:inbox"
      ? GmailApp.getInboxThreads(0, maxResults)
      : GmailApp.search(query, 0, maxResults);
  return threads.map(threadSummary);
}

function getMessage(messageId) {
  const msg = GmailApp.getMessageById(messageId);
  if (!msg) return { error: "Message not found" };
  return {
    threadId: msg.getThread().getId(),
    messageId: msg.getId(),
    from: msg.getFrom(),
    to: msg.getTo(),
    subject: msg.getSubject(),
    date: msg.getDate().toISOString(),
    body: msg.getPlainBody(),
    htmlBody: msg.getBody(),
  };
}

function createDraft(data) {
  const { to, subject, body, threadId, htmlBody, attachments } = data;
  let draft;

  const options = {};
  if (htmlBody) {
    options.htmlBody = htmlBody;
  } else if (body) {
    options.htmlBody = escapeHtml(body).split("\n").join("<br>");
  }

  if (attachments && attachments.length > 0) {
    options.attachments = attachments.map(function (a) {
      return Utilities.newBlob(
        Utilities.base64Decode(a.data),
        a.mimeType,
        a.name,
      );
    });
  }

  if (threadId) {
    const thread = GmailApp.getThreadById(threadId);
    if (!thread) return { error: "Thread not found" };
    draft = thread.createDraftReply(body || "", options);
  } else {
    if (!to || !subject)
      return { error: "to and subject are required for new drafts" };
    draft = GmailApp.createDraft(to, subject, body || "", options);
  }

  return { draftId: draft.getId(), status: "Draft created" };
}

function sendMessage(data) {
  const { to, subject, body, threadId, htmlBody, attachments } = data;

  const options = {};
  if (htmlBody) {
    options.htmlBody = htmlBody;
  } else if (body) {
    options.htmlBody = escapeHtml(body).split("\n").join("<br>");
  }

  if (attachments && attachments.length > 0) {
    options.attachments = attachments.map(function (a) {
      return Utilities.newBlob(
        Utilities.base64Decode(a.data),
        a.mimeType,
        a.name,
      );
    });
  }

  if (threadId) {
    const thread = GmailApp.getThreadById(threadId);
    if (!thread) return { error: "Thread not found" };
    thread.reply(body || "", options);
    return { status: "Reply sent" };
  }

  if (!to || !subject) return { error: "to and subject are required" };
  GmailApp.sendEmail(to, subject, body || "", options);
  return { status: "Message sent" };
}

function escapeHtml(text) {
  if (!text) return "";
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function archiveThread(threadId) {
  const thread = GmailApp.getThreadById(threadId);
  if (!thread) return { error: "Thread not found" };
  thread.moveToArchive();
  thread.markRead();
  return { status: "Archived and marked read" };
}

function applyLabel(threadId, labelName) {
  if (!threadId || !labelName)
    return { error: "threadId and labelName are required" };
  const thread = GmailApp.getThreadById(threadId);
  if (!thread) return { error: "Thread not found" };

  let label = GmailApp.getUserLabelByName(labelName);
  if (!label) label = GmailApp.createLabel(labelName);

  thread.addLabel(label);
  return { status: `Label '${labelName}' applied` };
}

function getProfile() {
  const email = Session.getActiveUser().getEmail();
  return { email, name: email.split("@")[0] };
}

function listLabels() {
  return GmailApp.getUserLabels().map((l) => ({
    id: l.getName(),
    name: l.getName(),
  }));
}

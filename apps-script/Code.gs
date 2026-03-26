// Sauver Gmail Backend — Google Apps Script Web App
// Deploy as: Execute as "Me", Who has access "Anyone"
// Docs: https://github.com/sauver-org/sauver

const SECRET_KEY = "CHANGE_ME"; // ← replaced by installer

function doGet(e) {
  const html = `
    <!DOCTYPE html>
    <html>
      <head>
        <base target="_top">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background: #0a0a0a; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          .card { background: #111; padding: 2rem; border-radius: 12px; border: 1px solid #222; text-align: center; max-width: 400px; box-shadow: 0 10px 40px rgba(0,0,0,0.8); }
          .icon { font-size: 3.5rem; margin-bottom: 1rem; filter: drop-shadow(0 0 10px rgba(255,255,255,0.1)); }
          h1 { margin: 0 0 1rem 0; font-size: 1.5rem; font-weight: 600; letter-spacing: -0.01em; }
          p { color: #999; margin: 0; line-height: 1.6; font-size: 0.95rem; }
          .status { display: inline-block; margin-top: 1.5rem; padding: 4px 12px; background: #1a2e1a; color: #4ade80; border-radius: 20px; font-size: 0.8rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon">🛡️</div>
          <h1>Sauver Backend Active</h1>
          <p>Your Gmail defense layer is successfully authorized and ready to protect your inbox.</p>
          <div class="status">Authorized</div>
          <p style="margin-top: 2rem; font-size: 0.8rem; color: #555;">You can now close this window and return to the terminal.</p>
        </div>
      </body>
    </html>
  `;
  return HtmlService.createHtmlOutput(html)
    .setTitle("Sauver | Backend Authorized")
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);

    if (data.key !== SECRET_KEY) {
      return json({ error: "Unauthorized" });
    }

    const handlers = {
      scan_inbox:      () => scanInbox(data.max_results || 10),
      search_messages: () => searchMessages(data.query, data.max_results || 10),
      get_message:     () => getMessage(data.messageId),
      create_draft:    () => createDraft(data),
      send_message:    () => sendMessage(data),
      archive_thread:  () => archiveThread(data.threadId),
      apply_label:     () => applyLabel(data.threadId, data.labelName),
      get_profile:     () => getProfile(),
      list_labels:     () => listLabels(),
    };

    const handler = handlers[data.action];
    if (!handler) return json({ error: `Unknown action: ${data.action}` });

    return json(handler());

  } catch (err) {
    return json({ error: err.toString() });
  }
}

function json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

// ── Actions ────────────────────────────────────────────────────────────────

function threadSummary(thread) {
  const messages = thread.getMessages();
  const msg      = messages[messages.length - 1];
  const plain    = msg.getPlainBody();
  return {
    threadId:  thread.getId(),
    messageId: msg.getId(),
    from:      msg.getFrom(),
    to:        msg.getTo(),
    subject:   msg.getSubject(),
    date:      msg.getDate().toISOString(),
    snippet:   plain.substring(0, 200),
  };
}

function scanInbox(maxResults) {
  // Fetch from the native inbox API (correct visual order), then filter unread.
  const threads = GmailApp.getInboxThreads(0, maxResults * 3);
  return threads.filter(t => t.isUnread()).slice(0, maxResults).map(threadSummary);
}

function searchMessages(query, maxResults) {
  // Use the native inbox API when possible — it returns threads in Gmail's
  // exact visual order, unlike GmailApp.search which can diverge.
  const threads = query.trim() === "in:inbox"
    ? GmailApp.getInboxThreads(0, maxResults)
    : GmailApp.search(query, 0, maxResults);
  return threads.map(threadSummary);
}

function getMessage(messageId) {
  const msg = GmailApp.getMessageById(messageId);
  if (!msg) return { error: "Message not found" };
  return {
    threadId:  msg.getThread().getId(),
    messageId: msg.getId(),
    from:      msg.getFrom(),
    to:        msg.getTo(),
    subject:   msg.getSubject(),
    date:      msg.getDate().toISOString(),
    body:      msg.getPlainBody(),
    htmlBody:  msg.getBody(),
  };
}

function createDraft(data) {
  const { to, subject, body, threadId } = data;
  let draft;

  if (threadId) {
    const thread = GmailApp.getThreadById(threadId);
    if (!thread) return { error: "Thread not found" };
    draft = thread.createDraftReply(body);
  } else {
    if (!to || !subject) return { error: "to and subject are required for new drafts" };
    draft = GmailApp.createDraft(to, subject, body);
  }

  return { draftId: draft.getId(), status: "Draft created" };
}

function sendMessage(data) {
  const { to, subject, body, threadId } = data;

  if (threadId) {
    const thread = GmailApp.getThreadById(threadId);
    if (!thread) return { error: "Thread not found" };
    thread.reply(body);
    return { status: "Reply sent" };
  }

  if (!to || !subject) return { error: "to and subject are required" };
  GmailApp.sendEmail(to, subject, body);
  return { status: "Message sent" };
}

function archiveThread(threadId) {
  const thread = GmailApp.getThreadById(threadId);
  if (!thread) return { error: "Thread not found" };
  thread.moveToArchive();
  thread.markRead();
  return { status: "Archived and marked read" };
}

function applyLabel(threadId, labelName) {
  if (!threadId || !labelName) return { error: "threadId and labelName are required" };
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
  return GmailApp.getUserLabels().map(l => ({ id: l.getName(), name: l.getName() }));
}

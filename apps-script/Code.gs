// Sauver Gmail Backend — Google Apps Script Web App
// Deploy as: Execute as "Me", Who has access "Anyone"
// Docs: https://github.com/mszczodrak/sauver

const SECRET_KEY = "CHANGE_ME"; // ← replaced by installer

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

function threadToResult(thread) {
  const messages = thread.getMessages();
  const msg      = messages[messages.length - 1];
  const plain    = msg.getPlainBody();
  const html     = msg.getBody();
  return {
    threadId:      thread.getId(),
    messageId:     msg.getId(),
    from:          msg.getFrom(),
    to:            msg.getTo(),
    subject:       msg.getSubject(),
    date:          msg.getDate().toISOString(),
    body:          plain.substring(0, 3000),
    htmlBody:      html.substring(0, 6000),
    bodyTruncated: plain.length > 3000 || html.length > 6000,
  };
}

function scanInbox(maxResults) {
  // Fetch from the native inbox API (correct visual order), then filter unread.
  const threads = GmailApp.getInboxThreads(0, maxResults * 3);
  return threads.filter(t => t.isUnread()).slice(0, maxResults).map(threadToResult);
}

function searchMessages(query, maxResults) {
  // Use the native inbox API when possible — it returns threads in Gmail's
  // exact visual order, unlike GmailApp.search which can diverge.
  const threads = query.trim() === "in:inbox"
    ? GmailApp.getInboxThreads(0, maxResults)
    : GmailApp.search(query, 0, maxResults);
  return threads.map(threadToResult);
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

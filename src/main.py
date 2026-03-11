import base64
import json
import os
import re
import secrets
from email.message import EmailMessage
from pathlib import Path

from fastmcp import FastMCP
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

# Scopes needed to read and modify drafts. Using gmail.modify to create drafts without sending.
SCOPES = ["https://www.googleapis.com/auth/gmail.modify"]

mcp = FastMCP("Sauver")


def get_gmail_service():  # type: ignore[no-untyped-def]
    """
    Authenticate with Google Workspace locally and return the Gmail API service instance.
    """
    creds = None
    token_file = Path("token.json")
    credentials_file = Path(os.getenv("GMAIL_CREDENTIALS_PATH", "credentials.json"))

    if token_file.exists():
        creds = Credentials.from_authorized_user_file(str(token_file), SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(str(credentials_file), SCOPES)
            creds = flow.run_local_server(port=0)

        with token_file.open("w") as token:
            token.write(creds.to_json())

    return build("gmail", "v1", credentials=creds)


@mcp.tool()
def tracker_shield(html_content: str) -> str:
    """
    Automated identification and stripping of 1x1 tracking pixels and spy-links.

    Args:
        html_content: The HTML body of the email.

    Returns:
        A JSON string containing the cleaned HTML and the number of trackers neutralized.
    """
    tracker_patterns = [
        r'<img[^>]*width=["\']?1["\']?[^>]*height=["\']?1["\']?[^>]*>',
        r'<img[^>]*height=["\']?1["\']?[^>]*width=["\']?1["\']?[^>]*>',
    ]

    trackers_neutralized = 0
    cleaned_html = html_content

    for pattern in tracker_patterns:
        matches = re.findall(pattern, cleaned_html, re.IGNORECASE)
        trackers_neutralized += len(matches)
        cleaned_html = re.sub(pattern, "", cleaned_html, flags=re.IGNORECASE)

    return json.dumps(
        {
            "trackers_neutralized": trackers_neutralized,
            "cleaned_html": cleaned_html,
        }
    )


@mcp.tool()
def bouncer_reply(
    to_email: str,
    subject: str,
    original_message_id: str,
    sender_name: str,
    topic: str,
) -> str:
    """
    Generates a "Time-Sink" draft to engage detected spammers.
    Creates a DRAFT in Gmail. It NEVER sends the email directly.

    Args:
        to_email: The email address of the spammer/marketer.
        subject: The subject of the email (usually 'Re: <original subject>').
        original_message_id: The Message-ID of the email we are replying to.
        sender_name: The name of the spammer/marketer to address them.
        topic: The topic they pitched, to incorporate into the confusing reply.

    Returns:
        Status message about the created draft.
    """
    time_sink_prompts = [
        f"Hi {sender_name},\n\nI am incredibly interested in what you're offering "
        f"regarding {topic}! However, my IT department requires all new vendors to "
        "provide their data transmission protocols on floppy disk or via ISDN. "
        "Can you confirm if you support this?",
        f"Hello {sender_name},\n\nThanks for reaching out about {topic}. This is "
        "exactly what we need for our Q3 alignment strategy! Before we proceed, "
        "could you clarify how your solution integrates with our bespoke OS/2 Warp "
        "mainframe? We had issues with the last vendor.",
        f"Dear {sender_name},\n\nFascinating pitch on {topic}. I'm forwarding this "
        "to our procurement team immediately. Quick question: does your pricing model "
        "account for leap years and lunar phases? Our billing cycle is strictly tied "
        "to the Julian calendar. Please advise.",
    ]

    reply_body = secrets.choice(time_sink_prompts)

    try:
        service = get_gmail_service()

        message = EmailMessage()
        message.set_content(reply_body)
        message["To"] = to_email
        message["Subject"] = subject
        message["In-Reply-To"] = original_message_id
        message["References"] = original_message_id

        encoded_message = base64.urlsafe_b64encode(message.as_bytes()).decode()
        create_message = {"message": {"raw": encoded_message}}

        draft = service.users().drafts().create(userId="me", body=create_message).execute()
        return f"Draft created successfully. Draft ID: {draft['id']}. Trap laid."
    except Exception as e:
        return f"Failed to create draft: {e!s}"


if __name__ == "__main__":
    mcp.run()

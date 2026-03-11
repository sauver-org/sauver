import json
import re
import secrets

from fastmcp import FastMCP

mcp = FastMCP("Sauver")


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
        r'<img[^>]*src=["\'][^"\']*(?:email-tracking|tracker|pixel|open-pixel)[^"\']*["\'][^>]*>',
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
    sender_name: str,
    topic: str,
) -> str:
    """
    Generates the text for a "Time-Sink" reply to engage detected spammers.
    This does NOT send the email. It provides the content for the Gemini CLI
    to create a draft using the gmail.createDraft tool.

    Args:
        sender_name: The name of the spammer/marketer to address them.
        topic: The topic they pitched, to incorporate into the confusing reply.

    Returns:
        The text body for the time-sink reply.
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

    return secrets.choice(time_sink_prompts)


if __name__ == "__main__":
    mcp.run()

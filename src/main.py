import json
import os
import re

from fastmcp import FastMCP

mcp = FastMCP("Sauver")


CONFIG_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".sauver-config.json")


def load_config() -> dict:
    """Loads the user configuration, using defaults if not found."""
    defaults = {
        "auto_draft": True,
        "yolo_mode": False,  # Auto-send
        "treat_job_offers_as_slop": True,
        "quarantine_folder": "Quarantine",
    }
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE) as f:
                return {**defaults, **json.load(f)}
        except (json.JSONDecodeError, OSError):
            pass
    return defaults


@mcp.tool()
def get_config() -> str:
    """
    Retrieves the current Sauver configuration.

    Returns:
        A JSON string of the configuration settings.
    """
    return json.dumps(load_config(), indent=2)


@mcp.tool()
def update_config(updates: dict) -> str:
    """
    Updates specific configuration settings.

    Args:
        updates: A dictionary of settings to update (e.g., {"yolo_mode": True}).

    Returns:
        A confirmation message with the updated configuration.
    """
    config = load_config()
    config.update(updates)
    try:
        with open(CONFIG_FILE, "w") as f:
            json.dump(config, f, indent=2)
        return f"Configuration updated successfully:\n{json.dumps(config, indent=2)}"
    except OSError as e:
        return f"Error saving configuration: {e}"


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


if __name__ == "__main__":
    mcp.run()

import json
import re
import sys
from pathlib import Path

from fastmcp import FastMCP

mcp = FastMCP("Sauver")


CONFIG_FILE = Path(__file__).parent.parent / ".sauver-config.json"


def load_config() -> dict:
    """Loads the user configuration, using defaults if not found."""
    defaults = {
        "auto_draft": True,
        "yolo_mode": False,  # Auto-send
        "treat_job_offers_as_slop": True,
        "treat_unsolicited_investors_as_slop": True,
        "sauver_label": "Sauver",
    }
    if CONFIG_FILE.exists():
        try:
            with CONFIG_FILE.open() as f:
                return {**defaults, **json.load(f)}
        except (json.JSONDecodeError, OSError):
            pass
    return defaults


@mcp.tool()
def get_sauver_config() -> str:
    """
    Retrieves the current Sauver configuration.

    Returns:
        A JSON string of the configuration settings.
    """
    return json.dumps(load_config(), indent=2)


VALID_CONFIG_KEYS = frozenset(
    {
        "auto_draft",
        "yolo_mode",
        "treat_job_offers_as_slop",
        "treat_unsolicited_investors_as_slop",
        "sauver_label",
    }
)


@mcp.tool()
def set_sauver_config(updates: dict[str, object]) -> str:
    """
    Updates specific Sauver configuration settings.

    Args:
        updates: A dictionary of settings to update (e.g., {"yolo_mode": True}).

    Returns:
        A confirmation message with the updated configuration.
    """
    unknown = set(updates) - VALID_CONFIG_KEYS
    if unknown:
        return f"Error: unknown configuration key(s): {', '.join(sorted(unknown))}"
    config = load_config()
    config.update(updates)
    try:
        with CONFIG_FILE.open("w") as f:
            json.dump(config, f, indent=2)
        return f"Configuration updated successfully:\n{json.dumps(config, indent=2)}"
    except OSError as e:
        return f"Error saving configuration: {e}"


@mcp.tool()
def start_sauver_config_wizard() -> str:
    """
    Guides the user on how to run the interactive configuration wizard.
    The wizard must be run in the terminal for interactivity.

    Returns:
        Instructions on how to run the wizard.
    """
    return (
        "To start the interactive Sauver Configuration Wizard, please run the following "
        "command in your terminal:\n\n"
        "uv run src/main.py configure\n\n"
        "This will allow you to set your preferences with an interactive, color-coded flow."
    )


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
        # 1x1 pixel by dimensions (width before height)
        r'<img[^>]*width=["\']?1["\']?[^>]*height=["\']?1["\']?[^>]*>',
        # 1x1 pixel by dimensions (height before width)
        r'<img[^>]*height=["\']?1["\']?[^>]*width=["\']?1["\']?[^>]*>',
        # Known tracking URL keywords in src
        r'<img[^>]*src=["\'][^"\']*(?:email-tracking|open-pixel)[^"\']*["\'][^>]*>',
        # Known tracking domains in src (regardless of dimensions)
        r'<img[^>]*src=["\'][^"\']*(?:'
        r"hubspot\.com|mailtrack\.io|sidekickopen|pixel\.google\.com"
        r"|trk\.klick|tracking\.|open-tracking|track\.goog"
        r"|sendgrid\.net/wf/open|list-manage\.com/track|exacttarget\.com"
        r"|pardot\.com|marketo\.net|eloqua\.com"
        r')[^"\']*["\'][^>]*>',
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


def run_configure() -> None:
    """Runs an interactive configuration wizard in the terminal."""
    config = load_config()

    # ANSI color codes
    bold = "\033[1m"
    yellow = "\033[93m"
    reset = "\033[0m"

    def ask_bool(question: str, key: str) -> bool:
        current = config.get(key, True)
        d_str = "Y/n" if current else "y/N"
        res = input(f"{bold}{question}{reset} [{yellow}{d_str}{reset}]: ").lower().strip()
        if not res:
            return bool(current)
        return res == "y"

    def ask_str(question: str, key: str, default: str = "") -> str:
        current = config.get(key, default)
        res = input(f"{bold}{question}{reset} [{yellow}{current}{reset}]: ").strip()
        return res if res else current

    # 1. Auto Draft
    config["auto_draft"] = ask_bool(
        "Should Sauver automatically create draft replies to slop?", "auto_draft"
    )

    # 2. YOLO Mode
    config["yolo_mode"] = ask_bool("Enable YOLO mode (Auto-Send)?", "yolo_mode")

    # 3. Job Slop
    config["treat_job_offers_as_slop"] = ask_bool(
        "Treat recruiter outreach as slop?", "treat_job_offers_as_slop"
    )

    # 4. Investor Slop
    config["treat_unsolicited_investors_as_slop"] = ask_bool(
        "Treat unsolicited investor outreach as slop?", "treat_unsolicited_investors_as_slop"
    )

    # 5. Sauver Label
    config["sauver_label"] = ask_str("Gmail label to apply when archiving?", "sauver_label")

    # Save
    try:
        with CONFIG_FILE.open("w") as f:
            json.dump(config, f, indent=2)
        print("\033[92mConfiguration saved.\033[0m")  # noqa: T201
    except OSError as e:
        print(f"\033[91mError: could not save configuration: {e}\033[0m")  # noqa: T201


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "configure":
        run_configure()
    else:
        mcp.run()

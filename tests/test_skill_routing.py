"""
Tests that verify the Sauver skill triggers on the right user queries.

Each test sends a query to Claude (claude-haiku-4-5) with the skill descriptions
as context and checks whether Claude decides to invoke a Sauver skill. This
mirrors how Claude Code actually routes user messages.

Requires ANTHROPIC_API_KEY to be set; tests are skipped otherwise.
"""

import json
import os

import anthropic
import pytest

# ---------------------------------------------------------------------------
# Queries that SHOULD cause Claude to invoke a Sauver skill
# ---------------------------------------------------------------------------
SHOULD_TRIGGER: list[str] = [
    # Full pipeline
    "Triage my inbox",
    "Clean up my unread emails and deal with any spam",
    "Run the inbox pipeline on my recent messages",
    # Slop-detector
    "I got a cold recruiting email, can you handle it with the expert-domain trap?",
    "A recruiter found my LinkedIn and wants to discuss an opportunity — shut it down",
    "Deploy slop detection on this recruiter pitch I just received",
    # Investor-trap
    "A family office reached out wanting to invest in my startup — run the due diligence loop",
    "Some VC cold-emailed me about raising a Series A. Waste their time.",
    # Bouncer-reply
    "Generate a confusing time-sink reply to this SaaS marketing email",
    "This SEO agency keeps spamming me — craft a bouncer reply",
    # Tracker-shield
    "Strip all tracking pixels and spy-links from this email body",
    "Purify this newsletter HTML from open-tracking beacons",
]

# ---------------------------------------------------------------------------
# Queries that should NOT trigger any Sauver skill
# ---------------------------------------------------------------------------
SHOULD_NOT_TRIGGER: list[str] = [
    # Coding / engineering
    "Write a Python function that parses a JSON file",
    "Help me debug this TypeScript compilation error",
    "Explain the difference between TCP and UDP",
    "How do I configure nginx as a reverse proxy?",
    "Review this pull request and suggest improvements",
    "Generate a commit message for my staged changes",
    "What are best practices for PostgreSQL indexing?",
    # General knowledge
    "What is the capital of France?",
    "Summarize this Wikipedia article for me",
    "What's a good recipe for banana bread?",
]

# ---------------------------------------------------------------------------
# System prompt — mirrors the skill descriptions Claude Code sees
# ---------------------------------------------------------------------------
_ROUTER_SYSTEM_PROMPT = """
You are a router for the Sauver email defense system. Your only job is to decide
whether the user's message is asking to invoke any of the following Sauver skills:

  - sauver        : Run the full inbox triage pipeline on recent unread emails
  - slop-detector : Analyze an email for recruiter/sales slop and deploy the Expert-Domain Trap
  - investor-trap : Identify unsolicited investor outreach and deploy the Due Diligence Loop
  - bouncer-reply : Generate a Time-Sink Trap reply for a spam or marketing email
  - tracker-shield: Purify an email by finding and stripping tracking pixels, spy-links, and beacons

A query triggers Sauver if — and only if — it is asking to perform one of those five
actions (email triage, slop handling, tracker removal, spam replies). Anything else —
coding help, general knowledge, non-email tasks — does NOT trigger Sauver.

Respond with a JSON object and nothing else:
{"triggers_sauver": true}   — if the query maps to any Sauver skill
{"triggers_sauver": false}  — if it does not
""".strip()


# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------
@pytest.fixture(scope="module")
def claude() -> anthropic.Anthropic:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        pytest.skip("ANTHROPIC_API_KEY is not set")
    return anthropic.Anthropic(api_key=api_key)


def _classify(client: anthropic.Anthropic, query: str) -> bool:
    """Ask Claude whether a query should trigger a Sauver skill."""
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=64,
        system=_ROUTER_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": query}],
    )
    text = message.content[0].text.strip()  # type: ignore[union-attr]
    return bool(json.loads(text)["triggers_sauver"])


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
@pytest.mark.parametrize("query", SHOULD_TRIGGER)
def test_query_triggers_skill(claude: anthropic.Anthropic, query: str) -> None:
    assert _classify(claude, query), f"Expected to trigger Sauver skill, but did not: {query!r}"


@pytest.mark.parametrize("query", SHOULD_NOT_TRIGGER)
def test_query_does_not_trigger_skill(claude: anthropic.Anthropic, query: str) -> None:
    assert not _classify(claude, query), f"Expected NOT to trigger Sauver skill, but did: {query!r}"

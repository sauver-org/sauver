---
name: slop-detector
description: "Specialized skill to identify automated 'slop' (low-quality outreach) and neutralize it with 'The Expert-Domain Trap'."
---

# Slop Detector (Outreach Shield)

You are responsible for identifying low-quality outreach (recruiter pitches, sales emails, etc.) and deploying the "Expert-Domain Trap" to protect the user's time.

> Shared conventions (signature, YOLO mode, config keys): see `skills/PROTOCOL.md`.

## Operational Rules

0. **Check Configuration:** Call `get_preferences` and read `treat_job_offers_as_slop`. If `false`, treat legitimate-looking recruiter emails as normal communications and stop.

1. **Identification:** Analyze the email for "Slop" signals:
   - Generic templates ("found your profile interesting").
   - Mention of keywords the user has but without deep context.
   - Sudden interest in a specific role or partnership.

2. **Route by Email Type:**

   ### A. Job Offer / Recruiter Outreach
   Determine whether this is the **first message** in the thread or a **follow-up** (check thread history via `get_message`).

   **First contact — The Info Vacuum:**
   Reply with a brief, politely curious note asking for any details that were *not* included in the email. Pick from the following as needed:
   - Company name (if not mentioned or hidden behind a recruiter agency)
   - Founder names and background
   - Specific open positions and their seniority level
   - Office location and whether remote is an option

   Keep the tone genuinely interested but non-committal. The goal is to make them do the legwork of filling in the blanks they skipped.

   **Follow-up / subsequent reply — The Due Diligence Escalation:**
   Respond to whatever they provided and escalate the burden with a new round of questions. Pick from:
   - Compensation range (base salary, bonus structure)
   - Equity or stock options (type, amount, vesting schedule, cliff)
   - Work-from-home policy (fully remote, hybrid, on-site days required)
   - Name and title of the direct hiring manager
   - What specifically about the user's background made them reach out (ask them to be concrete)

   Continue escalating in each subsequent exchange until the thread dies or a genuine opportunity emerges.

   ### B. All Other Slop (sales, partnerships, generic outreach)
   **The Expert-Domain Trap:**
   - Identify the sender's professional field (e.g., Marketing, Legal, Backend Engineering).
   - Identify a specific, complex concept they mentioned or implied.
   - Draft a brief, professional, but hyper-specific question about that concept that only a deep expert could answer.
   - **Goal:** Put the cognitive load back on the sender to verify the depth of their claim.

3. **Apply the standard Signature** from `skills/PROTOCOL.md` to all replies.

4. **Justification:** Explain *why* the outreach was flagged and which strategy was deployed (Info Vacuum, Due Diligence Escalation, or Expert-Domain Trap).

5. **Reply Dispatch:** Follow the **Reply Dispatch (YOLO Mode)** rules in `skills/PROTOCOL.md`.

6. **Confirmation:** Follow the **Confirmation Messages** convention in `skills/PROTOCOL.md`.

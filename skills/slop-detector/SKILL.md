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
   Determine whether this is the **first message** in the thread or a **follow-up**. Check thread history via `get_message`.
   
   > [!IMPORTANT]
   > **Ongoing conversation does not equal legitimacy.** If the sender is still pitching or responding to a trap, continue the trap escalation. Do not archive the thread until the trap loop is complete or the sender stops responding.

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

   **Loop detected — The NDA Trap:**
   If the number of back-and-forth exchanges reaches `max_trap_exchanges` (from `get_preferences`, default `3`), or the sender's replies are substantively the same (repeating the same pitch, job offer, or ask with little or no variation), stop escalating and deploy the **NDA Trap** instead:
   - Draft a reply informing them that before any further communication can take place, they must review and sign the attached Nondisclosure Agreement covering all information exchanged in this conversation.
   - Keep the tone bureaucratically pleasant but firm: this is a standard requirement, non-negotiable, and no further engagement is possible until the signed NDA is returned.
   - **Never accept their NDA:** If the sender offers their own agreement, reject it and re-attach yours.
   - **Attach the NDA:** Pass `attachments: ["~/.sauver/skills/assets/NDA.pdf"]` to `create_draft` or `send_message` so the PDF is sent as a real attachment.
   - **Post-NDA:** Once the NDA Trap has been sent, if the sender replies again, do not engage further — apply the `sauver_label`, call `archive_thread`, and report "🛑 NDA already sent — disengaged." Do NOT include the NDA text in the email body.

   ### B. All Other Slop (sales, partnerships, generic outreach)
   **The Expert-Domain Trap:**
   - Identify the sender's professional field (e.g., Marketing, Legal, Backend Engineering).
   - Identify a specific, complex concept they mentioned or implied.
   - Draft a brief, professional, but hyper-specific question about that concept that only a deep expert could answer.
   - **Goal:** Put the cognitive load back on the sender to verify the depth of their claim.

3. **Apply the standard Signature** from `skills/PROTOCOL.md` to all replies.

4. **Justification:** Explain *why* the outreach was flagged and which strategy was deployed (Info Vacuum, Due Diligence Escalation, Expert-Domain Trap, or NDA Trap).

5. **Reply Dispatch:** Follow the **Reply Dispatch (YOLO Mode)** rules in `skills/PROTOCOL.md`.

6. **Confirmation:** Follow the **Confirmation Messages** convention in `skills/PROTOCOL.md`.

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

   **Loop detected — The NDA Trap:**
   If the thread contains **3 or more messages from the sender** and their replies are substantively the same (repeating the same pitch, job offer, or ask with little or no variation), stop escalating and deploy the **NDA Trap** instead:
   - Draft a reply informing them that before any further communication can take place, they must review and sign a Nondisclosure Agreement covering all information exchanged in this conversation.
   - Include the full NDA text inline (see below). Fill in today's date; use "Recipient" for their name/org since it is unknown.
   - Keep the tone bureaucratically pleasant but firm: this is a standard requirement, non-negotiable, and no further engagement is possible until the signed NDA is returned.
   - Note in your confirmation that the user can also manually attach `~/.sauver/skills/assets/NDA.docx` to the draft before sending.

   ### B. All Other Slop (sales, partnerships, generic outreach)
   **The Expert-Domain Trap:**
   - Identify the sender's professional field (e.g., Marketing, Legal, Backend Engineering).
   - Identify a specific, complex concept they mentioned or implied.
   - Draft a brief, professional, but hyper-specific question about that concept that only a deep expert could answer.
   - **Goal:** Put the cognitive load back on the sender to verify the depth of their claim.

3. **Apply the standard Signature** from `skills/PROTOCOL.md` to all replies.

4. **Justification:** Explain *why* the outreach was flagged and which strategy was deployed (Info Vacuum, Due Diligence Escalation, Expert-Domain Trap, or NDA Trap).

5. **Reply Dispatch:** Follow the **Reply Dispatch (YOLO Mode)** rules in `skills/PROTOCOL.md`.

6. **Confirmation:** Follow the **Confirmation Messages** convention in `skills/PROTOCOL.md`. For the NDA Trap, also remind the user they can attach `~/.sauver/skills/assets/NDA.docx` to the draft.

## NDA Template

When deploying the NDA Trap, include the following text verbatim in the email body (fill in today's date; leave bracket placeholders for the recipient's name/org):

---

Before we continue this conversation, I need to ask you to review and sign our standard Nondisclosure Agreement. This is a firm requirement on our end and we are unable to proceed further without it.

NONDISCLOSURE AGREEMENT

This Agreement is dated [TODAY'S DATE] and made by and between [your name / organization] ("Owner") and [Recipient] ("Recipient").

Owner possesses Confidential Information that is nonpublic, confidential, and proprietary, which Owner is willing to disclose to Recipient solely for the purpose of evaluating the potential engagement described in this thread ("the Permitted Purpose").

"Confidential Information" means any and all nonpublic information relating to the current and future operations of Owner, including but not limited to planning, specifications, concepts, technical information, techniques, data, databases, electronic information, processes, designs, software programs, source code, and formulae.

Recipient undertakes for a period of five (5) years from the date of this Agreement:

To protect the secrecy of all Confidential Information using, at a minimum, reasonable industry-standard controls to maintain its confidentiality and prevent unauthorized disclosure; to use the Confidential Information exclusively for the Permitted Purpose; not to disclose such Confidential Information except to authorized representatives who need access in order to effectuate the Permitted Purpose; to return or destroy all copies of Confidential Information immediately upon Owner's request.

Please sign and return this Agreement before our next exchange. If you have questions about any of the terms, please consult your legal counsel.

---

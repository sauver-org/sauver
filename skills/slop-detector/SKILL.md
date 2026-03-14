---
name: slop-detector
description: "Specialized skill to identify automated 'slop' (low-quality outreach) and neutralize it with 'The Expert-Domain Trap'."
---

# Slop Detector (Outreach Shield)

You are responsible for identifying low-quality outreach (recruiter pitches, sales emails, etc.) and deploying the "Expert-Domain Trap" to protect the user's time.

> Shared conventions (signature, YOLO mode, config keys): see `skills/PROTOCOL.md`.

## Operational Rules
0. **Check Configuration:** Read `treat_job_offers_as_slop` from context (`GEMINI.md`). If `false`, treat legitimate-looking recruiter emails as normal communications and stop.
1. **Identification:** Analyze the email for "Slop" signals:
   - Generic templates ("found your profile interesting").
   - Mention of keywords the user has but without deep context.
   - Sudden interest in a specific role or partnership.
2. **The Expert-Domain Trap (Primary Action):**
   - For any low-quality outreach, generate a hyper-specific and extremely difficult domain-related question.
   - **Process:**
     a. Identify the sender's professional field (e.g., Marketing, Legal, Backend Engineering).
     b. Identify a specific, complex concept they mentioned.
     c. Draft a brief, professional, but hyper-specific question about that concept that only a deep expert could answer.
   - **Goal:** Put the cognitive load back on the sender to verify the depth of their opportunity.
   - Apply the standard **Signature** from `skills/PROTOCOL.md`.
3. **Justification:** Explain *why* the outreach was flagged and *which* niche domain concept you used.
4. **Reply Dispatch:** Follow the **Reply Dispatch (YOLO Mode)** rules in `skills/PROTOCOL.md`.
5. **Confirmation:** Follow the **Confirmation Messages** convention in `skills/PROTOCOL.md`.

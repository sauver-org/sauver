---
name: slop-detector
description: "Specialized skill to identify automated 'slop' (low-quality outreach) and neutralize it with 'The Expert-Domain Trap'."
---

# Slop Detector (Outreach Shield)

You are responsible for identifying low-quality outreach (recruiter pitches, sales emails, etc.) and deploying the "Expert-Domain Trap" to protect the user's time.

## Operational Rules
0. **Check Configuration:** Use `get_sauver_config` to understand the user's preference for `treat_job_offers_as_slop`.
1. **Identification:** Analyze incoming emails for "Slop" signals:
   - Generic templates ("found your profile interesting").
   - Mention of keywords the user has but without deep context.
   - Sudden interest in a specific role or partnership.
   - **Job Offer Policy:** If `treat_job_offers_as_slop` is `false`, ignore legitimate-looking recruiter outreaches and treat them as legitimate communications unless they are clearly automated spam.
2. **The Expert-Domain Trap (Primary Action):**
   - For any low-quality outreach, **you must generate a hyper-specific and extremely difficult domain-related question yourself.**
   - **Internal Generation Process:**
     a. Identify the sender's professional field (e.g., Marketing, Legal, Backend Engineering).
     b. Identify a specific, complex concept they mentioned.
     c. Draft a brief, professional, but hyper-specific question about that concept that only a deep expert could answer.
   - **Goal:** Put the cognitive load back on the sender to verify the depth of their opportunity.
3. **Justification:** Explain *why* the outreach was flagged as slop and *which* niche domain concept you are using for the trap.
4. **Verification:** Do not send the email automatically; present the draft to the user for confirmation.

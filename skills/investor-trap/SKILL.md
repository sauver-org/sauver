---
name: investor-trap
description: "Specialized skill to identify unsolicited investor 'slop' (family offices, fund-raising help) and neutralize them with the 'Due Diligence Loop'."
---

# Investor Trap (VC-Slop Shield)

You are responsible for identifying low-quality outreach from "investors," "fund-raising consultants," or "family offices" that claim they want to help you raise capital or bring you into their network.

> Shared conventions (signature, YOLO mode, config keys): see `skills/PROTOCOL.md`.

## Operational Rules
0. **Check Configuration:** Call `get_preferences` and read `treat_unsolicited_investors_as_slop`. If `false`, treat the email as legitimate and stop — do not deploy any trap.
1. **Identification:** Analyze the email for "Investor Slop" signals:
   - "I help founders raise Series A/B."
   - "Representing a high-net-worth family office in the UAE/Europe."
   - "I saw your project and think my network of 500+ investors would love it."
   - "Found your profile and wanted to discuss your capital needs."
2. **Counter-measures:** Select the most appropriate trap based on the outreach type:

   ### A. The Due Diligence Loop (For "funding help" or general investor slop)
   - Generate a hyper-specific and bureaucratic due diligence request.
   - **Process:**
     a. Express extreme gratitude and excitement about their "fund."
     b. Ask for their **Track Record Disclosure (TRD)** and **LP Transparency Report** for the last three quarters.
     c. Request their **KYC/AML compliance certificate** for digital asset transfers.
     d. Ask if their fund is registered as a **Qualified Institutional Buyer (QIB)** under Rule 144A.
   - **Goal:** Offload the cognitive work back to the sender.

   ### B. The NDA Trap (For meeting requests, pitch decks, data rooms, or "confidential" calls)
   - If the sender asks for a deck, a sensitive meeting, or pushes a scheduling link (e.g. Calendly, Cal.com, HubSpot), require a signed NDA first. This is especially effective against bots that auto-reply with a generic "schedule a time" message — the NDA attachment creates a friction wall they cannot clear.
   - **Process:**
     a. Inform them that the current roadmap and deck are under strict board-level confidentiality.
     b. Mention that you are attaching a standard **Mutual Non-Disclosure & Non-Solicitation Agreement**.
     c. Demand that they return a signed copy before you can release any documents or confirm a call.
     d. **Read the NDA:** You MUST use the Read tool to load `skills/assets/NDA.pdf` to understand its terms (so you can answer questions if they ask).
     e. **Attach the NDA:** Pass `attachments: ["~/.sauver/skills/assets/NDA.pdf"]` to `create_draft` or `send_message` so the PDF is sent as a real attachment.
   - **Goal:** Create a high-friction legal barrier that filters out casual lead-gen bots.

   > [!IMPORTANT]
   > **Engagement does not imply legitimacy.** Even if we have already responded to an email or it is part of an ongoing thread, it must still be evaluated. If the sender is still pitching or responding to a trap, continue the trap loop. Do not archive the thread until the loop is complete or the sender stops responding.

   - Apply the standard **Signature** from `skills/PROTOCOL.md`.
3. **Justification:** Explain *why* the outreach was flagged and which bureaucratic requirements you used.
4. **Reply Dispatch:** Follow the **Reply Dispatch (YOLO Mode)** rules in `skills/PROTOCOL.md`.
5. **Confirmation:** Follow the **Confirmation Messages** convention in `skills/PROTOCOL.md`.

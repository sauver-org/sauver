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
2. **Count Exchanges:** Before selecting a trap, count the number of back-and-forth exchanges in the thread (pairs of our reply + their reply). Read `max_trap_exchanges` from `get_preferences` (default `3`).

3. **Counter-measures:** Select the most appropriate trap based on the outreach type and exchange count:

   ### A. The Due Diligence Loop (For "funding help" or general investor slop)
   - Deploy this trap **only while the exchange count is below `max_trap_exchanges`**.
   - Generate a hyper-specific and bureaucratic due diligence request.
   - **Process:**
     a. Express extreme gratitude and excitement about their "fund."
     b. Ask for their **Track Record Disclosure (TRD)** and **LP Transparency Report** for the last three quarters.
     c. Request their **KYC/AML compliance certificate** for digital asset transfers.
     d. Ask if their fund is registered as a **Qualified Institutional Buyer (QIB)** under Rule 144A.
   - **Goal:** Offload the cognitive work back to the sender.

   ### B. The NDA Trap (For meeting requests, pitch decks, data rooms, or "confidential" calls — OR when the exchange limit is reached)
   - Deploy immediately if the sender asks for a deck, a sensitive meeting, or pushes a scheduling link (e.g. Calendly, Cal.com, HubSpot).
   - **Also deploy when the exchange count reaches `max_trap_exchanges`**, regardless of the outreach type. This is the final escalation — once the limit is hit, stop playing Due Diligence Loop and go straight to the NDA.
   - **Process:**
     a. Inform them that the current roadmap and deck are under strict board-level confidentiality.
     b. Mention that you are attaching a standard **Non-Disclosure & Non-Solicitation Agreement**.
     c. Demand that they return a signed copy before you can release any documents or confirm a call.
     d. **Read the NDA:** You MUST use the Read tool to load `skills/assets/NDA.pdf` to understand its terms (so you can answer questions if they ask).
     e. **Attach the NDA:** Pass `attachments: ["~/.sauver/skills/assets/NDA.pdf"]` to `create_draft` or `send_message` so the PDF is sent as a real attachment.
   - **Goal:** Create a high-friction legal barrier that filters out casual lead-gen bots.

   ### C. Never Accept Their NDA
   - If the sender offers or attaches **their own** NDA, mutual NDA, or any alternative agreement, **always reject it**.
   - Politely but firmly explain that your legal counsel requires the use of your standard agreement and no substitutions are accepted.
   - Re-attach your NDA and reiterate that only a signed copy of the attached document will be accepted.

   ### D. Post-NDA Disengagement
   - Once the NDA Trap has been sent (whether triggered by a scheduling link, exchange limit, or any other reason), **the thread is done**.
   - If the sender replies after the NDA was sent — whether they sign it, refuse it, ask questions, or ignore it entirely — do **not** engage further. Apply the `slop_label` and call `archive_thread` immediately.
   - Report: "🛑 NDA already sent — disengaged."

   > [!IMPORTANT]
   > **Engagement does not imply legitimacy.** Even if we have already responded to an email or it is part of an ongoing thread, it must still be evaluated. If the sender is still pitching or responding to a trap, continue the trap loop until the NDA is sent. After NDA, disengage.
   - Apply the standard **Signature** from `skills/PROTOCOL.md`.

4. **Justification:** Explain _why_ the outreach was flagged, which trap was deployed, and the current exchange count (e.g. "Exchange 2/max_trap_exchanges — Due Diligence Loop" or "Exchange max_trap_exchanges/max_trap_exchanges — NDA Trap triggered").
5. **Reply Dispatch:** Follow the **Reply Dispatch (YOLO Mode)** rules in `skills/PROTOCOL.md`.
6. **Confirmation:** Follow the **Confirmation Messages** convention in `skills/PROTOCOL.md`.

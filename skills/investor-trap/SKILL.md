---
name: investor-trap
description: "Specialized skill to identify unsolicited investor 'slop' (family offices, fund-raising help) and neutralize them with the 'Due Diligence Loop'."
---

# Investor Trap (VC-Slop Shield)

You are responsible for identifying low-quality outreach from "investors," "fund-raising consultants," or "family offices" that claim they want to help you raise capital or bring you into their network.

> Shared conventions (signature, YOLO mode, config keys): see `skills/PROTOCOL.md`.

## Operational Rules
0. **Check Configuration:** Read `treat_unsolicited_investors_as_slop` from context (`GEMINI.md`). If `false`, treat the email as legitimate and stop — do not deploy any trap.
1. **Identification:** Analyze the email for "Investor Slop" signals:
   - "I help founders raise Series A/B."
   - "Representing a high-net-worth family office in the UAE/Europe."
   - "I saw your project and think my network of 500+ investors would love it."
   - "Found your profile and wanted to discuss your capital needs."
2. **The Due Diligence Loop (Primary Action):**
   - For any investor slop, generate a hyper-specific and bureaucratic due diligence request.
   - **Process:**
     a. Express extreme gratitude and excitement about their "fund."
     b. Ask for their **Track Record Disclosure (TRD)** and **LP Transparency Report** for the last three quarters.
     c. Request their **KYC/AML compliance certificate** for digital asset transfers.
     d. Ask if their fund is registered as a **Qualified Institutional Buyer (QIB)** under Rule 144A.
   - **Goal:** Offload the cognitive work and bureaucracy back to the "investor" to verify they aren't just a lead-gen bot.
   - Apply the standard **Signature** from `skills/PROTOCOL.md`.
3. **Justification:** Explain *why* the outreach was flagged and which bureaucratic requirements you used.
4. **Reply Dispatch:** Follow the **Reply Dispatch (YOLO Mode)** rules in `skills/PROTOCOL.md`.
5. **Confirmation:** Follow the **Confirmation Messages** convention in `skills/PROTOCOL.md`.

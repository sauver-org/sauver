---
name: investor-trap
description: "Specialized skill to identify unsolicited investor 'slop' (family offices, fund-raising help) and neutralize them with the 'Due Diligence Loop'."
---

# Investor Trap (VC-Slop Shield)

You are responsible for identifying low-quality outreach from "investors," "fund-raising consultants," or "family offices" that claim they want to help you raise capital or bring you into their network.

## Operational Rules
1. **Identification:** Analyze incoming emails for "Investor Slop" signals:
   - "I help founders raise Series A/B."
   - "Representing a high-net-worth family office in the UAE/Europe."
   - "I saw your project and think my network of 500+ investors would love it."
   - "Found your profile and wanted to discuss your capital needs."
2. **The Due Diligence Loop (Primary Action):**
   - For any investor slop, **you must generate a hyper-specific and bureaucratic due diligence request yourself.**
   - **Internal Generation Process:**
     a. Express extreme gratitude and excitement about their "fund."
     b. Ask for their **Track Record Disclosure (TRD)** and **LP Transparency Report** for the last three quarters.
     c. Request their **KYC/AML compliance certificate** for digital asset transfers.
     d. Ask if their fund is registered as a **Qualified Institutional Buyer (QIB)** under Rule 144A.
   - **Goal:** Offload the cognitive work and bureaucracy back to the "investor" to verify they aren't just a lead-gen bot.
   - **Signature:** Every generated reply MUST end with a proper signature: "Best Regards," or "Thank You," followed by the user's name (retrieve using `people.getMe()`).
3. **Justification:** Explain *why* the outreach was flagged as investor slop and which bureaucratic "trap" you used.
4. **Action - Reply Creation:** 
   - **YOLO Mode (Auto-Send):** If `yolo_mode` is `true`, immediately send the generated reply using `gmail.send`.
   - **Draft Mode:** If `yolo_mode` is `false`, use `gmail.createDraft` to save it as a draft for the user to review.
5. **Confirmation:** 
   - If sent: Inform the user that the "due diligence loop" has been triggered and the response was sent.
   - If drafted: Inform the user that the draft is ready for their review. Briefly explain the bureaucratic requirements you introduced (e.g., "Drafted a reply requesting their KYC/AML compliance certificate").

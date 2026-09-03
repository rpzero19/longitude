# Shipping Longitude

## Done
- [x] Apple Developer Program paid (3 Sep 2026)
- [x] Xcode 26.3 installed, toolchain switched
- [x] App builds clean, runs, 116 tests passing
- [x] Bundle ID set: `io.github.rpzero19.longitude`
- [x] Privacy policy, support and landing pages written

## Next — you
- [ ] Confirm membership is **active** at developer.apple.com/account (not "pending")
- [ ] Replace `REPLACE-WITH-YOUR-EMAIL` in `docs/privacy.html` and `docs/support.html`
      — consider a dedicated address rather than your personal one; the page is public
      and gets scraped
- [ ] In Xcode: project → Signing & Capabilities → select your Team
      (this registers the bundle ID with Apple automatically)
- [ ] App Store Connect → My Apps → **+** → try to reserve the name "Longitude"
      — have a fallback ready; the name is independent of the bundle ID, so a rename
      costs nothing

## Then — App Store Connect
- [ ] Privacy policy URL → your GitHub Pages `privacy.html`
- [ ] Support URL → your GitHub Pages `support.html`
- [ ] App Privacy questionnaire → **Data Not Collected** for everything.
      This must match the privacy policy exactly; a mismatch is a rejection trigger.
- [ ] Category: Medical, or Health & Fitness
- [ ] Age rating: 4+
- [ ] Screenshots — 6.9" iPhone (1320 × 2868), at least one, 3–5 better.
      Scriptable: `xcrun simctl launch <sim> io.github.rpzero19.longitude -openSeries ldl`
- [ ] Description, subtitle, keywords

## Ship
- [ ] Xcode → Product → Archive → Distribute App
- [ ] TestFlight it yourself first, with a real report of your own
- [ ] Submit

## Review risks, ranked
1. **Medical claims.** The single biggest risk. Every screen and both site pages say the
   app doesn't interpret results. Keep it that way, and say so in the review notes.
2. **Guideline 4.2 (minimum functionality).** Mitigated: it parses documents, stores a
   longitudinal record, charts trends and exports. Not a single-screen utility.
3. **Privacy mismatch.** The questionnaire and the policy must agree.

## After v1
- [ ] Test against real PDFs from several labs — the parser has only met synthetic reports
- [ ] Reference ranges vary by sex and age; the app currently uses whatever the report
      printed, which is correct, but worth being deliberate about
- [ ] HealthKit export, so results join the rest of the user's health record
- [ ] More analytes — the registry is the moat, and it grows cheaply

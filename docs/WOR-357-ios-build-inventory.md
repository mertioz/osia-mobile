# WOR-357 — iOS build inventory, 2026-10-20

The operator signed into App Store Connect manually in the visible browser. Read-only navigation opened **OSIA: AI Assistant → TestFlight → Builds iOS** (Apple app ID `6792903371`). No password/2FA code was requested, read or entered by the agent. No upload, group assignment, submission, publication, terms acceptance or account setting was performed.

Both visible version groups were inspected, together with the upload history using **Tous les états / All statuses**:

| Product version | Build | Upload date exactly as displayed | Upload/build state |
|---|---|---|---|
| 1.1.2 | 16 | Oct 7, 2026 10:53 PM | Upload complete; Ready to Submit; OSIA Internal |
| 1.1.2 | 15 | Oct 7, 2026 8:25 PM | Upload complete; Ready to Submit; OSIA Internal |
| 1.0.1 | 3 | Jul 24, 2026 11:58 PM | Upload complete; Internal Testing; OSIA Internal |
| 1.0.1 | 2 | Jul 24, 2026 10:40 PM | Failed upload |

The highest existing build shown across this inventory is **16**. Dates above retain the browser's original presentation; no timezone or artifact build timestamp is inferred. The successful TestFlight groups show builds 16, 15 and 3; build 2 is an upload failure, not a released build. No additional version groups or pagination were present in the inspected inventory.

**Prepared candidate: Mobile 0.9.5, build 19.** It exceeds iOS maximum 16 and the accepted private Android maximum 18, and matches the existing `pubspec.yaml` source floor `0.9.5+19`. There is no need to consume builds 17 or 18 on iOS. The local release-helper inputs for this observation are `OSIA_IOS_STORE_MAX_BUILD=16` and `IOS_BUILD_NUMBER=19`; no build command was executed. Codemagic must still query the live all-version maximum immediately before a future authorized build, since another upload can change it. Never treat this dated observation as a permanent maximum.

The Apps page displayed an **updated Apple Developer Program agreement** notice requiring the account holder to review and accept it before app updates/submissions. That agreement remains untouched and is an operator release gate.

This establishes observed build-number ordering only. Apple acceptance of the new 0.9.5 marketing-version train, pending App Store version configuration, signed IPA creation, physical iOS Thinking/lifecycle, Keychain/pairing retention and store acceptance remain unverified. No new iOS binary exists from this mission.

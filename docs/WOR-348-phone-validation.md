# WOR-348 — private phone validation gate

Prepared 20 October 2026. This is a checklist, not a completed device test or
authorization to publish/upload. WOR-347 source corrections and evidence are in
[the parity report](WOR-347-parity-report.md).

## Inputs and identity

- Build from the Mobile PRIMARY repository only. Final delivery HEAD/origin/main/
  GitHub main must match the SHA posted in WOR-348 after the report commit.
- Runtime source is at least Mobile `bb3acd190ec585043cc43ecc4fa729356e20ad7a` and
  PC `8e187ef17dfc74c13f617f9f5e4abd2a51c5f6bc`; fetch and verify any later changes.
- Current source version: 1.1.2+16. The old local APK is versionCode 16 from
  7 October and must not be mistaken for a new build.
- Before choosing a build number, check the highest Android internal and iOS
  TestFlight build numbers. Choose a strictly higher number, at least greater than
  16. Record version, build number, Git SHA, build command, Flutter/Xcode/SDK
  versions, timestamp, artifact hash, package ID and signing identity.
- Android: new private signed build for `space.osia.app`. No public APK.
- iOS: new private signed archive from macOS/Xcode for `space.osia.app`, retaining
  the working Internal configuration. No automatic TestFlight upload.
- Record each phone model, OS version, installed app identity, installation source,
  paired PC version/process identity and selected provider/model. Capture the old
  installed identity before replacing it if possible; do not remove credentials
  or user conversations to obtain a clean-looking test.

## Expected visible changes

- Six moving orbs during an active canonical turn; disclosure starts expanded
  before commentary exists. Only actual public provider commentary appears.
- Manual close stays closed for the same turn; final chunks do not end Thinking.
  Done/cancel/error closes it once and leaves received commentary reopenable.
- ChatGPT shows remaining quota windows, including zero, rather than losing them.
- Runtime effort IDs, including `ultra` when PC offers it, remain selected.
- Claude API has the same optional workspace as PC; workspace-only changes do not
  replace an API key. No Claude Account login is implied.
- Provider presence badges/workspace reflect PC updates while the page is open.
- Completed answers render headings/lists/quotes/tables/code; user text remains
  literal. Long code and tables remain usable in portrait widths.
- Changing Mobile language changes the locale on subsequent canonical requests
  without creating another connection or engine.

## Run on both Android and iOS

1. Verify old/new build identities and exact PC/Mobile Git SHAs. Pair by QR and by
   token, including permission denial and recovery. Confirm credentials are never
   shown in diagnostics or status snapshots.
2. Send a turn with delayed commentary; observe expansion before the first event.
   Send a turn without commentary and confirm no generated Thinking narration.
3. Exercise multiple commentary revisions, manual close before the first comment,
   close during streaming and reopen. Scroll away/back and rotate/reconstruct the
   screen. Confirm exact turn identity and no duplicate orb timers.
4. Finish naturally; stop a tool turn; cause a controlled provider error. Reopen
   completed Thinking and verify all received public commentary remains available.
5. Switch conversations during work, start a distinct turn and revisit history.
   Old request/run/provider events must not modify the new turn or another chat.
6. Background/foreground, lock/wake and temporarily disconnect Wi-Fi. Repeat
   during commentary, a large upload, long tool execution and final streaming.
   Restore LAN, WebRTC and encrypted relay independently. Confirm ordered replay,
   exact final text, no duplicate messages/actions and correct Stop target.
7. Restart the paired PC while the phone is connected and during a pending turn.
   Verify canonical recovery, actual pending/unknown outcomes and fresh pairing
   metadata. A missing receipt must never become fabricated success.
8. Create/rename/delete conversations and projects from each client. Verify
   cross-client persistence, acknowledgements, failure rollback and ordering.
9. Change the selected model/effort from each side; confirm exact provider/model
   on the turn. Check ChatGPT status/remaining quotas and configured Claude API
   workspace. Live provider access requires an actually usable configured account.
10. Exercise generic tools, browser/document progress, factual results, recoverable
    errors, unknown outcomes and cancellation. Confirm canonical PC execution and
    no Mobile tool-routing or permission-broker layer.
11. Upload image, text, PDF and supported audio/video fixtures. Check progress,
    cancellation, metadata, supported/unsupported feedback and factual model-visible
    inputs. Do not infer codec/OCR support from a successful byte transfer.
12. Test microphone permission denial/recovery, STT/fallback settings, voice
    selection, TTS read-aloud, queue/Stop and late audio after a cancelled turn.
13. Exercise theme/language/personality/skills/memory, guides/legal/status,
    connectors/OAuth status, tasks and notifications. Confirm shared settings use
    the PC store; phone permission/delivery preferences remain device-specific.
14. Inspect portrait/landscape, keyboard, large accessibility text, long Markdown,
    screen reader expanded/collapsed state and reduced motion. Verify Android's
    opt-in foreground service and iOS's native background restrictions separately.

For every scenario record device, build, PC identity, route, provider/model,
expected/observed behavior and evidence. Mark DEVICE_VERIFIED only after actual
observation. Keep failed, skipped, blocked and untested scenarios visible. Fix and
retest discrepancies before requesting the operator's explicit acceptance. Do not
close WOR-348 or publish a store/public build as a side effect of this checklist.

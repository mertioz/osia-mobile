# Mobile 0.9.5 production release — 22 October 2026

Public App Store + Google Play availability and a signed universal APK on
osia.space are the objective. TestFlight, internal testing, upload and approval
are separate states. **The production release is not complete.** Desktop macOS
is paused; the accepted Windows 0.9.0 distribution is unchanged.

## Source and verified corrections

- `db19ae9603bbe794b125b3a938f060a8a84bde00`: remove the iOS Beta label,
  preserve Android's label, remove the donation link confirmed HTTP404 and
  prepare 0.9.5 build20. The operator explicitly requested iOS 0.9.5 without
  Beta, while the project remains in its beta phase; this is not feature acceptance.
- `6877bc03a6983cf9df6483b7f6b3f2530dbbdcbe`: candidate **0.9.5+21** adds
  voluntary response reports and bundled Inter fonts with runtime font HTTP
  fetching disabled. The actual assistant reply is the only initial report text;
  users can redact it, select a category and optionally add a note. Editing
  invalidates review consent. No automatic history, files, credentials or device
  identifiers are attached. Failed/uncertain requests never display a receipt.
- Worker `a225aad3c525a922fc3cc1558c43ca07fd8aba94` implements the separate
  private report inbox. Deployment `0f30cdf4786b4630a37607bb9718c5b7`, script
  `osia-content-reports`, dedicated KV `OSIA_CONTENT_REPORTS`. Health, synthetic
  submission and authenticated private readback were verified. Reports expire
  after 30 days, with no public read endpoint or application content logs.
  [Operator handling](https://github.com/mertioz/osia-worker/blob/a225aad3c525a922fc3cc1558c43ca07fd8aba94/docs/content-reports.md).
- Existing bilingual privacy policy 2026-10-05.4 already covers voluntary support
  messages and infrastructure metadata. The report form provides the precise
  fields and 30-day inbox notice. No published historical legal bundle was changed.
- Both iOS workflows upload and assign the existing internal group with
  `submit_to_testflight: false` and `submit_to_app_store: false`. Codemagic's
  `submit_to_testflight: true` means beta **review**, not binary upload.
  [Official publishing semantics](https://docs.codemagic.io/yaml-publishing/app-store-connect/).
- `tool/verify_ios_artifact.py` verifies the archive signature using macOS
  codesign, App Store profile/expiry, exact exported bundle/version/build and
  emits source SHA, IPA SHA256 and size. It explicitly records device_verified=false.

Call sites: ChatScreen supplies report actions only for completed, nonempty
assistant replies; ChatBubble renders the action; ContentReportDialog sends
only the reviewed fields through ContentReportService. Main disables font
fetches and registers the bundled Inter license. No PC Chat runtime, tool
dispatch, provider selection, conversation store or PC↔Mobile protocol changed.

Checks before the candidate21 commit: Flutter analysis clean; full suite
**516 pass / 1 existing opt-in live diagnostic skipped**, guide goldens excluded
as in the existing CI policy. iOS metadata verifier: 2 Python tests, compilation
and module imports pass. Report Worker: 5 tests; adjacent relay priority 37 and
Worker 59 pass; Wrangler dry-run and generated binding types pass. Built-in
candidate secret scans are clean. Mobile/Worker GitHub Secret scan workflows
must also pass for the final source. The upstream OFL license is preserved
verbatim with a file-scoped whitespace exception.

## Store/account inventory and actual artifact states

Apple app ID `6792903371`, bundle `space.osia.app`, team `N9NG7B76U8`.
The initially unpublished 1.0 draft was saved as **0.9.5**, manual release,
with English and French descriptions. Both explain the required user-owned PC
and LAN/WebRTC/encrypted relay. No App Store review submission was made.
Approved existing encryption document code is
`1030850b-a772-4efa-bb8d-1f07a1c65030`. Trader status is already declared.

TestFlight inventory initially had successful 16/15 under 1.1.2, 3 under
1.0.1 and failed upload 2. Candidate20 was built and signed by Codemagic job
`6ada07ca8a524d15d6a605af`, source db19ae9, and Apple independently shows
**0.9.5 build20 upload complete**, build UUID
`7cf91490-df76-46b3-9afa-78a21412aa8d`. Thus the historical 1.x TestFlight
marketing versions did not prevent this upload. Public App Review acceptance
is still unproven. Codemagic's subsequent post-processing failed; upload success
does not make that job entirely green. The beta-review flag was corrected
for candidate21. Requery the all-version maximum at every build.

Downloaded candidate20 IPA: **31,837,617 bytes**, SHA256
`dd0dff752d8cbcc27857b5dcb867092f88fc6544452e6520ca9f17a07cc10955`.
Its plist is space.osia.app / 0.9.5 / 20; profile app identifier is
N9NG7B76U8.space.osia.app, get-task-allow=false, no provisioned device list,
expiry 2027-07-24T20:27:45. Code signature resources are present; final native
signature verification is performed by the candidate21 CI verifier.
Candidate20 is preparatory and lacks candidate21's reporting/font changes.

Google Play account `9169427417377553135` is an **organization**, app
`4972414350754349792`, package space.osia.app. Production is accessible;
the 12-testers/14-days rule for new personal accounts is not an observed gate
here. The complete 7/7 bundle inventory was 1,2,3,4,5,15,16. The historical
code5/1.1.1 production release was refused on 11 August because reviewers could
not access the app with the supplied credentials. It is not publicly available.

Android candidate20 APK and AAB were genuinely signed locally with target API36.
APK v2 signature verifies, ZIP alignment passes and all 14 64-bit ELF libraries
have LOAD alignment >=16KiB. Official bundletool 1.18.3 validates the AAB.
Candidate21 must be rebuilt and verified separately from the final source.

## Signing, upgrade and rollback

| Channel | SHA256 certificate |
|---|---|
| Local/site APK and Play upload key | 4b6b58ed64aa30daca063a70f0f18139baf505e6ccd5707d25a7c225a8918d40 |
| Google Play app signing key | 62e6dd01e749d0126e8646c29e2ce412c7069772e20e051522d493c58b5b0518 |

Keep each existing identity. An APK signed with the local key can update the
operator's private code18 in place; Play uses its separate app signing identity.
**Do not promise an in-place switch between these channels.** Do not uninstall
an existing app, reset pairing/data or rotate a signing key to force a switch.
Publish this limitation with the direct APK, including its exact certificate,
versionCode and SHA256. Older Android release codes cannot be assumed to install
over a newer release; use a tested forward hotfix with a greater code for recovery.
Historical binaries and URLs remain immutable.

The connected Pixel 9a initially had 1.1.2/code18, same local certificate; its
installed APK was backed up outside Git. No iPhone is available according to
the operator. A new signed artifact is not proof of physical acceptance.

## Remaining acceptance gates

1. Final signed candidate21 artifacts, exact provenance/hashes and private
   Android in-place acceptance without losing settings/pairing. Independent iOS
   device/lifecycle/Keychain acceptance remains unverified.
2. Working, repeatable reviewer access. The existing synthetic local review
   mode does not prove access to real PC/provider/tool functionality; do not
   disguise it as a full live review environment. The earlier Google refusal
   must be resolved with genuinely usable access before resubmission.
3. Apple 4.2.7 interpretation for this native companion and its WAN transports
   remains a material review risk. Disclose actual PC execution and LAN/WAN
   behavior. Do not silently disable or conceal features. Public-beta labels
   have been removed on iOS; this alone does not satisfy production readiness.
4. Complete genuine screenshots, age rating, privacy/Data Safety and reviewer
   instructions against the final build. Voluntary reports are developer-held
   user content; relay/network identifiers and infrastructure metadata also need
   assessment. Never declare blanket no collection or no third-party processing.
5. Actual provider readiness/eligibility is not proven by contract tests. No
   paid inference, account purchase or new subscription was authorized or made.
   In particular, commercial ChatGPT plan eligibility must not be promised.
6. Operator's explicit go-ahead for the verified final store submission/release
   and direct APK publication; then verify public listings/full downloads before
   enabling store links on osia.space. No public artifact has been published here.

Official references: [Apple review rules](https://developer.apple.com/app-store/review/guidelines/),
[Google AI reporting](https://support.google.com/googleplay/android-developer/answer/13985936),
[reviewer access](https://support.google.com/googleplay/android-developer/answer/15748846),
[Play signing](https://support.google.com/googleplay/android-developer/answer/9842756).

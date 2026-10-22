# Mobile 0.9.5 production release — 22 October 2026

Public App Store + Google Play availability and a signed universal APK on
osia.space are the objective. TestFlight, internal testing, upload and approval
are separate states. **The production release is not complete.** Desktop macOS
is paused; the accepted Windows 0.9.0 distribution is unchanged.


## Published direct APK and final signed artifacts

The operator accepted build22 on the Pixel for retained pairing/settings and
its Android QR diagnostics notice, then explicitly authorized publication of
the exact APK and site. Build21's earlier functional acceptance remains the
record for real chat, single Thinking, Stop, background/network recovery and
editable reporting without automatic sending. No iPhone acceptance is claimed.

The signed universal **0.9.5/code22 APK is publicly available**:
https://osia.space/fr/download/android

Immutable binary:
https://download.osia.space/android/0.9.5/22/OSIA-Mobile.apk

**118,159,332 bytes**, SHA256
`e6266eb6b695e0ff9fed4093de1bb0ee89a98decad7e6d2f0bc5c4ff43c1fe81`.
Source: `9f88381f241c298fc2e2d05e2556663e871d5f99`.
The original local/upload certificate is preserved. APK v2, universal ABIs,
ZIP16KiB alignment and all 14 64-bit ELF alignments passed. The separate Play
AAB is **91,837,290 bytes**, SHA256
`d4a348b32427f42a786cd87348d6b96c531f552853c7ff7b8bbd83153dda9681`;
official bundletool1.18.3 validates it and its certificate matches the upload key.
Source22 analysis is clean; the full suite passed 516 with one existing live
opt-in skip. No runtime source was changed after building these binaries.

Five exact Android objects were uploaded using the existing bounded DPAPI
uploader, extended only to these pinned keys, sizes, hashes and source. All
five private readbacks and full unauthenticated public GET/hash checks passed.
The new site source is `908a0aa48c6915f1f24827954deb49b8cbc60c8a`;
primary HEAD, origin/main and GitHub matched. Cloudflare Pages production
`94c93df2-2afc-4d59-8db0-5792c47e71e9` deployed successfully. Ten EN/FR
public page checks passed, public release JSON equals source, and Windows
artifact/history metadata remains identical. Site tests34, build, export and
GitHub Secret scan39793384354 passed. Store links remain disabled.

Codemagic job `6ada147f8a524d15d6a60a5a` finished successfully, including
native signature verification and Apple upload. Downloaded final IPA:
**33,248,665 bytes**, SHA256
`2afec715ff4fb5b44d1eaa8743cb542032396e2a583573fb96727d4c7ed4e751`.
Its embedded identity/version/build and actual bytes match CI provenance.
Apple independently lists 0.9.5/build22 as ready to submit, UUID
`e5f85e1a-f351-4e7d-935e-301d42a0fac2`. It is associated with the App Store
0.9.5 draft, with manual release retained. No App Review submission was made.

Apple privacy draft now includes support content, device IDs and technical
diagnostics for functionality, potentially linked to identity, without ad
tracking; EN/FR privacy URLs are saved. Google Data Safety is saved as a draft
with SDK diagnostics/usage/install IDs and optional report text, plus the
privacy-policy deletion-request link. These drafts require final cross-check
against the complete review package, not a claim of store compliance approval.
No dedicated reviewer PC or iPhone is available. The operator authorized the
separate support requests for Apple and Google. Both were sent: Apple showed
a case acknowledgement; Google showed a created request with its number
pending. An automated Google suggestion was escalated to a support specialist
and is not treated as a human policy determination. References are in WOR-352.

Play independently accepted the signed AAB as **22 (0.9.5)**. Production release
record4 was saved with EN/FR notes and 100% of targeted countries; the UI
explicitly confirmed that a separate Publishing overview action is needed to
send it for review. No such action was taken. This is an uploaded/saved
production release, not approval or public Play availability.

## Final privacy audit update

The operator accepted Android **0.9.5/code21** on the Pixel for retained
pairing/settings, a real conversation, one Thinking disclosure, Stop,
background/network recovery and the editable report form with no automatic send.
This does not establish iOS acceptance or cover an untested replacement binary.

The subsequent native SDK audit confirmed Google ML Kit barcode-scanner metrics
on Android. Final source therefore advances to **0.9.5+22**, adds a localized
notice before opening the Android QR scanner (manual token pairing avoids the
SDK), and prepares canonical bilingual legal source **2026-10-22.1**. Sections
39/40 document voluntary reports and Android SDK processing. The prior legal
source remains immutable. New bundle SHA256:
`0bbe9ce0744e647a5ed840f2c1b824bbaf3bdf519847f2bf16b9d20bfb1a9670`.
The site legal update is prepared locally and must be deployed before the new
public Mobile release. Android Data Safety must include the SDK's diagnostic
and usage metrics/installation identifiers; the iOS native scanner is separate.
[Google's disclosure](https://developers.google.com/ml-kit/android-data-disclosure),
[SDK privacy terms](https://developers.google.com/ml-kit/terms).

Candidate21 also completed native signing verification and uploaded, but its
post-processing still failed. The release-candidate workflow now limits CI to
verification and binary upload; internal tester assignment is an explicit
App Store Connect operation. No automatic beta or App Store review is enabled.

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
- Both iOS workflows upload with
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

1. Signed candidate22 artifacts and Android acceptance are recorded above.
   Independent iOS device/lifecycle/Keychain acceptance remains unverified.
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
6. Operator's explicit go-ahead for the verified final store submission/release,
   then verify public listings before enabling store links. The direct APK
   checkpoint and publication are complete as recorded above.

Official references: [Apple review rules](https://developer.apple.com/app-store/review/guidelines/),
[Google AI reporting](https://support.google.com/googleplay/android-developer/answer/13985936),
[reviewer access](https://support.google.com/googleplay/android-developer/answer/15748846),
[Play signing](https://support.google.com/googleplay/android-developer/answer/9842756).

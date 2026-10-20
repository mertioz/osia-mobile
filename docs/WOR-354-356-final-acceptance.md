# Android acceptance and WOR-357 handoff — 2026-10-20

## Android result

The existing WOR-354 physical test passed on the operator's Pixel 9a (tegu),
Android 17, over its already connected and authorized wireless ADB transport.
`adb devices -l` identified the expected device before testing and after update.
No phone reset, wireless-pairing change or application uninstall was performed.

From the primary Mobile repository, runtime source
`ff96862917efd40fa8009f59a8840ca6cbdb749e`:

```powershell
flutter test integration_test/wor354_thinking_touch_device_test.dart -d <verified-device> --reporter expanded
```

**Result: 2 passed.** Dark and light tests compare raw pixels before/during
pointer-down with reduced motion, then verify collapse/reopen, expanded
semantics, minimum touch target and preserved keyboard focus configuration.
This supersedes the earlier installation-disconnect attempt; previous automated
regressions were not rerun during this acceptance pass.

A temporary visual entry point outside Git displayed the real production
`ThinkingDisclosure` widget in dark/light Material panels, with animated orbs.
It used the separate `space.osia.app.test` debug package, with no PC connection,
credential access or provider requests. The operator tapped/held the orbs and
explicitly answered **“No flash in either panel.”** Android physical touch and
operator visual acceptance therefore passed. The temporary visual fixture is
not a new product screen or a live canonical provider turn.

## Safe production-package update

| Property | Installed before | Installed after |
|---|---|---|
| Package | space.osia.app | space.osia.app |
| Visible version | 1.1.2 | 1.1.2 |
| Android versionCode | 17 | 18 |
| Minimum / target SDK | 24 / 36 | 24 / 36 |
| Signing certificate SHA-256 | 4b6b58ed64aa30daca063a70f0f18139baf505e6ccd5707d25a7c225a8918d40 | identical |

The installed APK was saved locally before replacement. Both APK signatures
verified with Android SDK apksigner; their single signer certificates match
exactly. aapt confirmed package/version/SDK/arm64 compatibility before install.
The private signed production candidate was built using:

```powershell
flutter build apk --release -t lib/main.dart --build-name 1.1.2 --build-number 18
adb -s <verified-device> install -r <verified-private-apk>
```

**Install result: Success.** Android reports 1.1.2 / build 18. The application
launched successfully and its process remained present. The installed base APK
SHA-256 matches the locally verified candidate:

`3c6d66a3c557949f2b764a8ab08998194696e84fb421f027bfabd6e090bd1ccc`

Android retained the original data-directory identities, credential/device
encrypted data inodes and first-install timestamps for both existing user
profiles. No clear-data, uninstall, downgrade flag, keystore replacement or
pairing reset was used. Private credentials were not read or exported to prove
retention. A separate operator check of existing pairing/settings after launch
has been requested and is still pending at this report revision; functional
credential/pairing retention is not claimed from inode evidence alone.

This is a private acceptance build of historical version 1.1.2, not the WOR-357
version transition. `pubspec.yaml` remains 1.1.2+16; the build number was supplied
only to the private build command. Runtime source remains ff968629; subsequent
acceptance-report commits change documentation only.

Build environment: Flutter 3.44.1, Dart 3.12.1, ADB 1.0.41 / platform-tools
37.0.0, SDK build-tools 36.1.0. A first release attempt with `--no-pub` failed
because a stale generated plugin registry referenced integration_test. Retrying
with normal Flutter dependency generation succeeded, without source or lockfile
changes. Existing Kotlin-plugin future-compatibility warnings remain.

Raw test/build/install logs, original APK, signed candidate and temporary visual
entry point are local evidence outside Git. No APK was publicly uploaded.

## Remaining WOR-355 / WOR-356 live validation

Credential presence was rechecked through the canonical Desktop key chain;
only booleans were reported. No model-list or inference request was made during
this acceptance pass, and no charged call was authorized or performed.

| Route | Current credential evidence | Remaining live work |
|---|---|---|
| OpenAI API | no key configured | account discovery and compatible inference routes |
| Anthropic Claude API | no key configured | account discovery/capabilities and native Messages |
| Google Gemini | no key configured | account discovery/pagination and supported inference |
| Mistral | no key configured | account discovery/capabilities and supported inference |
| Grok / xAI | no key configured | models/language-models access, Responses and model/endpoint ACLs/credits |
| DeepSeek | key present; prior free discovery passed | deepseek-flash live inference |
| GroqCloud | key present; prior free discovery passed | account-returned compatible models, including Qwen vision where supported |
| ChatGPT Account | prior managed model/list passed; session not revalidated here | authorized quota-consuming turns through its own account transport |

Before inference, obtain explicit operator approval for provider/model scope
and a spending or call budget. Missing API credentials belong on Desktop only.
Discovery GET requests can then establish actual account access without treating
public documentation or a static fallback as entitlement.

For each approved compatible route, record exact provider/model/effort and run
small text, supported image, streaming or documented nonstreaming, canonical
read-only tool/result-reinjection, public-summary and Stop/cancellation cases.
Verify PC-to-Mobile selection/provenance and exact-turn correlation. Cancellation
can still incur provider charges. Do not claim live success from the existing
synthetic transport tests, and do not deliberately incur charges to simulate
authentication/rate-limit/error cases already covered by fixtures.

The earlier provider audit and Grok audit remain authoritative implementation
evidence in the Desktop repository. Grok subscription/account login remains
unavailable pending an official eligible integration; no credential borrowing,
cookie reuse or informal subscription-entitlement claim is permitted. Claude
Account remains independent.

## WOR-357 handoff: prepared, release gates still open

Android Thinking acceptance and the private in-place update above are complete.
The operator's post-update pairing/settings check remains pending separately.
Outstanding gates remain explicit:

1. iOS physical Thinking interaction, light/dark and reduced-motion/accessibility
   behavior have not been tested. Produce a private correctly signed build on
   macOS/Xcode and verify in-place update, Keychain/settings/pairing retention
   and platform lifecycle on suitable hardware. No iOS acceptance is inferred
   from Android or Flutter widget results.
2. Complete only explicitly authorized live API/account scenarios above.
   WOR-355/WOR-356 retain their live-inference limitations.
3. WOR-357 owns Desktop 0.9.0 and Mobile 0.9.5 visible versions. Preserve all
   historical artifacts/tags/manifests. Implement explicit updater epoch/channel
   ordering so the new product chronology survives numeric 1.x-to-0.9.x changes.
4. Retain Android applicationId and signing identity; choose versionCode strictly
   above the maximum installed/store/internal value, including private build 18.
   Inventory iOS/TestFlight values independently and increase CFBundleVersion.
   Preserve PC configuration/conversations and Mobile pairing/secure stores.
5. Run signed install/update/migration/rollback QA, reconcile source/runtime/
   packaging/site/store version surfaces, and prepare release notes/provenance.
   Obtain actual final acceptance before public Windows, macOS or Mobile release
   or store submission. Linux remains last under the existing release order.

No WOR-357 version edits, public publication or store submission occurred here.
Desktop runtime/repository remains at
`3a870c18c31ee4df11002db14785532a25f34c2b`. Mobile runtime remains ff968629;
the report's documentation commit and final primary/origin/GitHub equality are
recorded in the acceptance conversation and Linear handoff.

The operator's pre-existing Mobile README.md changes and all Desktop local
operator files remain excluded from commits. Generated build/cache artifacts
and machine-specific evidence are not staged.

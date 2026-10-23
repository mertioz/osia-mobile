# OSIA Mobile 0.9.51 candidate — 23 October 2026

This candidate replaces the unsubmitted store candidate, not historical public
artifacts. Requested product version0.9.51, configured native build24. Live
Apple inventory showed maximum23 (UUID b5012c53-abc6-4c50-be65-c853a50f3487)
and Google Play showed maximum22. Codemagic rechecks Apple at build time.
Windows0.9.0 public binaries remain unchanged; Desktop macOS stays paused.

## Settings diagnosis and source changes

An authenticated production-PC WebSocket trace before changes measured the
first config at7179.3ms, models8201.6ms, account8756.4ms, duplicate config8757.2ms
and duplicate models9259.3ms. A warm repeat measured15.9/519.4/1076.7/1077.4/
1652.3ms respectively. Config payload2815bytes; models about21.5KB. These are
request-to-receive times on localhost, not physical-phone timings.

A fresh-process cProfile isolated config at3961.5ms, of which3879.7ms was the
import of osia.voice.stt and its SciPy/audio stack merely to inspect installed
Whisper directories. Extracting filesystem discovery into model_inventory
reduced the same fresh-process snapshot to57.9ms. The PC get_config handler now
runs filesystem snapshot work off the event loop. STT keeps its public import;
GUI discovery and both server callers use the lightweight module. No config
shape, execution authority, selected provider, turn protocol or Desktop binary
version changes. Frozen Windows0.9.0 does not acquire this source correction
without a separately authorized future Desktop release.

Mobile previously sent config/models twice on Settings open, plus account and
connector queries before the second config. Settings now has one owner for
config/models, with config first. Local controls load independently as before.
The PC-only section explicitly reports loading, unavailable after8seconds,
retry and disconnected. Disconnect clears its projection and time-format
optimism; reconnect requests fresh canonical data. There is no persistent
Mobile config authority and no stale snapshot presented as fresh. Late config
responses on the same live connection can resolve an operation timeout.
Models load independently from config. This is an operation timeout only,
never a Chat objective limit.

Physical Pixel9a baseline on installed0.9.5/code22: warm request-to-log config
276.3ms, models1321.3ms, duplicate config1777.3ms and duplicate models3546.3ms.
Clock calibration round trip95.3ms; UIAutomator polling has roughly2.5second
resolution and cannot establish exact first-frame latency. Cold app after
source edits saw relay-handshake retries and no config within15seconds; this
is an unsuccessful reconnect observation, not a cold connected benchmark.
Source provenance/runtime readiness must be restored before the after run.
Phone upgrade, after measurements, poor-network and offline results are pending.
The20second report is not declared solved by widget tests or profiling alone.

## Interface and native identity

Development History and its navigation/expansion are removed from production
Settings only. Historical aliases and release records are preserved. One small
gray footer reads PackageInfo.version from the installed native package, never
the source constant. Android: OSIA0.9.51 — Beta. iOS: OSIA0.9.51, without Beta,
respecting the prior operator decision and Apple's2.2 treatment of beta apps.
If native metadata is unavailable, the footer shows only OSIA.

The Android optional support shortcut opens https://osia.space/donate in the
external browser, with a localized launch-error message. No payment system,
receipt or digital reward is added. **The donation site must be live and
verified before publicly distributing this shortcut.**

## Payment and store assessment

Apple3.1.1 specifically addresses developer tips; the individual-to-individual
exception3.2.1(vii) is not verified for OSIA as the developer payee. A global
external-payment link has no proven basis across OSIA's175storefronts.
The iOS shortcut is therefore excluded. Website contributions remain available
independently once configured. No US-only entitlement/storefront inference or
regional bypass is implemented. This is a conservative engineering assessment,
not an Apple ruling. Apple2.2 also supports retaining the iOS footer without Beta.
https://developer.apple.com/app-store/review/guidelines/

Google's direct-tip exception requires100% to the creator and no digital
content/services/rewards. Ko-fi Free with its platform-fee mode disabled is
the intended configuration; ordinary processor fees remain disclosed. Verify
the real payee/configuration and exact checkout before relying on that basis.
No charitable/nonprofit status or tax deduction is asserted.
https://support.google.com/googleplay/android-developer/answer/10281818

Ko-fi's current pricing distinguishes Free0% one-time tips from default
Standard/Contributor5%; it is not enough to create a nominally free account.
Stripe/PayPal processing and possible FX/cross-border charges still apply.
The actual rate depends on the operator's connected account and transaction.
The operator must personally complete18+ eligibility, identity/banking/tax,
terms acceptance and payment-provider onboarding. Ko-fi never holds funds;
it connects the recipient's Stripe/PayPal account. No OSIA card collection,
webhook or payment-success endpoint exists. Checkout is not yet configured.
https://ko-fi.com/pricing
https://help.ko-fi.com/hc/en-us/articles/115003980093-How-do-I-get-paid
https://more.ko-fi.com/terms
https://more.ko-fi.com/privacy

## Release gates and current state

Source validation, signed artifact hashes, native verifications, CI job and
exact store draft associations must be recorded after they actually complete.
No build24 artifact or upload is claimed by this preparation record.
Apple currently displays an updated Paid Applications Schedule notice; only
the account holder may accept it. Reviewer access, real iPhone/Keychain and
upgrade testing, final authentic screenshots, age/content/privacy declarations,
Apple4.2.7 classification and provider commercial eligibility remain gates.
Google support case6-9050000041393 previously asked for no new submission until
reviewer access is resolved. Draft uploads are authorized; review submission
and public availability are not. Apple manual release and Google's disabled
managed publishing must remain distinguished.

Website /donate and /fr/donate are prepared with EN/FR navigation and explicit
unavailable state, with no fake checkout button. Public financial publication
is blocked until live setup verification and operator approval. The public
0.9.5/code22 APK URL/hash and Windows metadata remain unchanged. A new immutable
APK may be prepared, but its publication and site download switch require QA
and operator approval. Read docs/version-policy.md for the permanent increment
rule. Preserve the operator's preexisting README and review-completion file.

## Source verification before native build

Flutter analyze: no issues. Full Flutter regression:520passed,1existing live
opt-in diagnostic skipped (guide goldens excluded as in the pinned CI).
The focused settings/reconnect/navigation/iOS-policy/version set also passed58
after correcting a test-only platform override cleanup. Secret scanner clean.
PC source regression116passed; desktop correction commit
111bf2bc is separate from the unchanged published Windows0.9.0 installer.

Changed Mobile callers: SettingsScreen delegates remote initialization solely
to SystemSettingsSection. That section requests config before models, handles
connection freshness and operation timeout, and re-requests after editor exit.
PackageInfo supplies installed version independently of network. Existing
reconnect expectation now excludes the removed eager MCP status request;
connector screens continue to request and render their own status. Native IDs,
secure storage and signatures are unchanged. The generated Flutter macOS
registrar only reflects package_info_plus; no Desktop macOS work is performed.


## Signed Android24 and corrected iOS packaging

Android product source2dc0ce269e4ec6556a4f8e201c2f3a3dcdead583 produced:
- APK118126744bytes, SHA2565a9f3060250418553537ba29f1407315c2f27673d9d00ceff8decc5746eaeea6.
- AAB91797749bytes, SHA256d0fbeaddd4e2ee84e616d71695e683e787d6bd4132d4d23e1fef4400b77221b3.
APK v2 certificate unchanged4b6b58ed64aa30daca063a70f0f18139baf505e6ccd5707d25a7c225a8918d40;
ZIP16KiB and all14ELF64 libraries in each artifact pass. Universal APK includes
arm64-v8a,armeabi-v7a,x86_64; min24,target36. Bundletool1.18.3 validation and
JAR verification pass. adb install-r over the operator's build22 returned
Success, with no uninstall. Physical behavior is still being checked.

Codemagic6adb2dee1371b66e82e9e76c built/signed iOS24 but failed before successful
verification on a stale0.9.5-only product guard. It is not an accepted/uploaded
corrected IPA. The verifier now compares valid source pubspec and product
metadata, then verifies exported/archived native identity against that exact
version. Signature/profile/team/location-API checks are preserved. The next
iOS native build floor is25, independently rechecked against live Apple max.
This packaging-only correction does not alter Android24 application code or
its source SHA. Never relabel Android24 as built from the later packaging commit.

The operator subsequently authorized publishing the donation information page
without any real payment method. Site79b1ca9281a3f79550f7745902226124a012eebf
is deployed under15339838-60a8-447c-913f-b79c10054b60, with payments unavailable
and no checkout button. This supersedes the earlier live-checkout publication
gate for the information page only. Future payment activation still needs
verified setup and a distinct financial-publication approval.

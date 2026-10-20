# WOR-357 — Mobile 0.9.5 source transition

The 2026-10-20 operator decision establishes Mobile **0.9.5** for Android/iOS and Desktop **0.9.0** for Windows/macOS/Linux. This is a source candidate, not a published build.

`pubspec.yaml` now declares `0.9.5+19`. Android retains `space.osia.app` and its signing configuration, and rejects versionCode overrides <=18. The highest observed installed code is the previously accepted private Pixel build 18. Google Play all-track inventory must still be inspected before any publication; 19 is not claimed to exceed an inaccessible store record.

iOS retains its bundle identifier, Keychain entitlements, and Flutter version wiring. Both manual Codemagic workflows query the highest build across **all** App Store/TestFlight versions before choosing max(source floor, observed maximum+1). Empty/invalid/inaccessible results stop packaging. The local production helper likewise requires a queried store maximum and a greater selected build. After the operator signed in manually, the [read-only TestFlight inventory](WOR-357-ios-build-inventory.md) confirmed maximum **16**, so **0.9.5 build 19** is safely prepared. This does not verify a signed iOS update or Apple acceptance of the marketing-version transition. No workflow was triggered or store submission performed; an updated Apple Developer agreement requires manual operator review.

Settings shows the official version and build-qualified development history. The historical display aliases are:

| Original identity | Display alias |
|---|---|
| 1.0.0+1 | 0.8.0 |
| 1.0.1+2 | 0.8.1 |
| 1.0.1+3 | 0.8.2 |
| 1.0.2+3 | 0.8.3 |
| 1.1.0+4 | 0.8.4 |
| 1.1.1+5 | 0.8.5 |
| 1.1.1+14 | 0.8.6 |
| 1.1.2+15 | 0.8.7 |
| 1.1.2+16 | 0.8.8 |
| 1.1.2+17 (private Android) | 0.8.9 |
| 1.1.2+18 (private Android) | 0.8.10 |

These are observed source/build identities, not claims of App Store or public Play releases. Original technical identity remains in history details. No absent intermediate builds are invented. Historical dates/artifacts remain unchanged. The historical reuse of code 3 is recorded without rewriting it.

The [Desktop inventory and migration contract](https://github.com/mertioz/OSIA/blob/main/docs/WOR-357-version-inventory.md) contains original source SHAs/timestamps, known Windows artifact hashes, inventory limitations, and the legacy-Windows standalone-install transition. Published site history is a later publication task; it was not changed here.

The Thinking correction is separate from numbering: retained history belongs only to assistant replies, never user rows sharing the same turn identity. Cancellation terminal uses the same assistant attachment path. Real ChatScreen history/reconnect/streaming/completion and Qt composition tests verify placement above the reply and retained public commentary. The prior WOR-354 NoSplash/focus treatment is preserved. New source has not been physically revalidated on Android/iOS; the existing Pixel installation remains the accepted 1.1.2+18 build.

No user storage keys, pairing, credentials, application identity, canonical runtime, or transport authority changed. No new Mobile package was built or installed during this source mission.

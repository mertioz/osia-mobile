# OSIA Mobile

OSIA Mobile is the paired companion for the OSIA desktop assistant on Windows,
macOS, and Linux. Text, audio, streaming responses, tool results, and TTS remain
end-to-end protected between the paired phone and PC.

## Production transport behavior

Every official installation selects one authoritative application transport in
this order:

1. pinned-TLS/E2E LAN direct, discovered through `_osia._tcp.local.`;
2. direct data-only WebRTC over an ordered reliable DataChannel;
3. the endpoint-encrypted OSIA relay.

LAN and WebRTC are enabled automatically by the official release helper. The PC
sends the trusted STUN-only ICE configuration to the mobile app only inside the
authenticated E2E control session. The APK contains no PC host, IP, certificate
pin, pairing alias, STUN-resolved address, token, TURN credential, or other
installation identity.

Direct WebRTC cannot cross every NAT or firewall. "Enabled for everyone" means
every installation attempts WebRTC automatically after LAN fails; bounded
failure safely commits the relay. OSIA never resends or changes transport during
an active turn.

## Build

From the repository root:

```powershell
flutter pub get
flutter build apk --release
```

LAN, WebRTC, and encrypted relay fallback are enabled by default. Diagnostic
builds can still disable direct transports explicitly with `--dart-define`.

The policy-validating helper remains available for official release checks:

```powershell
dart run tool/build_release.dart
```

It validates the machine-readable `assets/production_capabilities.json` policy
and explicitly supplies:

```text
lan_direct_v1=true
webrtc_direct_v1=true
relay_fallback_v1=true
```

The same policy drives the future iOS release path on macOS:

```bash
dart run tool/build_release.dart --platform=ios
```

Use `dart run tool/build_release.dart --validate-only` for a non-building policy
gate. The helper rejects missing/false production capabilities, unknown
arguments, extra manifest fields, static endpoint identity, and a missing
authenticated runtime ICE-consumption path.

Diagnostic development builds stay distinct and may explicitly disable a path,
for example:

```powershell
flutter run --dart-define=lan_direct_v1=false --dart-define=webrtc_direct_v1=false
```

Plain Flutter release builds and the policy-validating helper use the same
transport defaults.

## Platform permissions

Android uses Internet and Wi-Fi multicast state for relay/WebRTC and LAN DNS-SD.
iOS declares local-network and Bonjour access for `_osia._tcp`. Voice commands
retain the existing microphone permission. WebRTC is data-only and adds no
camera permission.

## Pairing and upgrades

Pair once through the app's existing secure pairing flow. Upgrading with the
official artifact preserves secure storage, the paired PC identity, certificate
pin, conversations, and relay route. Production capabilities come from the new
binary and the authenticated PC configuration; users do not enter an IP, pin,
or STUN URL manually.

## Design

- background `#0d0b12`;
- violet accent `#c4b5f5`;
- glass chat surfaces and correlated ordered streaming.

## License

OSIA-authored code is open source under **Apache License 2.0**; commercial
use, modification and integration are permitted. See LICENSE and LICENSING.md.

The OSIA name and reserved original artwork have separate permissions in
TRADEMARKS.md and BRAND_ASSETS.json. Internal business use and noncommercial
sharing remain permitted. A commercial offering using that identity requires
prior written permission from contact@osia.space. Commercial code reuse under
your own branding, replacing reserved artwork, needs no OSIA commercial approval.

Third-party fonts, Flutter templates and libraries retain their own licenses.

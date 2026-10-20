# WOR-354 — Thinking touch correction, 2026-10-20

The transparent Thinking InkWell inherited Material splash/highlight colors.
It now uses NoSplash and transparent splash/highlight colors on that surface.
The accent keyboard focus, semantics, disclosure callback, 54×48 minimum target,
Thinking V5 orbs, theme and reduced-motion behavior remain intact.

`test/wor354_thinking_touch_test.dart` compares raw RGBA pixels before and
during pointer-down in both brightness modes, with reduced motion making the
comparison deterministic. It also verifies collapse/reopen and expanded
semantics. Adjacent Thinking tests cover animation, keyboard and lifecycle.

The isolated Android device entry point is
`integration_test/wor354_thinking_touch_device_test.dart`. It reuses those
assertions and performs no provider calls, pairing or credential-store access.
The existing Android debug variant uses `space.osia.app.test`, separate from
the operator's normal application.

Run from the primary Mobile repository:

```powershell
flutter devices
flutter test integration_test/wor354_thinking_touch_device_test.dart -d <device-id> --reporter expanded
```

Execution on 2026-10-20: Gradle assembleDebug succeeded and produced a private
debug APK. The wireless device disconnected during installation and subsequently
was absent from `adb devices`; installation failed before test execution. This
is **not DEVICE_VERIFIED**. No production application was uninstalled and no
public artifact/version/store submission was made. Reconnect Android and rerun;
an operator visual acceptance and iOS physical acceptance remain outstanding.

Final automated Mobile regression after the provider changes: 512 passed,
1 skipped; flutter analyze lib test plus this integration entry point reported
no issues. The initial Thinking correction commit was
`a79008635db33f0edb4da1e396b1a72108ecac3a`.

# Beginner onboarding localization — 24 October 2026

Source integration only. The existing ten-slide presentation from `4fdcbc6`
remains the first-launch introduction. No version bump, release build, store
submission, production draft edit or public artifact change is part of this work.
The next public Mobile version remains 0.9.52.

## Language policy and integration

The actual application catalogs and Settings selector support the same six
languages:

| Code | Language | Native selector name |
| --- | --- | --- |
| en | English | English |
| fr | French | Français |
| zh | Simplified Chinese | 中文 |
| ja | Japanese | 日本語 |
| de | German | Deutsch |
| es | Spanish | Español |

`LanguageController` starts in English. Bootstrap restores a saved language if
present and never reads the device locale to choose the default. It does not
write a default as though it were an explicit user selection. Settings continues
to save user choices through the existing secure-storage language key. No
migration overwrites existing saved values, including those saved by older
versions that did not distinguish an automatic choice from a manual choice.

`OnboardingScreen` reads `OsiaL10n`, exactly like the surrounding application;
there is no separate onboarding language argument. Changing the controller
updates slide text, swipe hint, tooltips and screen-reader progress without
resetting the current page. Text carries the selected locale for CJK glyph
selection.

`lib/guide/onboarding_content.dart` contains all ten titles and bodies in each
language, plus all five navigation/accessibility labels. All six translations
are required. There is no English/French fallback for a supported onboarding
language. Completeness tests compare the translation keys against the actual
application language list and reject duplicate/untranslated copy. Pairing menu
names were checked against PC `osia/i18n.py`, including Chinese and German.

## Layout and first-launch behavior

The illustrations, palette, swipe physics, next/check button, reduced-motion
behavior and 48px minimum touch targets remain intact. At normal text size all
60 slide/language combinations use exactly two body lines at 320px width, with
the illustration above the title/body and the arrow within the safe area.
At large text sizes or in landscape, content can scroll vertically while the
navigation remains outside the scroll viewport; text is never truncated.

Existing first-launch eligibility, presentation claim, early close, completion,
system back and shared manual progress are unchanged. The detailed Settings
manual and shared PC guide catalog are unchanged. Completing this introduction
does not mark unread manual lessons as visited.

## Verification

Final results:

| Check | Result |
| --- | --- |
| Complete `flutter test --no-pub --reporter expanded` | 579 passed; 1 opt-in live-relay diagnostic skipped because `OSIA_RELAY_LIVE_TOKEN` was not configured |
| `flutter analyze --no-pub` | No issues |
| Translation completeness and actual onboarding widgets | All 6 languages × 10 slides passed, including translated controls and semantics |
| Settings language picker and persisted startup choices | All 6 languages passed |
| Pixel 9a, Android 17 / API 37, debug integration | 46 passed: native storage, startup and all languages at native/320px size and 100%/200% text |
| Focused Pixel retest after Japanese wording review | 4 passed: all 10 Japanese slides at both sizes and text scales |
| Repository security policy | 7 passed |
| Current source, Gitleaks 8.30.1 + deterministic scanner | Clean |
| Deterministic history scanner | Clean |
| Optional all-ref Gitleaks history scanner | 2 historical synthetic fixture findings, detailed below |

Actual Android captures confirmed CJK font fallback without missing glyphs.
The production Android package remained 0.9.51 / versionCode 24 throughout;
only the separate debug test package was built and exercised. No native release
build or production installation/upgrade/reinstall was performed.

The implementation is covered by:

- `test/onboarding_screen_test.dart`: explicit translations and UI-text allowlist
  for every language; all ten actual rendered titles/bodies and controls; 320px
  line metrics; safe areas; 200% text at 320×568, 390×844 and 844×390; swipes,
  arrows, semantic navigation, reduced motion and live language changes.
- `test/widget_test.dart`: English first launch and application interface under
  six supported device locales plus Italian; existing-user suppression; saved
  choices in all six languages across bootstrap, onboarding and app remount.
- `test/settings_screen_test.dart`: actual language-picker interaction, live
  inherited strings and saved choice for every language.
- `integration_test/onboarding_localization_device_test.dart`: startup tests and
  all slides with native device fonts, touch input and safe areas; native and
  compact 320×568 layouts at 100% and 200% text; isolated native secure-storage
  write/read for all six choices. Optional fixture-only PNG captures stay outside
  Git and the production app's storage.

The device fixture uses Android's existing `space.osia.app.test` debug variant;
Flutter installs and removes that test app as part of the integration run.
Native storage uses a separate validation preference namespace. UI startup tests
mock storage and remount the app; they do not clear an installed user's profile.
They are not evidence of an installed production app upgrade or OS process-kill
and relaunch. iOS physical testing and manual TalkBack/VoiceOver listening remain
untested. No release artifact is produced by this fixture.

### Security scope

The current-source Gitleaks 8.30.1 and deterministic OSIA scanners are clean;
all seven repository security-policy tests pass. The deterministic history scan
is clean. The optional all-ref Gitleaks history scan reports two pre-existing
`generic-api-key` fixture matches, already replaced in current source:

- `test/pairing_qr_test.dart`, commit `1aaecda4835a4f60cd3963482ea59b7f806140a6`:
  an ordered numeric/hexadecimal sample used in the fake pairing scanner test.
- `test/wor340_thinking_test.dart`, commit
  `8ecb0d94673159226eb983953db343e466a23bbf`: an explicitly synthetic test label
  used with localhost and all real transports disabled.

No credential values were copied into this report. Historical commits and
security allowlists are unchanged.

The unrelated operator changes in `README.md` and untracked
`docs/WOR-352-review-completion.md` remain outside this delivery.

## Changed files and callers

- `lib/guide/onboarding_content.dart`: six required translations for each title,
  body and navigation label; kept independent from the shared detailed manual.
- `lib/screens/onboarding_screen.dart`: application-inherited strings and text
  locale; existing layout, illustration and navigation behavior retained.
- `lib/main.dart`: saved language restoration with English as the unset default;
  updated the single production `OnboardingScreen` constructor call.
- `lib/l10n.dart`: removed the now-unused device-language detector; its only
  caller was bootstrap. No application language was removed.
- `lib/services/storage_service.dart`: corrected the language-default comment;
  storage methods and keys are unchanged.
- `test/onboarding_screen_test.dart`, `test/widget_test.dart`,
  `test/settings_screen_test.dart`: localization, layout, app startup and actual
  selection/persistence coverage.
- `integration_test/onboarding_localization_device_test.dart`: isolated physical
  rendering, input and native storage checks.
- This report: scope, verification, device limitations and security findings.

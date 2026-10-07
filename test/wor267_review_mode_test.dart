import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/review/review_mode_session.dart';
import 'package:osia_mobile/screens/connection_screen.dart';
import 'package:osia_mobile/screens/legal_screen.dart';
import 'package:osia_mobile/screens/review_mode_screen.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/theme.dart';

class _CredentialProbeStorage extends StorageService {
  _CredentialProbeStorage() : super(storage: const FlutterSecureStorage());

  int credentialReads = 0;
  int credentialWrites = 0;

  @override
  Future<String?> getToken() async {
    credentialReads++;
    return null;
  }

  @override
  Future<void> setToken(String token) async {
    credentialWrites++;
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  Future<void> pumpConnection(
    WidgetTester tester, {
    _CredentialProbeStorage? storage,
    OsiaStrings strings = osiaStringsEn,
    Size viewport = const Size(400, 800),
    FakeViewPadding? viewPadding,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    if (viewPadding != null) {
      tester.view.padding = viewPadding;
      tester.view.viewPadding = viewPadding;
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: OsiaL10n(
          strings: strings,
          child: MaterialApp(
            theme: buildOsiaTheme(osiaPaletteViolet),
            home: ConnectionScreen(
              storage: storage ?? _CredentialProbeStorage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterReviewMode(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('review-mode-entry-tap-target')));
    await tester.pumpAndSettle();
  }

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('review-navigation-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('connection screen shows discreet bottom-left review text', (
    tester,
  ) async {
    await pumpConnection(tester);

    final entry = find.byKey(const Key('review-mode-entry-tap-target'));
    expect(find.text('test(review)'), findsOneWidget);
    expect(tester.getSize(entry), const Size(152, 48));
    expect(tester.getTopLeft(entry).dx, lessThan(24));
    expect(tester.getCenter(entry).dy, greaterThan(640));
    expect(
      find.ancestor(of: entry, matching: find.byType(ElevatedButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: entry, matching: find.byType(Icon)),
      findsNothing,
    );

    final text = tester.widget<Text>(find.text('test(review)'));
    expect(text.style?.fontSize, lessThanOrEqualTo(12));
    expect(
      tester.widget<InkWell>(entry).canRequestFocus,
      isTrue,
      reason: 'The text target remains keyboard reachable.',
    );
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(entry)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets(
    'review entry stays in the safe area on a compact portrait screen',
    (tester) async {
      await pumpConnection(
        tester,
        viewport: const Size(320, 568),
        viewPadding: const FakeViewPadding(bottom: 20),
      );

      final entry = find.byKey(const Key('review-mode-entry-tap-target'));
      expect(tester.getSize(entry), const Size(152, 48));
      expect(tester.getRect(entry).left, lessThan(24));
      expect(tester.getRect(entry).bottom, lessThanOrEqualTo(548));

      await enterReviewMode(tester);
      expect(find.byKey(const Key('review-mode-indicator')), findsOneWidget);
    },
  );

  testWidgets('review mode opens without reading or writing pairing tokens', (
    tester,
  ) async {
    final storage = _CredentialProbeStorage();
    await pumpConnection(tester, storage: storage);

    await enterReviewMode(tester);

    expect(find.byType(ReviewModeScreen), findsOneWidget);
    expect(find.byKey(const Key('review-mode-indicator')), findsOneWidget);
    expect(find.text('Review mode'), findsOneWidget);
    expect(find.text('What can I explore in OSIA Mobile?'), findsOneWidget);
    expect(storage.credentialReads, 0);
    expect(storage.credentialWrites, 0);
  });

  testWidgets(
    'review navigation shows synthetic conversations and local replies',
    (tester) async {
      final storage = _CredentialProbeStorage();
      await pumpConnection(tester, storage: storage);
      await enterReviewMode(tester);

      await openDrawer(tester);
      await tester.tap(find.byKey(const Key('review-nav-conversations')));
      await tester.pumpAndSettle();
      expect(find.text('Getting started'), findsOneWidget);
      expect(find.text('Planning a weekend walk'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('review-conversation-review-walk')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Can you help me plan a short walk?'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('review-message-field')),
        'Show me the local preview',
      );
      await tester.tap(find.byKey(const Key('review-send-button')));
      await tester.pumpAndSettle();
      expect(find.text('Show me the local preview'), findsOneWidget);
      expect(
        find.textContaining('No provider or PC was contacted'),
        findsOneWidget,
      );
      expect(storage.credentialReads, 0);
      expect(storage.credentialWrites, 0);
    },
  );

  testWidgets(
    'model selector, Settings, and bundled legal pages are reachable',
    (tester) async {
      await pumpConnection(tester);
      await enterReviewMode(tester);

      await tester.tap(find.byKey(const Key('review-model-shortcut')));
      await tester.pumpAndSettle();
      expect(find.text('Sample Balanced'), findsOneWidget);
      expect(find.text('OSIA demo provider'), findsWidgets);
      await tester.tap(
        find.byKey(const Key('review-model-option-sample-fast')),
      );
      await tester.pumpAndSettle();

      await openDrawer(tester);
      await tester.tap(find.byKey(const Key('review-nav-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review-settings-screen')), findsOneWidget);
      expect(find.byKey(const Key('review-auto-tts-toggle')), findsOneWidget);

      final settingsScrollable = find.descendant(
        of: find.byKey(const Key('review-settings-screen')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Terms of Service'),
        240,
        scrollable: settingsScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review-terms-link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(
        find.byKey(const Key('review-mode-legal-indicator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('legal-online-link')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Privacy Policy'),
        240,
        scrollable: settingsScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review-privacy-link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(
        find.byKey(const Key('review-mode-legal-indicator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('legal-online-link')), findsNothing);
    },
  );

  testWidgets('PC, attachment, and microphone actions are blocked locally', (
    tester,
  ) async {
    await pumpConnection(tester);
    await enterReviewMode(tester);

    for (final key in <String>[
      'review-pc-action',
      'review-attachment-button',
      'review-microphone-button',
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(find.text('Unavailable in review mode.'), findsOneWidget);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'exit destroys the ephemeral review screen and returns to pairing',
    (tester) async {
      final storage = _CredentialProbeStorage();
      await pumpConnection(tester, storage: storage);
      await enterReviewMode(tester);

      await tester.tap(find.byKey(const Key('review-exit-button')));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewModeScreen), findsNothing);
      expect(find.byType(ConnectionScreen), findsOneWidget);
      expect(find.byKey(const Key('pairing-token-field')), findsOneWidget);
      expect(find.byKey(const Key('pairing-scan-button')), findsOneWidget);
      expect(find.byKey(const Key('pairing-connect-button')), findsOneWidget);
      expect(find.text('test(review)'), findsOneWidget);
      expect(storage.credentialReads, 0);
      expect(storage.credentialWrites, 0);
    },
  );

  test(
    'review session blocks every production capability and clears on exit',
    () {
      final session = ReviewModeSession(strings: osiaStringsEn);
      expect(session.isActive, isTrue);
      expect(session.conversations, hasLength(2));
      for (final capability in ReviewCapability.values) {
        expect(
          session.tryCapability(capability),
          ReviewCapabilityResult.unavailable,
          reason: '$capability must not dispatch in review mode.',
        );
      }

      session.dispose();
      expect(session.isActive, isFalse);
      expect(session.conversations, isEmpty);
    },
  );

  testWidgets('entry label remains exact when the app is localized in French', (
    tester,
  ) async {
    await pumpConnection(tester, strings: osiaStringsFr);
    expect(find.text('test(review)'), findsOneWidget);

    await enterReviewMode(tester);
    expect(find.text('Mode d’évaluation'), findsOneWidget);
    expect(
      find.text(
        'Explorez OSIA avec des données synthétiques. Aucun PC ni service en ligne ne sera contacté.',
      ),
      findsOneWidget,
    );
  });
}

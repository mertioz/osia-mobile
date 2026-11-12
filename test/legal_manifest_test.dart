import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/legal_manifest.dart';
import 'package:osia_mobile/screens/legal_screen.dart';
import 'package:osia_mobile/theme.dart';

const acceptanceManifest = OsiaLegalManifest(
  version: '2026-10-04.1',
  termsVersion: '2026-10-04.1',
  privacyVersion: '2026-10-04.1',
  lastUpdated: '2026-10-04',
  effectiveDate: null,
  publicContactEmail: 'contact@osia.space',
  governingLaw: 'France',
  agePolicy:
      'OSIA is not specifically directed at children. Minors may use it subject to applicable law.',
  minimumAge: null,
  materialChange: true,
  termsAcceptanceRequired: true,
  privacyNoticeRequired: true,
  contentSha256: 'test-hash',
  termsUrls: {
    'en': 'https://osia.space/en/legal/terms',
    'fr': 'https://osia.space/legal/terms',
  },
  privacyUrls: {
    'en': 'https://osia.space/en/legal/privacy',
    'fr': 'https://osia.space/legal/privacy',
  },
  legalNoticeUrls: {
    'en': 'https://osia.space/en/legal/legal-notice',
    'fr': 'https://osia.space/legal/mentions-legales',
  },
  thirdPartyUrls: {
    'en': 'https://osia.space/en/legal/third-party',
    'fr': 'https://osia.space/legal/third-party',
  },
  licensesUrls: {
    'en': 'https://osia.space/en/legal/licenses',
    'fr': 'https://osia.space/legal/licenses',
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled legal manifest matches the canonical version and hash', () async {
    expect(currentLegalManifest.version, '2026-11-12.1');
    expect(currentLegalManifest.termsVersion, currentLegalManifest.version);
    expect(currentLegalManifest.privacyVersion, currentLegalManifest.version);
    expect(currentLegalManifest.lastUpdated, '2026-11-12');
    expect(currentLegalManifest.effectiveDate, '2026-11-12');
    expect(currentLegalManifest.publicContactEmail, 'contact@osia.space');
    expect(currentLegalManifest.governingLaw, 'France');
    expect(currentLegalManifest.minimumAge, isNull);
    expect(currentLegalManifest.termsAcceptanceRequired, isFalse);
    expect(currentLegalManifest.privacyNoticeRequired, isFalse);
    expect(
      currentLegalManifest.termsUrlFor('en'),
      'https://osia.space/en/legal/terms',
    );
    expect(
      currentLegalManifest.privacyUrlFor('fr'),
      'https://osia.space/legal/privacy',
    );

    final bytes = (await rootBundle.load('assets/legal/legal-source.json'))
        .buffer
        .asUint8List();
    expect(sha256.convert(bytes).toString(), currentLegalManifest.contentSha256);
    expect(
      currentLegalManifest.contentSha256,
      'dc417820accdacc4cc368185693c360bb8f865baffd614917eed83a713079f34',
    );
  });

  test('offline Legal Notice exposes only the operator-approved minimum identity block', () async {
    final source = jsonDecode(
      await rootBundle.loadString('assets/legal/legal-source.json'),
    ) as Map<String, dynamic>;
    final documents = source['documents'] as Map<String, dynamic>;
    final allDocuments = jsonEncode(documents);
    expect(allDocuments, contains('SIREN: 101 523 215'));
    expect(allDocuments, contains('SIREN : 101 523 215'));
    expect(allDocuments, contains('Cloudflare, Inc.'));
    expect(allDocuments, contains('+1 (650) 319-8930'));
    expect(allDocuments, contains('Téléphone professionnel : 07 59 54 40 53'));
    expect(allDocuments, contains('Professional telephone: +33 7 59 54 40 53'));
    expect(
      RegExp(r'\bSIRET\b|\b(?:APE|NAF|RCS|RNE)\b|\bDPO\b', caseSensitive: false)
          .hasMatch(allDocuments),
      isFalse,
    );
    for (final locale in ['en', 'fr']) {
      final pages = documents[locale] as Map<String, dynamic>;
      final legalNotice = (pages['legalNotice'] as Map<String, dynamic>)['markdown'] as String;
      expect(
        RegExp(r'\b\d{5}\s+[A-Za-zÀ-ÿ-]+')
            .allMatches(legalNotice.replaceAll(RegExp(r'\n-\s+'), ' '))
            .map((match) => match.group(0))
            .toSet(),
        {'69006 Lyon', locale == 'en' ? '94107 USA' : '94107 États-Unis'},
      );
      expect(legalNotice, contains('30 Avenue Maréchal Foch, Bureau 3'));
      expect(legalNotice, contains('69006 Lyon'));
      expect(
        legalNotice,
        contains(locale == 'en'
            ? 'Professional telephone: +33 7 59 54 40 53'
            : 'Téléphone professionnel : 07 59 54 40 53'),
      );
      for (final key in ['terms', 'privacy', 'thirdParty', 'licenses']) {
        final markdown = (pages[key] as Map<String, dynamic>)['markdown'] as String;
        expect(markdown, isNot(contains('07 59 54 40 53')));
        expect(markdown, isNot(contains('+33 7 59 54 40 53')));
        expect(markdown, isNot(contains('30 Avenue Maréchal Foch, Bureau 3')));
        expect(markdown, isNot(contains('69006 Lyon')));
      }
    }
  });

  test('both offline locales contain complete Terms and Privacy text', () async {
    final source = jsonDecode(
      await rootBundle.loadString('assets/legal/legal-source.json'),
    ) as Map<String, dynamic>;
    final documents = source['documents'] as Map<String, dynamic>;
    for (final locale in ['en', 'fr']) {
      final pages = documents[locale] as Map<String, dynamic>;
      for (final key in ['terms', 'privacy']) {
        final page = pages[key] as Map<String, dynamic>;
        final markdown = page['markdown'] as String;
        expect(markdown.length, greaterThan(7000));
        expect(
          RegExp(r'^## ', multiLine: true).allMatches(markdown).length,
          greaterThan(30),
        );
        expect(
          RegExp(
            r'draft|brouillon|legal review|revue juridique|not in force|non en vigueur',
            caseSensitive: false,
          ).hasMatch(markdown),
          isFalse,
        );
        expect(
          RegExp(
            r'Autonomous|GoalContract|WorldState|permission broker|anti-replay|semantic equivalence',
            caseSensitive: false,
          ).hasMatch(markdown),
          isFalse,
        );
      }
    }
  });

  test('startup shows no gate unless a manifest explicitly requires it', () {
    final noAcceptance = legalStartupDecision(
      currentLegalManifest,
      const LegalAcceptanceState(),
    );
    expect(noAcceptance.requiresTermsAcceptance, isFalse);
    expect(noAcceptance.showsPrivacyUpdate, isFalse);

    final required = legalStartupDecision(
      acceptanceManifest,
      const LegalAcceptanceState(),
    );
    expect(required.requiresTermsAcceptance, isTrue);
    expect(required.showsPrivacyUpdate, isFalse);

    final seen = legalStartupDecision(
      acceptanceManifest,
      LegalAcceptanceState(
        acceptedTermsVersion: acceptanceManifest.termsVersion,
        acceptedTermsAt: DateTime.utc(2026, 10, 4),
        seenPrivacyVersion: acceptanceManifest.privacyVersion,
      ),
    );
    expect(seen.requiresTermsAcceptance, isFalse);
    expect(seen.showsPrivacyUpdate, isFalse);
  });

  testWidgets('Terms screen displays the complete offline copy', (tester) async {
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: const MaterialApp(
          home: LegalScreen(document: LegalDocument.termsOfService),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    final body = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(body.data, contains('1. Operator and scope'));
    expect(body.data, contains('35. Contact'));
    expect(body.data, contains('Aymen Gherbi'));
    expect(find.text('Version 2026-11-12.1 · updated 2026-11-12'), findsOneWidget);
    expect(find.textContaining('18 years old'), findsNothing);
    expect(find.textContaining('Draft'), findsNothing);
    expect(find.textContaining('Brouillon'), findsNothing);
  });

  testWidgets('Privacy screen can switch to the full French copy', (tester) async {
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: const MaterialApp(
          home: LegalScreen(document: LegalDocument.privacyPolicy),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.byTooltip('Legal language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();

    final body = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(body.data, contains('1. Champ d’application'));
    expect(body.data, contains('38. Contact'));
    expect(body.data, contains('Les mineurs peuvent l’utiliser sous réserve du droit applicable'));
  });
}

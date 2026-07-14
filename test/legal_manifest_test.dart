import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/legal_manifest.dart';
import 'package:osia_mobile/screens/legal_screen.dart';
import 'package:osia_mobile/theme.dart';

const approvedManifest = OsiaLegalManifest(
  publicationState: 'approved',
  termsVersion: '2026-08-01.1',
  privacyVersion: '2026-08-01.1',
  lastUpdated: '2026-08-01',
  publicContactEmail: 'contact@osia.space',
  governingLaw: 'France',
  plannedEffectiveYear: 2026,
  effectiveDate: '2026-08-01',
  materialChange: true,
  termsAcceptanceRequired: true,
  termsUrl: 'https://osia.space/legal/terms',
  privacyUrl: 'https://osia.space/legal/privacy',
  minimumAge: 16,
);

void main() {
  test('bundled manifest matches canonical site links and review state', () {
    expect(currentLegalManifest.termsUrl, 'https://osia.space/legal/terms');
    expect(currentLegalManifest.privacyUrl, 'https://osia.space/legal/privacy');
    expect(currentLegalManifest.publicationState, 'draftForLegalReview');
    expect(currentLegalManifest.termsVersion, '2026-07-14-draft.1');
    expect(currentLegalManifest.privacyVersion, '2026-07-14-draft.1');
    expect(currentLegalManifest.publicContactEmail, 'contact@osia.space');
    expect(currentLegalManifest.governingLaw, 'France');
    expect(currentLegalManifest.plannedEffectiveYear, 2026);
    expect(currentLegalManifest.effectiveDate, isNull);
    expect(currentLegalManifest.termsAcceptanceRequired, isFalse);
  });

  test('review draft is safe offline and never forces acceptance', () {
    final decision = legalStartupDecision(
      currentLegalManifest,
      const LegalAcceptanceState(),
    );
    expect(decision.requiresTermsAcceptance, isFalse);
    expect(decision.showsPrivacyUpdate, isFalse);
  });

  test('older accepted material terms version triggers one new prompt', () {
    final outdated = legalStartupDecision(
      approvedManifest,
      LegalAcceptanceState(
        acceptedTermsVersion: '2026-07-01.1',
        acceptedTermsAt: DateTime.utc(2026, 7, 1),
        seenPrivacyVersion: approvedManifest.privacyVersion,
      ),
    );
    final current = legalStartupDecision(
      approvedManifest,
      LegalAcceptanceState(
        acceptedTermsVersion: approvedManifest.termsVersion,
        acceptedTermsAt: DateTime.utc(2026, 8, 1),
        seenPrivacyVersion: approvedManifest.privacyVersion,
      ),
    );
    expect(outdated.requiresTermsAcceptance, isTrue);
    expect(current.requiresTermsAcceptance, isFalse);
    expect(current.showsPrivacyUpdate, isFalse);
  });

  test('privacy change is an information notice, not terms consent', () {
    final decision = legalStartupDecision(
      approvedManifest,
      LegalAcceptanceState(
        acceptedTermsVersion: approvedManifest.termsVersion,
        acceptedTermsAt: DateTime.utc(2026, 8, 1),
        seenPrivacyVersion: '2026-07-01.1',
      ),
    );
    expect(decision.requiresTermsAcceptance, isFalse);
    expect(decision.showsPrivacyUpdate, isTrue);
  });

  testWidgets('terms acceptance starts unchecked and blocks continue', (
    tester,
  ) async {
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: MaterialApp(
          home: LegalGateScreen(
            privacyUpdateOnly: false,
            onAccepted: () async {},
          ),
        ),
      ),
    );

    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const Key('terms-acceptance-checkbox')),
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('legal-continue-button')),
    );
    expect(checkbox.value, isFalse);
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'bundled legal screen exposes approved contact and planned year',
    (tester) async {
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPaletteViolet,
          child: const MaterialApp(
            home: LegalScreen(document: LegalDocument.termsOfService),
          ),
        ),
      );

      expect(find.textContaining('contact@osia.space'), findsOneWidget);
      expect(
        find.textContaining('Entrée en vigueur prévue en 2026'),
        findsOneWidget,
      );
      expect(find.textContaining('Droit applicable : France'), findsOneWidget);
    },
  );
}

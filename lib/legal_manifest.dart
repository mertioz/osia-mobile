class OsiaLegalManifest {
  const OsiaLegalManifest({
    required this.publicationState,
    required this.termsVersion,
    required this.privacyVersion,
    required this.lastUpdated,
    required this.publicContactEmail,
    required this.governingLaw,
    required this.plannedEffectiveYear,
    required this.effectiveDate,
    required this.materialChange,
    required this.termsAcceptanceRequired,
    required this.termsUrl,
    required this.privacyUrl,
    required this.minimumAge,
  });

  final String publicationState;
  final String termsVersion;
  final String privacyVersion;
  final String lastUpdated;
  final String publicContactEmail;
  final String governingLaw;
  final int plannedEffectiveYear;
  final String? effectiveDate;
  final bool materialChange;
  final bool termsAcceptanceRequired;
  final String termsUrl;
  final String privacyUrl;
  final int? minimumAge;

  bool get isApproved => publicationState == 'approved';
}

const currentLegalManifest = OsiaLegalManifest(
  publicationState: 'draftForLegalReview',
  termsVersion: '2026-08-18-draft.3',
  privacyVersion: '2026-08-18-draft.3',
  lastUpdated: '2026-08-18',
  publicContactEmail: 'contact@osia.space',
  governingLaw: 'France',
  plannedEffectiveYear: 2026,
  effectiveDate: null,
  materialChange: true,
  termsAcceptanceRequired: false,
  termsUrl: 'https://osia.space/legal/terms',
  privacyUrl: 'https://osia.space/legal/privacy',
  minimumAge: 18,
);

class LegalAcceptanceState {
  const LegalAcceptanceState({
    this.acceptedTermsVersion,
    this.acceptedTermsAt,
    this.seenPrivacyVersion,
  });

  final String? acceptedTermsVersion;
  final DateTime? acceptedTermsAt;
  final String? seenPrivacyVersion;
}

class LegalStartupDecision {
  const LegalStartupDecision({
    required this.requiresTermsAcceptance,
    required this.showsPrivacyUpdate,
  });

  final bool requiresTermsAcceptance;
  final bool showsPrivacyUpdate;
}

LegalStartupDecision legalStartupDecision(
  OsiaLegalManifest manifest,
  LegalAcceptanceState state,
) {
  if (!manifest.isApproved) {
    return const LegalStartupDecision(
      requiresTermsAcceptance: false,
      showsPrivacyUpdate: false,
    );
  }
  final termsChanged = state.acceptedTermsVersion != manifest.termsVersion;
  final requiresTerms =
      manifest.termsAcceptanceRequired &&
      (state.acceptedTermsVersion == null ||
          (termsChanged && manifest.materialChange));
  return LegalStartupDecision(
    requiresTermsAcceptance: requiresTerms,
    showsPrivacyUpdate:
        !requiresTerms && state.seenPrivacyVersion != manifest.privacyVersion,
  );
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../legal_manifest.dart';
import '../theme.dart';

enum LegalDocument { termsOfService, privacyPolicy }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final isTerms = document == LegalDocument.termsOfService;
    final title = isTerms ? strings.termsOfService : strings.privacyPolicy;
    final version = isTerms
        ? currentLegalManifest.termsVersion
        : currentLegalManifest.privacyVersion;
    final url = isTerms
        ? currentLegalManifest.termsUrl
        : currentLegalManifest.privacyUrl;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentLegalManifest.isApproved
                        ? 'Version en vigueur'
                        : 'Projet pour revue juridique — non en vigueur',
                    style: TextStyle(
                      color: currentLegalManifest.isApproved
                          ? palette.accent
                          : palette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version $version · mise à jour ${currentLegalManifest.lastUpdated}',
                    style: TextStyle(color: palette.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Entrée en vigueur prévue en ${currentLegalManifest.plannedEffectiveYear} · date exacte non fixée',
                    style: TextStyle(color: palette.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Contact : ${currentLegalManifest.publicContactEmail}',
                    style: TextStyle(color: palette.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Public visé : B2C et B2B · âge minimal prévu : ${currentLegalManifest.minimumAge} ans',
                    style: TextStyle(color: palette.textMuted, fontSize: 13),
                  ),
                  if (isTerms) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Droit applicable : ${currentLegalManifest.governingLaw}, sous réserve des protections impératives des consommateurs.',
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isTerms
                  ? 'Le document complet couvre les actions agentiques, Gmail REST, Browser, les fournisseurs et coûts tiers, les tâches planifiées et les contrôles d’exécution. OSIA ne réserve jamais une capacité fonctionnelle à un paiement ; aucun achat, abonnement ou élément cosmétique OSIA n’existe dans ce brouillon.'
                  : 'Le document complet décrit les données locales, les contenus nécessaires envoyés au fournisseur choisi, Gmail REST, les endpoints personnalisés, Browser, les artefacts temporaires, l’anti-rejeu et Adaptive Intelligence. Le transport suit LAN, puis WebRTC, puis relais chiffré de repli, sans masquer toutes les métadonnées réseau.',
              style: TextStyle(
                color: palette.textPrimary.withValues(alpha: 0.86),
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cette copie intégrée fournit un résumé et les métadonnées de version hors ligne. Le texte canonique complet reste accessible en brouillon non approuvé et non en vigueur sur osia.space.',
              style: TextStyle(color: palette.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Ouvrir le texte canonique'),
            ),
          ],
        ),
      ),
    );
  }
}

class LegalGateScreen extends StatefulWidget {
  const LegalGateScreen({
    super.key,
    required this.onAccepted,
    required this.privacyUpdateOnly,
  });

  final Future<void> Function() onAccepted;
  final bool privacyUpdateOnly;

  @override
  State<LegalGateScreen> createState() => _LegalGateScreenState();
}

class _LegalGateScreenState extends State<LegalGateScreen> {
  bool _accepted = false;
  bool _saving = false;

  void _open(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalScreen(document: document)),
    );
  }

  Future<void> _continue() async {
    if (!widget.privacyUpdateOnly && !_accepted) return;
    setState(() => _saving = true);
    await widget.onAccepted();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.privacyUpdateOnly
                        ? 'Mise à jour de confidentialité'
                        : 'Avant de continuer',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.privacyUpdateOnly
                        ? 'La Politique de confidentialité a changé. Consultez-la; cette information ne transforme pas chaque traitement en consentement.'
                        : 'Lisez les Conditions et la Politique de confidentialité avant d’accepter les Conditions.',
                    style: TextStyle(color: palette.textMuted, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => _open(LegalDocument.termsOfService),
                    child: const Text('Conditions d’utilisation'),
                  ),
                  OutlinedButton(
                    onPressed: () => _open(LegalDocument.privacyPolicy),
                    child: const Text('Politique de confidentialité'),
                  ),
                  if (!widget.privacyUpdateOnly) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      key: const Key('terms-acceptance-checkbox'),
                      value: _accepted,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _accepted = value == true),
                      title: Text(
                        'J’accepte les Conditions d’utilisation ${currentLegalManifest.termsVersion}',
                        style: TextStyle(color: palette.textPrimary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    key: const Key('legal-continue-button'),
                    onPressed:
                        _saving || (!widget.privacyUpdateOnly && !_accepted)
                        ? null
                        : _continue,
                    child: Text(_saving ? 'Enregistrement…' : 'Continuer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

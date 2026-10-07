import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../legal_manifest.dart';
import '../theme.dart';

enum LegalDocument { termsOfService, privacyPolicy }

class LegalScreen extends StatefulWidget {
  const LegalScreen({
    super.key,
    required this.document,
    this.allowExternalLinks = true,
  });

  final LegalDocument document;
  final bool allowExternalLinks;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final Future<Map<String, dynamic>> _source;
  String? _legalLocale;

  @override
  void initState() {
    super.initState();
    _source = _loadSource();
  }

  Future<Map<String, dynamic>> _loadSource() async {
    final encoded = await rootBundle.loadString(
      'assets/legal/legal-source.json',
    );
    return jsonDecode(encoded) as Map<String, dynamic>;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _legalLocale ??= OsiaL10n.of(context).languageCode == 'fr' ? 'fr' : 'en';
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final isTerms = widget.document == LegalDocument.termsOfService;
    final title = isTerms ? strings.termsOfService : strings.privacyPolicy;
    final locale = _legalLocale ?? 'en';
    final onlineUrl = isTerms
        ? currentLegalManifest.termsUrlFor(locale)
        : currentLegalManifest.privacyUrlFor(locale);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Legal language',
            initialValue: locale,
            onSelected: (value) => setState(() => _legalLocale = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'fr', child: Text('Français')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  locale.toUpperCase(),
                  style: TextStyle(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _source,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(color: palette.accent),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'The bundled legal text could not be opened.',
                    style: TextStyle(color: palette.textMuted),
                  ),
                ),
              );
            }

            final source = snapshot.data!;
            final documents =
                (source['documents'] as Map<String, dynamic>)[locale]
                    as Map<String, dynamic>;
            final document =
                documents[isTerms ? 'terms' : 'privacy']
                    as Map<String, dynamic>;
            final markdown = document['markdown'] as String;
            final readableText = markdown
                .replaceAll(RegExp(r'^##\s+', multiLine: true), '')
                .replaceAll(RegExp(r'^-\s+', multiLine: true), '•  ');
            final updated = source['lastUpdated'] as String;

            return ListView(
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
                        [
                          'Version ',
                          currentLegalManifest.version,
                          ' · ',
                          locale == 'fr' ? 'mise à jour ' : 'updated ',
                          updated,
                        ].join(),
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      if (isTerms) ...[
                        const SizedBox(height: 6),
                        Text(
                          locale == 'fr'
                              ? 'Entrée en vigueur à la publication.'
                              : 'Effective on publication.',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          locale == 'fr'
                              ? 'Droit français, sous réserve des protections impératives des consommateurs.'
                              : 'French law, subject to mandatory consumer protections.',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        [
                          locale == 'fr' ? 'Contact : ' : 'Contact: ',
                          currentLegalManifest.publicContactEmail,
                        ].join(),
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  document['title'] as String,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  readableText,
                  style: TextStyle(
                    color: palette.textPrimary.withValues(alpha: 0.88),
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
                if (widget.allowExternalLinks) ...[
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    key: const Key('legal-online-link'),
                    onPressed: () => launchUrl(
                      Uri.parse(onlineUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(
                      locale == 'fr' ? 'Voir en ligne' : 'View online',
                    ),
                  ),
                ],
              ],
            );
          },
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
    final strings = OsiaL10n.of(context);
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
                    child: Text(strings.termsOfService),
                  ),
                  OutlinedButton(
                    onPressed: () => _open(LegalDocument.privacyPolicy),
                    child: Text(strings.privacyPolicy),
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
                        [
                          'J’accepte les Conditions ',
                          currentLegalManifest.termsVersion,
                        ].join(),
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

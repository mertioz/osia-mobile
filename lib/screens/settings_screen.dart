import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'legal_screen.dart';

/// Settings screen. Hosts four sections:
///   - Connexion: server IP + auth token
///   - Apparence: color theme picker
///   - Compte: disconnect (clears IP/token/model)
///   - Légal: ToS + privacy policy links
///
/// Doubles as the onboarding screen when nothing is configured yet.
class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final ThemeController themeController;

  const SettingsScreen({
    super.key,
    required this.storage,
    required this.themeController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _saving = false;
  bool _hasExistingCredentials = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ip = await widget.storage.getTailscaleIp();
    final token = await widget.storage.getToken();
    if (mounted) {
      setState(() {
        _ipController.text = ip ?? '';
        _tokenController.text = token ?? '';
        _hasExistingCredentials = (ip ?? '').isNotEmpty &&
            (token ?? '').isNotEmpty;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ip = _ipController.text.trim();
      final token = _tokenController.text.trim();

      if (ip.isEmpty || token.isEmpty) {
        setState(() => _error = 'Veuillez remplir tous les champs.');
        return;
      }

      await widget.storage.setTailscaleIp(ip);
      await widget.storage.setToken(token);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/chat');
      }
    } catch (e) {
      setState(() => _error = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _disconnect() async {
    final palette = OsiaTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: Text(
          'Votre adresse de serveur et votre jeton seront effacés. Le thème est conservé.',
          style: TextStyle(color: palette.textMuted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler',
                style: TextStyle(color: palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Se déconnecter',
                style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.storage.clearCredentials();
    if (!mounted) return;
    setState(() {
      _ipController.clear();
      _tokenController.clear();
      _hasExistingCredentials = false;
    });
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/settings', (_) => false);
  }

  void _onPickTheme(String key) {
    widget.themeController.setPaletteByKey(key);
    widget.storage.setThemeKey(key);
    setState(() {});
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    final t = data!.text!;
    if (t.length >= 32) {
      if (t.length == 64 && RegExp(r'^[a-f0-9]+$').hasMatch(t)) {
        _tokenController.text = t;
      } else {
        _ipController.text = t;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_hasExistingCredentials) _buildHeader(palette),

              // ── Connexion ────────────────────────────────────────────
              _SectionHeader(label: 'Connexion', palette: palette),
              _SectionCard(
                palette: palette,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldLabel(text: 'Adresse IP ou domaine', palette: palette),
                    const SizedBox(height: 6),
                    _OsiaTextField(
                      controller: _ipController,
                      hint: 'Ex: 100.64.0.42 ou osia.space',
                      palette: palette,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(text: 'Token d\'authentification', palette: palette),
                    const SizedBox(height: 6),
                    _OsiaTextField(
                      controller: _tokenController,
                      hint: 'Token affiché par votre serveur OSIA',
                      palette: palette,
                      obscure: true,
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: Icon(Icons.content_paste_rounded,
                            size: 16, color: palette.accent),
                        label: Text(
                          'Coller',
                          style: TextStyle(
                              color: palette.accent, fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: palette.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: palette.error, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: palette.isDark
                              ? palette.background
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_hasExistingCredentials
                                ? 'Mettre à jour'
                                : 'Se connecter'),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Apparence ────────────────────────────────────────────
              _SectionHeader(label: 'Apparence', palette: palette),
              _SectionCard(
                palette: palette,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Thème de couleur',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ThemeSwatchRow(
                      currentKey: widget.themeController.palette.key,
                      onTap: _onPickTheme,
                      palette: palette,
                    ),
                  ],
                ),
              ),

              // ── Compte ───────────────────────────────────────────────
              if (_hasExistingCredentials) ...[
                _SectionHeader(label: 'Compte', palette: palette),
                _SectionCard(
                  palette: palette,
                  child: _DangerTile(
                    icon: Icons.logout_rounded,
                    title: 'Se déconnecter',
                    subtitle:
                        'Efface l\'adresse, le jeton et le modèle mémorisé.',
                    onTap: _disconnect,
                    palette: palette,
                  ),
                ),
              ],

              // ── Légal ────────────────────────────────────────────────
              _SectionHeader(label: 'Légal', palette: palette),
              _SectionCard(
                palette: palette,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _NavTile(
                      icon: Icons.description_outlined,
                      title: 'Conditions d\'utilisation',
                      onTap: () => _openLegal(
                          'Conditions d\'utilisation', osiaTermsOfService),
                      palette: palette,
                    ),
                    Divider(
                      height: 1,
                      color: palette.border.withValues(alpha: 0.5),
                      indent: 56,
                    ),
                    _NavTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Politique de confidentialité',
                      onTap: () => _openLegal(
                          'Confidentialité', osiaPrivacyPolicy),
                      palette: palette,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'OSIA Mobile',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textMuted.withValues(alpha: 0.7),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(OsiaPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 18),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accent.withValues(alpha: 0.12),
              border: Border.all(
                  color: palette.accent.withValues(alpha: 0.4), width: 1),
            ),
            child: Icon(Icons.graphic_eq_rounded,
                size: 30, color: palette.accent),
          ),
          const SizedBox(height: 14),
          Text(
            'OSIA Mobile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configurez la connexion à votre serveur.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.textMuted),
          ),
        ],
      ),
    );
  }

  void _openLegal(String title, String body) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LegalScreen(title: title, body: body),
    ));
  }
}

// ── Reusable section primitives ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final OsiaPalette palette;
  const _SectionHeader({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.textMuted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final OsiaPalette palette;
  final EdgeInsets padding;
  const _SectionCard({
    required this.child,
    required this.palette,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border, width: 0.6),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final OsiaPalette palette;
  const _FieldLabel({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: palette.textMuted,
      ),
    );
  }
}

class _OsiaTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final OsiaPalette palette;
  final bool obscure;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  const _OsiaTextField({
    required this.controller,
    required this.hint,
    required this.palette,
    this.obscure = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      cursorColor: palette.accent,
      style: TextStyle(color: palette.textPrimary, fontSize: 14.5),
      decoration: InputDecoration(
        filled: true,
        fillColor: palette.background.withValues(
            alpha: palette.isDark ? 0.7 : 0.5),
        hintText: hint,
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.accent, width: 1.4),
        ),
      ),
    );
  }
}

class _ThemeSwatchRow extends StatelessWidget {
  final String currentKey;
  final ValueChanged<String> onTap;
  final OsiaPalette palette;
  const _ThemeSwatchRow({
    required this.currentKey,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final p in osiaPalettes)
          _ThemeSwatch(
            target: p,
            isActive: p.key == currentKey,
            highlight: palette.accent,
            label: palette.textPrimary,
            muted: palette.textMuted,
            onTap: () => onTap(p.key),
          ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final OsiaPalette target;
  final bool isActive;
  final Color highlight;
  final Color label;
  final Color muted;
  final VoidCallback onTap;
  const _ThemeSwatch({
    required this.target,
    required this.isActive,
    required this.highlight,
    required this.label,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: target.swatch,
              border: Border.all(
                color: isActive ? highlight : muted.withValues(alpha: 0.3),
                width: isActive ? 2.2 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: highlight.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isActive
                ? Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: target.isDark ? Colors.white : Colors.black,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          target.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? highlight : muted,
          ),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final OsiaPalette palette;
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
                width: 28,
                child: Icon(icon, size: 18, color: palette.accent)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: palette.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final OsiaPalette palette;
  const _DangerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.error.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 18, color: palette.error),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}

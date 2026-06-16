import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../motion.dart';
import '../nav.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';
import 'legal_screen.dart';
import 'providers_screen.dart';

/// Placeholder donation URL — to be replaced with the real one later.
const String _kDonationUrl = 'https://osia.space/donate';

/// Settings screen. Only reachable from the chat screen, i.e. after a
/// successful connection. Hosts five sections plus a donation link:
///   - Appearance: color theme swatches (applied live)
///   - Language: EN/FR/ZH/JA/DE/ES dropdown
///   - Voice: auto-TTS toggle
///   - Legal: ToS + privacy policy
///   - Connection: restart server + disconnect
class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final ThemeController themeController;
  final LanguageController languageController;

  /// Live connection to the OSIA server, owned by the chat screen.
  /// Used to send the restart command and watch the reconnection.
  final ws.WebSocketService wsService;

  const SettingsScreen({
    super.key,
    required this.storage,
    required this.themeController,
    required this.languageController,
    required this.wsService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _RestartState { idle, restarting }

class _SettingsScreenState extends State<SettingsScreen> {
  _RestartState _restartState = _RestartState.idle;
  ws.ConnectionState _connState = ws.ConnectionState.disconnected;
  StreamSubscription? _connSub;
  StreamSubscription? _restartStatusSub;
  Timer? _restartTimeout;

  /// Whether OSIA reads responses aloud automatically (OFF by default).
  bool _autoTts = false;

  /// Whether the voice-to-voice Live API is enabled (OFF by default).
  bool _liveApi = false;

  @override
  void initState() {
    super.initState();
    widget.storage.getAutoTts().then((enabled) {
      if (mounted) setState(() => _autoTts = enabled);
    });
    widget.storage.getLiveApiEnabled().then((enabled) {
      if (mounted) setState(() => _liveApi = enabled);
    });
    _connState = widget.wsService.state;
    // Track connection state only to enable/disable the restart tile; the
    // restart outcome itself is now confirmed by a status ack (see
    // [_restartServer]), not by watching for a reconnection.
    _connSub = widget.wsService.connectionStream.listen((state) {
      if (!mounted) return;
      setState(() => _connState = state);
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _restartStatusSub?.cancel();
    _restartTimeout?.cancel();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _onPickTheme(String key) {
    widget.themeController.setPaletteByKey(key);
    widget.storage.setThemeKey(key);
    setState(() {});
  }

  void _onPickLanguage(String? code) {
    if (code == null) return;
    widget.languageController.setLanguageByCode(code);
    widget.storage.setLanguageCode(code);
    setState(() {});
  }

  void _onToggleAutoTts(bool enabled) {
    setState(() => _autoTts = enabled);
    widget.storage.setAutoTts(enabled);
  }

  void _onToggleLiveApi(bool enabled) {
    setState(() => _liveApi = enabled);
    widget.storage.setLiveApiEnabled(enabled);
    // Push the choice to the PC; it disables STT/TTS while Live API is on.
    widget.wsService.sendSetSetting('liveapi_enabled', enabled);
  }

  void _openProviders() {
    Navigator.of(context).push(
      slideFadeRoute(ProvidersScreen(wsService: widget.wsService)),
    );
  }

  void _restartServer() {
    if (_restartState == _RestartState.restarting) return;
    // The restart command can only be delivered over a live socket; the
    // tile is disabled when disconnected, but guard anyway.
    if (widget.wsService.state != ws.ConnectionState.connected) return;
    widget.wsService.sendRestartServer();
    setState(() => _restartState = _RestartState.restarting);

    // The server confirms the restart with a status frame (content
    // "done"/"error"), which surfaces as a [ws.StatusMessage] on the existing
    // message stream — no protocol change needed. Subscribe only for the
    // duration of the restart so unrelated status frames are ignored.
    _restartStatusSub?.cancel();
    _restartStatusSub = widget.wsService.messageStream.listen((msg) {
      if (msg is! ws.StatusMessage) return;
      if (msg.content == 'done') {
        _finishRestart(success: true);
      } else if (msg.content == 'error') {
        _finishRestart(success: false);
      }
    });

    // Backstop: no acknowledgement within 10s → treat it as a failure.
    _restartTimeout?.cancel();
    _restartTimeout = Timer(const Duration(seconds: 10), () {
      _finishRestart(success: false);
    });
  }

  /// Resolve a pending restart exactly once: stop the spinner and show a
  /// success or error snackbar. Guarded so a racing ack and timeout can't
  /// fire it twice.
  void _finishRestart({required bool success}) {
    if (_restartState != _RestartState.restarting) return;
    _restartTimeout?.cancel();
    _restartTimeout = null;
    _restartStatusSub?.cancel();
    _restartStatusSub = null;
    if (!mounted) return;
    setState(() => _restartState = _RestartState.idle);
    final strings = OsiaL10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? strings.serverRestarted : strings.serverRestartFailed,
        ),
      ),
    );
  }

  Future<void> _disconnect() async {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.disconnectConfirmTitle),
        content: Text(
          strings.disconnectConfirmBody,
          style: TextStyle(color: palette.textMuted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              strings.cancel,
              style: TextStyle(color: palette.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              strings.disconnect,
              style: TextStyle(color: palette.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.storage.clearCredentials();
    if (!mounted) return;
    // Back to the connection page, clearing the whole navigation stack
    // (the chat screen underneath tears its connection down on dispose).
    Navigator.of(context).pushNamedAndRemoveUntil('/connection', (_) => false);
  }

  Future<void> _openDonation() async {
    final uri = Uri.parse(_kDonationUrl);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(OsiaL10n.of(context).linkOpenFailed)),
      );
    }
  }

  void _openLegal(LegalDocument document) {
    // Use the shared slide-fade route so the legal screen opens with the same
    // motion as every other navigation (not the default Material transition).
    Navigator.of(context).push(
      slideFadeRoute(LegalScreen(document: document)),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(strings.settingsTitle),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Appearance ───────────────────────────────────────────
              _SectionHeader(
                label: strings.appearance,
                subtitle: strings.appearanceSub,
                description: strings.appearanceDesc,
                palette: palette,
              ),
              _SectionCard(
                palette: palette,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.colorTheme,
                      style: TextStyle(fontSize: 13, color: palette.textMuted),
                    ),
                    const SizedBox(height: 14),
                    _ThemeSwatchRow(
                      currentKey: widget.themeController.palette.key,
                      onTap: _onPickTheme,
                      palette: palette,
                      strings: strings,
                    ),
                  ],
                ),
              ),

              // ── Language ─────────────────────────────────────────────
              _SectionHeader(
                label: strings.language,
                subtitle: strings.languageSub,
                description: strings.languageDesc,
                palette: palette,
              ),
              _SectionCard(
                palette: palette,
                child: _LanguageDropdown(
                  currentCode: widget.languageController.code,
                  onChanged: _onPickLanguage,
                  palette: palette,
                ),
              ),

              // ── Voice ────────────────────────────────────────────────
              _SectionHeader(
                label: strings.voiceSection,
                subtitle: strings.voiceSectionSub,
                description: strings.voiceSectionDesc,
                palette: palette,
              ),
              _SectionCard(
                palette: palette,
                padding: EdgeInsets.zero,
                child: _ToggleTile(
                  icon: Icons.volume_up_rounded,
                  title: strings.autoReadResponses,
                  subtitle: strings.autoReadResponsesSubtitle,
                  value: _autoTts,
                  onChanged: _onToggleAutoTts,
                  palette: palette,
                ),
              ),

              // ── APIs & Providers ─────────────────────────────────────
              _SectionHeader(
                label: strings.providersTitle,
                subtitle: strings.providersSub,
                description: strings.providersDesc,
                palette: palette,
              ),
              _SectionCard(
                palette: palette,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _NavTile(
                      icon: Icons.tune_rounded,
                      title: strings.configureProviders,
                      onTap: _openProviders,
                      palette: palette,
                    ),
                    Divider(
                      height: 1,
                      color: palette.border.withValues(alpha: 0.5),
                      indent: 56,
                    ),
                    _ToggleTile(
                      icon: Icons.graphic_eq_rounded,
                      title: strings.liveApi,
                      subtitle: strings.liveApiNotice,
                      value: _liveApi,
                      onChanged: _onToggleLiveApi,
                      palette: palette,
                    ),
                  ],
                ),
              ),

              // ── Legal ────────────────────────────────────────────────
              _SectionHeader(
                label: strings.legal,
                subtitle: strings.legalSub,
                description: strings.legalDesc,
                palette: palette,
              ),
              _SectionCard(
                palette: palette,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _NavTile(
                      icon: Icons.description_outlined,
                      title: strings.termsOfService,
                      onTap: () => _openLegal(LegalDocument.termsOfService),
                      palette: palette,
                    ),
                    Divider(
                      height: 1,
                      color: palette.border.withValues(alpha: 0.5),
                      indent: 56,
                    ),
                    _NavTile(
                      icon: Icons.privacy_tip_outlined,
                      title: strings.privacyPolicy,
                      onTap: () => _openLegal(LegalDocument.privacyPolicy),
                      palette: palette,
                    ),
                  ],
                ),
              ),

              // ── Connection ───────────────────────────────────────────
              _SectionHeader(
                label: strings.connectionSection,
                subtitle: strings.connectionSectionSub,
                description: strings.connectionSectionDesc,
                palette: palette,
              ),
              _SectionCard(
                palette: palette,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _RestartServerTile(
                      state: _restartState,
                      connected: _connState == ws.ConnectionState.connected,
                      onTap: _restartServer,
                      palette: palette,
                      strings: strings,
                    ),
                    Divider(
                      height: 1,
                      color: palette.border.withValues(alpha: 0.5),
                      indent: 56,
                    ),
                    _DangerTile(
                      icon: Icons.logout_rounded,
                      title: strings.disconnect,
                      subtitle: strings.disconnectSubtitle,
                      onTap: _disconnect,
                      palette: palette,
                    ),
                  ],
                ),
              ),

              // ── Donation + footer ────────────────────────────────────
              const SizedBox(height: 28),
              Center(
                child: InkWell(
                  onTap: _openDonation,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: palette.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.makeDonation,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: palette.accent,
                            decoration: TextDecoration.underline,
                            decorationColor: palette.accent.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
}

// ── Reusable section primitives ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final OsiaPalette palette;

  /// Optional ~6-word subtitle shown under the uppercase title, and an
  /// optional ~2-sentence pedagogical description under that (WOR-78).
  /// Both wrap freely and are omitted when null, so the bare-title layout
  /// is preserved for any caller that doesn't supply them.
  final String? subtitle;
  final String? description;

  const _SectionHeader({
    required this.label,
    required this.palette,
    this.subtitle,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.textMuted,
              letterSpacing: 1.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: 3),
            Text(
              description!,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: palette.textMuted,
              ),
            ),
          ],
        ],
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

// ── Theme swatches ────────────────────────────────────────────────────────

class _ThemeSwatchRow extends StatelessWidget {
  final String currentKey;
  final ValueChanged<String> onTap;
  final OsiaPalette palette;
  final OsiaStrings strings;
  const _ThemeSwatchRow({
    required this.currentKey,
    required this.onTap,
    required this.palette,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final p in osiaPalettes)
          _ThemeSwatch(
            target: p,
            label: strings.themeName(p.key),
            isActive: p.key == currentKey,
            highlight: palette.accent,
            muted: palette.textMuted,
            onTap: () => onTap(p.key),
          ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final OsiaPalette target;
  final String label;
  final bool isActive;
  final Color highlight;
  final Color muted;
  final VoidCallback onTap;
  const _ThemeSwatch({
    required this.target,
    required this.label,
    required this.isActive,
    required this.highlight,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressableScale(
          child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: MotionDurations.medium,
            curve: MotionCurves.enter,
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
        ),
        const SizedBox(height: 6),
        Text(
          label,
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

// ── Language dropdown ─────────────────────────────────────────────────────

class _LanguageDropdown extends StatelessWidget {
  final String currentCode;
  final ValueChanged<String?> onChanged;
  final OsiaPalette palette;
  const _LanguageDropdown({
    required this.currentCode,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: currentCode,
      onChanged: onChanged,
      borderRadius: BorderRadius.circular(14),
      dropdownColor: palette.surfaceElevated,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: palette.accent,
        size: 22,
      ),
      style: TextStyle(color: palette.textPrimary, fontSize: 14.5),
      decoration: InputDecoration(
        filled: true,
        fillColor: palette.background.withValues(
          alpha: palette.isDark ? 0.7 : 0.5,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
      // Closed state shows just the language name (no check icon).
      selectedItemBuilder: (context) => [
        for (final s in osiaAllStrings)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              s.languageName,
              style: TextStyle(fontSize: 14.5, color: palette.textPrimary),
            ),
          ),
      ],
      items: [
        for (final s in osiaAllStrings)
          DropdownMenuItem<String>(
            value: s.languageCode,
            child: Row(
              children: [
                Text(
                  s.languageName,
                  style: TextStyle(fontSize: 14.5, color: palette.textPrimary),
                ),
                if (s.languageCode == currentCode) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_rounded, size: 16, color: palette.accent),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ── Connection tiles ──────────────────────────────────────────────────────

class _RestartServerTile extends StatelessWidget {
  final _RestartState state;

  /// Whether the WebSocket is currently connected — the restart command
  /// can only be delivered over a live socket, so the tile is disabled
  /// (and dimmed) while disconnected.
  final bool connected;
  final VoidCallback onTap;
  final OsiaPalette palette;
  final OsiaStrings strings;
  const _RestartServerTile({
    required this.state,
    required this.connected,
    required this.onTap,
    required this.palette,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final (Widget leading, String title) = switch (state) {
      _RestartState.idle => (
        Icon(Icons.restart_alt_rounded, size: 18, color: palette.accent),
        strings.restartServer,
      ),
      _RestartState.restarting => (
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: palette.accent,
          ),
        ),
        strings.reconnecting,
      ),
    };

    final enabled = state == _RestartState.idle && connected;

    return AnimatedOpacity(
      duration: MotionDurations.medium,
      curve: MotionCurves.enter,
      opacity: enabled || state != _RestartState.idle ? 1.0 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(width: 28, child: Center(child: leading)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: MotionDurations.medium,
                      switchInCurve: MotionCurves.enter,
                      switchOutCurve: MotionCurves.exit,
                      child: Text(
                        title,
                        key: ValueKey(title),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.restartServerSubtitle,
                      style: TextStyle(fontSize: 12, color: palette.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final OsiaPalette palette;
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Icon(icon, size: 18, color: palette.accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: palette.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: palette.accent,
              activeThumbColor:
                  palette.isDark ? palette.background : Colors.white,
              inactiveTrackColor: palette.border.withValues(alpha: 0.5),
              inactiveThumbColor: palette.textMuted,
            ),
          ],
        ),
      ),
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
              child: Icon(icon, size: 18, color: palette.accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, color: palette.textPrimary),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.textMuted,
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.error.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 15, color: palette.error),
            ),
            const SizedBox(width: 8),
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
                    style: TextStyle(fontSize: 12, color: palette.textMuted),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

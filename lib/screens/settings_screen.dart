import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../legal_manifest.dart';
import '../motion.dart';
import '../nav.dart';
import '../services/background_connection_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';
import 'legal_screen.dart';
import 'guide_screen.dart';
import 'memory_screen.dart';
import 'providers_screen.dart';

/// Placeholder donation URL — to be replaced with the real one later.
const String _kDonationUrl = 'https://osia.space/donate';
bool get _liveApiAvailable => false;

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
  final OsiaNotificationService? notificationService;
  final BackgroundConnectionService? backgroundConnectionService;

  /// Live connection to the OSIA server, owned by the chat screen.
  /// Used to send the restart command and watch the reconnection.
  final ws.WebSocketService wsService;

  const SettingsScreen({
    super.key,
    required this.storage,
    required this.themeController,
    required this.languageController,
    required this.wsService,
    this.notificationService,
    this.backgroundConnectionService,
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
  late final OsiaNotificationService _notificationService;
  late final BackgroundConnectionService _backgroundConnectionService;
  late final bool _ownsBackgroundConnectionService;
  bool _notificationsEnabled = false;
  bool _notificationsBusy = false;
  bool _backgroundConnectionEnabled = false;
  bool _backgroundConnectionBusy = false;

  @override
  void initState() {
    super.initState();
    _notificationService =
        widget.notificationService ??
        OsiaNotificationService(storage: widget.storage);
    _ownsBackgroundConnectionService =
        widget.backgroundConnectionService == null;
    _backgroundConnectionService =
        widget.backgroundConnectionService ??
        BackgroundConnectionService(storage: widget.storage);
    _backgroundConnectionService.attachWebSocketService(widget.wsService);
    widget.storage.getAutoTts().then((enabled) {
      if (mounted) setState(() => _autoTts = enabled);
    });
    widget.storage.getLiveApiEnabled().then((enabled) {
      if (mounted) setState(() => _liveApi = _liveApiAvailable && enabled);
    });
    widget.storage.getNotificationsEnabled().then((enabled) {
      if (mounted) setState(() => _notificationsEnabled = enabled);
    });
    _backgroundConnectionService.backgroundConnectionEnabled().then((enabled) {
      if (mounted) setState(() => _backgroundConnectionEnabled = enabled);
    });
    _connState = widget.wsService.state;
    // Track connection state only to enable/disable the restart tile; the
    // restart outcome itself is now confirmed by a status ack (see
    // [_restartServer]), not by watching for a reconnection.
    _connSub = widget.wsService.connectionStream.listen((state) {
      if (!mounted) return;
      setState(() => _connState = state);
      if (state == ws.ConnectionState.connected) {
        _refreshServerState();
      }
    });
    _recoverConnection();
  }

  @override
  void dispose() {
    if (_ownsBackgroundConnectionService) {
      _backgroundConnectionService.detachWebSocketService(widget.wsService);
    }
    _connSub?.cancel();
    _restartStatusSub?.cancel();
    _restartTimeout?.cancel();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _onPickTheme(String key) {
    widget.themeController.setPaletteByKey(key);
    widget.storage.setThemeKey(key);
    // The PC owns the canonical theme setting; the local value is only a
    // startup cache for the Mobile surface while it reconnects.
    widget.wsService.sendSetSetting('ui_theme', key);
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
    if (!_liveApiAvailable) return;
    setState(() => _liveApi = enabled);
    widget.storage.setLiveApiEnabled(enabled);
    // Push the choice to the PC; it disables STT/TTS while Live API is on.
    widget.wsService.sendSetSetting('liveapi_enabled', enabled);
  }

  Future<void> _onToggleNotifications(bool enabled) async {
    if (_notificationsBusy) return;
    setState(() => _notificationsBusy = true);
    final allowed = await _notificationService
        .setNotificationsEnabledFromSettings(enabled);
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = allowed;
      _notificationsBusy = false;
    });
    if (enabled && !allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(OsiaL10n.of(context).notificationPermissionDenied),
        ),
      );
    }
  }

  Future<void> _onToggleBackgroundConnection(bool enabled) async {
    if (_backgroundConnectionBusy) return;
    setState(() => _backgroundConnectionBusy = true);
    final active = await _backgroundConnectionService
        .setBackgroundConnectionEnabledFromSettings(enabled);
    if (!mounted) return;
    setState(() {
      _backgroundConnectionEnabled = active;
      _backgroundConnectionBusy = false;
    });
    if (enabled && !active) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(OsiaL10n.of(context).backgroundConnectionUnavailable),
        ),
      );
    }
  }

  void _recoverConnection() {
    unawaited(widget.wsService.ensureConnected(reason: 'settings_open'));
    if (widget.wsService.state == ws.ConnectionState.connected) {
      _refreshServerState();
    }
  }

  void _refreshServerState() {
    widget.wsService.sendGetConfig();
    widget.wsService.sendGetModels();
    widget.wsService.sendGetChatGptAccount();
    widget.wsService.sendMcpStatus();
  }

  void _openProviders() {
    Navigator.of(
      context,
    ).push(slideFadeRoute(ProvidersScreen(wsService: widget.wsService)));
  }

  void _openMemory() {
    Navigator.of(
      context,
    ).push(slideFadeRoute(MemoryScreen(wsService: widget.wsService)));
  }

  void _openGuide() {
    Navigator.of(context).push(
      slideFadeRoute(
        GuideScreen(
          storage: widget.storage,
          languageCode: widget.languageController.code,
        ),
      ),
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

    await _backgroundConnectionService
        .setBackgroundConnectionEnabledFromSettings(false);
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
    Navigator.of(context).push(slideFadeRoute(LegalScreen(document: document)));
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
            key: const Key('settings-sections'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Language ─────────────────────────────────────────────
              _SectionHeader(
                label: strings.language,
                subtitle: strings.languageSub,
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

              _SectionHeader(label: strings.sectionGeneral, palette: palette),
              _SectionCard(
                palette: palette,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ToggleTile(
                      icon: Icons.notifications_active_rounded,
                      title: strings.osiaNotifications,
                      subtitle: strings.osiaNotificationsSubtitle,
                      value: _notificationsEnabled,
                      onChanged: _notificationsBusy
                          ? null
                          : _onToggleNotifications,
                      palette: palette,
                    ),
                    if (defaultTargetPlatform == TargetPlatform.android) ...[
                      Divider(
                        height: 1,
                        color: palette.border.withValues(alpha: 0.5),
                        indent: 56,
                      ),
                      _ToggleTile(
                        icon: Icons.sync_rounded,
                        title: strings.backgroundConnection,
                        subtitle: strings.backgroundConnectionSubtitle,
                        value: _backgroundConnectionEnabled,
                        onChanged: _backgroundConnectionBusy
                            ? null
                            : _onToggleBackgroundConnection,
                        palette: palette,
                      ),
                    ],
                    Divider(
                      height: 1,
                      color: palette.border.withValues(alpha: 0.5),
                      indent: 56,
                    ),
                    _ToggleTile(
                      icon: Icons.volume_up_rounded,
                      title: strings.autoReadResponses,
                      subtitle: strings.autoReadResponsesSubtitle,
                      value: _autoTts,
                      onChanged: _onToggleAutoTts,
                      palette: palette,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              SystemSettingsSection(
                wsService: widget.wsService,
                showHeader: false,
              ),

              // ── Memory ───────────────────────────────────────────────
              const SizedBox(height: 18),
              _SectionHeader(
                label: strings.memoryTitle,
                subtitle: strings.localMemories,
                palette: palette,
              ),
              _SectionCard(
                palette: palette,
                padding: EdgeInsets.zero,
                child: _NavTile(
                  icon: Icons.psychology_alt_rounded,
                  title: strings.memoryTitle,
                  onTap: _openMemory,
                  palette: palette,
                ),
              ),

              // ── APIs & Providers ─────────────────────────────────────
              _SectionHeader(
                label: strings.providersTitle,
                subtitle: strings.providersSub,
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
                      value: _liveApiAvailable && _liveApi,
                      onChanged: _liveApiAvailable ? _onToggleLiveApi : null,
                      trailingLabel: strings.comingSoon,
                      palette: palette,
                    ),
                  ],
                ),
              ),

              // ── Colors ───────────────────────────────────────────────
              _SectionHeader(
                label: strings.colorTheme,
                subtitle: strings.appearanceSub,
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
                    AccentThemeSelector(
                      currentKey: widget.themeController.palette.key,
                      onTap: _onPickTheme,
                      palette: palette,
                      strings: strings,
                    ),
                  ],
                ),
              ),

              // ── Legal ────────────────────────────────────────────────
              _SectionHeader(
                label: strings.legal,
                subtitle: strings.legalSub,
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
                      subtitle: currentLegalManifest.termsVersion,
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
                      subtitle: currentLegalManifest.privacyVersion,
                      onTap: () => _openLegal(LegalDocument.privacyPolicy),
                      palette: palette,
                    ),
                  ],
                ),
              ),

              // ── Help + Connection ────────────────────────────────────
              _SectionHeader(
                key: const Key('settings-help-section'),
                label: widget.languageController.code == 'fr' ? 'Aide' : 'Help',
                palette: palette,
              ),
              _SectionCard(
                palette: palette,
                padding: EdgeInsets.zero,
                child: _NavTile(
                  key: const Key('show-mobile-guide'),
                  icon: Icons.menu_book_rounded,
                  title: widget.languageController.code == 'fr'
                      ? 'Revoir le guide OSIA Mobile'
                      : 'Show OSIA Mobile guide',
                  subtitle: widget.languageController.code == 'fr'
                      ? 'Hors ligne · progression conservée'
                      : 'Offline · progress preserved',
                  onTap: _openGuide,
                  palette: palette,
                ),
              ),

              _SectionHeader(
                key: const Key('settings-connection-section'),
                label: strings.connectionSection,
                subtitle: strings.connectionSectionSub,
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

  /// Optional ~6-word subtitle shown under the uppercase title (WOR-78).
  /// It wraps freely and is omitted when null, so the bare-title layout
  /// is preserved for any caller that doesn't supply it.
  final String? subtitle;

  const _SectionHeader({
    super.key,
    required this.label,
    required this.palette,
    this.subtitle,
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

// ── Accent theme selector ─────────────────────────────────────────────────

class AccentThemeSelector extends StatelessWidget {
  final String currentKey;
  final ValueChanged<String> onTap;
  final OsiaPalette palette;
  final OsiaStrings strings;
  const AccentThemeSelector({
    super.key,
    required this.currentKey,
    required this.onTap,
    required this.palette,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final columns = constraints.maxWidth >= 280 ? 2 : 1;
        final optionWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          key: const Key('accent-theme-selector'),
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final target in osiaPalettes)
              SizedBox(
                width: optionWidth,
                child: _AccentThemeOption(
                  target: target,
                  label: strings.themeName(target.key),
                  isActive: target.key == currentKey,
                  palette: palette,
                  onTap: () => onTap(target.key),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AccentThemeOption extends StatelessWidget {
  final OsiaPalette target;
  final String label;
  final bool isActive;
  final OsiaPalette palette;
  final VoidCallback onTap;
  const _AccentThemeOption({
    required this.target,
    required this.label,
    required this.isActive,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = palette.accent;
    return Semantics(
      key: Key('theme-option-${target.key}'),
      button: true,
      selected: isActive,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressableScale(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(14),
            focusColor: highlight.withValues(alpha: 0.14),
            hoverColor: highlight.withValues(alpha: 0.08),
            child: AnimatedContainer(
              duration: Motion.duration(context, MotionDurations.medium),
              curve: Motion.curve(context, MotionCurves.enter),
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? highlight.withValues(alpha: 0.10)
                    : palette.background.withValues(
                        alpha: palette.isDark ? 0.54 : 0.32,
                      ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive ? highlight : palette.border,
                  width: isActive ? 1.6 : 0.8,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: highlight.withValues(alpha: 0.22),
                          blurRadius: 12,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: target.swatch,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: target
                            .foregroundOn(target.swatch)
                            .withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isActive ? highlight : palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedSwitcher(
                    duration: Motion.duration(context, MotionDurations.fast),
                    child: isActive
                        ? Icon(
                            Icons.check_circle_rounded,
                            key: const ValueKey('selected'),
                            size: 20,
                            color: highlight,
                          )
                        : const SizedBox(
                            key: ValueKey('unselected'),
                            width: 20,
                            height: 20,
                          ),
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
  final ValueChanged<bool>? onChanged;
  final String? trailingLabel;
  final OsiaPalette palette;
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.trailingLabel,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final contentColor = enabled ? palette.textPrimary : palette.textMuted;
    final iconColor = enabled ? palette.accent : palette.textMuted;
    return InkWell(
      onTap: enabled ? () => onChanged!(!value) : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(width: 28, child: Icon(icon, size: 18, color: iconColor)),
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
                      color: contentColor,
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
            if (trailingLabel != null) ...[
              _SoonPill(label: trailingLabel!, palette: palette),
              const SizedBox(width: 8),
            ],
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: palette.accent,
              activeThumbColor: palette.isDark
                  ? palette.background
                  : Colors.white,
              inactiveTrackColor: palette.border.withValues(alpha: 0.5),
              inactiveThumbColor: palette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SoonPill extends StatelessWidget {
  final String label;
  final OsiaPalette palette;

  const _SoonPill({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.textMuted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.textMuted.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.textMuted,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final OsiaPalette palette;
  const _NavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: palette.textPrimary),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11, color: palette.textMuted),
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

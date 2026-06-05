import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';

/// Minimal, premium connection screen — the first thing the user sees on
/// first launch (and after disconnecting).
///
/// One token field, one button. The server host is fixed
/// ([StorageService.defaultHost]); only the token is asked for. The token
/// is verified by opening a real WebSocket connection before being saved,
/// and is never shown again once stored.
class ConnectionScreen extends StatefulWidget {
  final StorageService storage;

  const ConnectionScreen({super.key, required this.storage});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _tokenCtrl = TextEditingController();

  bool _connecting = false;
  String? _error;

  // Entrance animation — same rhythm as the rest of the app (easeOutCubic).
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Temporary service used only to verify the token before saving it.
  ws.WebSocketService? _probe;
  StreamSubscription? _probeConnSub;
  StreamSubscription? _probeErrSub;
  Timer? _probeTimeout;
  Timer? _probeGrace;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _disposeProbe();
    _enterCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _disposeProbe() {
    _probeTimeout?.cancel();
    _probeTimeout = null;
    _probeGrace?.cancel();
    _probeGrace = null;
    _probeConnSub?.cancel();
    _probeConnSub = null;
    _probeErrSub?.cancel();
    _probeErrSub = null;
    _probe?.dispose();
    _probe = null;
  }

  Future<void> _pasteToken() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _tokenCtrl.text = text;
    setState(() {});
  }

  /// Verify the token by opening a real connection to the OSIA server,
  /// then persist it and enter the chat.
  Future<void> _connect() async {
    final strings = OsiaL10n.of(context);
    final token = _tokenCtrl.text.trim();

    if (token.isEmpty) {
      setState(() => _error = strings.tokenRequired);
      return;
    }
    if (_connecting) return;

    setState(() {
      _connecting = true;
      _error = null;
    });

    final probe = ws.WebSocketService(
      ip: StorageService.defaultHost,
      token: token,
    );
    _probe = probe;

    // Hard backstop: a bad token never accumulates a stable connection
    // (the server keeps closing the socket and the probe keeps retrying),
    // so after 15 s without success we report failure.
    _probeTimeout = Timer(const Duration(seconds: 15), () {
      _failConnection(strings.connectionFailed);
    });

    _probeConnSub = probe.connectionStream.listen((state) {
      if (state == ws.ConnectionState.connected) {
        // Socket is open and auth was sent. The token is considered good
        // once the connection stays up for a continuous grace period (a
        // bad token gets its socket closed by the server well within it).
        // Transient drops just restart the clock — the probe's built-in
        // reconnect brings the socket back on flaky networks.
        _probeGrace?.cancel();
        _probeGrace = Timer(const Duration(milliseconds: 1200), () {
          if (_probe == probe && probe.state == ws.ConnectionState.connected) {
            _finishConnection(token);
          }
        });
      }
    });

    _probeErrSub = probe.errorStream.listen((_) {
      // Network-level failure (unreachable, timeout, refused) — report
      // immediately rather than waiting out the backstop.
      _failConnection(strings.connectionFailed);
    });

    probe.connect();
  }

  Future<void> _finishConnection(String token) async {
    _disposeProbe();
    await widget.storage.setTailscaleIp(StorageService.defaultHost);
    await widget.storage.setToken(token);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/chat');
  }

  void _failConnection(String message) {
    _disposeProbe();
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLogo(palette),
                      const SizedBox(height: 48),
                      _buildTokenField(palette, strings),
                      const SizedBox(height: 12),
                      _buildError(palette),
                      const SizedBox(height: 12),
                      _buildConnectButton(palette, strings),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(OsiaPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The logo mark, shown directly — no disc, no glow. The asset is a
        // tightly-cropped, centred square so BoxFit.contain keeps it centred.
        SizedBox(
          width: 104,
          height: 104,
          child: Image.asset(
            'assets/osia_logo_mark.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'OSIA',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTokenField(OsiaPalette palette, OsiaStrings strings) {
    return TextField(
      controller: _tokenCtrl,
      enabled: !_connecting,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.go,
      onSubmitted: (_) => _connect(),
      cursorColor: palette.accent,
      style: TextStyle(color: palette.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: palette.surface,
        hintText: strings.enterYourToken,
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.accent, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        suffixIcon: IconButton(
          onPressed: _connecting ? null : _pasteToken,
          icon: Icon(
            Icons.content_paste_rounded,
            size: 18,
            color: palette.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildError(OsiaPalette palette) {
    // AnimatedSize keeps the layout from jumping when the error appears.
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _error == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.error, fontSize: 13),
              ),
            ),
    );
  }

  Widget _buildConnectButton(OsiaPalette palette, OsiaStrings strings) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _connecting ? null : _connect,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.isDark ? palette.background : Colors.white,
          disabledBackgroundColor: palette.accent.withValues(alpha: 0.6),
          disabledForegroundColor:
              (palette.isDark ? palette.background : Colors.white).withValues(
                alpha: 0.8,
              ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _connecting
              ? Row(
                  key: const ValueKey('connecting'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: palette.isDark
                            ? palette.background
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(strings.connectingEllipsis),
                  ],
                )
              : Text(strings.connect, key: const ValueKey('connect')),
        ),
      ),
    );
  }
}

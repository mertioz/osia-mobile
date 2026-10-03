import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../motion.dart';
import '../pairing_token.dart';
import '../services/rendezvous_service.dart';
import '../services/relay_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';
import '../widgets/accent_logo.dart';
import 'chat_screen.dart' show ChatHandoff;
import 'legal_screen.dart';
import 'pairing_scanner_screen.dart';

/// Minimal, premium connection screen — the first thing the user sees on
/// first launch (and after disconnecting).
///
/// One token field, one button. The server host is fixed
/// ([StorageService.defaultHost]); only the token is asked for. The token
/// is verified by opening a real WebSocket connection before being saved,
/// and is never shown again once stored.
class ConnectionScreen extends StatefulWidget {
  final StorageService storage;
  final PairingScannerAdapter Function()? pairingScannerFactory;

  const ConnectionScreen({
    super.key,
    required this.storage,
    this.pairingScannerFactory,
  });

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _tokenCtrl = TextEditingController();

  bool _connecting = false;
  // The token field is obscured by default; the eye toggle in its suffix
  // flips this so the user can verify what they pasted/typed.
  bool _obscureToken = true;
  String? _error;

  // Entrance animation — shared app rhythm: fade on [enter], slide on the
  // light [spring], over MotionDurations.entrance.
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _entered = false;

  // Service used to verify the token. On success we DON'T close it — the
  // same authenticated socket is handed to the chat screen (see
  // [_finishConnection]) so the app never closes and reopens a connection.
  ws.WebSocketService? _probe;
  StreamSubscription? _probeConnSub;
  StreamSubscription? _probeMsgSub;
  StreamSubscription? _probeErrSub;
  Timer? _probeTimeout;
  Timer? _probeGrace;

  // True once the probe's socket has opened (and auth was sent) at least
  // once this attempt — lets us tell a network failure (never connected)
  // from an auth rejection (connected, then the server hung up).
  bool _probeReachedConnected = false;
  // Latch so the spinner resolves to exactly one outcome (chat or error),
  // even if success and failure signals race.
  bool _resolved = false;

  // Server frames seen during validation, buffered so the chat screen can
  // replay them. The server pushes the initial conversations/active/history/
  // models burst right after auth; the chat screen subscribes only after the
  // hand-off and would otherwise miss it.
  final List<ws.OsiaMessage> _bufferedMessages = [];
  // Set once the live connection has been handed to the chat screen: from
  // then on this screen must NOT dispose the service (the chat screen owns
  // it now), only its own subscriptions.
  bool _handedOff = false;

  // No verdict from the server within this window → give up and tell the
  // user to check their token.
  // The relay may establish WebRTC (up to 20s) before E2E auth can complete.
  static const Duration _verifyTimeout = Duration(seconds: 40);
  // How long the socket must stay open after auth (with no rejecting close)
  // before we treat a silent server as a valid token.
  static const Duration _verifyGrace = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: MotionDurations.entrance,
    );
    _fade = CurvedAnimation(parent: _enterCtrl, curve: MotionCurves.enter);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: MotionCurves.spring));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    _entered = true;
    // Reduced motion: show the screen immediately, no slide/fade.
    if (Motion.reduced(context)) {
      _enterCtrl.value = 1.0;
    } else {
      _enterCtrl.forward();
    }
  }

  @override
  void dispose() {
    if (_handedOff) {
      // The live socket now belongs to the chat screen — tear down only our
      // own subscriptions/timers, never the service itself.
      _probeTimeout?.cancel();
      _probeGrace?.cancel();
      _probeConnSub?.cancel();
      _probeMsgSub?.cancel();
      _probeErrSub?.cancel();
    } else {
      _disposeProbe();
    }
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
    _probeMsgSub?.cancel();
    _probeMsgSub = null;
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

  Future<void> _scanQrCode() async {
    if (_connecting) return;
    final scannedToken = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            PairingScannerScreen(adapter: widget.pairingScannerFactory?.call()),
      ),
    );
    if (!mounted || scannedToken == null) return;
    final input = parsePairingToken(scannedToken);
    if (!input.isValid) {
      setState(() => _error = OsiaL10n.of(context).invalidToken);
      return;
    }
    _tokenCtrl.value = TextEditingValue(
      text: input.value,
      selection: TextSelection.collapsed(offset: input.value.length),
    );
    setState(() => _error = null);
  }

  /// Verify the token by opening a real connection to the OSIA server,
  /// then persist it and enter the chat.
  Future<void> _connect() async {
    final strings = OsiaL10n.of(context);
    final input = parsePairingToken(_tokenCtrl.text);

    if (input.issue == PairingTokenIssue.empty) {
      setState(() => _error = strings.tokenRequired);
      return;
    }
    if (!input.isValid) {
      setState(() => _error = strings.invalidToken);
      return;
    }
    final token = input.value;
    if (_connecting) return;

    setState(() {
      _connecting = true;
      _error = null;
    });

    // Fresh attempt: drop any leftover probe and reset the latches.
    _disposeProbe();
    _resolved = false;
    _probeReachedConnected = false;
    _handedOff = false;
    _bufferedMessages.clear();

    debugPrint('[OSIA Connect] Verifying public relay connection.');

    // This validated connection is reused by the chat screen — on success we
    // hand the live socket over instead of closing and reopening it — so it
    // uses the same autoReconnect:true as a normal chat session (a mid-chat
    // network blip shouldn't kill it). A rejected token still surfaces
    // immediately: the disconnected-after-connected branch below resolves the
    // attempt and disposes the probe before any reconnect timer can fire, so
    // there is no "infinite Connecting" loop.
    final probe = ws.WebSocketService(
      ip: StorageService.defaultHost,
      token: token,
      storage: widget.storage,
      // WOR-64: resolve the PC's current host from the token on every connect/
      // reconnect instead of using a fixed host. [ip] stays as the fallback.
      resolveRelay: () =>
          RelayService(storage: widget.storage).connectionConfig(token),
      resolveHost: () => RendezvousService().resolveHost(token),
    );
    _probe = probe;

    // Backstop: if the server neither accepts nor rejects us in time, stop
    // the spinner and tell the user to check the token.
    _probeTimeout = Timer(_verifyTimeout, () {
      debugPrint(
        '[OSIA Connect] No verdict after '
        '${_verifyTimeout.inSeconds}s → failure.',
      );
      _failConnection(strings.connectionFailed);
    });

    _probeConnSub = probe.connectionStream.listen((state) {
      debugPrint(
        '[OSIA Connect] probe state → $state '
        '(reachedConnected=$_probeReachedConnected)',
      );
      if (state == ws.ConnectionState.connected) {
        _probeReachedConnected = true;
        // Socket is open and auth was sent. Treat the token as good once
        // the connection survives a short grace window without the server
        // closing it (a real data frame, handled below, confirms it
        // sooner). A bad token's socket is closed well within the window.
        _probeGrace?.cancel();
        _probeGrace = Timer(_verifyGrace, () {
          if (_resolved) return;
          if (_probe == probe && probe.state == ws.ConnectionState.connected) {
            debugPrint(
              '[OSIA Connect] Stayed connected through grace → success.',
            );
            _finishConnection(token);
          }
        });
      } else if (state == ws.ConnectionState.disconnected &&
          _probeReachedConnected) {
        // We were open and authenticated, then the server hung up: that is
        // an auth rejection — a valid token's socket stays up.
        debugPrint(
          '[OSIA Connect] Server closed the socket after auth '
          '→ token rejected.',
        );
        _failConnection(strings.invalidToken);
      }
    });

    _probeMsgSub = probe.messageStream.listen((msg) {
      // Buffer every server frame so the chat screen can replay the initial
      // burst (conversations list, active conversation, history, models)
      // after the hand-off — it subscribes too late to receive these live.
      if (_bufferedMessages.isEmpty) {
        debugPrint(
          '[OSIA Connect] First server frame after auth: '
          '${msg.runtimeType} → token is valid.',
        );
      }
      _bufferedMessages.add(msg);

      // These frames are only ever sent to an authenticated client, so the
      // first one proves the token is valid — enter the chat right away
      // instead of waiting out the grace window.
      if (msg is ws.ConversationsMessage ||
          msg is ws.ModelsListMessage ||
          msg is ws.ActiveConversationMessage ||
          msg is ws.ConversationHistoryMessage) {
        debugPrint(
          '[OSIA Connect] Authenticated frame (${msg.runtimeType}) '
          '→ success.',
        );
        _finishConnection(token);
      }
    });

    _probeErrSub = probe.errorStream.listen((err) {
      debugPrint(
        '[OSIA Connect] probe error: $err '
        '(reachedConnected=$_probeReachedConnected)',
      );
      // A rendezvous 404 means the PC isn't publishing a tunnel URL — it's
      // offline, NOT a bad token. Surface that distinctly so an offline PC is
      // never reported as a rejected token. Otherwise: before the socket ever
      // opened this is a reachability problem; after, it's the server refusing
      // us.
      if (ws.isRelayConnectionError(err)) {
        _failConnection(err);
      } else if (err == kPcOfflineError) {
        _failConnection(strings.pcOffline);
      } else {
        _failConnection(
          _probeReachedConnected
              ? strings.invalidToken
              : strings.connectionFailed,
        );
      }
    });

    probe.connect();
  }

  Future<void> _finishConnection(String token) async {
    if (_resolved) return;
    _resolved = true;
    final probe = _probe;
    debugPrint(
      '[OSIA Connect] SUCCESS — keeping the live connection open to '
      'hand it to the chat screen.',
    );

    // Stop the validation machinery but KEEP the socket open: the same
    // authenticated connection is reused by the chat screen, so we never
    // close+reopen (the gap that left the chat stuck "Connecting"). The
    // message listener stays alive to keep buffering frames until the chat
    // screen subscribes; the connection/error listeners are detached so a
    // transient event during navigation can't tear the socket down.
    _probeTimeout?.cancel();
    _probeTimeout = null;
    _probeGrace?.cancel();
    _probeGrace = null;
    _probeConnSub?.cancel();
    _probeConnSub = null;
    _probeErrSub?.cancel();
    _probeErrSub = null;

    try {
      await widget.storage.setTailscaleIp(StorageService.defaultHost);
      await widget.storage.setToken(token);
    } catch (e) {
      // Persisting shouldn't fail, but if it does don't strand the user on
      // a dead spinner — tear the probe down and surface it so they can retry.
      debugPrint('[OSIA Connect] Failed to persist credentials: $e');
      _disposeProbe();
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _resolved = false;
        _error = OsiaL10n.of(context).connectionFailed;
      });
      return;
    }
    if (probe == null || !mounted) return;
    // Past this point the chat screen owns the socket — dispose() must not
    // close it.
    _handedOff = true;
    debugPrint(
      '[OSIA Connect] Navigating to /chat with the live connection '
      '(${_bufferedMessages.length} buffered frame(s)).',
    );
    Navigator.of(context).pushReplacementNamed(
      '/chat',
      arguments: ChatHandoff(
        service: probe,
        bufferedMessages: _bufferedMessages,
      ),
    );
  }

  void _failConnection(String message) {
    if (_resolved) return;
    _resolved = true;
    debugPrint('[OSIA Connect] FAILURE — "$message"');
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
                      const SizedBox(height: 10),
                      _buildTokenHint(palette, strings),
                      const SizedBox(height: 8),
                      _buildScanButton(palette, strings),
                      const SizedBox(height: 12),
                      _buildError(palette),
                      const SizedBox(height: 12),
                      _buildConnectButton(palette, strings),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          TextButton(
                            key: const Key('onboarding-terms-link'),
                            onPressed: () =>
                                _openLegal(LegalDocument.termsOfService),
                            child: Text(strings.termsOfService),
                          ),
                          Text('·', style: TextStyle(color: palette.textMuted)),
                          TextButton(
                            key: const Key('onboarding-privacy-link'),
                            onPressed: () =>
                                _openLegal(LegalDocument.privacyPolicy),
                            child: Text(strings.privacyPolicy),
                          ),
                        ],
                      ),
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

  void _openLegal(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalScreen(document: document)),
    );
  }

  Widget _buildLogo(OsiaPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The logo mark, shown directly — no disc, no glow. The asset is a
        // tightly-cropped, centred square so BoxFit.contain keeps it centred.
        SizedBox(width: 104, height: 104, child: const AccentLogo()),
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
      key: const Key('pairing-token-field'),
      controller: _tokenCtrl,
      enabled: !_connecting,
      obscureText: _obscureToken,
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
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show/hide toggle for the obscured token.
            IconButton(
              onPressed: _connecting
                  ? null
                  : () => setState(() => _obscureToken = !_obscureToken),
              icon: Icon(
                _obscureToken
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 18,
                color: palette.textMuted,
              ),
            ),
            IconButton(
              onPressed: _connecting ? null : _pasteToken,
              icon: Icon(
                Icons.content_paste_rounded,
                size: 18,
                color: palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton(OsiaPalette palette, OsiaStrings strings) {
    return TextButton.icon(
      key: const Key('pairing-scan-button'),
      onPressed: _connecting ? null : _scanQrCode,
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
      label: Text(strings.scanQrCode),
      style: TextButton.styleFrom(
        foregroundColor: palette.accent,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTokenHint(OsiaPalette palette, OsiaStrings strings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: palette.textMuted.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              strings.tokenHint,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(OsiaPalette palette) {
    // AnimatedSize keeps the layout from jumping when the error appears.
    return AnimatedSize(
      duration: MotionDurations.medium,
      curve: MotionCurves.enter,
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
        key: const Key('pairing-connect-button'),
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
          duration: MotionDurations.medium,
          switchInCurve: MotionCurves.enter,
          switchOutCurve: MotionCurves.exit,
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

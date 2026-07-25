import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n.dart';
import '../pairing_token.dart';
import '../theme.dart';

enum PairingScannerFailure { permissionDenied, unavailable }

/// Camera seam used by deterministic widget tests and the production scanner.
abstract interface class PairingScannerAdapter {
  Widget buildPreview(ValueChanged<String?> onDetect);

  Future<PairingScannerFailure?> start();

  Future<void> stop();

  Future<void> dispose();
}

final class MobilePairingScannerAdapter implements PairingScannerAdapter {
  MobilePairingScannerAdapter()
    : _controller = MobileScannerController(
        autoStart: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
        returnImage: false,
      );

  final MobileScannerController _controller;
  bool _disposed = false;

  @override
  Widget buildPreview(ValueChanged<String?> onDetect) {
    return MobileScanner(
      key: const Key('pairing-scanner-preview'),
      controller: _controller,
      useAppLifecycleState: false,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          if (barcode.format == BarcodeFormat.qrCode) {
            onDetect(barcode.rawValue);
            return;
          }
        }
      },
      errorBuilder: (_, _) => const ColoredBox(color: Colors.black),
    );
  }

  @override
  Future<PairingScannerFailure?> start() async {
    if (_disposed) return PairingScannerFailure.unavailable;
    try {
      await _controller.start();
      return null;
    } on MobileScannerException catch (error) {
      if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
        return PairingScannerFailure.permissionDenied;
      }
      return PairingScannerFailure.unavailable;
    }
  }

  @override
  Future<void> stop() async {
    if (!_disposed) await _controller.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await _controller.stop();
    _disposed = true;
    await _controller.dispose();
  }
}

class PairingScannerScreen extends StatefulWidget {
  const PairingScannerScreen({super.key, this.adapter});

  final PairingScannerAdapter? adapter;

  @override
  State<PairingScannerScreen> createState() => _PairingScannerScreenState();
}

class _PairingScannerScreenState extends State<PairingScannerScreen>
    with WidgetsBindingObserver {
  late final PairingScannerAdapter _adapter;
  PairingScannerFailure? _cameraFailure;
  bool _accepted = false;
  bool _starting = false;
  bool _foreground = true;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _adapter = widget.adapter ?? MobilePairingScannerAdapter();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        unawaited(_startCamera());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _foreground = false;
        unawaited(_adapter.stop());
    }
  }

  Future<void> _startCamera() async {
    if (!mounted || _accepted || _starting) return;
    _starting = true;
    final failure = await _adapter.start();
    _starting = false;
    if (!mounted || _accepted) return;
    if (!_foreground) {
      await _adapter.stop();
      return;
    }
    setState(() => _cameraFailure = failure);
  }

  void _onDetect(String? rawValue) {
    if (_accepted) return;
    final strings = OsiaL10n.of(context);
    final input = parsePairingToken(rawValue);
    if (!input.isValid) {
      setState(() => _scanError = strings.invalidPairingQr);
      return;
    }
    _accepted = true;
    unawaited(_acceptToken(input.value));
  }

  Future<void> _acceptToken(String token) async {
    await _adapter.stop();
    if (mounted) Navigator.of(context).pop(token);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_adapter.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final cameraMessage = switch (_cameraFailure) {
      PairingScannerFailure.permissionDenied =>
        strings.cameraPermissionDeniedForPairing,
      PairingScannerFailure.unavailable => strings.cameraUnavailableForPairing,
      null => null,
    };

    return Scaffold(
      key: const Key('pairing-scanner-screen'),
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        title: Text(strings.scanPairingQrTitle),
        leading: IconButton(
          key: const Key('pairing-scanner-cancel'),
          tooltip: strings.cancel,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _adapter.buildPreview(_onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 248,
                height: 248,
                decoration: BoxDecoration(
                  border: Border.all(color: palette.accent, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cameraMessage ?? _scanError ?? strings.scanPairingQrHint,
                      key: const Key('pairing-scanner-message'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cameraMessage != null || _scanError != null
                            ? palette.error
                            : palette.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    if (cameraMessage != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton(
                            key: const Key('pairing-scanner-retry'),
                            onPressed: _startCamera,
                            child: Text(strings.retry),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(strings.cancel),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

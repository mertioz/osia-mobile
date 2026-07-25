import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/autonomous_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

const sensitiveMarker = 'WOR173_PRIVATE_MARKER_DO_NOT_LEAK';

class _FakeAutonomousWebSocketService extends ws.WebSocketService {
  _FakeAutonomousWebSocketService()
    : super(ip: '127.0.0.1', token: 'synthetic', autoReconnect: false);

  final StreamController<ws.AutonomousProgressMessage> _autonomous =
      StreamController<ws.AutonomousProgressMessage>.broadcast();
  final StreamController<ws.ConfigData> _config =
      StreamController<ws.ConfigData>.broadcast();
  final StreamController<ws.OsiaMessage> _messages =
      StreamController<ws.OsiaMessage>.broadcast();

  @override
  Stream<ws.AutonomousProgressMessage> get autonomousStream =>
      _autonomous.stream;

  @override
  Stream<ws.ConfigData> get configStream => _config.stream;

  @override
  Stream<ws.OsiaMessage> get messageStream => _messages.stream;

  @override
  void sendGetAutonomousStatus() {}

  @override
  void sendGetConfig() {}

  @override
  void sendGetModels() {}

  void emit(ws.AutonomousProgressMessage message) => _autonomous.add(message);

  @override
  void dispose() {
    _autonomous.close();
    _config.close();
    _messages.close();
    super.dispose();
  }
}

void main() {
  test('parses additive typed diagnostics and preserves legacy frames', () {
    final legacy = ws.AutonomousProgressMessage.fromJson({
      'event': 'running',
      'tasks_done': 1,
      'tasks_total': 2,
    });
    expect(legacy.event, 'running');
    expect(legacy.errorCategory, isNull);
    expect(legacy.stage, isNull);

    final parsed = ws.AutonomousProgressMessage.fromJson({
      'event': 'failed',
      'stage': 'verification',
      'error_category': 'verification_error',
      'attempt': 2,
      'max_attempts': 3,
      'replan_count': 1,
      'max_replans': 2,
      'provider': 'synthetic_provider',
      'model': 'synthetic-model',
      'resumable': true,
      'checkpoint_present': true,
      'reason_code': 'verification_error',
      'run_ref': 'run_0123456789ab',
      'transition_at': '2026-07-25T12:00:00+00:00',
    });
    expect(parsed.stage, ws.AutonomousFailureStage.verification);
    expect(
      parsed.errorCategory,
      ws.AutonomousFailureCategory.verificationError,
    );
    expect(parsed.attempt, 2);
    expect(parsed.maxAttempts, 3);
    expect(parsed.replanCount, 1);
    expect(parsed.maxReplans, 2);
    expect(parsed.provider, 'synthetic_provider');
    expect(parsed.model, 'synthetic-model');
    expect(parsed.resumable, isTrue);
    expect(parsed.checkpointPresent, isTrue);
    expect(parsed.reasonCode, 'verification_error');
    expect(parsed.runRef, 'run_0123456789ab');
  });

  test('unknown future category and stage fail closed', () {
    final parsed = ws.AutonomousProgressMessage.fromJson({
      'event': 'failed',
      'stage': 'future_stage',
      'error_category': 'future_failure',
    });
    expect(parsed.stage, ws.AutonomousFailureStage.unknown);
    expect(parsed.errorCategory, ws.AutonomousFailureCategory.unknownFailure);
    expect(
      osiaStringsFr.autonomousFailureDiagnostic(
        parsed.errorCategory!.wireValue,
      ),
      contains('échoué'),
    );
  });

  test('localized category and metadata are consistent', () {
    expect(
      osiaStringsEn.autonomousFailureDiagnostic('planning_timeout'),
      contains('timed out'),
    );
    expect(
      osiaStringsFr.autonomousFailureDiagnostic('planning_timeout'),
      contains('expiré'),
    );
    expect(
      osiaStringsFr.autonomousDiagnosticMetadata(
        attempt: 2,
        maxAttempts: 3,
        replanCount: 1,
        maxReplans: 2,
      ),
      'Tentative 2/3. Plans de reprise 1/2.',
    );
  });

  testWidgets('renders localized category without raw server text', (
    tester,
  ) async {
    final service = _FakeAutonomousWebSocketService();
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: OsiaL10n(
          strings: osiaStringsFr,
          child: MaterialApp(
            theme: buildOsiaTheme(),
            home: AutonomousScreen(wsService: service),
          ),
        ),
      ),
    );

    service.emit(
      ws.AutonomousProgressMessage.fromJson({
        'event': 'failed',
        'phase_name': 'RAW PHASE $sensitiveMarker',
        'status': 'RAW STATUS $sensitiveMarker',
        'reason': 'RAW REASON $sensitiveMarker',
        'stage': 'verification',
        'error_category': 'verification_error',
        'attempt': 2,
        'max_attempts': 3,
        'replan_count': 0,
        'max_replans': 2,
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining("n'a pas pu vérifier"), findsOneWidget);
    expect(find.textContaining('Tentative 2/3.'), findsOneWidget);
    expect(find.textContaining(sensitiveMarker), findsNothing);

    // This screen contains the repository's existing lazy PressableScale
    // controller, whose dispose-only lookup triggers a test-framework assertion.
    // Use the same narrow teardown guard as the adjacent navigation tests.
    final previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final exception = details.exceptionAsString();
      final stack = details.stack?.toString() ?? '';
      if (exception.contains('Looking up a deactivated widget') &&
          stack.contains('_PressableScaleState.dispose')) {
        return;
      }
      previousFlutterErrorHandler?.call(details);
    };
    try {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    } finally {
      FlutterError.onError = previousFlutterErrorHandler;
      service.dispose();
    }
  });

  testWidgets('legacy failure does not render raw phase or status text', (
    tester,
  ) async {
    final service = _FakeAutonomousWebSocketService();
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: OsiaL10n(
          strings: osiaStringsEn,
          child: MaterialApp(
            theme: buildOsiaTheme(),
            home: AutonomousScreen(wsService: service),
          ),
        ),
      ),
    );

    service.emit(
      ws.AutonomousProgressMessage.fromJson({
        'event': 'failed',
        'phase_name': 'RAW PHASE $sensitiveMarker',
        'status': 'RAW STATUS $sensitiveMarker',
        'reason': 'RAW REASON $sensitiveMarker',
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining(sensitiveMarker), findsNothing);

    final previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final exception = details.exceptionAsString();
      final stack = details.stack?.toString() ?? '';
      if (exception.contains('Looking up a deactivated widget') &&
          stack.contains('_PressableScaleState.dispose')) {
        return;
      }
      previousFlutterErrorHandler?.call(details);
    };
    try {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    } finally {
      FlutterError.onError = previousFlutterErrorHandler;
      service.dispose();
    }
  });

  testWidgets('typed failure on legacy idle event renders as failed', (
    tester,
  ) async {
    final service = _FakeAutonomousWebSocketService();
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: OsiaL10n(
          strings: osiaStringsEn,
          child: MaterialApp(
            theme: buildOsiaTheme(),
            home: AutonomousScreen(wsService: service),
          ),
        ),
      ),
    );

    service.emit(
      ws.AutonomousProgressMessage.fromJson({
        'event': 'idle',
        'stage': 'resume',
        'error_category': 'invalid_resume_state',
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('cannot be resumed safely'), findsOneWidget);

    final previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final exception = details.exceptionAsString();
      final stack = details.stack?.toString() ?? '';
      if (exception.contains('Looking up a deactivated widget') &&
          stack.contains('_PressableScaleState.dispose')) {
        return;
      }
      previousFlutterErrorHandler?.call(details);
    };
    try {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    } finally {
      FlutterError.onError = previousFlutterErrorHandler;
      service.dispose();
    }
  });
}

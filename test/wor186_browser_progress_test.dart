import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/autonomous_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

Map<String, dynamic> _browserFrame(
  ws.WebSocketService service, {
  int sequence = 1,
  String eventId = 'browser-event:one',
  String sessionId = 'browser-session:one',
  String runId = 'run-one',
  int planRevision = 1,
  int authorizationRevision = 1,
  String phase = 'waiting',
  String site = 'https://example.test',
  String text = 'Waiting for the download',
  bool terminal = false,
  Map<String, dynamic>? artifact,
}) => <String, dynamic>{
  'type': 'browser_progress',
  'schema_version': 1,
  'event_id': eventId,
  'sequence': sequence,
  'server_id': service.expectedPermissionServerIdForTest,
  'session_id': sessionId,
  'browser_session_id': 'browser-owner:one',
  'run_id': runId,
  'plan_revision': planRevision,
  'authorization_revision': authorizationRevision,
  'safe_operation_phase': phase,
  'safe_site_display': site,
  'safe_progress_text': text,
  'artifact_safe_summary': artifact,
  'terminal': terminal,
};

Map<String, dynamic> _autonomousFrame(
  ws.WebSocketService service, {
  int sequence = 1,
  String eventId = 'autonomous-event:one',
  String sessionId = 'autonomous-session:one',
  String runId = 'run-one',
  int planRevision = 1,
  int authorizationRevision = 1,
  String event = 'running',
  String text = 'Autonomous work is running',
  bool terminal = false,
}) => <String, dynamic>{
  'type': 'autonomous_progress',
  'schema_version': 1,
  'event_id': eventId,
  'sequence': sequence,
  'server_id': service.expectedPermissionServerIdForTest,
  'session_id': sessionId,
  'run_id': runId,
  'plan_revision': planRevision,
  'authorization_revision': authorizationRevision,
  'event': event,
  'safe_operation_phase': event,
  'safe_site_display': 'https://example.test',
  'safe_progress_text': text,
  'artifact_safe_summary': null,
  'terminal': terminal,
  'tasks_done': terminal ? 1 : 0,
  'tasks_total': 1,
};

ws.WebSocketService _service({List<Map<String, dynamic>>? sent}) =>
    ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'wor186-token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        sent?.add(frame);
        return true;
      },
    );

void main() {
  test(
    'browser frames reject duplicate, older, wrong run/revision and leaks',
    () async {
      final service = _service();
      addTearDown(service.dispose);
      service.setPermissionConnectionForTest(true);
      final accepted = <ws.BrowserProgressMessage>[];
      final sub = service.browserProgressStream.listen(accepted.add);
      addTearDown(sub.cancel);

      service.handleIncomingFrameForTest(_browserFrame(service));
      service.handleIncomingFrameForTest(
        _browserFrame(service, eventId: 'browser-event:duplicate'),
      );
      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 2,
          eventId: 'browser-event:wrong-run',
          runId: 'run-two',
          phase: 'downloading',
          text: 'Downloading to private storage',
        ),
      );
      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 2,
          eventId: 'browser-event:old-revision',
          planRevision: 0,
        ),
      );
      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 2,
          eventId: 'browser-event:query-leak',
          site: 'https://example.test/safe?token=PRIVATE_TOKEN',
        ),
      );
      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 2,
          eventId: 'browser-event:account-path-leak',
          site: 'https://example.test/account/PRIVATE_ACCOUNT',
        ),
      );
      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 2,
          eventId: 'browser-event:filename-leak',
          phase: 'complete',
          text: 'Private artifact ready',
          terminal: true,
          artifact: <String, dynamic>{
            'private': true,
            'size': 12,
            'filename': 'PRIVATE_FILE.txt',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(accepted, hasLength(1));
      expect(service.browserProgress?.sequence, 1);

      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 2,
          eventId: 'browser-event:complete',
          phase: 'complete',
          text: 'Private artifact ready',
          terminal: true,
          artifact: <String, dynamic>{'private': true, 'size': 12},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(accepted, hasLength(2));
      expect(service.browserProgress?.artifactSafeSummary, <String, dynamic>{
        'private': true,
        'size': 12,
      });
      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 3,
          eventId: 'browser-event:after-terminal',
          phase: 'downloading',
          text: 'Downloading to private storage',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(accepted, hasLength(2));
      expect(service.browserProgress?.terminal, isTrue);
    },
  );

  test(
    'reconnect refresh accepts current/new session and rejects retired session',
    () async {
      final sent = <Map<String, dynamic>>[];
      final service = _service(sent: sent);
      addTearDown(service.dispose);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(_browserFrame(service));
      expect(service.browserProgressLive, isTrue);

      service.setPermissionConnectionForTest(false);
      service.setPermissionConnectionForTest(true);
      expect(service.browserProgressLive, isFalse);
      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 2,
          eventId: 'browser-event:same-session-refresh',
          phase: 'snapshot',
          text: 'Browser state refreshed',
        ),
      );
      expect(service.browserProgressLive, isTrue);

      service.setPermissionConnectionForTest(false);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 1,
          eventId: 'browser-event:new-session',
          sessionId: 'browser-session:two',
          phase: 'snapshot',
          text: 'Browser state refreshed',
        ),
      );
      expect(service.browserProgressLive, isTrue);
      expect(service.browserProgress?.sessionId, 'browser-session:two');

      service.setPermissionConnectionForTest(false);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 3,
          eventId: 'browser-event:retired-session',
        ),
      );
      expect(service.browserProgressLive, isFalse);
      service.handleIncomingFrameForTest(
        _browserFrame(
          service,
          sequence: 2,
          eventId: 'browser-event:current-session',
          sessionId: 'browser-session:two',
          phase: 'snapshot',
          text: 'Browser state refreshed',
        ),
      );
      expect(service.browserProgressLive, isTrue);

      service.expectAuthenticatedInitialSyncForTest();
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'status',
        'content': 'done',
      });
      expect(
        sent.any((frame) => frame['type'] == 'get_autonomous_status'),
        isTrue,
      );
      expect(
        sent.any(
          (frame) =>
              frame['type'] == 'get_browser_status' &&
              frame['schema_version'] == 1,
        ),
        isTrue,
      );
    },
  );

  test(
    'canonical Autonomous terminal cannot be replaced by stale progress',
    () async {
      final service = _service();
      addTearDown(service.dispose);
      service.setPermissionConnectionForTest(true);
      final accepted = <ws.AutonomousProgressMessage>[];
      final sub = service.autonomousStream.listen(accepted.add);
      addTearDown(sub.cancel);

      service.handleIncomingFrameForTest(
        _autonomousFrame(
          service,
          eventId: 'autonomous-event:unknown',
          event: 'private_event',
          text: 'Autonomous state updated',
        ),
      );
      service.handleIncomingFrameForTest(_autonomousFrame(service));
      service.handleIncomingFrameForTest(
        _autonomousFrame(
          service,
          sequence: 2,
          eventId: 'autonomous-event:terminal',
          event: 'done',
          text: 'Autonomous work completed',
          terminal: true,
        ),
      );
      service.handleIncomingFrameForTest(
        _autonomousFrame(
          service,
          sequence: 3,
          eventId: 'autonomous-event:late',
          event: 'task_done',
          text: 'One planned step completed',
        ),
      );
      service.handleIncomingFrameForTest(
        _autonomousFrame(
          service,
          sequence: 4,
          eventId: 'autonomous-event:wrong-revision',
          planRevision: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(accepted.map((item) => item.event), <String?>['running', 'done']);
    },
  );

  testWidgets('Autonomous shows only safe browser progress and private size', (
    tester,
  ) async {
    final service = _service();
    addTearDown(service.dispose);
    service.setPermissionConnectionForTest(true);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOsiaTheme(osiaPaletteViolet),
        home: OsiaTheme(
          palette: osiaPaletteViolet,
          child: OsiaL10n(
            strings: osiaStringsEn,
            child: AutonomousScreen(wsService: service),
          ),
        ),
      ),
    );
    service.handleIncomingFrameForTest(
      _browserFrame(
        service,
        phase: 'complete',
        text: 'Private artifact ready',
        terminal: true,
        artifact: <String, dynamic>{'private': true, 'size': 1536},
      ),
    );
    expect(service.browserProgressLive, isTrue);
    await tester.pump();
    expect(find.byKey(const Key('browser-progress-card')), findsOneWidget);
    expect(find.text('Private artifact ready'), findsOneWidget);
    expect(find.text('Private artifact · 1.5 KiB'), findsOneWidget);
    expect(find.textContaining('PRIVATE_'), findsNothing);
    expect(find.textContaining('?token='), findsNothing);

    service.setPermissionConnectionForTest(false);
    await tester.pump();
    expect(find.byKey(const Key('browser-progress-card')), findsOneWidget);
    expect(find.text('Private artifact ready'), findsOneWidget);
    expect(
      find.byKey(const Key('browser-progress-last-known')),
      findsOneWidget,
    );

    service.setPermissionConnectionForTest(true);
    await tester.pump();
    expect(
      find.byKey(const Key('browser-progress-last-known')),
      findsOneWidget,
    );
    service.handleIncomingFrameForTest(
      _browserFrame(
        service,
        sequence: 2,
        eventId: 'browser-event:fresh-snapshot',
        phase: 'snapshot',
        text: 'Private artifact ready',
        terminal: true,
        artifact: <String, dynamic>{'private': true, 'size': 1536},
      ),
    );
    expect(service.browserProgressLive, isTrue);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('browser-progress-last-known')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
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
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    } finally {
      FlutterError.onError = previousFlutterErrorHandler;
    }
  });
}

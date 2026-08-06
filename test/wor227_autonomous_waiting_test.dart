import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/autonomous_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

Map<String, dynamic> _progressFrame(
  ws.WebSocketService service, {
  required int sequence,
  required String event,
  required String durableState,
  bool terminal = false,
}) => <String, dynamic>{
  'type': 'autonomous_progress',
  'schema_version': 1,
  'event_id': 'wor227-durable-$sequence',
  'sequence': sequence,
  'server_id': service.expectedPermissionServerIdForTest,
  'session_id': 'wor227-durable-session',
  'run_id': 'wor227-durable-run',
  'plan_revision': 1,
  'authorization_revision': 1,
  'event': event,
  'safe_operation_phase': event,
  'safe_site_display': '',
  'safe_progress_text': event == 'cancelled'
      ? 'Autonomous work was cancelled'
      : 'Autonomous state updated',
  'terminal': terminal,
  'status': terminal ? 'aborted' : 'in_progress',
  'run_state': durableState,
  'durable_state': durableState,
  'tasks_done': 0,
  'tasks_total': 1,
  'provider': 'fixture-provider',
  'model': 'fixture-model',
};

void main() {
  test('strict progress parser accepts additive durable states', () async {
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'test',
      autoReconnect: false,
      sendFrameForTest: (_) => true,
    );
    addTearDown(service.dispose);
    final received = <ws.AutonomousProgressMessage>[];
    final subscription = service.autonomousStream.listen(received.add);
    addTearDown(subscription.cancel);

    service.handleIncomingFrameForTest(
      _progressFrame(
        service,
        sequence: 1,
        event: 'state_updated',
        durableState: 'waiting_tool',
      ),
    );
    service.handleIncomingFrameForTest(
      _progressFrame(
        service,
        sequence: 2,
        event: 'blocked_outcome_unknown',
        durableState: 'blocked_unknown_effect',
      ),
    );
    service.handleIncomingFrameForTest(
      _progressFrame(
        service,
        sequence: 3,
        event: 'cancelled',
        durableState: 'cancelled_proven',
        terminal: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(received.map((message) => message.durableState), <String>[
      'waiting_tool',
      'blocked_unknown_effect',
      'cancelled_proven',
    ]);
    expect(received.last.terminal, isTrue);
  });

  test('reconnect cache retains canonical Autonomous waiting identity', () {
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'test',
      autoReconnect: false,
      sendFrameForTest: (_) => true,
    );
    addTearDown(service.dispose);
    service.handleIncomingFrameForTest(
      _progressFrame(
        service,
        sequence: 1,
        event: 'state_updated',
        durableState: 'waiting_tool',
      ),
    );

    expect(service.autonomousProgress?.runId, 'wor227-durable-run');
    expect(service.autonomousProgress?.durableState, 'waiting_tool');
    expect(service.autonomousProgress?.terminal, isFalse);
  });

  test('terminal failure outranks its preserved unknown-effect run state', () {
    const progress = ws.AutonomousProgressMessage(
      event: 'failed',
      terminal: true,
      status: 'failed',
      runState: 'blocked_unknown_effect',
      durableState: '',
    );

    expect(autonomousRunLifecycleForTest(progress), 'failed');
  });

  test('durable Autonomous labels are explicit in French and English', () {
    expect(
      autonomousDurableStateLabel(osiaStringsFr, 'waiting_tool'),
      'En attente de vérification du résultat…',
    );
    expect(
      autonomousDurableStateLabel(osiaStringsEn, 'waiting_tool'),
      'Waiting to verify the result…',
    );
    expect(
      autonomousDurableStateLabel(osiaStringsFr, 'blocked_unknown_effect'),
      contains('sans répétition de l’action'),
    );
    expect(
      autonomousDurableStateLabel(osiaStringsEn, 'cancelled_proven'),
      'The action was cancelled before any effect was confirmed.',
    );
  });
}

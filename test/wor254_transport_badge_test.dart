import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/services/transport_coordinator.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/connection_badge.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';
import 'package:osia_mobile/widgets/transport_status_sheet.dart';

Widget host(Widget child, {OsiaStrings strings = osiaStringsEn}) => OsiaTheme(
  palette: osiaPaletteViolet,
  child: OsiaL10n(
    strings: strings,
    child: MaterialApp(
      theme: buildOsiaTheme(),
      home: Scaffold(body: Center(child: child)),
    ),
  ),
);

ws.WebSocketService service() => ws.WebSocketService(
  ip: '127.0.0.1',
  token: 'wor-254-route-token',
  autoReconnect: false,
  relayFallbackV1: false,
  lanDirectV1: false,
  webRtcDirectV1: false,
);

Map<String, dynamic> traceEvent({
  required String id,
  required int sequence,
  required String kind,
  required String displayKey,
  bool terminal = false,
}) => <String, dynamic>{
  'schema_version': executionTraceSchemaVersion,
  'event_id': id,
  'conversation_id': 'conv-254',
  'request_id': 'request-254',
  'turn_id': 'turn-254',
  'sequence': sequence,
  'revision': 1,
  'kind': kind,
  'display': <String, Object?>{'key': displayKey, 'args': <String, Object?>{}},
  'timestamp': '2026-08-10T10:00:00Z',
  'terminal': terminal,
  'redaction_class': executionTraceRedactionClass,
};

ExecutionTraceSnapshot snapshot(List<Map<String, dynamic>> events) =>
    ExecutionTraceSnapshot.parseHistory(<String, dynamic>{
      'schema_version': executionTraceSchemaVersion,
      'conversation_id': 'conv-254',
      'request_id': 'request-254',
      'turn_id': 'turn-254',
      'redaction_class': executionTraceRedactionClass,
      'events': events,
    })!;

void main() {
  testWidgets('green health dot opens a live committed-route sheet', (
    tester,
  ) async {
    final client = service();
    addTearDown(client.dispose);
    expect(
      client.acquireApplicationTransportForTest(ApplicationTransportKind.lan),
      isTrue,
    );
    client.markDirectTransportConnectedForTest(ApplicationTransportKind.lan);

    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => ConnectionBadge(
            state: ws.ConnectionState.connected,
            onTap: () => showTransportStatusSheet(context, client),
          ),
        ),
      ),
    );
    expect(find.byTooltip(osiaStringsEn.connected), findsOneWidget);
    expect(find.byType(ConnectionBadge), findsOneWidget);

    await tester.tap(find.byType(ConnectionBadge));
    await tester.pumpAndSettle();
    expect(find.text(osiaStringsEn.activeTransportTitle), findsOneWidget);
    expect(
      find.text(
        osiaStringsEn.transportStateText(
          ws.CommittedTransportState.lanDirect.name,
        ),
      ),
      findsOneWidget,
    );

    client.disconnect();
    await tester.pump();
    expect(
      find.text(
        osiaStringsEn.transportStateText(
          ws.CommittedTransportState.switching.name,
        ),
      ),
      findsOneWidget,
    );
  });

  test('committed route is rejected without an authority lease', () {
    final client = service();
    addTearDown(client.dispose);
    client.markDirectTransportConnectedForTest(ApplicationTransportKind.lan);
    expect(
      client.committedTransportState,
      ws.CommittedTransportState.switching,
    );
  });

  testWidgets('terminal trace is one collapsed row and expands locally', (
    tester,
  ) async {
    final goal = traceEvent(
      id: 'trace-goal',
      sequence: 1,
      kind: 'goal',
      displayKey: 'execution.goal.complete_task',
    );
    final terminal = traceEvent(
      id: 'trace-terminal',
      sequence: 2,
      kind: 'terminal',
      displayKey: 'execution.terminal.success',
      terminal: true,
    );
    await tester.pumpWidget(
      host(
        ExecutionTraceBlock(
          snapshot: snapshot(<Map<String, dynamic>>[goal, terminal]),
          collapsed: true,
        ),
      ),
    );

    expect(find.byType(ExecutionTraceBlock), findsOneWidget);
    expect(find.text(osiaStringsEn.executionTraceTitle), findsOneWidget);
    expect(
      find.text(
        osiaStringsEn.executionTraceText('execution.goal.complete_task'),
      ),
      findsNothing,
    );
    await tester.tap(find.text(osiaStringsEn.executionTraceTitle));
    await tester.pump();
    expect(
      find.text(
        osiaStringsEn.executionTraceText('execution.goal.complete_task'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });

  testWidgets('live trace starts expanded', (tester) async {
    final action = traceEvent(
      id: 'trace-action',
      sequence: 1,
      kind: 'action',
      displayKey: 'execution.action.browser',
    );
    await tester.pumpWidget(
      host(
        ExecutionTraceBlock(snapshot: snapshot(<Map<String, dynamic>>[action])),
      ),
    );
    expect(
      find.text(osiaStringsEn.executionTraceText('execution.action.browser')),
      findsNWidgets(2),
    );
  });

  test('WOR-254 labels exist in every supported language', () {
    for (final code in osiaSupportedLanguages) {
      final strings = osiaStringsForCode(code);
      expect(strings.activeTransportTitle, isNotEmpty);
      expect(strings.executionTraceTitle, isNotEmpty);
      for (final state in ws.CommittedTransportState.values) {
        expect(strings.transportStateText(state.name), isNotEmpty);
      }
      for (final key in executionTraceDisplayKeys.keys) {
        expect(strings.executionTraceText(key), isNotEmpty);
        expect(strings.executionTraceText(key), isNot(key));
      }
    }
  });
}

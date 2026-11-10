import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/providers_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

class _CronSocket extends ws.WebSocketService {
  _CronSocket(this.sent)
    : super(
        ip: '127.0.0.1',
        token: 'test-only',
        autoReconnect: false,
        sendFrameForTest: (frame) {
          sent.add(frame);
          return true;
        },
      );

  final List<Map<String, dynamic>> sent;

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  Future<void> ensureConnected({
    String reason = 'unspecified',
    bool forceReconnect = false,
  }) async {}

  List<Map<String, dynamic>> get writes => sent
      .where(
        (frame) =>
            frame['type'] == 'set_setting' && frame['key'] == 'cron_jobs',
      )
      .toList();

  void emitConfig(
    String revision,
    List<Map<String, dynamic>> jobs, {
    bool conflict = false,
  }) {
    handleIncomingFrameForTest({
      'type': 'config',
      'config': {
        'cron_jobs': jobs,
        'cron_jobs_revision': revision,
        if (conflict) 'cron_jobs_conflict': true,
      },
    });
  }
}

const _original = {
  'id': 'original',
  'task': 'Original task',
  'schedule': 'every 5 minutes',
  'enabled': true,
};
const _newOnPc = {
  'id': 'new-on-pc',
  'task': 'Added on PC',
  'schedule': 'every 10 minutes',
  'enabled': true,
};

Future<_CronSocket> _openCron(WidgetTester tester) async {
  final service = _CronSocket([]);
  addTearDown(service.dispose);
  await tester.pumpWidget(
    OsiaTheme(
      palette: osiaPalette,
      child: OsiaL10n(
        strings: osiaStringsEn,
        child: MaterialApp(
          home: Scaffold(body: SystemSettingsSection(wsService: service)),
        ),
      ),
    ),
  );
  service.emitConfig('revision-1', [_original]);
  await tester.pump();
  await tester.tap(find.text(osiaStringsEn.catScheduledTasks));
  await tester.pumpAndSettle();
  return service;
}

void main() {
  testWidgets('a stale toggle reloads the PC list and its revision', (
    tester,
  ) async {
    final service = await _openCron(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(service.writes.single['expected_cron_jobs_revision'], 'revision-1');
    expect(service.writes.single['value'], [
      {..._original, 'enabled': false},
    ]);

    service.emitConfig('revision-2', [_original, _newOnPc], conflict: true);
    await tester.pumpAndSettle();
    expect(find.text(osiaStringsEn.cronJobsConflict), findsOneWidget);
    expect(find.text('Added on PC'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);

    await tester.tap(find.byType(Switch).first);
    expect(service.writes.last['expected_cron_jobs_revision'], 'revision-2');
    expect(service.writes.last['value'], [
      {..._original, 'enabled': false},
      _newOnPc,
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an open editor cannot save over a newer PC snapshot', (
    tester,
  ) async {
    final service = await _openCron(tester);
    await tester.tap(find.text('Original task'));
    await tester.pump();
    service.handleIncomingFrameForTest({
      'type': 'conversations_list',
      'conversations': [],
    });
    await tester.pumpAndSettle();

    service.emitConfig('revision-2', [_newOnPc]);
    await tester.pump();
    final save = find.text(osiaStringsEn.save);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(service.writes, isEmpty);
    expect(find.text('Added on PC'), findsOneWidget);
    expect(find.text(osiaStringsEn.cronJobsConflict), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('legacy PCs still receive the original scheduled-task frame', () {
    final service = _CronSocket([]);
    addTearDown(service.dispose);
    service.sendSetCronJobs([_original]);
    expect(service.writes.single, {
      'type': 'set_setting',
      'key': 'cron_jobs',
      'value': [_original],
    });
  });

  test('an unavailable revision does not bypass the PC revision guard', () {
    final service = _CronSocket([]);
    addTearDown(service.dispose);
    final config = ws.ConfigData.fromJson({'cron_jobs_revision': ''});
    service.sendSetCronJobs([
      _original,
    ], expectedRevision: config.cronJobsRevision);
    expect(service.writes.single['expected_cron_jobs_revision'], '');
  });
}

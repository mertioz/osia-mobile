import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/permissions_settings_section.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

Map<String, dynamic> _contract() => <String, dynamic>{
  'schema_version': 1,
  'custom_access': 'derived',
  'full_access_activation': 'local_pc_ceremony',
  'mobile_changes': 'canonical_requests',
  'categories': <Map<String, dynamic>>[
    for (final key in ws.permissionCategoryKeys)
      <String, dynamic>{
        'id': key,
        'label_key': 'permissions.category.$key',
        'description_key': 'permissions.switch.$key',
        'delegation_rule': key == 'purchases_payments'
            ? 'ordinary_actions_with_pc_limits'
            : key == 'autonomous_actions' || key == 'scheduled_actions'
            ? 'explicit_scoped_or_ordinary_actions'
            : 'ordinary_actions_only',
        'mobile_request_allowed': true,
      },
  ],
};

Map<String, bool> _categories({bool enabled = false}) => <String, bool>{
  for (final key in ws.permissionCategoryKeys) key: enabled,
};

Map<String, dynamic> _snapshot(
  ws.WebSocketService service, {
  String session = 'permission-session:wor218',
  int sequence = 1,
  int epoch = 3,
  bool fullAccess = false,
  bool storeAvailable = true,
  Map<String, bool>? categories,
  List<Map<String, dynamic>>? permissions,
  List<Map<String, dynamic>>? history,
}) {
  final values = categories ?? _categories(enabled: fullAccess);
  return <String, dynamic>{
    'type': 'permission_snapshot',
    'schema_version': 1,
    'snapshot_id': 'snapshot:$session:$sequence',
    'server_id': service.expectedPermissionServerIdForTest,
    'session_id': session,
    'policy_epoch': epoch,
    'sequence': sequence,
    'generated_at': 2000000000.0 + sequence,
    'preset': fullAccess
        ? 'full_access'
        : values.values.any((value) => value)
        ? 'mixed'
        : 'default_access',
    'categories': values,
    'full_access_active': fullAccess,
    'protected_store': storeAvailable ? 'available' : 'unavailable',
    'temporary_permissions': permissions ?? <Map<String, dynamic>>[],
    'history':
        history ??
        <Map<String, dynamic>>[
          <String, dynamic>{
            'timestamp': 2000000000.0,
            'event': 'automatic_permission_changed',
            'context': '',
          },
        ],
    'pending_requests': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _temporary(String id, {String context = 'chat'}) =>
    <String, dynamic>{
      'action_label': context == 'scheduled' ? 'commands' : 'files_and_folders',
      'context': context,
      'expires_at': 2100000000.0,
      'remaining_uses': 2,
      'mobile_item_id': id,
      'revocable': true,
    };

Map<String, dynamic> _ack(
  ws.WebSocketService service,
  Map<String, dynamic> request,
) => <String, dynamic>{
  'type': 'permission_revocation_ack',
  'schema_version': 1,
  'request_id': request['request_id'],
  'server_id': service.expectedPermissionServerIdForTest,
  'session_id': request['session_id'],
  'base_policy_epoch': request['expected_policy_epoch'],
  'base_snapshot_sequence': request['expected_snapshot_sequence'],
  'status': 'applied',
  'reason': 'applied',
  'policy_epoch': request['expected_policy_epoch'] + 1,
};

void _emitContract(ws.WebSocketService service, [Object? contract]) {
  service.handleIncomingFrameForTest(<String, dynamic>{
    'type': 'config',
    'config': <String, dynamic>{'permission_contract': contract ?? _contract()},
  });
}

Widget _screenHarness(
  ws.WebSocketService service, {
  OsiaPalette palette = osiaPaletteViolet,
  Duration timeout = const Duration(seconds: 30),
  Size size = const Size(412, 915),
  double textScale = 1,
}) => OsiaTheme(
  palette: palette,
  child: OsiaL10n(
    strings: osiaStringsEn,
    child: MaterialApp(
      theme: buildOsiaTheme(palette),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: PermissionsScreen(wsService: service, requestTimeout: timeout),
      ),
    ),
  ),
);

Future<void> _pumpScreen(
  WidgetTester tester,
  ws.WebSocketService service, {
  Duration timeout = const Duration(seconds: 30),
  OsiaPalette palette = osiaPaletteViolet,
  Size size = const Size(412, 915),
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    _screenHarness(
      service,
      timeout: timeout,
      palette: palette,
      size: size,
      textScale: textScale,
    ),
  );
  _emitContract(service);
  await tester.pump();
}

ws.WebSocketService _service(List<Map<String, dynamic>> sent) {
  final service = ws.WebSocketService(
    ip: '127.0.0.1',
    token: 'wor218-token',
    autoReconnect: false,
    sendFrameForTest: (frame) {
      sent.add(frame);
      return true;
    },
  );
  service.setPermissionConnectionForTest(true);
  return service;
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.text('Confirm'));
  await tester.pump();
}

void main() {
  testWidgets('compact entry shows only canonical summary and opens on tap', (
    tester,
  ) async {
    final sent = <Map<String, dynamic>>[];
    final service = _service(sent);
    addTearDown(service.dispose);
    service.handleIncomingFrameForTest(_snapshot(service));
    var opened = false;
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: OsiaL10n(
          strings: osiaStringsEn,
          child: MaterialApp(
            home: Scaffold(
              body: PermissionsSettingsEntry(
                wsService: service,
                onTap: () => opened = true,
              ),
            ),
          ),
        ),
      ),
    );
    _emitContract(service);
    await tester.pump();

    expect(find.byKey(const Key('settings-permissions-entry')), findsOneWidget);
    expect(find.text('PC-controlled access'), findsOneWidget);
    expect(find.text('Ask every time'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byKey(const Key('permission-history')), findsNothing);
    expect(find.text('Temporary permissions'), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const Key('settings-permissions-entry')))
          .height,
      greaterThanOrEqualTo(68),
    );

    await tester.tap(find.byKey(const Key('settings-permissions-entry')));
    expect(opened, isTrue);
  });

  testWidgets(
    'dedicated screen renders Default, Custom, Full and every PC category',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      final service = _service(sent);
      addTearDown(service.dispose);
      service.handleIncomingFrameForTest(_snapshot(service));
      await _pumpScreen(tester, service);

      expect(find.byKey(const Key('permissions-screen')), findsOneWidget);
      expect(find.byKey(const Key('mode-default-access')), findsOneWidget);
      expect(find.byKey(const Key('mode-custom-access')), findsOneWidget);
      expect(find.byKey(const Key('mode-full-access')), findsOneWidget);
      for (final key in ws.permissionCategoryKeys) {
        expect(find.byKey(Key('permission-category-$key')), findsOneWidget);
      }
      expect(find.text('Ask every time'), findsWidgets);

      final custom = _categories()..['commands'] = true;
      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 2, epoch: 4, categories: custom),
      );
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('permission-current-mode')))
            .data,
        'Custom Access',
      );

      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 3, epoch: 5, fullAccess: true),
      );
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('permission-current-mode')))
            .data,
        'Full Access',
      );
      expect(find.byKey(const Key('disable-full-access')), findsOneWidget);
    },
  );

  testWidgets(
    'category request has no optimistic state and handles accept reject timeout',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      final service = _service(sent);
      addTearDown(service.dispose);
      service.handleIncomingFrameForTest(_snapshot(service));
      await _pumpScreen(
        tester,
        service,
        timeout: const Duration(milliseconds: 50),
      );

      final row = find.byKey(const Key('permission-category-files_modify'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      final request = sent.last;
      expect(request['type'], 'set_setting');
      expect(request['key'], 'permission_change_request');
      final envelope = request['value'] as Map<String, dynamic>;
      expect(envelope['operation'], 'set_category');
      expect(envelope['category_id'], 'files_modify');
      expect(envelope['enabled'], isTrue);
      expect(envelope['expected_policy_epoch'], 3);
      expect(service.permissionSnapshot!.categories['files_modify'], isFalse);
      expect(find.byKey(const Key('permission-pending')), findsOneWidget);

      final accepted = _categories()..['files_modify'] = true;
      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 2, epoch: 4, categories: accepted),
      );
      await tester.pump();
      expect(service.permissionSnapshot!.categories['files_modify'], isTrue);
      expect(find.byKey(const Key('permission-pending')), findsNothing);

      await tester.tap(row);
      await tester.pump();
      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 3, epoch: 4, categories: accepted),
      );
      await tester.pump();
      expect(service.permissionSnapshot!.categories['files_modify'], isTrue);
      expect(find.text('The PC did not apply that change.'), findsOneWidget);

      final commands = find.byKey(const Key('permission-category-commands'));
      await tester.ensureVisible(commands);
      await tester.tap(commands);
      await tester.pump(const Duration(milliseconds: 60));
      expect(service.permissionSnapshot!.categories['commands'], isFalse);
      expect(find.text('The confirmed PC state was restored.'), findsOneWidget);
    },
  );

  testWidgets(
    'Full Access waits for the local PC ceremony and never claims success',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      final service = _service(sent);
      addTearDown(service.dispose);
      service.handleIncomingFrameForTest(_snapshot(service));
      await _pumpScreen(tester, service);

      final fullAccess = find.byKey(const Key('mode-full-access'));
      await tester.ensureVisible(fullAccess);
      await tester.tap(fullAccess);
      await tester.pump();
      expect(
        find.textContaining('Confirmation required on the PC'),
        findsOneWidget,
      );
      await _confirm(tester);
      final envelope = sent.last['value'] as Map<String, dynamic>;
      expect(envelope['operation'], 'request_full_access');
      expect(service.permissionSnapshot!.fullAccessActive, isFalse);
      expect(find.byKey(const Key('full-access-pending-pc')), findsOneWidget);
      expect(find.text('Confirmed by your PC.'), findsNothing);

      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 2, epoch: 3),
      );
      await tester.pump();
      expect(find.byKey(const Key('full-access-pending-pc')), findsOneWidget);

      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 3, epoch: 4, fullAccess: true),
      );
      await tester.pump();
      expect(service.permissionSnapshot!.fullAccessActive, isTrue);
      expect(find.byKey(const Key('full-access-pending-pc')), findsNothing);
      expect(find.text('Confirmed by your PC.'), findsOneWidget);
    },
  );

  testWidgets(
    'individual and global temporary revocation await canonical PC state',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      final service = _service(sent);
      addTearDown(service.dispose);
      final permissions = <Map<String, dynamic>>[
        _temporary('permission:item-one'),
        _temporary('permission:item-two', context: 'scheduled'),
      ];
      service.handleIncomingFrameForTest(
        _snapshot(service, permissions: permissions),
      );
      await _pumpScreen(tester, service);

      final first = find.byKey(
        const Key('temporary-permission-permission:item-one'),
      );
      final revoke = find.descendant(of: first, matching: find.text('Revoke'));
      await tester.ensureVisible(revoke);
      await tester.tap(revoke);
      await tester.pump();
      await _confirm(tester);
      var request = sent.last;
      expect(request['operation'], 'revoke_temporary_permission');
      expect(service.permissionSnapshot!.temporaryPermissions, hasLength(2));
      service.handleIncomingFrameForTest(_ack(service, request));
      service.handleIncomingFrameForTest(
        _snapshot(
          service,
          sequence: 2,
          epoch: 4,
          permissions: <Map<String, dynamic>>[permissions.last],
        ),
      );
      await tester.pump();
      expect(service.permissionSnapshot!.temporaryPermissions, hasLength(1));

      final revokeAll = find.byKey(
        const Key('revoke-all-temporary-permissions'),
      );
      await tester.ensureVisible(revokeAll);
      await tester.tap(revokeAll);
      await tester.pump();
      await _confirm(tester);
      request = sent.last;
      expect(request['type'], 'set_setting');
      expect(
        (request['value'] as Map<String, dynamic>)['operation'],
        'revoke_all_temporary_permissions',
      );
      expect(service.permissionSnapshot!.temporaryPermissions, hasLength(1));
      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 3, epoch: 5, permissions: const []),
      );
      await tester.pump();
      expect(service.permissionSnapshot!.temporaryPermissions, isEmpty);
    },
  );

  testWidgets('disconnect and incompatible contract remain fail closed', (
    tester,
  ) async {
    final sent = <Map<String, dynamic>>[];
    final service = _service(sent);
    addTearDown(service.dispose);
    service.handleIncomingFrameForTest(_snapshot(service));
    await _pumpScreen(tester, service);

    final commands = find.byKey(const Key('permission-category-commands'));
    await tester.ensureVisible(commands);
    await tester.tap(commands);
    await tester.pump();
    service.setPermissionConnectionForTest(false);
    await tester.pump();
    expect(find.text('PC offline'), findsOneWidget);
    expect(find.byKey(const Key('permission-pending')), findsNothing);
    expect(service.permissionSnapshot!.categories['commands'], isFalse);

    service.setPermissionConnectionForTest(true);
    service.handleIncomingFrameForTest(
      _snapshot(
        service,
        session: 'permission-session:reconnect',
        sequence: 1,
        epoch: 4,
      ),
    );
    await tester.pump();
    _emitContract(service, <String, dynamic>{'schema_version': 99});
    await tester.pump();
    expect(
      find.byKey(const Key('permission-contract-incompatible')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('permission-category-commands')), findsNothing);
  });

  testWidgets(
    'reopen rebuilds activity and temporary permissions from PC snapshot',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      final service = _service(sent);
      addTearDown(service.dispose);
      service.handleIncomingFrameForTest(
        _snapshot(
          service,
          permissions: <Map<String, dynamic>>[_temporary('permission:reopen')],
        ),
      );
      await _pumpScreen(tester, service);
      expect(
        find.byKey(const Key('temporary-permission-permission:reopen')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await _pumpScreen(tester, service);
      expect(
        find.byKey(const Key('temporary-permission-permission:reopen')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('permission-history')));
      await tester.tap(find.byKey(const Key('permission-history')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          osiaStringsEn.permissionHistoryLabel('automatic_permission_changed'),
        ),
        findsOneWidget,
      );
    },
  );

  for (final configuration
      in <({OsiaPalette palette, Size size, double scale})>[
        (palette: osiaPaletteViolet, size: const Size(320, 640), scale: 1.6),
        (palette: osiaPaletteBlanc, size: const Size(900, 1200), scale: 1.0),
      ]) {
    testWidgets(
      'layout keeps accessible targets for ${configuration.palette.key} '
      '${configuration.size.width} at ${configuration.scale}x text',
      (tester) async {
        final sent = <Map<String, dynamic>>[];
        final service = _service(sent);
        addTearDown(service.dispose);
        service.handleIncomingFrameForTest(_snapshot(service));
        await _pumpScreen(
          tester,
          service,
          palette: configuration.palette,
          size: configuration.size,
          textScale: configuration.scale,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(const Key('mode-default-access'))).height,
          greaterThanOrEqualTo(72),
        );
        final category = find.byKey(
          const Key('permission-category-files_modify'),
        );
        await tester.ensureVisible(category);
        expect(tester.getSize(category).height, greaterThanOrEqualTo(72));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/widgets/mcp_confirm_dialog.dart';

void main() {
  test('reinforced deletion payload keeps only sanitized counters', () {
    final request = ws.McpConfirmRequest.fromJson(<String, dynamic>{
      'id': 'opaque-request-1',
      'server': 'osia',
      'tool': 'colossal_deletion',
      'summary': 'Review locally on the PC',
      'confirmation_kind': 'colossal_deletion_pc_only',
      'can_approve': true,
      'files_count': 1000,
      'folders_count': 12,
      'total_bytes': 4096,
      'root_count': 1,
      'safe_reason': 'colossal_deletion',
      'path': r'C:\Users\private\secret',
      'inventory': <String>[r'C:\Users\private\secret\one.txt'],
    });

    expect(request.isPcOnlyColossalDeletion, isTrue);
    expect(request.canApprove, isFalse);
    expect(request.filesCount, 1000);
    expect(request.foldersCount, 12);
    expect(request.totalBytes, 4096);
    expect(request.rootCount, 1);
    expect(request.summary, isNot(contains('private')));
  });

  testWidgets('mobile colossal state has no approve action', (tester) async {
    final request = ws.McpConfirmRequest.fromJson(<String, dynamic>{
      'id': 'opaque-request-2',
      'server': 'osia',
      'tool': 'colossal_deletion',
      'confirmation_kind': 'colossal_deletion_pc_only',
      'can_approve': true,
      'files_count': 1000,
      'folders_count': 20,
      'total_bytes': 1048576,
      'root_count': 1,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: McpConfirmDialog(request: request)),
      ),
    );

    expect(find.text('Local PC review required'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
    expect(find.textContaining('1000 files'), findsOneWidget);
  });

  testWidgets('ordinary confirmation behavior remains approvable', (
    tester,
  ) async {
    const request = ws.McpConfirmRequest(
      id: 'ordinary-request',
      server: 'calendar',
      tool: 'create_event',
      summary: 'title',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: McpConfirmDialog(request: request)),
      ),
    );

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('legacy non-approvable payload fails closed', (tester) async {
    final request = ws.McpConfirmRequest.fromJson(<String, dynamic>{
      'id': 'legacy-safe-state',
      'server': 'osia',
      'tool': 'delete_many',
      'summary': 'Review on the PC',
      'can_approve': false,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: McpConfirmDialog(request: request)),
      ),
    );

    expect(find.text('Approve'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });
}

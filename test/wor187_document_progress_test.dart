import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/autonomous_screen.dart';
import 'package:osia_mobile/services/attachment_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

ws.WebSocketService _service({List<Map<String, dynamic>>? sent}) =>
    ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'wor187-token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        sent?.add(Map<String, dynamic>.from(frame));
        return true;
      },
    );

Map<String, dynamic> _autonomousFrame(
  ws.WebSocketService service, {
  int sequence = 1,
  String eventId = 'autonomous-event:one',
  String sessionId = 'autonomous-session:one',
  String runId = 'run-document-one',
  int planRevision = 1,
  String event = 'running',
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
  'authorization_revision': 1,
  'event': event,
  'safe_operation_phase': event,
  'safe_site_display': 'https://example.test',
  'safe_progress_text': terminal
      ? 'Autonomous work completed'
      : 'Autonomous work is running',
  'artifact_safe_summary': null,
  'terminal': terminal,
  'final_answer': null,
  'tasks_done': terminal ? 1 : 0,
  'tasks_total': 1,
};

Map<String, dynamic> _documentFrame(
  ws.WebSocketService service, {
  int sequence = 1,
  String eventId = 'document-event:one',
  String sessionId = 'document-session:one',
  String scopeType = 'autonomous',
  String scopeId = 'run-document-one',
  int planRevision = 1,
  String itemId = 'item_000000000000000000000001',
  String documentType = 'docx',
  String phase = 'identifying',
  bool snapshot = false,
}) => <String, dynamic>{
  'type': 'document_progress',
  'schema_version': 1,
  'event_id': eventId,
  'server_id': service.expectedPermissionServerIdForTest,
  'session_id': sessionId,
  'scope_type': scopeType,
  'scope_id': scopeId,
  'plan_revision': planRevision,
  'sequence': sequence,
  'item_id': itemId,
  'document_type': documentType,
  'phase': phase,
  'terminal': phase == 'ready' || phase == 'failed',
  'failure_category': phase == 'failed' ? 'extraction_failure' : '',
  'counts': null,
  'snapshot': snapshot,
};

void main() {
  test('document UX text is localized in all six supported languages', () {
    for (final language in osiaSupportedLanguages) {
      final strings = osiaStringsForCode(language);
      final values = <String>[
        strings.autonomousDocuments,
        strings.autonomousAddDocuments,
        strings.autonomousRemoveDocument,
        strings.documentTransferPreparing,
        strings.documentTransferUploading,
        strings.documentTransferVerifying,
        strings.documentTransferReady,
        strings.documentTransferFailed,
        strings.documentProcessingFailed,
        for (final phase in const <String>[
          'identifying',
          'inspecting',
          'extracting',
          'indexing',
          'ready',
          'failed',
        ])
          strings.documentPhase(phase),
      ];
      expect(values.every((value) => value.trim().isNotEmpty), isTrue);
      expect(values.join(), isNot(anyOf(contains('Ã'), contains('Â'))));
    }
  });

  test(
    'document progress rejects stale, regressive, foreign and leaky frames',
    () async {
      final service = _service();
      addTearDown(service.dispose);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(_autonomousFrame(service));
      final accepted = <ws.DocumentProgressMessage>[];
      final subscription = service.documentProgressStream.listen(accepted.add);
      addTearDown(subscription.cancel);

      service.handleIncomingFrameForTest(_documentFrame(service));
      service.handleIncomingFrameForTest(
        _documentFrame(service, eventId: 'document-event:duplicate'),
      );
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 2,
          eventId: 'document-event:wrong-run',
          scopeId: 'run-document-other',
        ),
      );
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 2,
          eventId: 'document-event:old-revision',
          planRevision: 0,
        ),
      );
      service.handleIncomingFrameForTest({
        ..._documentFrame(service, sequence: 2, eventId: 'document-event:leak'),
        'filename': 'PRIVATE_REPORT.docx',
      });
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 2,
          eventId: 'document-event:extracting',
          phase: 'extracting',
        ),
      );
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 3,
          eventId: 'document-event:regression',
          phase: 'inspecting',
        ),
      );
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 3,
          eventId: 'document-event:ready',
          phase: 'ready',
        ),
      );
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 4,
          eventId: 'document-event:post-terminal',
          phase: 'failed',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(accepted.map((item) => item.phase), [
        'identifying',
        'extracting',
        'ready',
      ]);
      expect(
        service.documentProgressForScope('autonomous', 'run-document-one'),
        hasLength(1),
      );

      service.handleIncomingFrameForTest(
        _autonomousFrame(
          service,
          sequence: 2,
          eventId: 'autonomous-event:terminal',
          event: 'done',
          terminal: true,
        ),
      );
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 5,
          eventId: 'document-event:after-run-terminal',
          itemId: 'item_000000000000000000000002',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(accepted, hasLength(3));
    },
  );

  test(
    'reconnect accepts authoritative snapshot and retires old session',
    () async {
      final sent = <Map<String, dynamic>>[];
      final service = _service(sent: sent);
      addTearDown(service.dispose);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(_autonomousFrame(service));
      service.handleIncomingFrameForTest(_documentFrame(service));
      expect(service.documentProgressLive, isTrue);

      service.setPermissionConnectionForTest(false);
      service.setPermissionConnectionForTest(true);
      expect(service.documentProgressLive, isFalse);
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 2,
          eventId: 'document-event:same-session-snapshot',
          phase: 'extracting',
          snapshot: true,
        ),
      );
      expect(service.documentProgressLive, isTrue);

      service.setPermissionConnectionForTest(false);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 1,
          eventId: 'document-event:new-session-snapshot',
          sessionId: 'document-session:two',
          phase: 'indexing',
        ),
      );
      expect(service.documentProgressLive, isTrue);
      service.setPermissionConnectionForTest(false);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 3,
          eventId: 'document-event:retired-session',
          phase: 'ready',
          snapshot: true,
        ),
      );
      expect(service.documentProgressLive, isFalse);

      service.expectAuthenticatedInitialSyncForTest();
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'status',
        'content': 'done',
      });
      expect(
        sent.any((frame) => frame['type'] == 'get_document_status'),
        isTrue,
      );
    },
  );

  test(
    'Chat progress is owned by its accepted turn and closes on error',
    () async {
      final service = _service();
      addTearDown(service.dispose);
      service.setPermissionConnectionForTest(true);
      service.rememberRequestForTest('conversation-one', 'request-one');
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'turn_accepted',
        'event_type': 'turn_accepted',
        'conversation_id': 'conversation-one',
        'client_request_id': 'request-one',
        'request_id': 'request-one',
        'turn_id': 'turn-chat-one',
        'message_id': 'message-chat-one',
        'event_id': 'event-chat-accepted',
        'sequence': 1,
        'terminal': false,
        'status': 'accepted',
        'persisted': true,
      });
      final accepted = <ws.DocumentProgressMessage>[];
      final subscription = service.documentProgressStream.listen(accepted.add);
      addTearDown(subscription.cancel);
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          scopeType: 'chat',
          scopeId: 'turn-chat-one',
          planRevision: 0,
        ),
      );
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'turn_status',
        'event_type': 'turn_status',
        'conversation_id': 'conversation-one',
        'client_request_id': 'request-one',
        'request_id': 'request-one',
        'turn_id': 'turn-chat-one',
        'message_id': 'message-chat-one',
        'event_id': 'event-chat-error',
        'sequence': 2,
        'terminal': true,
        'status': 'error',
        'persisted': false,
      });
      service.handleIncomingFrameForTest(
        _documentFrame(
          service,
          sequence: 2,
          eventId: 'document-event:late-chat',
          scopeType: 'chat',
          scopeId: 'turn-chat-one',
          planRevision: 0,
          phase: 'extracting',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(accepted, hasLength(1));
    },
  );

  test('Autonomous start sends only exact runtime capabilities', () {
    final sent = <Map<String, dynamic>>[];
    final service = _service(sent: sent);
    addTearDown(service.dispose);
    service.setPermissionConnectionForTest(true);
    const refs = <String>[
      'src_00000000000000000000000000000001',
      'src_00000000000000000000000000000002',
      'src_00000000000000000000000000000003',
    ];
    expect(
      service.sendAutonomousStartWithSources('Compare', 'fixture:model', refs),
      isTrue,
    );
    final frame = sent.last;
    expect(frame['type'], 'autonomous_start');
    expect(frame['document_sources'], refs);
    expect(frame.containsKey('filename'), isFalse);
    expect(
      service.sendAutonomousStartWithSources('Compare', 'fixture:model', [
        refs.first,
        refs.first,
      ]),
      isFalse,
    );
    expect(
      autonomousAttachmentSelectionCanStart(
        ready: const [true, false, true],
        busy: false,
        hasFailure: false,
      ),
      isFalse,
    );
    expect(
      autonomousAttachmentSelectionCanStart(
        ready: const [true, true],
        busy: false,
        hasFailure: false,
      ),
      isTrue,
    );
    expect(
      autonomousAttachmentSelectionCanStart(
        ready: const [],
        busy: false,
        hasFailure: false,
      ),
      isTrue,
    );
  });

  test('Autonomous upload returns strict safe capability metadata', () async {
    final root = await Directory.systemTemp.createTemp('wor187-mobile-');
    addTearDown(() => root.delete(recursive: true));
    final staged = File('${root.path}${Platform.pathSeparator}fixture.docx');
    final bytes = <int>[1, 2, 3, 4];
    await staged.writeAsBytes(bytes);
    final events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
    addTearDown(events.close);
    final sent = <Map<String, dynamic>>[];
    late Map<String, dynamic> prepare;
    Future<bool> send(Map<String, dynamic> frame, String session) async {
      sent.add(Map<String, dynamic>.from(frame));
      if (frame['type'] == 'attachment_batch_prepare') {
        prepare = Map<String, dynamic>.from(frame);
        events.add(<String, dynamic>{
          'type': 'attachment_batch_accept',
          'batch_id': frame['batch_id'],
        });
      } else if (frame['type'] == 'attachment_batch_commit') {
        final metadata = (prepare['files'] as List).single as Map;
        events.add(<String, dynamic>{
          'type': 'attachment_batch_commit_ack',
          'batch_id': frame['batch_id'],
          'file_count': 1,
          'aggregate_size': bytes.length,
          'attachments': <Map<String, dynamic>>[
            <String, dynamic>{
              'attachment_id': 'att_00000000000000000000000000000001',
              'file_id': metadata['file_id'],
              'logical_order': 0,
              'byte_size': bytes.length,
              'hash_match': true,
            },
          ],
          'autonomous_sources': <Map<String, dynamic>>[
            <String, dynamic>{
              'source_ref': 'src_00000000000000000000000000000001',
              'type_label': 'docx',
              'document_family': 'document',
              'state': 'ready',
              'warnings': <String>[],
              'logical_order': 0,
            },
          ],
        });
      }
      return true;
    }

    final client = AttachmentTransferClient(
      sendFrame: send,
      events: events.stream,
      transportSession: () => 'authenticated-session-one',
    );
    final result = await client.upload(
      files: <PreparedAttachment>[
        PreparedAttachment(
          fileId: 'file_00000000000000000000000000000001',
          displayName: 'fixture.docx',
          stagedPath: staged.path,
          byteSize: bytes.length,
          sha256: sha256.convert(bytes).toString(),
          declaredMime: 'application/octet-stream',
          detectedCategory: 'document',
          extension: 'docx',
        ),
      ],
      conversationId: '',
      clientRequestId: 'request_0000000000000000000000000001',
      attachmentPurpose: 'autonomous',
    );
    expect(result.attachmentPurpose, 'autonomous');
    expect(
      result.autonomousSources.single.sourceRef,
      'src_00000000000000000000000000000001',
    );
    final prepareFrame = sent.first;
    expect(prepareFrame['attachment_purpose'], 'autonomous');
    expect(prepareFrame['conversation_id'], '');
    expect(sent.any((frame) => frame.containsKey('source_ref')), isFalse);
  });
}

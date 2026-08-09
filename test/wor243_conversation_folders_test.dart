import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test('canonical folder snapshot remains backward compatible', () async {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'test-token',
      autoReconnect: false,
    );
    addTearDown(service.dispose);

    final snapshot = service.messageStream
        .where((message) => message is ConversationsMessage)
        .cast<ConversationsMessage>()
        .first;
    service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'conversations',
      'version': 2,
      'snapshot_revision': 17,
      'operation_id': 'folder-op-17',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'conv-foldered',
          'title': 'Foldered',
          'folder_id': 'folder-alpha',
        },
        <String, dynamic>{'id': 'conv-ungrouped', 'title': 'Ungrouped'},
      ],
      'folders': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'folder-alpha',
          'name': 'Alpha',
          'order': 0,
          'collapsed': true,
          'allow_folder_context': true,
        },
        <String, dynamic>{
          'id': 'folder-empty',
          'name': 'Empty',
          'order': 1,
          'collapsed': false,
          'allow_folder_context': false,
        },
      ],
    });

    final message = await snapshot;
    expect(message.version, 2);
    expect(message.snapshotRevision, 17);
    expect(message.operationId, 'folder-op-17');
    expect(message.conversations, hasLength(2));
    expect(message.conversations.first.folderId, 'folder-alpha');
    expect(message.conversations.last.folderId, isNull);
    expect(message.folders, hasLength(2));
    expect(message.folders.first.name, 'Alpha');
    expect(message.folders.first.collapsed, isTrue);
    expect(message.folders.first.allowFolderContext, isTrue);
    expect(message.folders.last.id, 'folder-empty');

    final legacy = ConversationsMessage(<Conversation>[
      const Conversation(id: 'legacy', title: 'Legacy'),
    ]);
    expect(legacy.version, 1);
    expect(legacy.folders, isEmpty);
    expect(legacy.conversations.single.folderId, isNull);
  });

  test('folder mutations emit stable idempotent protocol frames', () {
    final frames = <Map<String, dynamic>>[];
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'test-token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        frames.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);

    service.sendCreateConversationFolder('Alpha', operationId: 'op-create');
    service.sendRenameConversationFolder(
      'folder-alpha',
      'Renamed',
      operationId: 'op-rename',
    );
    service.sendConversationFolderCollapsed(
      'folder-alpha',
      true,
      operationId: 'op-collapse',
    );
    service.sendConversationFolderContextPolicy(
      'folder-alpha',
      true,
      operationId: 'op-context',
    );
    service.sendReorderConversationFolders(<String>[
      'folder-empty',
      'folder-alpha',
    ], operationId: 'op-order');
    service.sendMoveConversationToFolder(
      'conv-one',
      'folder-alpha',
      operationId: 'op-move-in',
    );
    service.sendMoveConversationToFolder(
      'conv-one',
      null,
      operationId: 'op-move-out',
    );
    service.sendBulkDeleteUngroupedConversations(
      expectedCount: 3,
      operationId: 'op-delete',
    );
    service.sendBulkDeleteUngroupedConversations(
      expectedCount: 3,
      operationId: 'op-delete',
    );

    expect(frames.map((frame) => frame['type']), <String>[
      'create_conversation_folder',
      'rename_conversation_folder',
      'set_conversation_folder_state',
      'set_conversation_folder_context',
      'reorder_conversation_folders',
      'move_conversation_to_folder',
      'move_conversation_to_folder',
      'bulk_delete_ungrouped_conversations',
      'bulk_delete_ungrouped_conversations',
    ]);
    expect(frames[0], containsPair('name', 'Alpha'));
    expect(frames[1], containsPair('folder_id', 'folder-alpha'));
    expect(frames[2], containsPair('collapsed', true));
    expect(frames[3], containsPair('allow_folder_context', true));
    expect(frames[4]['folder_ids'], <String>['folder-empty', 'folder-alpha']);
    expect(frames[5], containsPair('conversation_id', 'conv-one'));
    expect(frames[5], containsPair('folder_id', 'folder-alpha'));
    expect(frames[6]['folder_id'], isNull);
    expect(frames[7], frames[8]);
    expect(frames[7], containsPair('expected_count', 3));
    expect(frames[7], containsPair('operation_id', 'op-delete'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
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
    service.sendNewConversationInProject(
      'folder-alpha',
      operationId: 'op-project-chat',
    );
    service.sendNewConversationInProject(
      'folder-alpha',
      operationId: 'op-project-chat',
    );
    service.sendDeleteConversationProject(
      'folder-alpha',
      expectedCount: 3,
      operationId: 'op-project-delete',
    );
    service.sendDeleteConversationProject(
      'folder-alpha',
      expectedCount: 3,
      operationId: 'op-project-delete',
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
      'create_conversation_folder',
      'rename_conversation_folder',
      'set_conversation_folder_state',
      'set_conversation_folder_context',
      'reorder_conversation_folders',
      'move_conversation_to_folder',
      'move_conversation_to_folder',
      'new_conversation_in_project',
      'new_conversation_in_project',
      'delete_conversation_project',
      'delete_conversation_project',
      'bulk_delete_ungrouped_conversations',
      'bulk_delete_ungrouped_conversations',
    ]);
    expect(frames[0], containsPair('name', 'Alpha'));
    expect(frames[0], frames[1]);
    expect(frames[2], containsPair('folder_id', 'folder-alpha'));
    expect(frames[3], containsPair('collapsed', true));
    expect(frames[4], containsPair('allow_folder_context', true));
    expect(frames[5]['folder_ids'], <String>['folder-empty', 'folder-alpha']);
    expect(frames[6], containsPair('conversation_id', 'conv-one'));
    expect(frames[6], containsPair('folder_id', 'folder-alpha'));
    expect(frames[7]['folder_id'], isNull);
    expect(frames[8], frames[9]);
    expect(frames[8], containsPair('folder_id', 'folder-alpha'));
    expect(frames[10], frames[11]);
    expect(frames[10], containsPair('expected_count', 3));
    expect(frames[12], frames[13]);
    expect(frames[12], containsPair('expected_count', 3));
    expect(frames[12], containsPair('operation_id', 'op-delete'));
  });

  test(
    'destructive confirmation requests a fresh canonical snapshot',
    () async {
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

      final pending = service.requestCanonicalConversationSnapshot();
      final operationId = frames.single['operation_id'] as String;
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'conversations',
        'version': 2,
        'snapshot_revision': 8,
        'operation_id': 'unrelated-refresh',
        'items': const <Map<String, dynamic>>[],
        'folders': const <Map<String, dynamic>>[],
      });
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'conversations',
        'version': 2,
        'snapshot_revision': 9,
        'operation_id': operationId,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'member',
            'title': 'Member',
            'folder_id': 'folder-alpha',
          },
        ],
        'folders': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'folder-alpha', 'name': 'Alpha', 'order': 0},
        ],
      });

      final snapshot = await pending;
      expect(frames.single['type'], 'get_conversation_snapshot');
      expect(operationId, startsWith('snapshot_'));
      expect(snapshot.operationId, operationId);
      expect(snapshot.snapshotRevision, 9);
      expect(snapshot.conversations.single.folderId, 'folder-alpha');
    },
  );

  test('active project chat pointer keeps its operation correlation', () async {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'test-token',
      autoReconnect: false,
    );
    addTearDown(service.dispose);

    final pending = service.messageStream
        .where((message) => message is ActiveConversationMessage)
        .cast<ActiveConversationMessage>()
        .first;
    service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'active_conversation',
      'id': 'conv-project-new',
      'title': 'New conversation',
      'operation_id': 'op-project-new',
    });

    final message = await pending;
    expect(message.id, 'conv-project-new');
    expect(message.operationId, 'op-project-new');
  });

  test('projects render before ungrouped conversations', () {
    final source = File('lib/screens/chat_screen.dart').readAsStringSync();
    final method = source.indexOf(
      'List<Widget> _buildConversationDrawerItems(OsiaPalette palette)',
    );
    final projectRows = source.indexOf(
      'for (final folder in _conversationFolders) {',
      method,
    );
    final ungroupedRows = source.indexOf(
      'for (final conversation in ungrouped) {',
      method,
    );

    expect(method, greaterThanOrEqualTo(0));
    expect(projectRows, greaterThan(method));
    expect(ungroupedRows, greaterThan(projectRows));
  });

  test('project UI copy has no folder terminology', () {
    const languages = <OsiaStrings>[
      osiaStringsEn,
      osiaStringsFr,
      osiaStringsZh,
      osiaStringsJa,
      osiaStringsDe,
      osiaStringsEs,
    ];
    final visibleCopy = languages
        .expand(
          (strings) => <String>[
            strings.createFolder,
            strings.folderName,
            strings.renameFolder,
            strings.folderSettings,
            strings.deleteProject,
            strings.deleteProjectConfirmation('OSIA', 3),
            strings.allowFolderContext,
            strings.moveToFolder,
            strings.removeFromProject,
            strings.projectsSection,
            strings.outsideFolders,
            strings.moveFolderUp,
            strings.moveFolderDown,
            strings.noUngroupedConversations,
            strings.bulkDeleteWarning(3),
          ],
        )
        .join('\n')
        .toLowerCase();

    for (final forbidden in <String>[
      'folder',
      'dossier',
      'ordner',
      'carpeta',
      '文件夹',
      'フォルダー',
    ]) {
      expect(visibleCopy, isNot(contains(forbidden)));
    }
    expect(osiaStringsEn.createFolder, 'Create project');
    expect(osiaStringsEn.deleteProject, 'Delete project');
    expect(
      osiaStringsFr.deleteProjectConfirmation('OSIA', 3),
      'Supprimer le projet « OSIA » et ses 3 conversations ? Cette action est définitive.',
    );
    expect(osiaStringsFr.createFolder, 'Créer un projet');
  });

  test(
    'project actions use a fresh canonical count and select the new chat',
    () {
      final source = File('lib/screens/chat_screen.dart').readAsStringSync();
      final menu = source.indexOf(
        'Future<void> _showConversationFolderActions(',
      );
      final newChat = source.indexOf("pop('new_chat')", menu);
      final rename = source.indexOf("pop('rename')", menu);
      final settings = source.indexOf("pop('settings')", menu);
      final delete = source.indexOf("pop('delete')", menu);
      final confirmation = source.indexOf(
        'Future<void> _confirmDeleteConversationFolder(',
        menu,
      );

      expect(menu, greaterThanOrEqualTo(0));
      expect(newChat, inInclusiveRange(menu, rename));
      expect(rename, lessThan(settings));
      expect(settings, lessThan(delete));
      expect(
        source.indexOf('requestCanonicalConversationSnapshot()', confirmation),
        greaterThan(confirmation),
      );
      expect(
        source.indexOf('if (confirmed != true) return;', confirmation),
        greaterThan(confirmation),
      );
      expect(source, contains('selectingProjectConversation'));
      expect(source, contains('operationId == _projectNewChatOperationId'));
      expect(source, contains('_onNewChat();'));
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/screens/chat_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

ws.HistoryMessage message(String id, String role, String content) {
  return ws.HistoryMessage(
    role: role,
    content: content,
    conversationId: 'conv-a',
    messageId: id,
  );
}

void main() {
  test('accepts a strictly newer canonical snapshot', () {
    final ledger = CanonicalHistoryLedger();
    final user = message('m-user', 'user', 'Question');
    final assistant = message('m-assistant', 'assistant', 'Answer');

    expect(ledger.accept('conv-a', [user]), isTrue);
    expect(ledger.accept('conv-a', [user, assistant]), isTrue);
  });

  test('rejects delayed shorter and divergent snapshots', () {
    final ledger = CanonicalHistoryLedger();
    final user = message('m-user', 'user', 'Question');
    final assistant = message('m-assistant', 'assistant', 'Answer');

    expect(ledger.accept('conv-a', [user, assistant]), isTrue);
    expect(ledger.accept('conv-a', [user]), isFalse);
    expect(
      ledger.accept('conv-a', [user, message('m-other', 'assistant', 'Old')]),
      isFalse,
    );
  });

  test('duplicate snapshots apply only for an explicit reload', () {
    final ledger = CanonicalHistoryLedger();
    final history = [message('m-user', 'user', 'Question')];

    expect(ledger.accept('conv-a', history), isTrue);
    expect(ledger.accept('conv-a', history), isFalse);
    expect(ledger.accept('conv-a', history, allowEquivalent: true), isTrue);
  });

  test('legacy messages use stable role and content identity', () {
    final ledger = CanonicalHistoryLedger();
    const legacyUser = ws.HistoryMessage(role: 'user', content: 'Question');
    const legacyAssistant = ws.HistoryMessage(
      role: 'assistant',
      content: 'Answer',
    );

    expect(ledger.accept('legacy', [legacyUser]), isTrue);
    expect(ledger.accept('legacy', [legacyUser, legacyAssistant]), isTrue);
    expect(ledger.accept('legacy', [legacyUser]), isFalse);
  });

  test('empty, independent and forgotten conversations stay coherent', () {
    final ledger = CanonicalHistoryLedger();
    final a = message('a', 'user', 'A');
    final b = message('b', 'user', 'B');

    expect(ledger.accept('conv-a', [a]), isTrue);
    expect(ledger.accept('conv-b', [b]), isTrue);
    expect(ledger.accept('conv-a', const []), isFalse);
    ledger.forget('conv-a');
    expect(ledger.accept('conv-a', const []), isTrue);
  });

  test('canonical list updates an active title and proves remote deletion', () {
    final fullList = List<ws.Conversation>.generate(
      50,
      (index) => ws.Conversation(id: 'conv-$index', title: 'Title $index'),
    );

    expect(
      canonicalConversationForActiveId(fullList, 'conv-12')?.title,
      'Title 12',
    );
    expect(canonicalConversationForActiveId(fullList, 'deleted-conv'), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/transport_coordinator.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test('only one application transport lease can be active', () {
    final coordinator = ApplicationTransportCoordinator();
    final lan = coordinator.tryAcquire(ApplicationTransportKind.lan, Object());

    expect(lan, isNotNull);
    expect(lan!.active, isTrue);
    expect(coordinator.activeKind, ApplicationTransportKind.lan);
    expect(
      coordinator.tryAcquire(ApplicationTransportKind.relay, Object()),
      isNull,
    );

    lan.release();
    expect(lan.active, isFalse);
    final relay = coordinator.tryAcquire(
      ApplicationTransportKind.relay,
      Object(),
    );
    expect(relay, isNotNull);
    expect(coordinator.activeKind, ApplicationTransportKind.relay);

    relay!.release();
    relay.release();
    expect(coordinator.activeKind, isNull);
  });

  test('two WebSocketService instances share one application authority', () {
    final first = WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
    );
    final second = WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    expect(
      first.acquireApplicationTransportForTest(ApplicationTransportKind.lan),
      isTrue,
    );
    expect(
      second.acquireApplicationTransportForTest(ApplicationTransportKind.relay),
      isFalse,
    );
    expect(
      applicationTransportCoordinator.activeKind,
      ApplicationTransportKind.lan,
    );

    // A non-owner disconnect must not release the first service's lease.
    second.disconnect();
    expect(
      applicationTransportCoordinator.activeKind,
      ApplicationTransportKind.lan,
    );
    first.disconnect();
    expect(applicationTransportCoordinator.activeKind, isNull);
  });

  test(
    'normal, error, cancellation and rejection terminals clear activity',
    () {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
      );
      addTearDown(service.dispose);

      void accept(String conversationId, String requestId) {
        service.handleIncomingFrameForTest(<String, dynamic>{
          'type': 'turn_accepted',
          'conversation_id': conversationId,
          'client_request_id': requestId,
          'turn_id': 'turn-$requestId',
        });
        expect(service.isRequestAccepted(requestId), isTrue);
        expect(service.hasActiveApplicationTurnForTest, isTrue);
      }

      accept('conv-done', 'req-done');
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'status',
        'conversation_id': 'conv-done',
        'client_request_id': 'req-done',
        'content': 'done',
      });
      expect(service.isRequestAccepted('req-done'), isFalse);
      expect(service.hasActiveApplicationTurnForTest, isFalse);

      accept('conv-error', 'req-error');
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'error',
        'conversation_id': 'conv-error',
        'client_request_id': 'req-error',
      });
      expect(service.isRequestAccepted('req-error'), isFalse);
      expect(service.hasActiveApplicationTurnForTest, isFalse);

      for (final status in <String>['cancelled', 'canceled', 'rejected']) {
        final requestId = 'req-$status';
        final conversationId = 'conv-$status';
        accept(conversationId, requestId);
        service.handleIncomingFrameForTest(<String, dynamic>{
          'type': 'turn_status',
          'conversation_id': conversationId,
          'client_request_id': requestId,
          'status': status,
        });
        expect(service.isRequestAccepted(requestId), isFalse, reason: status);
        expect(
          service.hasActiveApplicationTurnForTest,
          isFalse,
          reason: status,
        );
      }
    },
  );

  test('duplicate and stale terminals never clear a newer active request', () {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
    );
    addTearDown(service.dispose);

    Map<String, dynamic> frame(String type, String requestId, String status) =>
        <String, dynamic>{
          'type': type,
          'conversation_id': 'conv-stale',
          'client_request_id': requestId,
          if (type == 'turn_status') 'status': status else 'content': status,
        };

    service.handleIncomingFrameForTest(
      frame('turn_accepted', 'req-old', 'accepted'),
    );
    service.handleIncomingFrameForTest(frame('status', 'req-old', 'done'));
    // A duplicate terminal is idempotent.
    service.handleIncomingFrameForTest(frame('status', 'req-old', 'done'));

    service.handleIncomingFrameForTest(
      frame('turn_accepted', 'req-new', 'accepted'),
    );
    service.handleIncomingFrameForTest(frame('status', 'req-old', 'done'));

    expect(service.isRequestAccepted('req-old'), isFalse);
    expect(service.isRequestAccepted('req-new'), isTrue);
    expect(service.isSamePendingRequest('conv-stale', 'req-new'), isTrue);
    expect(service.hasActiveApplicationTurnForTest, isTrue);
  });

  test(
    'untagged correlated terminal and disconnect clear request tracking',
    () {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
      );
      addTearDown(service.dispose);

      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'turn_accepted',
        'client_request_id': 'req-untagged',
        'turn_id': 'turn-untagged',
      });
      expect(service.hasActiveApplicationTurnForTest, isTrue);
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'status',
        'client_request_id': 'req-untagged',
        'content': 'done',
      });
      expect(service.hasActiveApplicationTurnForTest, isFalse);

      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'turn_accepted',
        'client_request_id': 'req-disconnect',
        'turn_id': 'turn-disconnect',
      });
      expect(service.hasActiveApplicationTurnForTest, isTrue);
      service.disconnect();
      expect(service.isRequestAccepted('req-disconnect'), isFalse);
      expect(service.hasActiveApplicationTurnForTest, isFalse);
    },
  );
}

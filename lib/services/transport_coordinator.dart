enum ApplicationTransportKind { lan, webrtc, relay, legacy }

/// Whether an outbound application frame starts or joins the one active turn.
/// Waiting-turn commands carry a fresh request id for server-side idempotence,
/// but remain controls for the existing turn and must not replace its transport
/// correlation.
bool isApplicationTurnStartingFrame(Map<String, dynamic> frame) {
  final type = frame['type']?.toString() ?? '';
  if (type == 'text' && frame['waiting_turn_command'] == true) return false;
  return const <String>{'text', 'audio', 'speak'}.contains(type) ||
      (type == 'file' && frame['is_image'] == true);
}

class ApplicationTransportLease {
  ApplicationTransportLease._(this._coordinator, this.kind, this.owner);

  final ApplicationTransportCoordinator _coordinator;
  final ApplicationTransportKind kind;
  final Object owner;
  bool _released = false;

  bool get active => !_released && _coordinator.owns(this);

  void release() {
    if (_released) return;
    _released = true;
    _coordinator.release(this);
  }
}

/// Grants one application transport lease to the WebSocketService facade.
class ApplicationTransportCoordinator {
  ApplicationTransportLease? _lease;

  ApplicationTransportLease? tryAcquire(
    ApplicationTransportKind kind,
    Object owner,
  ) {
    if (_lease != null) return null;
    final lease = ApplicationTransportLease._(this, kind, owner);
    _lease = lease;
    return lease;
  }

  bool owns(ApplicationTransportLease lease) => identical(_lease, lease);

  void release(ApplicationTransportLease lease) {
    if (identical(_lease, lease)) _lease = null;
  }

  ApplicationTransportKind? get activeKind => _lease?.kind;
}

/// The single application-wide authority shared by every WebSocketService.
final ApplicationTransportCoordinator applicationTransportCoordinator =
    ApplicationTransportCoordinator();

class SkillSnapshotDecision {
  final bool enabled;
  final bool confirmed;
  final bool rejected;

  const SkillSnapshotDecision({
    required this.enabled,
    required this.confirmed,
    required this.rejected,
  });
}

/// Keeps a pending skill toggle ahead of older PC config snapshots.
///
/// The PC remains authoritative: a matching requested flag confirms the
/// mutation, while its effective flag still decides whether validation or a
/// missing dependency must keep the skill disabled.
class SkillActivationGuard {
  int _latestRevision;
  final Map<String, bool> _pending = <String, bool>{};

  SkillActivationGuard({int initialRevision = 0})
    : _latestRevision = initialRevision < 0 ? 0 : initialRevision;

  int get latestRevision => _latestRevision;

  void begin(String name, bool enabled) {
    _pending[name] = enabled;
  }

  bool acceptSnapshot(int revision) {
    final normalized = revision < 0 ? 0 : revision;
    if (normalized < _latestRevision) return false;
    _latestRevision = normalized;
    return true;
  }

  SkillSnapshotDecision reconcile({
    required String name,
    required bool requested,
    required bool effective,
  }) {
    final pending = _pending[name];
    if (pending == null) {
      return SkillSnapshotDecision(
        enabled: effective,
        confirmed: false,
        rejected: false,
      );
    }
    if (requested != pending) {
      return SkillSnapshotDecision(
        enabled: pending,
        confirmed: false,
        rejected: false,
      );
    }
    _pending.remove(name);
    return SkillSnapshotDecision(
      enabled: effective,
      confirmed: true,
      rejected: pending && !effective,
    );
  }

  void retainSkills(Iterable<String> names) {
    final current = names.toSet();
    _pending.removeWhere((name, enabled) => !current.contains(name));
  }
}

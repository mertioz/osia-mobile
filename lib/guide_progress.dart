import 'dart:convert';

import 'services/storage_service.dart';

const int guideStateSchemaVersion = 2;

/// Retains the first-launch claim across upgrades, including profiles that
/// still contain fields written by the retired guide.
class GuideProgress {
  const GuideProgress._(this._state);

  final Map<String, Object?> _state;

  bool get finished => _state['finished'] == true;
  bool get automaticPresentationHandled =>
      _state['automaticPresentationHandled'] == true;
  String get outcome =>
      _state['outcome'] is String ? _state['outcome'] as String : 'migrated';

  factory GuideProgress.freshPresentation() =>
      GuideProgress.migrated().copyWith(outcome: 'presenting');

  factory GuideProgress.migrated() => const GuideProgress._({
    'schemaVersion': guideStateSchemaVersion,
    'finished': false,
    'skipped': false,
    'automaticPresentationHandled': true,
    'outcome': 'migrated',
  });

  GuideProgress copyWith({
    bool? finished,
    bool? automaticPresentationHandled,
    String? outcome,
  }) => GuideProgress._({
    ..._state,
    'schemaVersion': guideStateSchemaVersion,
    'finished': finished ?? this.finished,
    'automaticPresentationHandled':
        automaticPresentationHandled ?? this.automaticPresentationHandled,
    'outcome': outcome ?? this.outcome,
  });

  Map<String, Object?> toJson() => Map.of(_state);

  static GuideProgress? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final state = jsonDecode(raw);
      if (state is! Map<String, dynamic>) return null;
      final schema = state['schemaVersion'];
      if (schema != 1 && schema != guideStateSchemaVersion) return null;
      return GuideProgress._(state);
    } on FormatException {
      return null;
    }
  }
}

class GuideLaunchDecision {
  const GuideLaunchDecision({
    required this.progress,
    required this.showAutomatically,
  });

  final GuideProgress progress;
  final bool showAutomatically;
}

class GuideProgressService {
  GuideProgressService(this.storage);

  final StorageService storage;

  Future<GuideProgress> load() async {
    final progress = GuideProgress.tryDecode(await storage.getGuideState());
    return progress ?? GuideProgress.migrated();
  }

  Future<GuideLaunchDecision> prepareLaunch() async {
    final stored = GuideProgress.tryDecode(await storage.getGuideState());
    if (stored != null) {
      if (stored.automaticPresentationHandled) {
        return GuideLaunchDecision(progress: stored, showAutomatically: false);
      }
      final claimed = stored.copyWith(
        automaticPresentationHandled: true,
        outcome: 'presenting',
      );
      await save(claimed);
      return GuideLaunchDecision(progress: claimed, showAutomatically: true);
    }

    final hasExistingState = await storage.hasPreGuideAppState();
    final progress = hasExistingState
        ? GuideProgress.migrated()
        : GuideProgress.freshPresentation();
    await save(progress);
    return GuideLaunchDecision(
      progress: progress,
      showAutomatically: !hasExistingState,
    );
  }

  Future<void> save(GuideProgress progress) =>
      storage.setGuideState(jsonEncode(progress.toJson()));

  Future<GuideProgress> markClosed(GuideProgress progress) async {
    final next = progress.copyWith(
      outcome: progress.outcome == 'presenting' ? 'closed' : progress.outcome,
      automaticPresentationHandled: true,
    );
    await save(next);
    return next;
  }
}

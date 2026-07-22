import 'dart:convert';

import 'guide_content.dart';
import 'services/storage_service.dart';

const int guideStateSchemaVersion = 1;

String _identity(String value) => value;

class GuideProgress {
  const GuideProgress({
    required this.schemaVersion,
    required this.contentSchemaVersion,
    required this.essentialCompleted,
    required this.masteryCompleted,
    required this.advancedCompleted,
    required this.currentLessonId,
    required this.finished,
    required this.skipped,
    required this.automaticPresentationHandled,
    required this.outcome,
  });

  final int schemaVersion;
  final int contentSchemaVersion;
  final Set<String> essentialCompleted;
  final Set<String> masteryCompleted;
  final Set<String> advancedCompleted;
  final String? currentLessonId;
  final bool finished;
  final bool skipped;
  final bool automaticPresentationHandled;
  final String outcome;

  factory GuideProgress.freshPresentation() => GuideProgress(
    schemaVersion: guideStateSchemaVersion,
    contentSchemaVersion: guideContentSchemaVersion,
    essentialCompleted: const <String>{},
    masteryCompleted: const <String>{},
    advancedCompleted: const <String>{},
    currentLessonId: guideLessonsForCategory(guideEssentialCategoryId).first.id,
    finished: false,
    skipped: false,
    automaticPresentationHandled: true,
    outcome: 'presenting',
  );

  factory GuideProgress.migrated() => const GuideProgress(
    schemaVersion: guideStateSchemaVersion,
    contentSchemaVersion: guideContentSchemaVersion,
    essentialCompleted: <String>{},
    masteryCompleted: <String>{},
    advancedCompleted: <String>{},
    currentLessonId: null,
    finished: false,
    skipped: false,
    automaticPresentationHandled: true,
    outcome: 'migrated',
  );

  GuideProgress copyWith({
    Set<String>? essentialCompleted,
    Set<String>? masteryCompleted,
    Set<String>? advancedCompleted,
    String? currentLessonId,
    bool clearCurrentLesson = false,
    bool? finished,
    bool? skipped,
    bool? automaticPresentationHandled,
    String? outcome,
  }) => GuideProgress(
    schemaVersion: guideStateSchemaVersion,
    contentSchemaVersion: guideContentSchemaVersion,
    essentialCompleted: essentialCompleted ?? this.essentialCompleted,
    masteryCompleted: masteryCompleted ?? this.masteryCompleted,
    advancedCompleted: advancedCompleted ?? this.advancedCompleted,
    currentLessonId: clearCurrentLesson
        ? null
        : (currentLessonId ?? this.currentLessonId),
    finished: finished ?? this.finished,
    skipped: skipped ?? this.skipped,
    automaticPresentationHandled:
        automaticPresentationHandled ?? this.automaticPresentationHandled,
    outcome: outcome ?? this.outcome,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'contentSchemaVersion': contentSchemaVersion,
    'essentialCompleted': essentialCompleted.toList()..sort(),
    'masteryCompleted': masteryCompleted.toList()..sort(),
    'advancedCompleted': advancedCompleted.toList()..sort(),
    'currentLesson': currentLessonId,
    'finished': finished,
    'skipped': skipped,
    'automaticPresentationHandled': automaticPresentationHandled,
    'outcome': outcome,
  };

  static GuideProgress? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != guideStateSchemaVersion) {
        return null;
      }
      final essentialIds = guideLessonsForCategory(
        guideEssentialCategoryId,
      ).map((lesson) => lesson.id).toSet();
      final masteryIds = guideLessonsForCategory(
        guideMasteryCategoryId,
      ).map((lesson) => lesson.id).toSet();
      final advancedIds = guideLessonsForCategory(
        guideAdvancedCategoryId,
      ).map((lesson) => lesson.id).toSet();

      String migrateEssentialId(String id) => switch (id) {
        'essential.reconnection' => 'essential.notifications-background',
        _ => id,
      };

      String migrateLegacyMasteryId(String id) => switch (id) {
        'advanced.pairing-trust' ||
        'advanced.connection-hierarchy' ||
        'advanced.lan' ||
        'advanced.webrtc' ||
        'advanced.relay-reconnect' ||
        'advanced.security-privacy' => 'advanced.pc-mobile-connection',
        'advanced.android-background' ||
        'advanced.ios-background' ||
        'advanced.notifications' => 'mastery.notifications-background',
        'advanced.voice-tts-stt' || 'advanced.tts' => 'advanced.voice-tts-stt',
        'advanced.conversations-sync' => 'mastery.conversations-turns',
        'advanced.models' => 'advanced.ai-model-hierarchy',
        'advanced.troubleshooting' ||
        'advanced.troubleshooting-media' => 'mastery.troubleshooting',
        _ => id,
      };

      Set<String> completed(
        Object? value,
        Set<String> allowed, {
        String Function(String) migrate = _identity,
      }) {
        if (value is! List) return <String>{};
        return value
            .whereType<String>()
            .map(migrate)
            .where(allowed.contains)
            .toSet();
      }

      final essentialCompleted = completed(
        decoded['essentialCompleted'],
        essentialIds,
        migrate: migrateEssentialId,
      );
      final storedContentSchema = decoded['contentSchemaVersion'];
      final legacyContent =
          storedContentSchema is! int || storedContentSchema < 3;
      final masteryCompleted = legacyContent
          ? completed(
              decoded['advancedCompleted'],
              masteryIds,
              migrate: migrateLegacyMasteryId,
            )
          : completed(decoded['masteryCompleted'], masteryIds);
      final advancedCompleted = legacyContent
          ? <String>{}
          : completed(decoded['advancedCompleted'], advancedIds);
      if (storedContentSchema is! int || storedContentSchema < 2) {
        if (essentialCompleted.contains('essential.pair-token')) {
          essentialCompleted.add('essential.enter-token');
        }
      }

      final rawCurrent = decoded['currentLesson'];
      final migratedCurrent = rawCurrent is String
          ? (legacyContent
                ? migrateLegacyMasteryId(migrateEssentialId(rawCurrent))
                : migrateEssentialId(rawCurrent))
          : null;
      final current = guideLessonById(migratedCurrent) != null
          ? migratedCurrent
          : null;
      const allowedOutcomes = <String>{
        'presenting',
        'completed',
        'skipped',
        'closed',
        'migrated',
      };
      final rawOutcome = decoded['outcome'];
      final outcome =
          rawOutcome is String && allowedOutcomes.contains(rawOutcome)
          ? rawOutcome
          : 'migrated';
      return GuideProgress(
        schemaVersion: guideStateSchemaVersion,
        contentSchemaVersion: guideContentSchemaVersion,
        essentialCompleted: essentialCompleted,
        masteryCompleted: masteryCompleted,
        advancedCompleted: advancedCompleted,
        currentLessonId: current,
        finished: decoded['finished'] == true,
        skipped: decoded['skipped'] == true,
        automaticPresentationHandled:
            decoded['automaticPresentationHandled'] == true,
        outcome: outcome,
      );
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

  Future<GuideProgress> selectLesson(
    GuideProgress progress,
    String lessonId,
  ) async {
    if (guideLessonById(lessonId) == null) return progress;
    final next = progress.copyWith(currentLessonId: lessonId);
    await save(next);
    return next;
  }

  Future<GuideProgress> completeLesson(
    GuideProgress progress,
    GuideLesson lesson,
  ) async {
    final essential = Set<String>.from(progress.essentialCompleted);
    final mastery = Set<String>.from(progress.masteryCompleted);
    final advanced = Set<String>.from(progress.advancedCompleted);
    if (lesson.categoryId == guideEssentialCategoryId) {
      essential.add(lesson.id);
    } else if (lesson.categoryId == guideMasteryCategoryId) {
      mastery.add(lesson.id);
    } else {
      advanced.add(lesson.id);
    }
    final next = progress.copyWith(
      essentialCompleted: essential,
      masteryCompleted: mastery,
      advancedCompleted: advanced,
    );
    await save(next);
    return next;
  }

  Future<GuideProgress> markSkipped(GuideProgress progress) async {
    final next = progress.copyWith(
      skipped: true,
      outcome: 'skipped',
      automaticPresentationHandled: true,
    );
    await save(next);
    return next;
  }

  Future<GuideProgress> markFinished(GuideProgress progress) async {
    final essentialIds = guideLessonsForCategory(
      guideEssentialCategoryId,
    ).map((lesson) => lesson.id).toSet();
    final next = progress.copyWith(
      essentialCompleted: essentialIds,
      finished: true,
      outcome: 'completed',
      automaticPresentationHandled: true,
    );
    await save(next);
    return next;
  }

  Future<GuideProgress> markClosed(GuideProgress progress) async {
    final next = progress.copyWith(
      outcome: progress.outcome == 'presenting' ? 'closed' : progress.outcome,
      automaticPresentationHandled: true,
    );
    await save(next);
    return next;
  }
}

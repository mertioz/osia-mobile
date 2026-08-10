import 'dart:convert';

import 'guide/guide_catalog.dart';
import 'services/storage_service.dart';

const int guideStateSchemaVersion = 2;

class GuideProgress {
  const GuideProgress({
    required this.schemaVersion,
    required this.contentVersion,
    required this.lastTrackId,
    required this.lastSlideByTrack,
    required this.visitedByTrack,
    required this.finished,
    required this.skipped,
    required this.automaticPresentationHandled,
    required this.outcome,
  });

  final int schemaVersion;
  final int contentVersion;
  final String lastTrackId;
  final Map<String, String> lastSlideByTrack;
  final Map<String, Set<String>> visitedByTrack;
  final bool finished;
  final bool skipped;
  final bool automaticPresentationHandled;
  final String outcome;

  int get contentSchemaVersion => guideContentSchemaVersion;
  String? get currentLessonId => lastSlideByTrack[lastTrackId];
  Set<String> get essentialCompleted =>
      visitedByTrack[guideEssentialCategoryId] ?? const <String>{};
  Set<String> get masteryCompleted =>
      visitedByTrack[guideMasteryCategoryId] ?? const <String>{};
  Set<String> get advancedCompleted =>
      visitedByTrack[guideAdvancedCategoryId] ?? const <String>{};

  factory GuideProgress.freshPresentation() => GuideProgress(
    schemaVersion: guideStateSchemaVersion,
    contentVersion: guideCatalog.contentVersion,
    lastTrackId: guideEssentialCategoryId,
    lastSlideByTrack: <String, String>{
      guideEssentialCategoryId: guideLessonsForCategory(
        guideEssentialCategoryId,
      ).first.id,
    },
    visitedByTrack: const <String, Set<String>>{
      guideEssentialCategoryId: <String>{},
      guideMasteryCategoryId: <String>{},
      guideAdvancedCategoryId: <String>{},
    },
    finished: false,
    skipped: false,
    automaticPresentationHandled: true,
    outcome: 'presenting',
  );

  factory GuideProgress.migrated() => const GuideProgress(
    schemaVersion: guideStateSchemaVersion,
    contentVersion: 4,
    lastTrackId: guideEssentialCategoryId,
    lastSlideByTrack: <String, String>{},
    visitedByTrack: <String, Set<String>>{
      guideEssentialCategoryId: <String>{},
      guideMasteryCategoryId: <String>{},
      guideAdvancedCategoryId: <String>{},
    },
    finished: false,
    skipped: false,
    automaticPresentationHandled: true,
    outcome: 'migrated',
  );

  GuideProgress copyWith({
    String? lastTrackId,
    Map<String, String>? lastSlideByTrack,
    Map<String, Set<String>>? visitedByTrack,
    Set<String>? essentialCompleted,
    Set<String>? masteryCompleted,
    Set<String>? advancedCompleted,
    String? currentLessonId,
    bool clearCurrentLesson = false,
    bool? finished,
    bool? skipped,
    bool? automaticPresentationHandled,
    String? outcome,
  }) {
    final nextVisited = <String, Set<String>>{
      for (final entry in (visitedByTrack ?? this.visitedByTrack).entries)
        entry.key: Set<String>.from(entry.value),
    };
    if (essentialCompleted != null) {
      nextVisited[guideEssentialCategoryId] = Set<String>.from(
        essentialCompleted,
      );
    }
    if (masteryCompleted != null) {
      nextVisited[guideMasteryCategoryId] = Set<String>.from(masteryCompleted);
    }
    if (advancedCompleted != null) {
      nextVisited[guideAdvancedCategoryId] = Set<String>.from(
        advancedCompleted,
      );
    }
    final nextLast = Map<String, String>.from(
      lastSlideByTrack ?? this.lastSlideByTrack,
    );
    var nextTrack = lastTrackId ?? this.lastTrackId;
    if (clearCurrentLesson) {
      nextLast.remove(nextTrack);
    } else if (currentLessonId != null) {
      final slide = guideLessonById(_resolveLegacyCurrent(currentLessonId));
      if (slide != null) {
        nextTrack = slide.trackId;
        nextLast[slide.trackId] = slide.id;
      }
    }
    return GuideProgress(
      schemaVersion: guideStateSchemaVersion,
      contentVersion: guideCatalog.contentVersion,
      lastTrackId: nextTrack,
      lastSlideByTrack: nextLast,
      visitedByTrack: nextVisited,
      finished: finished ?? this.finished,
      skipped: skipped ?? this.skipped,
      automaticPresentationHandled:
          automaticPresentationHandled ?? this.automaticPresentationHandled,
      outcome: outcome ?? this.outcome,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'contentVersion': contentVersion,
    'lastTrackId': lastTrackId,
    'lastSlideByTrack': <String, String>{
      for (final entry in lastSlideByTrack.entries) entry.key: entry.value,
    },
    'visitedByTrack': <String, List<String>>{
      for (final entry in visitedByTrack.entries)
        entry.key: entry.value.toList()..sort(),
    },
    // Compatibility mirrors for the pre-v4 state readers.
    'contentSchemaVersion': guideContentSchemaVersion,
    'essentialCompleted': essentialCompleted.toList()..sort(),
    'masteryCompleted': masteryCompleted.toList()..sort(),
    'advancedCompleted': advancedCompleted.toList()..sort(),
    'currentLesson': currentLessonId,
    'finished': finished,
    'skipped': skipped,
    'automaticPresentationHandled': automaticPresentationHandled,
    'outcome': outcome,
  };

  static const _trackIds = <String>{
    guideEssentialCategoryId,
    guideMasteryCategoryId,
    guideAdvancedCategoryId,
  };

  static String _legacyMobileId(String id) => switch (id) {
    'essential.what-is-mobile' => 'essential.osia-role',
    'essential.before-pairing' => 'essential.requirements',
    'essential.pair-token' => 'essential.pairing-token',
    'essential.enter-token' => 'essential.pairing-connect',
    'essential.mobile-pages' => 'essential.mobile-navigation',
    'essential.first-message' => 'essential.first-request',
    'essential.voice' => 'essential.voice',
    'essential.notifications-background' ||
    'essential.reconnection' => 'essential.reconnect',
    'advanced.pairing-trust' ||
    'advanced.connection-hierarchy' ||
    'advanced.lan' ||
    'advanced.webrtc' ||
    'advanced.relay-reconnect' ||
    'advanced.security-privacy' => 'advanced.pc-mobile-connection',
    'advanced.android-background' ||
    'advanced.ios-background' ||
    'advanced.notifications' => 'mastery.notifications-background',
    'advanced.tts' => 'advanced.voice-tts-stt',
    'advanced.conversations-sync' => 'mastery.conversations-turns',
    'advanced.models' => 'advanced.ai-model-hierarchy',
    'advanced.troubleshooting' ||
    'advanced.troubleshooting-media' => 'mastery.troubleshooting',
    _ => id,
  };

  static Set<String> _migrateIds(Object? raw, String trackId) {
    if (raw is! List) return <String>{};
    final allowed = guideLessonsForCategory(
      trackId,
    ).map((slide) => slide.id).toSet();
    final result = <String>{};
    for (final value in raw.whereType<String>()) {
      final legacy = _legacyMobileId(value);
      final children = guideLegacyChildren(legacy);
      if (children.isNotEmpty) {
        result.addAll(children.where(allowed.contains));
      }
    }
    return result;
  }

  static String? _resolveLegacyCurrent(String? value, {String? trackId}) {
    if (value == null || value.isEmpty) return null;
    return resolveGuideSlideId(_legacyMobileId(value), trackId: trackId);
  }

  static GuideProgress? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final schema = decoded['schemaVersion'];
      if (schema != 1 && schema != guideStateSchemaVersion) return null;

      final visited = <String, Set<String>>{};
      final rawVisited = decoded['visitedByTrack'];
      if (rawVisited is Map<String, dynamic>) {
        for (final trackId in _trackIds) {
          visited[trackId] = _migrateIds(rawVisited[trackId], trackId);
        }
      } else {
        visited[guideEssentialCategoryId] = _migrateIds(
          decoded['essentialCompleted'],
          guideEssentialCategoryId,
        );
        final storedContentSchema = decoded['contentSchemaVersion'];
        final legacyContent =
            storedContentSchema is! int || storedContentSchema < 3;
        visited[guideMasteryCategoryId] = _migrateIds(
          legacyContent
              ? decoded['advancedCompleted']
              : decoded['masteryCompleted'],
          guideMasteryCategoryId,
        );
        visited[guideAdvancedCategoryId] = legacyContent
            ? <String>{}
            : _migrateIds(
                decoded['advancedCompleted'],
                guideAdvancedCategoryId,
              );
      }
      for (final trackId in _trackIds) {
        visited.putIfAbsent(trackId, () => <String>{});
      }

      final lastByTrack = <String, String>{};
      final rawLast = decoded['lastSlideByTrack'];
      if (rawLast is Map<String, dynamic>) {
        for (final trackId in _trackIds) {
          final value = rawLast[trackId];
          final resolved = value is String
              ? _resolveLegacyCurrent(value, trackId: trackId)
              : null;
          final slide = guideLessonById(resolved);
          if (slide?.trackId == trackId) lastByTrack[trackId] = slide!.id;
        }
      }
      final rawCurrent = decoded['currentLesson'];
      final current = rawCurrent is String
          ? _resolveLegacyCurrent(rawCurrent)
          : null;
      final currentSlide = guideLessonById(current);
      if (currentSlide != null) {
        lastByTrack.putIfAbsent(currentSlide.trackId, () => currentSlide.id);
      }
      var lastTrack = decoded['lastTrackId'];
      if (lastTrack is! String || !_trackIds.contains(lastTrack)) {
        lastTrack = currentSlide?.trackId ?? guideEssentialCategoryId;
      }
      if (!lastByTrack.containsKey(lastTrack)) {
        lastByTrack[lastTrack] = guideLessonsForCategory(lastTrack).first.id;
      }

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
        contentVersion: guideCatalog.contentVersion,
        lastTrackId: lastTrack,
        lastSlideByTrack: lastByTrack,
        visitedByTrack: visited,
        finished: decoded['finished'] == true,
        skipped: decoded['skipped'] == true,
        automaticPresentationHandled:
            decoded['automaticPresentationHandled'] == true,
        outcome: outcome,
      );
    } catch (_) {
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
    final resolved = resolveGuideSlideId(lessonId);
    final slide = guideLessonById(resolved);
    if (slide == null) return progress;
    final next = progress.copyWith(
      lastTrackId: slide.trackId,
      lastSlideByTrack: <String, String>{
        ...progress.lastSlideByTrack,
        slide.trackId: slide.id,
      },
    );
    await save(next);
    return next;
  }

  Future<GuideProgress> completeLesson(
    GuideProgress progress,
    Object lesson,
  ) async {
    final dynamic legacyCompatible = lesson;
    final String lessonId = legacyCompatible.id as String;
    final String trackId = legacyCompatible.categoryId as String;
    final resolved = resolveGuideSlideId(lessonId, trackId: trackId);
    final slide = guideLessonById(resolved);
    if (slide == null) return progress;
    final visited = <String, Set<String>>{
      for (final entry in progress.visitedByTrack.entries)
        entry.key: Set<String>.from(entry.value),
    };
    final children = guideLegacyChildren(
      GuideProgress._legacyMobileId(lessonId),
    );
    visited
        .putIfAbsent(slide.trackId, () => <String>{})
        .addAll(children.isEmpty ? <String>{slide.id} : children);
    final next = progress.copyWith(visitedByTrack: visited);
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
    final visited = <String, Set<String>>{
      for (final entry in progress.visitedByTrack.entries)
        entry.key: Set<String>.from(entry.value),
    };
    visited[guideEssentialCategoryId] = guideLessonsForCategory(
      guideEssentialCategoryId,
    ).map((lesson) => lesson.id).toSet();
    final next = progress.copyWith(
      visitedByTrack: visited,
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

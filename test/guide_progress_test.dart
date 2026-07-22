import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/guide_content.dart';
import 'package:osia_mobile/guide_progress.dart';
import 'package:osia_mobile/services/storage_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('genuinely fresh profile is claimed once before presentation', () async {
    final service = GuideProgressService(StorageService());
    final first = await service.prepareLaunch();
    expect(first.showAutomatically, isTrue);
    expect(first.progress.automaticPresentationHandled, isTrue);
    expect(first.progress.outcome, 'presenting');
    expect(first.progress.currentLessonId, 'essential.what-is-mobile');

    final second = await service.prepareLaunch();
    expect(second.showAutomatically, isFalse);
    expect(second.progress.currentLessonId, first.progress.currentLessonId);
  });

  test(
    'any pre-guide state migrates an existing user without opening',
    () async {
      for (final existing in <Map<String, String>>[
        <String, String>{'osia_language': 'en'},
        <String, String>{'osia_token': 'existing-token'},
        <String, String>{'osia_theme_key': 'violet'},
        <String, String>{'osia_notifications_enabled': 'false'},
      ]) {
        FlutterSecureStorage.setMockInitialValues(existing);
        final decision = await GuideProgressService(
          StorageService(),
        ).prepareLaunch();
        expect(decision.showAutomatically, isFalse, reason: '$existing');
        expect(decision.progress.outcome, 'migrated');
        expect(decision.progress.automaticPresentationHandled, isTrue);
      }
    },
  );

  test('normal update and crash recovery never reopen handled guide', () async {
    final presenting = GuideProgress.freshPresentation().copyWith(
      currentLessonId: 'essential.voice',
    );
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'osia_mobile_guide_state_v1': jsonEncode(presenting.toJson()),
    });
    final service = GuideProgressService(StorageService());
    final afterCrash = await service.prepareLaunch();
    expect(afterCrash.showAutomatically, isFalse);
    expect(afterCrash.progress.currentLessonId, 'essential.voice');

    final completed = await service.markFinished(afterCrash.progress);
    final afterUpdate = await service.prepareLaunch();
    expect(afterUpdate.showAutomatically, isFalse);
    expect(afterUpdate.progress.finished, isTrue);
    expect(
      afterUpdate.progress.essentialCompleted,
      completed.essentialCompleted,
    );
  });

  test(
    'progress is separate across three categories and survives service instances',
    () async {
      final storage = StorageService();
      final service = GuideProgressService(storage);
      final decision = await service.prepareLaunch();
      final essential = guideLessonById('essential.first-message')!;
      final mastery = guideLessonById('advanced.ai-model-hierarchy')!;
      final advanced = guideLessonById('advanced.handshake')!;
      var progress = await service.completeLesson(decision.progress, essential);
      progress = await service.completeLesson(progress, mastery);
      progress = await service.completeLesson(progress, advanced);
      progress = await service.selectLesson(progress, advanced.id);

      final restored = await GuideProgressService(storage).load();
      expect(restored.essentialCompleted, contains(essential.id));
      expect(restored.masteryCompleted, contains(mastery.id));
      expect(restored.advancedCompleted, contains(advanced.id));
      expect(restored.currentLessonId, advanced.id);
      expect(restored.automaticPresentationHandled, isTrue);
    },
  );

  test('corrupt and stale progress is bounded to registered lesson ids', () {
    final raw = jsonEncode(<String, Object?>{
      'schemaVersion': guideStateSchemaVersion,
      'contentSchemaVersion': 0,
      'essentialCompleted': <Object?>[
        'essential.voice',
        'advanced.models',
        'unknown',
        4,
      ],
      'advancedCompleted': <Object?>[
        'advanced.models',
        'essential.voice',
        'unknown',
      ],
      'currentLesson': 'unknown',
      'finished': false,
      'skipped': false,
      'automaticPresentationHandled': true,
      'outcome': 'completed',
    });
    final progress = GuideProgress.tryDecode(raw)!;
    expect(progress.contentSchemaVersion, guideContentSchemaVersion);
    expect(progress.essentialCompleted, <String>{'essential.voice'});
    expect(progress.masteryCompleted, <String>{'advanced.ai-model-hierarchy'});
    expect(progress.advancedCompleted, isEmpty);
    expect(progress.currentLessonId, isNull);
  });

  test('schema-one progress expands split slides without resetting state', () {
    final raw = jsonEncode(<String, Object?>{
      'schemaVersion': guideStateSchemaVersion,
      'contentSchemaVersion': 1,
      'essentialCompleted': <String>[
        'essential.pair-token',
        'essential.reconnection',
      ],
      'advancedCompleted': <String>[
        'advanced.connection-hierarchy',
        'advanced.voice-tts-stt',
        'advanced.troubleshooting',
      ],
      'currentLesson': 'essential.reconnection',
      'finished': false,
      'skipped': false,
      'automaticPresentationHandled': true,
      'outcome': 'closed',
    });

    final progress = GuideProgress.tryDecode(raw)!;
    expect(progress.contentSchemaVersion, guideContentSchemaVersion);
    expect(progress.currentLessonId, 'essential.notifications-background');
    expect(
      progress.essentialCompleted,
      containsAll(<String>{
        'essential.pair-token',
        'essential.enter-token',
        'essential.notifications-background',
      }),
    );
    expect(
      progress.masteryCompleted,
      containsAll(<String>{
        'advanced.pc-mobile-connection',
        'advanced.voice-tts-stt',
        'mastery.troubleshooting',
      }),
    );
    expect(progress.advancedCompleted, isEmpty);
  });

  test('schema-two advanced progress migrates only into mastery', () {
    final raw = jsonEncode(<String, Object?>{
      'schemaVersion': guideStateSchemaVersion,
      'contentSchemaVersion': 2,
      'essentialCompleted': <String>['essential.ready'],
      'advancedCompleted': <String>[
        'advanced.models',
        'advanced.notifications',
      ],
      'currentLesson': 'advanced.models',
      'finished': true,
      'skipped': false,
      'automaticPresentationHandled': true,
      'outcome': 'completed',
    });

    final progress = GuideProgress.tryDecode(raw)!;
    expect(progress.essentialCompleted, contains('essential.ready'));
    expect(progress.masteryCompleted, <String>{
      'advanced.ai-model-hierarchy',
      'mastery.notifications-background',
    });
    expect(progress.advancedCompleted, isEmpty);
    expect(progress.currentLessonId, 'advanced.ai-model-hierarchy');
    expect(progress.finished, isTrue);
    expect(progress.automaticPresentationHandled, isTrue);
  });

  test(
    'disconnect-style credential clearing preserves guide progress',
    () async {
      final storage = StorageService();
      final service = GuideProgressService(storage);
      final decision = await service.prepareLaunch();
      await storage.setToken('DEMO-CODE');
      await service.selectLesson(
        decision.progress,
        'mastery.notifications-background',
      );
      await storage.clearCredentials();
      final restored = await service.load();
      expect(restored.currentLessonId, 'mastery.notifications-background');
      expect(await storage.getToken(), isNull);
    },
  );
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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

    final second = await service.prepareLaunch();
    expect(second.showAutomatically, isFalse);
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

  test(
    'an existing claim and legacy fields survive upgrade and disconnect',
    () async {
      final storage = StorageService();
      final service = GuideProgressService(storage);
      await storage.setGuideState(
        jsonEncode({
          'schemaVersion': 1,
          'automaticPresentationHandled': true,
          'outcome': 'presenting',
          'currentLesson': 'essential.voice',
        }),
      );
      final afterCrash = await service.prepareLaunch();
      expect(afterCrash.showAutomatically, isFalse);
      await service.markClosed(
        afterCrash.progress.copyWith(finished: true, outcome: 'completed'),
      );
      await storage.setToken('DEMO-CODE');
      await storage.clearCredentials();
      final afterUpdate = await service.prepareLaunch();
      expect(afterUpdate.showAutomatically, isFalse);
      expect(afterUpdate.progress.finished, isTrue);
      expect(afterUpdate.progress.toJson()['currentLesson'], 'essential.voice');
      expect(await storage.getToken(), isNull);
    },
  );
}

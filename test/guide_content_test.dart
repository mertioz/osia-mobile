import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/guide_content.dart';

String _copy(Iterable<GuideLesson> lessons, String language) => lessons
    .expand<String>(
      (lesson) => <String>[
        lesson.title.resolve(language),
        lesson.introduction.resolve(language),
        ...lesson.paragraphs.map((value) => value.resolve(language)),
        ...lesson.bullets.map((value) => value.resolve(language)),
        lesson.exampleTitle.resolve(language),
        lesson.example.resolve(language),
        if (lesson.remember != null) lesson.remember!.resolve(language),
        if (lesson.caption != null) lesson.caption!.resolve(language),
        if (lesson.altText != null) lesson.altText!.resolve(language),
      ],
    )
    .join('\n');

int _wordCount(String text) => RegExp(
  r"[A-Za-zÀ-ÖØ-öø-ÿ0-9]+(?:[-’'][A-Za-zÀ-ÖØ-öø-ÿ0-9]+)*",
).allMatches(text).length;

int _mainWordCount(GuideLesson lesson, String language) => _wordCount(
  <String>[
    lesson.introduction.resolve(language),
    ...lesson.paragraphs.map((value) => value.resolve(language)),
    ...lesson.bullets.map((value) => value.resolve(language)),
  ].join(' '),
);

({int width, int height, Set<String> chunks}) _pngInfo(List<int> bytes) {
  expect(bytes.take(8), orderedEquals(<int>[137, 80, 78, 71, 13, 10, 26, 10]));
  final data = Uint8List.fromList(bytes);
  final view = ByteData.sublistView(data);
  var offset = 8;
  var width = 0;
  var height = 0;
  final chunks = <String>{};
  while (offset + 12 <= data.length) {
    final length = view.getUint32(offset);
    final type = ascii.decode(data.sublist(offset + 4, offset + 8));
    chunks.add(type);
    if (type == 'IHDR') {
      width = view.getUint32(offset + 8);
      height = view.getUint32(offset + 12);
    }
    offset += 12 + length;
    if (type == 'IEND') break;
  }
  return (width: width, height: height, chunks: chunks);
}

void main() {
  test('guide has three ordered categories and unique stable slide ids', () {
    expect(guideContentSchemaVersion, 3);
    expect(guideCategories.map((category) => category.id), <String>[
      guideEssentialCategoryId,
      guideMasteryCategoryId,
      guideAdvancedCategoryId,
    ]);
    expect(guideCategories.map((category) => category.semanticId), <String>[
      'essential',
      'mastery',
      'advanced',
    ]);
    final ids = guideLessons.map((lesson) => lesson.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(guideLessonsForCategory(guideEssentialCategoryId), hasLength(9));
    expect(guideLessonsForCategory(guideMasteryCategoryId), hasLength(20));
    expect(guideLessonsForCategory(guideAdvancedCategoryId), hasLength(38));
    for (final category in guideCategories) {
      final orders = guideLessonsForCategory(
        category.id,
      ).map((lesson) => lesson.order).toList();
      expect(orders, List<int>.generate(orders.length, (index) => index + 1));
    }
  });

  test('mastery and advanced semantic subject coverage is complete', () {
    final mastery = guideLessonsForCategory(
      guideMasteryCategoryId,
    ).map((lesson) => lesson.subjectId).toSet();
    expect(mastery, <String?>{
      'mental-model',
      'conversations-turns',
      'providers-accounts',
      'provider-hierarchy',
      'model-hierarchy',
      'reasoning',
      'keys-quotas-security',
      'files-images',
      'autonomous',
      'scheduled-tasks',
      'connectors',
      'memory-context',
      'tools-computer-control',
      'voice',
      'pairing-connection',
      'notifications-background',
      'settings-tour',
      'updates',
      'troubleshooting',
      'practical-workflows',
    });
    final advanced = guideLessonsForCategory(
      guideAdvancedCategoryId,
    ).map((lesson) => lesson.subjectId).toSet();
    expect(advanced, <String?>{
      'product-architecture',
      'repository-topology',
      'pc-architecture',
      'mobile-architecture',
      'worker-architecture',
      'message-flow',
      'pairing-protocol',
      'transport-overview',
      'lan',
      'webrtc',
      'ice-stun-turn',
      'relay',
      'e2e',
      'handshake',
      'correlation',
      'attachments',
      'vision',
      'provider-architecture',
      'provider-hierarchy',
      'model-capabilities',
      'agent-runtime',
      'autonomous',
      'computer-use',
      'cron',
      'mcp',
      'memory-persistence',
      'configuration-secrets',
      'development-environment',
      'takeover-workflow',
      'safe-modification',
      'testing-strategy',
      'windows-packaging',
      'android-packaging',
      'worker-site-deployment',
      'release-process',
      'security-model',
      'developer-troubleshooting',
      'glossary',
    });
    final glossary = guideLessonsForCategory(
      guideAdvancedCategoryId,
    ).singleWhere((lesson) => lesson.subjectId == 'glossary');
    expect(glossary.glossaryIds.toSet(), <String>{
      'provider',
      'model',
      'api',
      'token',
      'context',
      'thinking',
      'mcp',
      'dcr',
      'oauth',
      'cron',
      'websocket',
      'e2e',
      'lan',
      'p2p',
      'webrtc',
      'sdp',
      'ice',
      'stun',
      'turn',
      'signaling',
      'relay',
      'durable-object',
      'hibernation',
      'chunking',
      'hash',
      'mime',
      'abi',
      'apk',
      'aab',
      'r8',
      'pyinstaller',
      'inno-setup',
      'r2',
      'rollout',
      'version-name',
      'version-code',
    });
  });

  test('every slide contains complete English and French offline copy', () {
    for (final category in guideCategories) {
      expect(category.title.en.trim(), isNotEmpty);
      expect(category.title.fr.trim(), isNotEmpty);
      expect(category.summary.en.trim(), isNotEmpty);
      expect(category.summary.fr.trim(), isNotEmpty);
    }
    for (final lesson in guideLessons) {
      expect(lesson.id, matches(RegExp(r'^(essential|mastery|advanced)\.')));
      expect(lesson.paragraphs.length, lessThanOrEqualTo(5), reason: lesson.id);
      expect(lesson.bullets.length, lessThanOrEqualTo(3), reason: lesson.id);
      for (final value in <GuideText>[
        lesson.title,
        lesson.introduction,
        ...lesson.paragraphs,
        ...lesson.bullets,
        lesson.exampleTitle,
        lesson.example,
        if (lesson.remember != null) lesson.remember!,
      ]) {
        expect(value.en.trim(), isNotEmpty, reason: lesson.id);
        expect(value.fr.trim(), isNotEmpty, reason: lesson.id);
      }
      if (lesson.asset != null) {
        expect(lesson.caption, isNotNull, reason: lesson.id);
        expect(lesson.altText, isNotNull, reason: lesson.id);
        expect(lesson.caption!.en.trim(), isNotEmpty);
        expect(lesson.caption!.fr.trim(), isNotEmpty);
        expect(lesson.altText!.en.trim(), isNotEmpty);
        expect(lesson.altText!.fr.trim(), isNotEmpty);
      }
    }
    final copy = _copy(guideLessons, 'en');
    expect(copy, isNot(contains('http://')));
    expect(copy, isNot(contains('https://')));
  });

  test('mobile density is bounded and essential slides are shorter', () {
    final essential = guideLessonsForCategory(guideEssentialCategoryId);
    final mastery = guideLessonsForCategory(guideMasteryCategoryId);
    final advanced = guideLessonsForCategory(guideAdvancedCategoryId);
    final essentialCounts = <int>[];
    final detailedCounts = <int>[];
    for (final lesson in essential) {
      final count = _mainWordCount(lesson, 'en');
      essentialCounts.add(count);
      expect(count, inInclusiveRange(20, 68), reason: lesson.id);
    }
    for (final lesson in <GuideLesson>[...mastery, ...advanced]) {
      final count = _mainWordCount(lesson, 'en');
      detailedCounts.add(count);
      expect(
        count,
        inInclusiveRange(15, lesson.subjectId == 'glossary' ? 450 : 220),
        reason: lesson.id,
      );
    }
    final essentialAverage =
        essentialCounts.reduce((a, b) => a + b) / essentialCounts.length;
    final detailedAverage =
        detailedCounts.reduce((a, b) => a + b) / detailedCounts.length;
    expect(essentialAverage, lessThan(detailedAverage));
    for (final lesson in guideLessons) {
      for (final block in <GuideText>[
        lesson.introduction,
        ...lesson.paragraphs,
        ...lesson.bullets,
      ]) {
        final maximum = lesson.subjectId == 'glossary' ? 420 : 145;
        expect(
          _wordCount(block.en),
          lessThanOrEqualTo(maximum),
          reason: lesson.id,
        );
        expect(
          _wordCount(block.fr),
          lessThanOrEqualTo(maximum + 20),
          reason: lesson.id,
        );
      }
    }
  });

  test('essential copy covers every validated beginner subject and page', () {
    final copy = _copy(
      guideLessonsForCategory(guideEssentialCategoryId),
      'en',
    ).toLowerCase();
    for (final phrase in <String>[
      'phone interface',
      'pairing token',
      'connection',
      'connected',
      'chat',
      'conversations',
      'autonomous',
      'settings',
      'memory',
      'providers',
      'first message',
      'microphone',
      'speech-to-text',
      'reconnect',
      'notifications',
      'background',
      'apns',
    ]) {
      expect(copy, contains(phrase), reason: phrase);
    }
    final ready = guideLessonById('essential.ready')!;
    expect(
      ready.remember!.en,
      'Finish closes this guide; Help keeps all three guide levels available.',
    );
    expect(
      ready.remember!.fr,
      'Terminer ferme ce guide ; Aide garde les trois niveaux de guide disponibles.',
    );
  });

  test('mastery copy covers audited user features without false promises', () {
    final copy = _copy(
      guideLessonsForCategory(guideMasteryCategoryId),
      'en',
    ).toLowerCase();
    for (final phrase in <String>[
      'provider and api hierarchy',
      'models and ai hierarchy',
      'reasoning',
      'scheduled tasks',
      'autonomous',
      'mcp',
      'memory',
      'computer',
      'tts',
      'stt',
      'pairing',
      'webrtc',
    ]) {
      expect(copy, contains(phrase), reason: phrase);
    }
    for (final unsupported in <String>[
      'wake word is available',
      'apns push is supported',
      'works while the pc is off',
      'unlimited background',
    ]) {
      expect(copy, isNot(contains(unsupported)), reason: unsupported);
    }
  });

  test(
    'advanced guide covers architecture, takeover, release and glossary',
    () {
      final copy = _copy(
        guideLessonsForCategory(guideAdvancedCategoryId),
        'en',
      ).toLowerCase();
      for (final phrase in <String>[
        'durable object',
        'private-lan wss',
        'webrtc',
        'stun',
        'turn',
        'end-to-end',
        'dynamic client registration',
        'pyinstaller',
        'inno setup',
        'versioncode',
        'r2',
        'twelve-step',
      ]) {
        expect(copy, contains(phrase), reason: phrase);
      }
      expect(copy, isNot(contains('works while the pc is off')));
    },
  );

  test(
    'curated screenshots are declared, decodable and metadata-free',
    () async {
      final referenced = guideLessons
          .map((lesson) => lesson.asset)
          .whereType<String>()
          .toSet();
      expect(referenced, <String>{
        'assets/guide/pc-pairing.png',
        'assets/guide/mobile-navigation.png',
        'assets/guide/mobile-chat.png',
        'assets/guide/mobile-settings.png',
      });
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/guide/'));
      for (final relative in referenced) {
        final file = File(relative);
        expect(file.existsSync(), isTrue, reason: relative);
        expect(file.lengthSync(), lessThanOrEqualTo(500000), reason: relative);
        final info = _pngInfo(file.readAsBytesSync());
        expect(info.width, inInclusiveRange(300, 1000), reason: relative);
        expect(info.height, inInclusiveRange(500, 1000), reason: relative);
        expect(info.chunks, containsAll(<String>['IHDR', 'IDAT', 'IEND']));
        expect(
          info.chunks.intersection(<String>{'eXIf', 'tEXt', 'iTXt', 'zTXt'}),
          isEmpty,
          reason: relative,
        );
        final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, info.width, reason: relative);
        expect(frame.image.height, info.height, reason: relative);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  test(
    'guide fixtures contain no secret, identity, email, IP or local path',
    () {
      final source = <String>[
        File('lib/guide_content.dart').readAsStringSync(),
        File('lib/guide_curriculum.g.dart').readAsStringSync(),
        File('test/guide_asset_capture_test.dart').readAsStringSync(),
      ].join('\n');
      final forbidden = <RegExp>[
        RegExp(r'sk-[A-Za-z0-9_-]{16,}'),
        RegExp(r'ghp_[A-Za-z0-9_]{16,}'),
        RegExp(r'xox[abprs]-[A-Za-z0-9-]{16,}'),
        RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
        RegExp(r'-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----'),
        RegExp(r'C:\\Users\\', caseSensitive: false),
        RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),
      ];
      for (final pattern in forbidden) {
        expect(pattern.hasMatch(source), isFalse, reason: pattern.pattern);
      }
      expect(source, isNot(contains('Aymen')));
      expect(source, contains('DEMO-CODE'));
    },
  );
}

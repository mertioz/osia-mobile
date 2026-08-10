import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/guide/guide_catalog.dart';

void main() {
  test('canonical semantic catalog is ordered, localized and accessible', () {
    expect(guideCatalog.schemaVersion, 4);
    expect(guideCatalog.contentVersion, 4);
    expect(guideCatalog.tracks.map((track) => track.id), <String>[
      guideEssentialCategoryId,
      guideMasteryCategoryId,
      guideAdvancedCategoryId,
    ]);
    expect(guideCatalog.tracks.map((track) => track.semanticId), <String>[
      'essential',
      'mastery',
      'advanced',
    ]);
    expect(guideCatalog.tracks.map((track) => track.slides.length), <int>[
      17,
      46,
      43,
    ]);
    expect(guideCatalog.slides.map((slide) => slide.id).toSet().length, 106);

    for (final track in guideCatalog.tracks) {
      expect(
        track.slides.map((slide) => slide.order),
        List<int>.generate(track.slides.length, (index) => index + 1),
      );
      expect(track.title.resolve('de'), track.title.en);
      for (final slide in track.slides) {
        expect(slide.title.en, isNotEmpty);
        expect(slide.title.fr, isNotEmpty);
        expect(slide.title.resolve('de'), slide.title.en);
        expect(slide.visual.alt.en, isNotEmpty);
        expect(slide.visual.alt.fr, isNotEmpty);
      }
    }
  });

  test(
    'mobile variant and settings-only correction match the audited scope',
    () {
      final pairing = guideLessonById('essential.pairing-token')!;
      expect(pairing.visual.kind, 'screenshot');
      expect(pairing.visual.asset, 'assets/guide/pc-pairing.png');
      expect(
        guideCatalog.slides.where((slide) => slide.visual.kind == 'screenshot'),
        hasLength(1),
      );

      final settings = guideCatalog.slides
          .where(
            (slide) =>
                slide.id.contains('settings') ||
                slide.id == 'essential.pc-settings-map',
          )
          .expand(
            (slide) => <String>[
              slide.subtitle.en,
              ...slide.bodyBlocks.map((block) => block.en),
              ...slide.callouts.expand(
                (callout) => <String>[callout.title.en, callout.body.en],
              ),
            ],
          )
          .join(' ');
      expect(settings, contains('eleven real categories'));
      expect(settings, contains('Permissions'));
      expect(settings, isNot(contains('ten real categories')));
      expect(
        guideCatalog.slides.any(
          (slide) => <String>[
            'projects',
            'reflection',
            'multi-action',
          ].any(slide.id.contains),
        ),
        isFalse,
      );
    },
  );

  test('packaged JSON is the exact source of generated typed data', () {
    final bytes = File('assets/guide/catalog.v4.json').readAsBytesSync();
    expect(sha256.convert(bytes).toString(), guideCatalogSha256);
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(decoded['schema_version'], guideCatalog.schemaVersion);
    expect(decoded['content_version'], guideCatalog.contentVersion);
    expect(
      (decoded['tracks'] as List<dynamic>).length,
      guideCatalog.tracks.length,
    );
  });

  test('legacy split completion expands in stable order', () {
    expect(resolveGuideSlideId('advanced.voice-tts-stt'), 'mastery.voice-tts');
    expect(guideLegacyChildren('advanced.voice-tts-stt'), <String>{
      'mastery.voice-tts',
      'mastery.voice-stt',
      'mastery.voice-recovery',
      'mastery.voice-privacy',
    });
    expect(
      resolveGuideSlideId(
        'removed',
        trackId: guideMasteryCategoryId,
        oldOrder: 8,
      ),
      'mastery.manual-model',
    );
  });
}

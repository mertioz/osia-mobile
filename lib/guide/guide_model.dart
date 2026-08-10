import 'package:flutter/foundation.dart';

@immutable
class GuideText {
  const GuideText({required this.en, required this.fr});

  final String en;
  final String fr;

  String resolve(String languageCode) => languageCode == 'fr' ? fr : en;
}

@immutable
class GuideCallout {
  const GuideCallout({
    required this.kind,
    required this.title,
    required this.body,
  });

  final String kind;
  final GuideText title;
  final GuideText body;
}

@immutable
class GuideVisual {
  const GuideVisual({
    required this.kind,
    required this.key,
    required this.alt,
    this.asset,
  });

  final String kind;
  final String key;
  final GuideText alt;
  final String? asset;
}

@immutable
class GuideSlide {
  const GuideSlide({
    required this.id,
    required this.trackId,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.bodyBlocks,
    required this.callouts,
    required this.visual,
    required this.legacyIds,
  });

  final String id;
  final String trackId;
  final int order;
  final GuideText title;
  final GuideText subtitle;
  final List<GuideText> bodyBlocks;
  final List<GuideCallout> callouts;
  final GuideVisual visual;
  final List<String> legacyIds;

  // Compatibility projections retained until every external Guide caller has
  // migrated from the former lesson model.
  String get categoryId => trackId;
  GuideText get introduction => subtitle;
  List<GuideText> get paragraphs => bodyBlocks;
  List<GuideText> get bullets => const <GuideText>[];
  GuideText get exampleTitle => callouts.isEmpty
      ? const GuideText(en: 'In practice', fr: 'En pratique')
      : callouts.first.title;
  GuideText get example => callouts.isEmpty
      ? const GuideText(
          en: 'Continue when ready.',
          fr: 'Continuez quand vous êtes prêt.',
        )
      : callouts.first.body;
  GuideText? get remember {
    for (final callout in callouts) {
      if (callout.kind == 'remember' || callout.kind == 'safety') {
        return callout.body;
      }
    }
    return null;
  }

  String? get asset => visual.asset;
  GuideText? get caption => visual.asset == null ? null : visual.alt;
  GuideText? get altText => visual.alt;
  String? get subjectId => null;
  List<String> get glossaryIds => const <String>[];
}

@immutable
class GuideTrack {
  const GuideTrack({
    required this.id,
    required this.semanticId,
    required this.order,
    required this.title,
    required this.summary,
    required this.slides,
  });

  final String id;
  final String semanticId;
  final int order;
  final GuideText title;
  final GuideText summary;
  final List<GuideSlide> slides;
}

@immutable
class GuideCatalog {
  const GuideCatalog({
    required this.schemaVersion,
    required this.contentVersion,
    required this.tracks,
  });

  final int schemaVersion;
  final int contentVersion;
  final List<GuideTrack> tracks;

  List<GuideSlide> get slides => <GuideSlide>[
    for (final track in tracks) ...track.slides,
  ];
}

typedef GuideLesson = GuideSlide;
typedef GuideCategory = GuideTrack;

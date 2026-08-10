import 'guide_catalog_data.g.dart' as generated;
import 'guide_model.dart';

export 'guide_model.dart';

const int guideContentSchemaVersion = 4;
const String guideEssentialCategoryId = 'getting-started';
const String guideMasteryCategoryId = 'master-osia';
const String guideAdvancedCategoryId = 'osia-advanced';
const String guideLegacyAdvancedCategoryId = 'master-osia-mobile';

const GuideCatalog guideCatalog = generated.guideCatalog;
const String guideCatalogSha256 = generated.guideCatalogSha256;
final List<GuideTrack> guideCategories = guideCatalog.tracks;

List<GuideSlide> get guideLessons => guideCatalog.slides;

List<GuideSlide> guideLessonsForCategory(String categoryId) {
  for (final track in guideCatalog.tracks) {
    if (track.id == categoryId) return track.slides;
  }
  return const <GuideSlide>[];
}

GuideSlide? guideLessonById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final slide in guideCatalog.slides) {
    if (slide.id == id) return slide;
  }
  return null;
}

Map<String, String> get guideLegacyAliases {
  final result = <String, String>{};
  for (final slide in guideCatalog.slides) {
    for (final alias in slide.legacyIds) {
      result.putIfAbsent(alias, () => slide.id);
    }
  }
  return result;
}

String? resolveGuideSlideId(String? value, {String? trackId, int? oldOrder}) {
  final current = guideLessonById(value);
  if (current != null) return current.id;
  if (value != null) {
    final alias = guideLegacyAliases[value];
    if (alias != null) return alias;
  }
  final candidates = guideLessonsForCategory(
    trackId ?? guideEssentialCategoryId,
  );
  if (candidates.isEmpty) return null;
  if (oldOrder != null) {
    for (final slide in candidates) {
      if (slide.order >= oldOrder) return slide.id;
    }
    for (final slide in candidates.reversed) {
      if (slide.order < oldOrder) return slide.id;
    }
  }
  return candidates.first.id;
}

Set<String> guideLegacyChildren(String legacyId) => <String>{
  for (final slide in guideCatalog.slides)
    if (slide.id == legacyId || slide.legacyIds.contains(legacyId)) slide.id,
};

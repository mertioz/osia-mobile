import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:osia_mobile/guide_content.dart';

const String expectedEssentialHash =
    'f5776eabd8eb19145313803eb12267efd361fea19c98f04d64cb3fec7036d337';

Map<String, String>? _text(GuideText? value) =>
    value == null ? null : <String, String>{'en': value.en, 'fr': value.fr};

Map<String, Object?> _essentialRecord(GuideLesson lesson) => <String, Object?>{
  'id': lesson.id,
  'order': lesson.order,
  'title': _text(lesson.title),
  'intro': _text(lesson.introduction),
  'paragraphs': lesson.paragraphs.map(_text).toList(),
  'bullets': lesson.bullets.map(_text).toList(),
  'exampleTitle': _text(lesson.exampleTitle),
  'example': _text(lesson.example),
  'remember': _text(lesson.remember),
  'asset': lesson.asset,
  'caption': _text(lesson.caption),
  'altText': _text(lesson.altText),
};

String _essentialHash() {
  final payload = guideLessonsForCategory(
    guideEssentialCategoryId,
  ).map(_essentialRecord).toList();
  return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
}

List<Map<String, Object?>> _curriculum(String categoryId) =>
    guideLessonsForCategory(categoryId)
        .map(
          (lesson) => <String, Object?>{
            'id': lesson.id,
            'order': lesson.order,
            'subjectId': lesson.subjectId,
            'title': _text(lesson.title),
            'glossaryIds': lesson.glossaryIds,
          },
        )
        .toList();

Map<String, Object?> buildGuideManifest() {
  final glossaryIds = <String>{
    for (final categoryId in <String>[
      guideMasteryCategoryId,
      guideAdvancedCategoryId,
    ])
      for (final lesson in guideLessonsForCategory(categoryId))
        ...lesson.glossaryIds,
  }.toList()..sort();
  return <String, Object?>{
    'platform': 'mobile',
    'schemaVersion': guideContentSchemaVersion,
    'guideIds': guideCategories.map((category) => category.id).toList(),
    'categories': guideCategories
        .map(
          (category) => <String, Object?>{
            'id': category.id,
            'semanticId': category.semanticId,
            'order': category.order,
            'title': _text(category.title),
          },
        )
        .toList(),
    'essentialHash': _essentialHash(),
    'curriculum': <String, Object?>{
      'mastery': _curriculum(guideMasteryCategoryId),
      'advanced': _curriculum(guideAdvancedCategoryId),
    },
    'glossaryIds': glossaryIds,
  };
}

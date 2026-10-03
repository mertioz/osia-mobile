import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Hash of the current canonical PC guide catalog, shared as
/// `assets/guide/catalog.v4.json` in both repositories.
const String expectedCanonicalGuideSha256 =
    'd45049de840a81dad766268777f5cf1b71fdbd0e2e5a83b2b2327e4ec606bf52';

Map<String, Object?> buildGuideManifest() {
  final bytes = File('assets/guide/catalog.v4.json').readAsBytesSync();
  final source = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  return <String, Object?>{
    'platform': 'mobile',
    'schemaVersion': source['schema_version'],
    'contentVersion': source['content_version'],
    'catalogSha256': sha256.convert(bytes).toString(),
  };
}

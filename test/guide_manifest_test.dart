import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/guide_content_manifest.dart';

void main() {
  test('Mobile guide catalog matches the canonical PC guide catalog', () {
    final manifest = buildGuideManifest();
    expect(manifest['schemaVersion'], 4);
    expect(manifest['contentVersion'], 4);
    expect(manifest['catalogSha256'], expectedCanonicalGuideSha256);
    final output = Platform.environment['OSIA_GUIDE_MANIFEST_OUTPUT'];
    if (output != null && output.isNotEmpty) {
      final rendered = const JsonEncoder.withIndent('  ').convert(manifest);
      File(output).writeAsStringSync('$rendered\n');
    }
  });
}

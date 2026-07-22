import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/guide_content_manifest.dart';

void main() {
  test(
    'safe guide manifest preserves essential and can be compared with PC',
    () {
      final manifest = buildGuideManifest();
      if (expectedEssentialHash != 'TO_BE_RECORDED') {
        expect(manifest['essentialHash'], expectedEssentialHash);
      }
      final output = Platform.environment['OSIA_GUIDE_MANIFEST_OUTPUT'];
      if (output != null && output.isNotEmpty) {
        final rendered = const JsonEncoder.withIndent('  ').convert(manifest);
        File(output).writeAsStringSync('$rendered\n');
      }
    },
  );
}

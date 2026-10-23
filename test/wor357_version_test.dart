import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/product_version.dart';
import '../tool/build_release.dart';

void main() {
  test(
    'official mobile version and historical aliases retain build identity',
    () {
      expect(productVersion, '0.9.51');
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('version: $productVersion+24'),
      );
      final aliases = historicalMobileVersions.values.toList();
      expect(aliases.toSet().length, aliases.length);
      expect(displayMobileVersion('1.1.2+18'), '0.8.10');
      expect(displayMobileVersion('unknown'), 'unknown');
      final patches = aliases.map((s) => int.parse(s.split('.').last)).toList();
      expect(patches, orderedEquals(List.generate(11, (i) => i)));
      expect(
        File('android/app/build.gradle.kts').readAsStringSync(),
        contains('flutter.versionCode > 18'),
      );
      final workflow = File('codemagic.yaml').readAsStringSync();
      expect(RegExp('--all-versions').allMatches(workflow).length, 2);
      expect(workflow, isNot(contains('triggering:')));
    },
  );
  test('iOS packaging fails closed until a store maximum is supplied', () {
    // App Store Connect browser inventory verified 2026-10-20; source build 19
    // must also exceed the accepted Android 18, not merely iOS maximum 16.
    expect(
      validatedIosBuildNumber({
        'OSIA_IOS_STORE_MAX_BUILD': '16',
        'IOS_BUILD_NUMBER': '19',
      }),
      19,
    );
    for (final env in <Map<String, String>>[
      {},
      {'OSIA_IOS_STORE_MAX_BUILD': '24', 'IOS_BUILD_NUMBER': '19'},
      {'OSIA_IOS_STORE_MAX_BUILD': '24', 'IOS_BUILD_NUMBER': '24'},
      {'OSIA_IOS_STORE_MAX_BUILD': 'unknown', 'IOS_BUILD_NUMBER': '25'},
    ]) {
      expect(() => validatedIosBuildNumber(env), throwsFormatException);
    }
    expect(
      validatedIosBuildNumber({
        'OSIA_IOS_STORE_MAX_BUILD': '24',
        'IOS_BUILD_NUMBER': '25',
      }),
      25,
    );
  });
}

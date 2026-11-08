import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory('build/store-captures');
  await output.create(recursive: true);

  await integrationDriver(
    onScreenshot: (name, image, [args]) async {
      await File(
        '${output.path}/OSIA-iPad-Pro-13-$name.png',
      ).writeAsBytes(image);
      return true;
    },
  );
}

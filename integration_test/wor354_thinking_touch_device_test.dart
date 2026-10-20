import 'package:integration_test/integration_test.dart';

import '../test/wor354_thinking_touch_test.dart' as thinking_touch;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The Android debug variant has applicationIdSuffix .test. This fixture
  // neither opens the paired app's store nor sends provider requests.
  thinking_touch.main();
}

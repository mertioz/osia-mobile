import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all production Inter weights load from bundled assets without HTTP',
    () async {
      GoogleFonts.config.allowRuntimeFetching = false;
      for (final weight in FontWeight.values) {
        GoogleFonts.inter(fontWeight: weight);
      }
      await GoogleFonts.pendingFonts();
    },
  );
}

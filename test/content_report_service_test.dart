import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/content_report_service.dart';

const receipt = '382b5c70-c0e1-4d45-9104-161ced820251';
void main() {
  test(
    'HTTP report has only consented fields and requires a typed stored receipt',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bodies = <Map<String, dynamic>>[];
      var status = 201;
      var result = <String, dynamic>{'received': true, 'report_id': receipt};
      final subscription = server.listen((request) async {
        bodies.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.statusCode = status;
        request.response.write(jsonEncode(result));
        await request.response.close();
      });
      try {
        final service = ContentReportService(
          endpoint: Uri.parse('http://127.0.0.1:${server.port}/v1/reports'),
        );
        expect(
          await service.submit(
            text: 'Reviewed text',
            category: 'other',
            details: '',
          ),
          receipt,
        );
        expect(bodies.single, {
          'schema_version': 1,
          'category': 'other',
          'text': 'Reviewed text',
          'details': '',
        });
        status = 503;
        await expectLater(
          service.submit(text: 'Reviewed text', category: 'other', details: ''),
          throwsA(isA<HttpException>()),
        );
        status = 201;
        result = {'received': false, 'report_id': receipt};
        await expectLater(
          service.submit(text: 'Reviewed text', category: 'other', details: ''),
          throwsFormatException,
        );
      } finally {
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}

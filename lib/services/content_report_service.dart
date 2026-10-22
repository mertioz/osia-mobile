import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A voluntary support report, separate from the PC's canonical chat state.
/// Sends only the editable fields the user reviewed. Never reads credentials.
class ContentReportService {
  ContentReportService({Uri? endpoint})
    : endpoint =
          endpoint ??
          Uri.parse(
            'https://osia-content-reports.aymengherbi06.workers.dev/v1/reports',
          );

  final Uri endpoint;

  Future<String> submit({
    required String text,
    required String category,
    required String details,
  }) async {
    if (text.trim().isEmpty ||
        text.length > 3000 ||
        details.length > 500 ||
        !const {
          'harmful',
          'sexual',
          'violence',
          'deceptive',
          'other',
        }.contains(category)) {
      throw const FormatException('Invalid report fields.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await _send(
        client,
        text,
        category,
        details,
      ).timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _send(
    HttpClient client,
    String text,
    String category,
    String details,
  ) async {
    final request = await client.postUrl(endpoint);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'schema_version': 1,
        'category': category,
        'text': text,
        'details': details,
      }),
    );
    final response = await request.close();
    if (response.statusCode != HttpStatus.created) {
      throw const HttpException('Report receipt was not confirmed.');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > 2048) {
        throw const FormatException('Invalid report receipt.');
      }
      bytes.addAll(chunk);
    }
    final receipt = jsonDecode(utf8.decode(bytes));
    if (receipt is! Map<String, dynamic> ||
        receipt['received'] != true ||
        receipt['report_id'] is! String ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(receipt['report_id'] as String)) {
      throw const FormatException('Invalid report receipt.');
    }
    return receipt['report_id'] as String;
  }
}

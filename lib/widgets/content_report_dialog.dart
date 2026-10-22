import 'package:flutter/material.dart';

import '../content_report_strings.dart';
import '../l10n.dart';
import '../services/content_report_service.dart';

class ContentReportDialog extends StatefulWidget {
  const ContentReportDialog({super.key, required this.text, this.service});
  final String text;
  final ContentReportService? service;

  @override
  State<ContentReportDialog> createState() => _ContentReportDialogState();
}

class _ContentReportDialogState extends State<ContentReportDialog> {
  late final TextEditingController _text;
  late String _lastText;
  final _note = TextEditingController();
  String _category = 'other';
  bool _consent = false;
  bool _sending = false;
  bool _unconfirmed = false;
  String? _receipt;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: widget.text.length > 3000
          ? widget.text.substring(0, 3000)
          : widget.text,
    );
    _text.addListener(_changed);
    _lastText = _text.text;
  }

  void _changed() {
    if (_lastText == _text.text) return;
    _lastText = _text.text;
    setState(() {
      _consent = false;
    });
  }

  @override
  void dispose() {
    _text.removeListener(_changed);
    _text.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_consent || _sending || _text.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _unconfirmed = false;
    });
    try {
      final receipt = await (widget.service ?? ContentReportService()).submit(
        text: _text.text,
        category: _category,
        details: _note.text,
      );
      if (mounted) {
        setState(() {
          _receipt = receipt;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unconfirmed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = OsiaL10n.of(context);
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        title: Text(strings.reportContent),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: _receipt != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(strings.reportReceived),
                      const SizedBox(height: 12),
                      SelectableText(_receipt!),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(strings.reportDisclosure),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('report-text'),
                        controller: _text,
                        enabled: !_sending,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 3000,
                        decoration: InputDecoration(
                          labelText: strings.reportText,
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: InputDecoration(
                          labelText: strings.reportReason,
                        ),
                        items: [
                          for (final category in [
                            'harmful',
                            'sexual',
                            'violence',
                            'deceptive',
                            'other',
                          ])
                            DropdownMenuItem(
                              value: category,
                              child: Text(strings.reportCategory(category)),
                            ),
                        ],
                        onChanged: _sending
                            ? null
                            : (value) => setState(() {
                                _category = value!;
                                _consent = false;
                              }),
                      ),
                      TextField(
                        key: const Key('report-note'),
                        controller: _note,
                        enabled: !_sending,
                        maxLines: 2,
                        maxLength: 500,
                        onChanged: (_) => setState(() {
                          _consent = false;
                        }),
                        decoration: InputDecoration(
                          labelText: strings.reportNote,
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(strings.reportConsent),
                        value: _consent,
                        onChanged: _sending
                            ? null
                            : (value) => setState(() {
                                _consent = value == true;
                              }),
                      ),
                      if (_unconfirmed)
                        Text(
                          strings.reportUnconfirmed,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: Text(
              _receipt == null
                  ? strings.cancel
                  : MaterialLocalizations.of(context).closeButtonLabel,
            ),
          ),
          if (_receipt == null)
            FilledButton(
              onPressed: _consent && !_sending && _text.text.trim().isNotEmpty
                  ? _send
                  : null,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(strings.reportSend),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';

const List<String> _memoryTypes = [
  'route',
  'preference',
  'fact',
  'workflow',
  'contact',
  'shortcut',
];

const List<String> _memoryCategories = [
  'app',
  'site',
  'deep_link',
  'folder',
  'file',
  'game',
  'user',
  'workflow',
  'contact',
  'other',
];

const List<String> _valueKinds = [
  'path',
  'url',
  'uri',
  'steam_appid',
  'text',
  'steps',
];

enum _PendingMemoryAction { save, delete, clear }

class MemoryScreen extends StatefulWidget {
  final ws.WebSocketService wsService;

  const MemoryScreen({super.key, required this.wsService});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  ws.MemorySnapshot? _snapshot;
  ws.ConnectionState _connState = ws.ConnectionState.disconnected;
  StreamSubscription? _memorySub;
  StreamSubscription? _memoryErrorSub;
  StreamSubscription? _connSub;
  _PendingMemoryAction? _pendingAction;
  bool _busy = false;

  bool get _connected => _connState == ws.ConnectionState.connected;

  List<ws.MemoryEntryData> get _entries {
    final list = List<ws.MemoryEntryData>.from(_snapshot?.entries ?? const []);
    list.sort((a, b) {
      final ad = a.lastUsedAt ?? a.updatedAt ?? a.createdAt;
      final bd = b.lastUsedAt ?? b.updatedAt ?? b.createdAt;
      return (bd ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        ad ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _snapshot = widget.wsService.memorySnapshot;
    _connState = widget.wsService.state;
    _memorySub = widget.wsService.memoryStream.listen(_onMemorySnapshot);
    _memoryErrorSub = widget.wsService.memoryErrorStream.listen(_onMemoryError);
    _connSub = widget.wsService.connectionStream.listen((state) {
      if (!mounted) return;
      final wasDisconnected = !_connected;
      setState(() => _connState = state);
      if (wasDisconnected && state == ws.ConnectionState.connected) {
        widget.wsService.requestMemory();
      }
    });
    if (_connected) widget.wsService.requestMemory();
  }

  @override
  void dispose() {
    _memorySub?.cancel();
    _memoryErrorSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  void _onMemorySnapshot(ws.MemorySnapshot snapshot) {
    if (!mounted) return;
    final action = _pendingAction;
    setState(() {
      _snapshot = snapshot;
      _busy = false;
      _pendingAction = null;
    });
    if (action != null) {
      final strings = OsiaL10n.of(context);
      final message = switch (action) {
        _PendingMemoryAction.save => strings.memorySaved,
        _PendingMemoryAction.delete => strings.memoryDeleted,
        _PendingMemoryAction.clear => strings.memoryCleared,
      };
      _snack(message);
    }
  }

  void _onMemoryError(ws.MemoryErrorMessage error) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pendingAction = null;
    });
    final strings = OsiaL10n.of(context);
    final detail = error.message.trim();
    _snack(
      detail.isEmpty ? strings.memoryError : '${strings.memoryError}: $detail',
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _requireConnected() {
    if (_connected) return true;
    _snack(OsiaL10n.of(context).connectedRequired);
    return false;
  }

  void _refresh() {
    if (!_requireConnected()) return;
    widget.wsService.requestMemory();
  }

  Future<void> _edit({ws.MemoryEntryData? entry}) async {
    if (!_requireConnected() || _busy) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _MemoryEditDialog(entry: entry),
    );
    if (result == null) return;
    setState(() {
      _busy = true;
      _pendingAction = _PendingMemoryAction.save;
    });
    widget.wsService.upsertMemory(result);
  }

  void _delete(ws.MemoryEntryData entry) {
    if (!_requireConnected() || _busy || entry.id.isEmpty) return;
    setState(() {
      _busy = true;
      _pendingAction = _PendingMemoryAction.delete;
    });
    widget.wsService.deleteMemory(entry.id);
  }

  Future<void> _clearAll() async {
    if (!_requireConnected() || _busy || _entries.isEmpty) return;
    final strings = OsiaL10n.of(context);
    final palette = OsiaTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.clearAll),
        content: Text(
          strings.memoryClearConfirm,
          style: TextStyle(color: palette.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              strings.clearAll,
              style: TextStyle(color: palette.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _pendingAction = _PendingMemoryAction.clear;
    });
    widget.wsService.clearMemory();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final entries = _entries;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(strings.memoryTitle),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
        actions: [
          IconButton(
            tooltip: strings.refresh,
            onPressed: _connected ? _refresh : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: strings.add,
            onPressed: _connected && !_busy ? () => _edit() : null,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: strings.clearAll,
            onPressed: _connected && !_busy && entries.isNotEmpty
                ? _clearAll
                : null,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              strings.localMemories,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: palette.textMuted,
              ),
            ),
            if (!_connected) ...[
              const SizedBox(height: 12),
              _InfoBand(text: strings.connectedRequired, palette: palette),
            ],
            const SizedBox(height: 18),
            if (entries.isEmpty)
              _EmptyMemoryState(
                enabled: _connected && !_busy,
                onAdd: () => _edit(),
                palette: palette,
                strings: strings,
              )
            else
              for (final entry in entries) ...[
                _MemoryEntryCard(
                  entry: entry,
                  enabled: _connected && !_busy,
                  onEdit: () => _edit(entry: entry),
                  onDelete: () => _delete(entry),
                  palette: palette,
                  strings: strings,
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _MemoryEntryCard extends StatelessWidget {
  final ws.MemoryEntryData entry;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final OsiaPalette palette;
  final OsiaStrings strings;

  const _MemoryEntryCard({
    required this.entry,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
    required this.palette,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final date = entry.lastUsedAt ?? entry.updatedAt ?? entry.createdAt;
    final meta = [
      if (entry.type.isNotEmpty || entry.category.isNotEmpty)
        '${entry.type}/${entry.category}',
      if (entry.source.isNotEmpty) entry.source,
      if (date != null) _formatDate(date),
    ].where((s) => s.trim().isNotEmpty).join('  |  ');

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border, width: 0.6),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title.isEmpty ? entry.key : entry.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: TextStyle(fontSize: 11.5, color: palette.textMuted),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _previewValue(entry),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: palette.textPrimary.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                tooltip: strings.edit,
                onPressed: enabled ? onEdit : null,
                icon: Icon(Icons.edit_rounded, color: palette.accent, size: 19),
              ),
              IconButton(
                tooltip: strings.delete,
                onPressed: enabled ? onDelete : null,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: palette.error,
                  size: 19,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyMemoryState extends StatelessWidget {
  final bool enabled;
  final VoidCallback onAdd;
  final OsiaPalette palette;
  final OsiaStrings strings;

  const _EmptyMemoryState({
    required this.enabled,
    required this.onAdd,
    required this.palette,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border, width: 0.6),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.psychology_alt_rounded, color: palette.accent, size: 24),
          const SizedBox(height: 12),
          Text(
            strings.noMemoriesYet,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(strings.add),
          ),
        ],
      ),
    );
  }
}

class _InfoBand extends StatelessWidget {
  final String text;
  final OsiaPalette palette;

  const _InfoBand({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border, width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, color: palette.textMuted),
      ),
    );
  }
}

class _MemoryEditDialog extends StatefulWidget {
  final ws.MemoryEntryData? entry;

  const _MemoryEditDialog({this.entry});

  @override
  State<_MemoryEditDialog> createState() => _MemoryEditDialogState();
}

class _MemoryEditDialogState extends State<_MemoryEditDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _valueCtrl;
  late String _type;
  late String _category;
  late String _kind;
  String? _error;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _titleCtrl = TextEditingController(text: entry?.title ?? '');
    _keyCtrl = TextEditingController(text: entry?.key ?? '');
    _valueCtrl = TextEditingController(
      text: entry?.valueData?.toString() ?? '',
    );
    _type = _memoryTypes.contains(entry?.type) ? entry!.type : 'fact';
    _category = _memoryCategories.contains(entry?.category)
        ? entry!.category
        : 'user';
    _kind = _valueKinds.contains(entry?.valueKind) ? entry!.valueKind : 'text';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _keyCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    final data = _valueCtrl.text.trim();
    if (title.isEmpty || key.isEmpty || data.isEmpty) {
      setState(() => _error = OsiaL10n.of(context).memoryRequiredFields);
      return;
    }
    final entry = widget.entry;
    final json = <String, dynamic>{
      if (entry != null && entry.id.isNotEmpty) 'id': entry.id,
      'type': _type,
      'category': _category,
      'key': key,
      'title': title,
      'value': {'kind': _kind, 'data': data},
      'confidence': entry?.confidence ?? 1.0,
      'source': 'mobile_settings',
      if (entry?.createdAt != null)
        'created_at': entry!.createdAt!.toUtc().toIso8601String(),
      if (entry?.lastUsedAt != null)
        'last_used_at': entry!.lastUsedAt!.toUtc().toIso8601String(),
      'tags': entry?.tags ?? const <String>[],
      'device': {'origin': 'mobile', 'platform': 'mobile'},
      if (entry?.expiresAt != null)
        'expires_at': entry!.expiresAt!.toUtc().toIso8601String(),
    };
    Navigator.of(context).pop(json);
  }

  @override
  Widget build(BuildContext context) {
    final strings = OsiaL10n.of(context);
    final palette = OsiaTheme.of(context);

    return AlertDialog(
      title: Text(
        widget.entry == null ? strings.memoryNewTitle : strings.memoryEditTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: strings.memoryTitleField),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _keyCtrl,
              decoration: InputDecoration(labelText: strings.memoryKeyField),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _valueCtrl,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(labelText: strings.memoryValueField),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: strings.memoryTypeField),
              items: [
                for (final type in _memoryTypes)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: strings.memoryCategoryField,
              ),
              items: [
                for (final category in _memoryCategories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: strings.memoryKindField),
              items: [
                for (final kind in _valueKinds)
                  DropdownMenuItem(value: kind, child: Text(kind)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _kind = value);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: palette.error, fontSize: 12.5),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        TextButton(onPressed: _save, child: Text(strings.save)),
      ],
    );
  }
}

String _previewValue(ws.MemoryEntryData entry) {
  final kind = entry.valueKind;
  final data = entry.valueData?.toString() ?? '';
  if (kind.isEmpty) return data;
  return '$kind: $data';
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

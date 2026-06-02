import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/connection_badge.dart';
import '../widgets/glass_input_bar.dart';
import '../widgets/model_selector_sheet.dart';
import '../widgets/thinking_indicator.dart';

/// Main chat screen: conversation history, floating glass input,
/// thinking indicator, model selector and connection badge.
class ChatScreen extends StatefulWidget {
  final StorageService storage;

  const ChatScreen({super.key, required this.storage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Services
  late final ws.WebSocketService _wsService;
  final AudioService _audioService = AudioService();

  // State
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatEntry> _entries = [];
  bool _thinking = false;
  ws.ConnectionState _connState = ws.ConnectionState.disconnected;
  StreamSubscription? _msgSub;
  StreamSubscription? _connSub;
  StreamSubscription? _errSub;
  String? _connError;
  bool _initialized = false;

  // Conversations
  List<ws.Conversation> _conversations = [];
  String? _activeConversationId;
  String? _activeConversationTitle;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Models
  List<ws.OsiaModel> _models = [];
  String? _selectedModel;
  // Active notifier for the open model-selector sheet, if any. Lets the
  // chat screen push state updates (models arriving, load timing out) into
  // a sheet that's already on screen.
  ValueNotifier<ModelSelectorState>? _modelSelectorNotifier;
  Timer? _modelLoadTimeout;

  // Index of the entry currently receiving streamed chunks (null when idle).
  int? _streamingIndex;

  // Pending attachment shown as a chip in the input bar. Only sent when
  // the user taps the send arrow (or hits enter).
  String? _pendingFilename;
  Uint8List? _pendingFileBytes;
  bool _pendingIsImage = false;

  // True while we sent a turn and haven't yet seen status=done/error.
  bool _awaitingResponse = false;
  // True if the user switched conversation mid-response — every subsequent
  // response_chunk / response / audio frame for the in-flight request is
  // dropped until the matching status=done/error arrives.
  bool _discardCurrentResponse = false;

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  Future<void> _initConnection() async {
    final ip = await widget.storage.getTailscaleIp();
    final token = await widget.storage.getToken();
    _selectedModel = await widget.storage.getSelectedModel();

    if (ip == null || token == null || ip.isEmpty || token.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/settings');
      }
      return;
    }

    _wsService = ws.WebSocketService(ip: ip, token: token);

    _connSub = _wsService.connectionStream.listen((state) {
      if (mounted) {
        setState(() {
          _connState = state;
          if (state == ws.ConnectionState.connected) {
            _connError = null;
            // Ask for available models once the socket is up.
            _wsService.sendGetModels();
            // Replay our remembered selection so the server is in sync.
            if (_selectedModel != null && _selectedModel!.isNotEmpty) {
              _wsService.sendSetModel(_selectedModel!);
            }
          }
        });
      }
    });

    _msgSub = _wsService.messageStream.listen(_onMessage);

    _errSub = _wsService.errorStream.listen((err) {
      if (mounted) setState(() => _connError = err);
    });

    _wsService.connect();
    setState(() => _initialized = true);
  }

  void _onMessage(ws.OsiaMessage msg) {
    switch (msg) {
      case ws.TranscriptMessage(:final content):
        if (content.isNotEmpty) {
          _addEntry(_ChatEntry(
              content: content, isUser: true, isTranscript: true));
        }
      case ws.ResponseChunkMessage(:final content):
        if (content.isEmpty) break;
        if (_discardCurrentResponse) break;
        setState(() {
          _thinking = false;
          final idx = _streamingIndex;
          if (idx == null) {
            _entries.add(_ChatEntry(
              content: content,
              isUser: false,
              isStreaming: true,
            ));
            _streamingIndex = _entries.length - 1;
          } else {
            final cur = _entries[idx];
            final needsSpace = cur.content.isNotEmpty &&
                !cur.content.endsWith(' ') &&
                !cur.content.endsWith('\n') &&
                !content.startsWith(' ');
            _entries[idx] = cur.copyWith(
              content: cur.content + (needsSpace ? ' ' : '') + content,
            );
          }
        });
        _scrollToBottomAnimated();
      case ws.ResponseMessage(:final content):
        if (_discardCurrentResponse) break;
        setState(() {
          _thinking = false;
          final idx = _streamingIndex;
          if (idx != null) {
            // Final assembled reply — keep `isStreaming` true until
            // status=done so the cursor stays visible through TTS playback.
            _entries[idx] = _entries[idx].copyWith(content: content);
          } else {
            _entries.add(_ChatEntry(content: content, isUser: false));
          }
        });
        _scrollToBottomAnimated();
      case ws.AudioMessage(:final data):
        if (_discardCurrentResponse) break;
        _audioService.playMp3(data);
      case ws.StatusMessage(:final content):
        if (content == 'thinking') {
          if (_discardCurrentResponse) break;
          setState(() => _thinking = true);
          _scrollToBottomAnimated();
        } else if (content == 'done' || content == 'error') {
          final wasDiscarding = _discardCurrentResponse;
          setState(() {
            _awaitingResponse = false;
            _discardCurrentResponse = false;
            if (!wasDiscarding) {
              _thinking = false;
              final idx = _streamingIndex;
              if (idx != null) {
                _entries[idx] =
                    _entries[idx].copyWith(isStreaming: false);
                _streamingIndex = null;
              }
            }
          });
        }
      case ws.ConversationsMessage(:final conversations):
        setState(() => _conversations = conversations);
      case ws.ActiveConversationMessage(:final id, :final title):
        setState(() {
          _activeConversationId = id;
          _activeConversationTitle = title;
        });
      case ws.ConversationHistoryMessage(:final id, :final messages):
        setState(() {
          _entries
            ..clear()
            ..addAll(messages.map((m) => _ChatEntry(
                  content: m.content,
                  isUser: m.role == 'user',
                )));
          _thinking = false;
          _streamingIndex = null;
          if (id != null && id.isNotEmpty) _activeConversationId = id;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
      case ws.ModelsListMessage(:final models, :final current):
        setState(() {
          _models = models;
          // Server-reported current wins unless we already have a saved
          // selection that's still in the list.
          final saved = _selectedModel;
          if (saved == null || !models.any((m) => m.id == saved)) {
            _selectedModel = current;
            if (current != null && current.isNotEmpty) {
              widget.storage.setSelectedModel(current);
            }
          }
        });
        // If the model selector sheet is currently open, push the fresh
        // list into it so it stops spinning.
        final notifier = _modelSelectorNotifier;
        if (notifier != null) {
          _modelLoadTimeout?.cancel();
          notifier.value = ModelSelectorState(
            models: models,
            isLoading: false,
          );
        }
    }
  }

  void _loadConversation(ws.Conversation conv) {
    _wsService.sendLoadConversation(conv.id);
    setState(() {
      // If a response was in flight, drop everything it sends after the
      // switch so chunks meant for the old conversation never land on
      // this one. The flag clears on the next status=done/error.
      if (_awaitingResponse) {
        _discardCurrentResponse = true;
      }
      _entries.clear();
      _thinking = false;
      _streamingIndex = null;
      _activeConversationId = conv.id;
      _activeConversationTitle = conv.title;
    });
    Navigator.of(context).maybePop();
  }

  void _newConversation() {
    _wsService.sendNewConversation();
    setState(() {
      if (_awaitingResponse) {
        _discardCurrentResponse = true;
      }
      _entries.clear();
      _thinking = false;
      _streamingIndex = null;
      _activeConversationId = null;
      _activeConversationTitle = null;
    });
    Navigator.of(context).maybePop();
  }

  Future<void> _deleteConversation(ws.Conversation conv) async {
    final palette = OsiaTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la conversation ?'),
        content: Text(
          '« ${conv.title} » sera supprimée définitivement.',
          style: TextStyle(color: palette.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text('Annuler', style: TextStyle(color: palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Supprimer', style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _wsService.sendDeleteConversation(conv.id);
    setState(() {
      _conversations =
          _conversations.where((c) => c.id != conv.id).toList();
      if (_activeConversationId == conv.id) {
        _entries.clear();
        _activeConversationId = null;
        _activeConversationTitle = null;
      }
    });
  }

  String _formatConversationDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final local = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays == 0) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return "Aujourd'hui $h:$m";
    }
    if (diffDays == 1) return 'Hier';
    if (diffDays < 7) return 'Il y a $diffDays j';
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    return '$d/$mo/$y';
  }

  void _addEntry(_ChatEntry entry) {
    setState(() => _entries.add(entry));
    _scrollToBottomAnimated();
  }

  void _scrollToBottomAnimated() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  bool get _canSend =>
      _textCtrl.text.trim().isNotEmpty || _pendingFileBytes != null;

  void _sendText() {
    final text = _textCtrl.text.trim();
    final filename = _pendingFilename;
    final bytes = _pendingFileBytes;
    final isImage = _pendingIsImage;
    final hasFile = filename != null && bytes != null;
    if (text.isEmpty && !hasFile) return;

    final displayContent = hasFile
        ? (text.isEmpty ? '📎 $filename' : '📎 $filename\n$text')
        : text;
    _addEntry(_ChatEntry(content: displayContent, isUser: true));

    if (hasFile) {
      _wsService.sendFile(filename, base64Encode(bytes), isImage: isImage);
    }

    final prompt = text.isNotEmpty
        ? text
        : (isImage
            ? "Analyse cette image."
            : "Voici le fichier ${filename ?? ''}.");
    _wsService.sendText(prompt);

    _textCtrl.clear();
    setState(() {
      _pendingFilename = null;
      _pendingFileBytes = null;
      _pendingIsImage = false;
      _awaitingResponse = true;
      _discardCurrentResponse = false;
    });
  }

  void _clearPendingFile() {
    setState(() {
      _pendingFilename = null;
      _pendingFileBytes = null;
      _pendingIsImage = false;
    });
  }

  bool _isImageFilename(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  Future<void> _toggleRecording() async {
    if (_audioService.isRecording) {
      final base64Wav = await _audioService.stopRecording();
      if (base64Wav != null && base64Wav.isNotEmpty) {
        _wsService.sendAudio(base64Wav);
        _awaitingResponse = true;
        _discardCurrentResponse = false;
      }
      setState(() {});
    } else {
      try {
        await _audioService.startRecording();
        setState(() {});
      } catch (e) {
        if (mounted) {
          final msg = _audioService.isPermissionPermanentlyDenied
              ? "Permission micro refusée. Ouvrez les paramètres pour l'autoriser."
              : "Impossible d'accéder au microphone.";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              action: _audioService.isPermissionPermanentlyDenied
                  ? SnackBarAction(
                      label: 'Paramètres',
                      onPressed: () =>
                          _audioService.openMicrophoneSettings(),
                    )
                  : null,
            ),
          );
        }
      }
    }
  }

  /// Request the storage / media permissions file_picker may need on
  /// Android. On Android 13+ generic-file picks go through the Storage
  /// Access Framework which doesn't require any of these — but media picks
  /// do, and asking up-front sidesteps a confusing "nothing happens" UX
  /// when the user taps a media file.
  ///
  /// The request is best-effort: we log each outcome and proceed regardless
  /// of the grant state, because the SAF picker works without permissions
  /// and we don't want to block the user.
  Future<void> _requestAttachPermissions() async {
    if (!Platform.isAndroid) {
      debugPrint('[OSIA Attach] non-Android platform, skipping permissions');
      return;
    }
    final perms = <Permission>[
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ];
    for (final p in perms) {
      try {
        final before = await p.status;
        debugPrint('[OSIA Attach] $p initial status=$before');
        if (before.isGranted || before.isLimited) continue;
        if (before.isPermanentlyDenied) {
          debugPrint('[OSIA Attach] $p permanently denied — skipping request');
          continue;
        }
        final result = await p.request();
        debugPrint('[OSIA Attach] $p request -> $result');
      } catch (e) {
        debugPrint('[OSIA Attach] $p threw on request: $e');
      }
    }
  }

  Future<void> _onAttach() async {
    debugPrint('[OSIA Attach] tap → _onAttach start');
    await _requestAttachPermissions();

    FilePickerResult? result;
    try {
      debugPrint('[OSIA Attach] calling FilePicker.pickFiles(FileType.any)');
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      debugPrint(
        '[OSIA Attach] pickFiles returned: '
        '${result == null ? "null (user cancelled)" : "${result.files.length} file(s)"}',
      );
    } catch (e, stack) {
      debugPrint('[OSIA Attach] pickFiles threw: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sélection de fichier impossible : $e")),
        );
      }
      return;
    }
    if (result == null || result.files.isEmpty) {
      debugPrint('[OSIA Attach] no file picked, returning');
      return;
    }

    final picked = result.files.first;
    final filename = picked.name;
    debugPrint(
      '[OSIA Attach] picked: name=$filename '
      'path=${picked.path} '
      'size=${picked.size} '
      'bytesPresent=${picked.bytes != null}',
    );

    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      try {
        debugPrint('[OSIA Attach] reading bytes from path');
        bytes = await File(picked.path!).readAsBytes();
        debugPrint('[OSIA Attach] read ${bytes.length} bytes from disk');
      } catch (e, stack) {
        debugPrint('[OSIA Attach] disk read failed: $e\n$stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lecture du fichier impossible : $e")),
          );
        }
        return;
      }
    }
    if (bytes == null || bytes.isEmpty) {
      debugPrint('[OSIA Attach] empty / null bytes after load');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier vide ou inaccessible.')),
        );
      }
      return;
    }

    setState(() {
      _pendingFilename = filename;
      _pendingFileBytes = bytes;
      _pendingIsImage = _isImageFilename(filename);
    });
    debugPrint(
        '[OSIA Attach] staged ${bytes.length} bytes for $filename (image=$_pendingIsImage)');
  }

  Future<void> _openModelSelector() async {
    // The sheet listens to this notifier so we can flip from spinner →
    // model list (or → error) after it's already on screen.
    final notifier = ValueNotifier<ModelSelectorState>(
      ModelSelectorState(
        models: _models,
        isLoading: _models.isEmpty,
      ),
    );
    _modelSelectorNotifier = notifier;
    _modelLoadTimeout?.cancel();

    if (_models.isEmpty) {
      _wsService.sendGetModels();
      _modelLoadTimeout = Timer(const Duration(seconds: 5), () {
        if (_modelSelectorNotifier != notifier) return;
        if (notifier.value.models.isNotEmpty) return;
        notifier.value = const ModelSelectorState(
          models: [],
          isLoading: false,
          errorMessage: 'Impossible de charger les modèles',
        );
      });
    }

    try {
      final chosen = await showModelSelector(
        context: context,
        stateListenable: notifier,
        currentModel: _selectedModel,
      );
      if (chosen != null && chosen != _selectedModel) {
        setState(() => _selectedModel = chosen);
        await widget.storage.setSelectedModel(chosen);
        _wsService.sendSetModel(chosen);
      }
    } finally {
      _modelLoadTimeout?.cancel();
      _modelLoadTimeout = null;
      _modelSelectorNotifier = null;
      notifier.dispose();
    }
  }

  /// Full label of the active model for the input-bar pill. Falls back to
  /// the raw id until the server's models_list gives us a pretty label.
  String get _currentModelLabel {
    final id = _selectedModel;
    if (id == null || id.isEmpty) return 'Modèle';
    final found = _models.where((m) => m.id == id).toList();
    return found.isNotEmpty ? found.first.label : id;
  }

  @override
  void dispose() {
    _modelLoadTimeout?.cancel();
    _modelSelectorNotifier?.dispose();
    _msgSub?.cancel();
    _connSub?.cancel();
    _errSub?.cancel();
    _wsService.dispose();
    _audioService.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);

    if (!_initialized && _connState == ws.ConnectionState.disconnected) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: palette.background,
      drawer: _buildConversationsDrawer(palette),
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Conversations',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _activeConversationTitle?.isNotEmpty == true
                    ? _activeConversationTitle!
                    : 'OSIA',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConnectionBadge(state: _connState),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () async {
              await Navigator.of(context).pushNamed('/settings');
              _msgSub?.cancel();
              _connSub?.cancel();
              _errSub?.cancel();
              _wsService.dispose();
              setState(() {
                _initialized = false;
                _entries.clear();
                _thinking = false;
                _connError = null;
                _conversations = [];
                _activeConversationId = null;
                _activeConversationTitle = null;
                _streamingIndex = null;
              });
              _initConnection();
            },
            tooltip: 'Paramètres',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _entries.isEmpty && !_thinking
                    ? _buildEmptyState(palette)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
                        itemCount:
                            _entries.length + (_thinking ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_thinking && index == _entries.length) {
                            return const ThinkingIndicator();
                          }
                          final entry = _entries[index];
                          return ChatBubble(
                            // Stable key per slot so the bubble (and its
                            // blinking-cursor Timer) is preserved while
                            // the streaming text grows.
                            key: ValueKey('msg_$index'),
                            text: entry.content,
                            isUser: entry.isUser,
                            isTranscript: entry.isTranscript,
                            isStreaming: entry.isStreaming,
                            isSystem: entry.isSystem,
                          );
                        },
                      ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: (_connError != null &&
                      _connState != ws.ConnectionState.connected)
                  ? _buildErrorBanner(palette)
                  : const SizedBox.shrink(key: ValueKey('no-banner')),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 10,
            child: GlassInputBar(
              textController: _textCtrl,
              isRecording: _audioService.isRecording,
              hasText: _canSend,
              onSend: _sendText,
              onMicTap: _toggleRecording,
              onAttach: _onAttach,
              modelLabel: _currentModelLabel,
              onModelTap: _openModelSelector,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _sendText(),
              pendingFilename: _pendingFilename,
              onRemovePending: _clearPendingFile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(OsiaPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accent.withValues(alpha: 0.08),
              border: Border.all(
                  color: palette.accent.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 30,
              color: palette.accent.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dites bonjour à OSIA',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: palette.textPrimary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tapez un message ou utilisez le micro.',
            style: TextStyle(
              fontSize: 13,
              color: palette.textMuted.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsDrawer(OsiaPalette palette) {
    return Drawer(
      backgroundColor: palette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.surface.withValues(alpha: 0.95),
              palette.background,
            ],
          ),
          border: Border(
            right: BorderSide(
              color: palette.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.forum_rounded,
                        color: palette.accent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Conversations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _newConversation,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Nouveau chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: palette.isDark
                          ? palette.background
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                color: palette.border.withValues(alpha: 0.4),
                height: 1,
              ),
              Expanded(
                child: _conversations.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Aucune conversation pour le moment',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.textMuted.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final conv = _conversations[index];
                          return _buildConversationTile(conv, palette);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(ws.Conversation conv, OsiaPalette palette) {
    final isActive = conv.id == _activeConversationId;
    final dateLabel = _formatConversationDate(conv.date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Dismissible(
        key: ValueKey('conv_${conv.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          await _deleteConversation(conv);
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: palette.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.delete_outline_rounded,
              color: palette.error, size: 22),
        ),
        child: Material(
          color: isActive
              ? palette.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _loadConversation(conv),
            onLongPress: () => _deleteConversation(conv),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? palette.accent.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          conv.title.isEmpty ? 'Sans titre' : conv.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isActive
                                ? palette.accent
                                : palette.textPrimary
                                    .withValues(alpha: 0.92),
                          ),
                        ),
                        if (dateLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: palette.textMuted
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_rounded,
                        color: palette.accent, size: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(OsiaPalette palette) {
    return Container(
      key: const ValueKey('error-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(
            color: palette.error.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: palette.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _connError ?? '',
              style: TextStyle(
                color: palette.error,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _connError = null);
              _wsService.connect();
            },
            style: TextButton.styleFrom(
              foregroundColor: palette.error,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Réessayer',
                style:
                    TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// A single entry in the chat history.
class _ChatEntry {
  final String content;
  final bool isUser;
  final bool isTranscript;
  final bool isStreaming;
  final bool isSystem;

  const _ChatEntry({
    required this.content,
    required this.isUser,
    this.isTranscript = false,
    this.isStreaming = false,
    this.isSystem = false,
  });

  _ChatEntry copyWith({String? content, bool? isStreaming}) {
    return _ChatEntry(
      content: content ?? this.content,
      isUser: isUser,
      isTranscript: isTranscript,
      isStreaming: isStreaming ?? this.isStreaming,
      isSystem: isSystem,
    );
  }
}

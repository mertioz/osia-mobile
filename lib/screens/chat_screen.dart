import 'dart:async';

import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/connection_badge.dart';
import '../widgets/mic_button.dart';
import '../widgets/thinking_indicator.dart';

/// Main chat screen: conversation history, text input, mic button,
/// thinking indicator, and connection badge.
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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  Future<void> _initConnection() async {
    final ip = await widget.storage.getTailscaleIp();
    final token = await widget.storage.getToken();

    if (ip == null || token == null || ip.isEmpty || token.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/settings');
      }
      return;
    }

    _wsService = ws.WebSocketService(ip: ip, token: token);

    _connSub = _wsService.connectionStream.listen((state) {
      if (mounted) setState(() => _connState = state);
    });

    _msgSub = _wsService.messageStream.listen(_onMessage);

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
      case ws.ResponseMessage(:final content):
        _addEntry(_ChatEntry(content: content, isUser: false));
        setState(() => _thinking = false);
      case ws.AudioMessage(:final data):
        _audioService.playMp3(data);
      case ws.StatusMessage(:final content):
        if (content == 'thinking') {
          setState(() => _thinking = true);
        } else if (content == 'done') {
          setState(() => _thinking = false);
        } else if (content == 'error') {
          setState(() => _thinking = false);
        }
    }
  }

  void _addEntry(_ChatEntry entry) {
    setState(() => _entries.add(entry));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    _addEntry(_ChatEntry(content: text, isUser: true));
    _wsService.sendText(text);
    _textCtrl.clear();
  }

  Future<void> _toggleRecording() async {
    if (_audioService.isRecording) {
      // Stop recording and send
      final base64Wav = await _audioService.stopRecording();
      if (base64Wav != null && base64Wav.isNotEmpty) {
        _wsService.sendAudio(base64Wav);
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

  @override
  void dispose() {
    _msgSub?.cancel();
    _connSub?.cancel();
    _wsService.dispose();
    _audioService.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && _connState == ws.ConnectionState.disconnected) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: osiaAccent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_rounded, color: osiaAccent, size: 22),
            const SizedBox(width: 8),
            const Text('OSIA'),
            const SizedBox(width: 12),
            ConnectionBadge(state: _connState),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () async {
              await Navigator.of(context).pushNamed('/settings');
              // After returning from settings, reconnect with new values
              _msgSub?.cancel();
              _connSub?.cancel();
              _wsService.dispose();
              setState(() {
                _initialized = false;
                _entries.clear();
                _thinking = false;
              });
              _initConnection();
            },
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: osiaTextMuted.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Dites bonjour à OSIA',
                          style: TextStyle(
                            fontSize: 16,
                            color: osiaTextMuted.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return ChatBubble(
                        key:
                            ValueKey('msg_${index}_${entry.content.hashCode}'),
                        text: entry.content,
                        isUser: entry.isUser,
                        isTranscript: entry.isTranscript,
                      );
                    },
                  ),
          ),

          // Thinking indicator
          if (_thinking) const ThinkingIndicator(),

          // Bottom input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: osiaBackground,
        border: Border(
          top:
              BorderSide(color: osiaBorder.withValues(alpha: 0.5), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Mic button
            MicButton(
              isRecording: _audioService.isRecording,
              onTap: _toggleRecording,
            ),
            const SizedBox(width: 8),

            // Text input
            Expanded(
              child: TextField(
                controller: _textCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: const InputDecoration(
                  hintText: 'Écrivez votre message…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                style:
                    const TextStyle(color: osiaTextPrimary, fontSize: 15),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: _sendText,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _textCtrl.text.trim().isNotEmpty
                      ? osiaViolet
                      : osiaSurface,
                  border: Border.all(
                    color: _textCtrl.text.trim().isNotEmpty
                        ? osiaViolet
                        : osiaBorder,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.send_rounded,
                  size: 20,
                  color: _textCtrl.text.trim().isNotEmpty
                      ? Colors.white
                      : osiaTextMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single entry in the chat history.
class _ChatEntry {
  final String content;
  final bool isUser;
  final bool isTranscript;

  const _ChatEntry({
    required this.content,
    required this.isUser,
    this.isTranscript = false,
  });
}

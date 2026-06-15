import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n.dart';
import '../motion.dart';
import '../nav.dart';
import '../services/audio_service.dart';
import '../services/rendezvous_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/connection_badge.dart';
import '../widgets/glass_input_bar.dart';
import '../widgets/model_selector_sheet.dart';
import '../widgets/thinking_indicator.dart';
import 'autonomous_screen.dart';
import 'settings_screen.dart';

/// Main chat screen: conversation history, floating glass input,
/// thinking indicator, model selector and connection badge.
class ChatScreen extends StatefulWidget {
  final StorageService storage;
  final ThemeController themeController;
  final LanguageController languageController;

  /// A live, already-authenticated connection handed over by the connection
  /// screen on first launch. When present it is reused as-is instead of
  /// opening a new socket (see [_ChatScreenState._initConnection]). Null on
  /// app relaunch and Settings round-trips, which build a fresh connection.
  final ChatHandoff? handoff;

  const ChatScreen({
    super.key,
    required this.storage,
    required this.themeController,
    required this.languageController,
    this.handoff,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Services
  // Not `final`: the service is disposed and recreated on every Settings
  // round-trip (see _openSettings → _initConnection).
  late ws.WebSocketService _wsService;
  final AudioService _audioService = AudioService();

  // State
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  // The floating input bar is drawn in a Stack on top of the message list, so
  // the list reserves bottom padding equal to the bar's measured height to keep
  // the last message from hiding behind it. Remeasured each frame because the
  // bar grows with the attachment chip and multi-line text.
  final GlobalKey _inputBarKey = GlobalKey();
  double _inputBarHeight = 0;
  final List<_ChatEntry> _entries = [];
  bool _thinking = false;
  ws.ConnectionState _connState = ws.ConnectionState.disconnected;
  StreamSubscription? _msgSub;
  StreamSubscription? _convStreamSub;
  StreamSubscription? _connSub;
  StreamSubscription? _errSub;
  StreamSubscription? _newChatSub;
  StreamSubscription? _configSub;
  String? _connError;
  // Monotonic generation for the connection-banner AnimatedSwitcher keys.
  // Bumped on every connection-state change so the error banner / placeholder
  // get a fresh key on each (dis)appearance. During the offline reconnect loop
  // the banner can flip hidden→shown faster than the 280ms switch animation;
  // without a fresh key the reappearing banner collides with the still-
  // animating outgoing one inside the switcher's Stack ("Duplicate keys found
  // ... key [<'error-banner'>]"). A strictly-increasing suffix guarantees the
  // outgoing and incoming children can never share a key.
  int _bannerSeq = 0;
  bool _initialized = false;

  // Conversations
  List<ws.Conversation> _conversations = [];
  String? _activeConversationId;
  String? _activeConversationTitle;
  // The conversation whose history we've asked the server for and are still
  // waiting on (`load_conversation` sent, `conversation_history` not yet
  // received). Cleared when the history lands. Drives the load retry below and
  // the re-request after a (re)connect so an in-session switch reliably shows
  // its content without an app restart.
  String? _pendingConvLoadId;
  // Short safety-net timer: if a requested conversation's history never lands
  // (a dropped frame, or the request going out across a momentary socket blip)
  // we re-ask once instead of leaving the chat stuck empty.
  Timer? _convLoadRetry;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Models
  List<ws.OsiaModel> _models = [];
  String? _selectedModel;
  // Whether the PC's AI hierarchy is enabled. When true, the model selector
  // sheet notes that the chosen model is overridden by the configured chain.
  // Tracked via [configStream]; requested on connect.
  bool _aiHierarchyEnabled = false;
  // Active notifier for the open model-selector sheet, if any. Lets the
  // chat screen push state updates (models arriving, load timing out) into
  // a sheet that's already on screen.
  ValueNotifier<ModelSelectorState>? _modelSelectorNotifier;
  Timer? _modelLoadTimeout;

  // Index of the entry currently receiving streamed chunks (null when idle).
  int? _streamingIndex;

  // ── Feature 1: optimistic user message (in memory, mobile-only) ──────────
  // The user's just-sent message is shown instantly (via _addEntry) AND retained
  // here, keyed by conversation id, so any rebuild of _entries (a conversation
  // switch that hydrates from the buffer, a reconnect/sleep re-fetch, or a still
  // reply-less history) RE-INJECTS it — the question is NEVER missing above the
  // assistant reply. In memory only (zero disk): the server already persists the
  // user turn, so an app kill + re-fetch restores it. Dropped when an
  // authoritative history that already contains the user message reconciles it
  // (see [ConversationHistoryMessage]), and on new/delete/settings. Voice turns
  // store their STT transcript here when it arrives.
  final Map<String, String> _optimisticUser = {};
  // A turn sent on a brand-new conversation that has no id yet. Migrated into
  // [_optimisticUser] under the real id once the server assigns one (see the
  // ActiveConversationMessage handler).
  String? _optimisticUserNoId;

  // ── Feature 2: smooth typewriter reveal (display-rate layer) ─────────────
  // Chunk RECEPTION (the WOR-53 per-conv buffer, surfaced by _onConvStream) is
  // decoupled from DISPLAY: the full buffered text is snapshotted into
  // [_typeTarget] and a single timer reveals it toward the streaming bubble at a
  // constant readable pace, instead of dumping each burst on arrival. This is
  // purely a display-rate layer over the existing buffer — it never changes what
  // is stored, the done/persistence logic, or the buffer hydration. Honors
  // reduced motion (renders the full text immediately, no timer).
  static const Duration _typewriterTick = Duration(milliseconds: 16); // ~60fps
  // Single tunable: target reveal pace. ~200 chars/sec ≈ 5ms/char.
  static const int _typewriterCharsPerSecond = 200;
  // On a big burst, reveal at least this fraction of the backlog per tick so the
  // reveal speeds up gently and never lags far behind the buffer.
  static const double _typewriterCatchUpFactor = 0.08;
  Timer? _typewriterTimer;
  // Full text the typewriter is revealing into the active streaming bubble.
  String _typeTarget = '';
  // Characters of [_typeTarget] currently shown in the streaming bubble.
  int _typeRevealed = 0;

  // WOR-75/WOR-53/WOR-62 (recovery poll): when the displayed conversation has an
  // in-flight turn whose streamed chunks never reached us — the socket dropped
  // during sleep/network loss, so its per-conversation stream buffer is empty —
  // we can render neither a live partial nor an instant buffer hydration, and a
  // mid-turn load_conversation only returns end-of-turn persisted state (no
  // partial). This periodic poll re-fetches the displayed conversation's content
  // every few seconds until its persisted reply lands, then self-cancels. It is
  // gated to pending + EMPTY-buffer (see [_startRecoveryPoll]): while chunks are
  // flowing the buffer is non-empty so the poll is OFF — the live stream renders
  // instead — which keeps it silent during normal live streaming. It NEVER
  // switches the view: it only re-requests the displayed conversation's own
  // content, and the conversation_history handler's view-guard keeps the
  // displayed conversation changing on explicit user tap alone.
  Timer? _recoveryPoll;

  // Pending attachment shown as a chip in the input bar. Only sent when
  // the user taps the send arrow (or hits enter).
  String? _pendingFilename;
  Uint8List? _pendingFileBytes;
  bool _pendingIsImage = false;

  // True while we sent a turn and haven't yet seen status=done/error.
  bool _awaitingResponse = false;

  // ── Optimistic thinking + no-response watchdog ──────────────────────────
  // Standalone UI state (deliberately NOT a sealed [ws.OsiaMessage] subtype):
  // the thinking indicator is shown locally the instant the user taps send —
  // before any network round-trip — to mask first-token latency. A 12s timer
  // armed at send is cancelled at the FIRST SIGN OF LIFE from the server for
  // this turn — any turn-progress frame: a status (thinking / tool-status)
  // update, an audio frame, the voice transcript, or the first response_chunk
  // / full response, whichever lands first. It therefore only elapses on TOTAL
  // silence (server down, lost connection, request never received). On a long
  // multi-step task the server keeps emitting status/tool/audio frames well
  // before the final reply's first token, so the watchdog stands down and the
  // false error never shows. If it does elapse with no frame at all,
  // [_noResponse] flips and an inline "no response" + Réessayer tile replaces
  // the thinking dots.
  static const Duration _firstTokenTimeout = Duration(seconds: 12);
  Timer? _firstTokenTimer;
  // True once the watchdog fired with no first token — drives the retry tile.
  // Mutually exclusive with [_thinking] (arming the error clears thinking).
  bool _noResponse = false;
  // The last text turn we sent, captured so "Réessayer" re-sends it verbatim
  // (file + prompt) without the user retyping. Cleared on switch/new/reset.
  _PendingTurn? _pendingTurn;

  // Auto-TTS preference (Settings → Voice). When false, audio frames that
  // arrive with a response are not played automatically.
  bool _autoTts = true;
  // True right after the user taps the speaker button on a message, so the
  // resulting TTS audio plays even when auto-TTS is off. Reset on playback.
  bool _speakRequested = false;

  // The handed-over connection, consumed on the first _initConnection only —
  // Settings round-trips rebuild a fresh one.
  ChatHandoff? _pendingHandoff;

  @override
  void initState() {
    super.initState();
    _pendingHandoff = widget.handoff;
    _initConnection();
  }

  Future<void> _initConnection() async {
    final handoff = _pendingHandoff;
    _pendingHandoff = null;

    // Read persisted prefs defensively. A keystore change (app reinstall /
    // Android Keystore rotation) can leave secure-storage values
    // undecryptable, throwing a PlatformException. StorageService already
    // swallows those per key, but guard here too so a storage failure can
    // never block connection/chat init — fall back to sensible defaults.
    String? ip;
    String? token;
    try {
      ip = await widget.storage.getTailscaleIp();
      token = await widget.storage.getToken();
      _selectedModel = await widget.storage.getSelectedModel();
      // Re-read on every (re)connection so a toggle change in Settings is
      // picked up when the chat screen rebuilds its connection.
      _autoTts = await widget.storage.getAutoTts();
    } catch (e) {
      debugPrint(
          '[OSIA Chat] storage read failed during init: $e — using defaults');
      _autoTts = true;
    }

    // WOR-64: the server host is no longer persisted — it is resolved fresh
    // from the token on every connect. Only the token gates readiness, so a
    // user with a valid token is never wrongly bounced to /connection.
    if (token == null || token.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/connection');
      }
      return;
    }
    // token is non-null past the guard; capture it in a final so the resolver
    // closure below sees a non-nullable value (closures don't inherit flow
    // promotion of a non-final local).
    final authToken = token;

    // Reuse the validated, still-open socket the connection screen handed
    // over, rather than opening a second connection (the close+reopen race
    // left the chat stuck "Connecting"). Falls back to a fresh service for
    // app relaunch / Settings round-trips — which resolves the host from the
    // token just like the connection screen ([ip] kept only as a fallback).
    _wsService = handoff?.service ??
        ws.WebSocketService(
          ip: ip ?? StorageService.defaultHost,
          token: authToken,
          resolveHost: () => RendezvousService().resolveHost(authToken),
        );

    _connSub = _wsService.connectionStream.listen((state) {
      if (mounted) {
        setState(() {
          _connState = state;
          // Fresh banner-switcher key on every connection-state change so a
          // reappearing banner never collides with a still-animating one.
          _bannerSeq++;
          if (state == ws.ConnectionState.connected) {
            _connError = null;
            // Ask for available models once the socket is up.
            _wsService.sendGetModels();
            // Pull config too, so we know whether the AI hierarchy is on.
            _wsService.sendGetConfig();
            // Replay our remembered selection so the server is in sync.
            if (_selectedModel != null && _selectedModel!.isNotEmpty) {
              _wsService.sendSetModel(_selectedModel!);
            }
            // Re-fetch the open conversation's messages on every (re)connect.
            // The post-auth burst only carries the conversation LIST (never a
            // conversation's messages), and the server resets its
            // per-connection active conversation on each auth — so without this
            // a reopened socket would leave the chat showing an empty
            // conversation. Mirrors the models/config re-requests just above.
            final openConv = _pendingConvLoadId ?? _activeConversationId;
            if (openConv != null && openConv.isNotEmpty) {
              _requestConversationContent(openConv);
            }
            // WOR-75/WOR-53/WOR-62 (recovery poll): if the displayed
            // conversation has an in-flight turn we weren't watching live (the
            // socket dropped during sleep/network loss), its live stream on the
            // old socket is gone and the new socket won't resume it. Its stream
            // buffer is likely empty, so start the recovery poll: it re-fetches
            // the displayed conversation's content until the finished reply lands
            // (alongside the one-shot _requestConversationContent above), then
            // self-cancels. Non-destructive: any pre-disconnect content stays on
            // screen and reconciles when a complete history arrives. Never
            // switches the view (the conversation_history view-guard keeps the
            // displayed conversation changing on explicit user tap).
            final displayed = _activeConversationId;
            if (displayed != null &&
                displayed.isNotEmpty &&
                _wsService.isPending(displayed)) {
              _startRecoveryPoll();
              if (ws.kOsiaDebugPlaceholder) {
                debugPrint('[OSIA WOR-75] reconnect: displayed="$displayed" '
                    'isPending=true → recovery poll started');
              }
            } else if (ws.kOsiaDebugPlaceholder) {
              debugPrint('[OSIA WOR-75] reconnect: displayed='
                  '"${displayed ?? ""}" isPending='
                  '${displayed != null && _wsService.isPending(displayed)} '
                  '→ recovery poll NOT started');
            }
          }
        });
      }
    });

    _msgSub = _wsService.messageStream.listen(_onMessage);

    // WOR-53: per-conversation streamed-reply events (kept off the sealed
    // message switch). Renders the ACTIVE conversation's stream; events for
    // other conversations keep accumulating in the service buffer and hydrate
    // when the user switches to them.
    _convStreamSub = _wsService.convStreamStream.listen(_onConvStream);

    // AI-hierarchy state arrives on its own config channel (kept off the
    // sealed-message switch). Track it so the model selector can note when
    // the chosen model is overridden by the configured chain.
    _configSub = _wsService.configStream.listen((cfg) {
      if (mounted) {
        setState(() => _aiHierarchyEnabled = cfg.aiHierarchyEnabled);
      }
    });

    // WOR-10: the PC can push a "new_chat" signal on its own stream (kept off
    // the sealed-message switch). Mirror it by resetting the chat locally.
    _newChatSub = _wsService.newChatStream.listen((_) => _onNewChat());

    _errSub = _wsService.errorStream.listen((err) {
      if (mounted) {
        setState(() {
          _connError = err;
          // Same fresh-key guarantee as the connection-state listener: an error
          // can arrive without a coincident state change, so bump here too.
          _bannerSeq++;
        });
      }
    });

    final reusing =
        handoff != null && _wsService.state == ws.ConnectionState.connected;
    if (reusing) {
      // The socket is already open and authenticated, so the 'connected'
      // event (and the initial server frames) fired before we subscribed.
      // Replay the buffered frames the connection screen captured, then run
      // the post-connect side-effects the live listener would have run.
      final buffered = List<ws.OsiaMessage>.of(handoff.bufferedMessages);
      debugPrint('[OSIA Chat] Reusing live connection — replaying '
          '${buffered.length} buffered frame(s).');
      for (final msg in buffered) {
        _onMessage(msg);
      }
      _connState = ws.ConnectionState.connected;
      _connError = null;
      _wsService.sendGetModels();
      _wsService.sendGetConfig();
      if (_selectedModel != null && _selectedModel!.isNotEmpty) {
        _wsService.sendSetModel(_selectedModel!);
      }
    } else {
      // Fresh connection (relaunch, Settings round-trip, or a handed-over
      // socket that dropped during navigation).
      _wsService.connect();
    }

    setState(() => _initialized = true);
  }

  void _onMessage(ws.OsiaMessage msg) {
    switch (msg) {
      case ws.TranscriptMessage(:final content):
        // The STT transcript of the user's voice turn — proof the server
        // received the request and is working. Stand the watchdog down.
        _cancelFirstTokenTimer();
        if (content.isNotEmpty) {
          _addEntry(_ChatEntry(
              content: content, isUser: true, isTranscript: true));
          // Feature 1: retain the voice transcript (the user's "message" for a
          // voice turn) so a switch-back / reconnect re-fetch re-injects it
          // above the reply instead of dropping it.
          _recordOptimisticUser(content);
        }
      case ws.ResponseChunkMessage():
        // WOR-53: streamed chunks are now rendered by [_onConvStream] (routed
        // by conversation id) so a backgrounded conversation's reply keeps
        // streaming while the user views another. Kept present (no-op) so the
        // sealed switch stays exhaustive.
        break;
      case ws.ResponseMessage():
        // WOR-53: the assembled reply is rendered by [_onConvStream] (routed by
        // conversation id). Kept present (no-op) so the sealed switch stays
        // exhaustive.
        break;
      case ws.AudioMessage(:final data, :final source):
        // Read-aloud audio (speaker button): always play — the user
        // explicitly asked for it. Untagged frames (older server) fall
        // back to the _speakRequested flag.
        final isSpeakAudio =
            source == 'speak' || (source == null && _speakRequested);
        if (isSpeakAudio) {
          debugPrint(
              '[OSIA Chat] audio: source=$source → playing (read-aloud)');
          _speakRequested = false;
          _audioService.playMp3(data);
          break;
        }
        // Response audio (auto-TTS path): gated by the toggle.
        // The server is actively producing this turn's reply as audio — a
        // sign of life that stands the no-response watchdog down even when the
        // first text token is still pending (and whether or not auto-TTS plays
        // it below).
        _cancelFirstTokenTimer();
        debugPrint('[OSIA Chat] audio: autoTts=$_autoTts → '
            '${_autoTts ? "playing audio" : "dropped (auto-TTS off)"}');
        if (!_autoTts) break;
        _audioService.playMp3(data);
      case ws.StatusMessage(:final content):
        // ANY status frame — "thinking", a tool-execution/status update, or the
        // terminal "done"/"error" — proves the server is alive and working on
        // this turn, so it stands the no-response watchdog down. On a long
        // multi-step task these arrive well before the final reply's first
        // token; without this the 12s timer would trip a false error mid-task.
        _cancelFirstTokenTimer();
        // WOR-75: a `status` frame is conversation-agnostic (no conversation_id),
        // so it deliberately does NOT touch the recovery poll. That poll is gated
        // purely on the DISPLAYED conversation's own pending + empty-buffer state
        // (see [_startRecoveryPoll]) — never on broadcast status traffic — so one
        // conversation's status frames can't disturb another's recovery (the
        // WOR-53 concurrency guarantee).
        if (content == 'done' || content == 'error') {
          // The turn ended. WOR-53: finalizing the streaming bubble (clearing
          // `isStreaming` on its entry) is now handled by [_onConvStream],
          // routed by conversation id, so the right conversation's bubble is
          // closed out even when another conversation is on screen. Here we
          // only clear the conversation-agnostic thinking / awaiting flags.
          setState(() {
            _awaitingResponse = false;
            _thinking = false;
          });
        } else if (content == 'thinking') {
          // Server confirms it's working — clear any stale no-response tile.
          setState(() {
            _thinking = true;
            _noResponse = false;
          });
          _scrollToBottomAnimated();
        }
      case ws.ConversationsMessage(:final conversations):
        setState(() => _conversations = conversations);
      case ws.ActiveConversationMessage(:final id, :final title):
        // Defensive mirror of the conversation_history guard below: an inbound
        // active_conversation must never silently repoint the view off the
        // conversation the user is on. Adopt it only when nothing is displayed
        // yet (first launch, or a just-created new chat where
        // _activeConversationId was reset to null — preserving the
        // new-conversation creation UX), OR it matches the conversation the
        // user is viewing / just explicitly requested. Otherwise it is an
        // unsolicited server repoint, so ignore it: the displayed conversation
        // changes only on explicit user action, never in reaction to a frame.
        final viewingActive = _activeConversationId;
        if (viewingActive != null &&
            id != viewingActive &&
            id != _pendingConvLoadId) {
          return;
        }
        setState(() {
          _activeConversationId = id;
          _activeConversationTitle = title;
        });
        // Feature 1: a brand-new conversation just learned its id — migrate any
        // no-id optimistic user message under it so it is retained / reconciled
        // like any other (its first chunk also carries this id).
        final adoptedId = id;
        if (_optimisticUserNoId != null &&
            adoptedId != null &&
            adoptedId.isNotEmpty) {
          _optimisticUser[adoptedId] = _optimisticUserNoId!;
          _optimisticUserNoId = null;
        }
      case ws.ConversationHistoryMessage(:final id, :final messages):
        // Capture the in-flight requested-load id BEFORE anything clears it: a
        // late/deferred history frame for a DIFFERENT conversation must not
        // cancel a load the user is still waiting on (part of the WOR-53/WOR-75
        // root cause — a late history for A used to cancel a pending load of B).
        final pendingId = _pendingConvLoadId;
        final viewing = _activeConversationId;
        // The displayed conversation changes ONLY on explicit user action — an
        // inbound frame is a routing hint, never a switch command. Apply this
        // history to the view only when it is FOR the conversation the user is
        // viewing (the WOR-62 deferred-recovery / reconnect re-request
        // reconcile), the one they just explicitly requested via
        // _loadConversation, or — when nothing is displayed yet — first-launch
        // hydration (which overrides no user choice). An untagged (null/empty
        // id) frame can only be the reply to our own load_conversation, so it
        // too targets the current view and is allowed through.
        final hasId = id != null && id.isNotEmpty;
        final isForView = hasId && (id == viewing || id == pendingId);
        final nothingDisplayed = viewing == null && pendingId == null;
        if (hasId && !isForView && !nothingDisplayed) {
          // History for a conversation the user is NOT viewing (e.g. the
          // server's WOR-62 deferred push for the last-messaged conv). Do NOT
          // clear _entries or repoint _activeConversationId — that is exactly
          // the forced redirect (WOR-75) and the mid-generation bounce (the
          // WOR-53 regression) being fixed. The reply text is already kept live
          // in the service's per-conversation buffer (bufferedText/isStreaming,
          // fed by _onConvStream regardless of which conversation is on screen),
          // and tapping that conversation re-requests its persisted history via
          // _loadConversation — so its content is current when the user later
          // switches to it. Leave the pending load + retry untouched so a
          // still-pending load of a DIFFERENT conversation keeps waiting.
          return;
        }
        final effectiveConvId = hasId ? id : viewing;
        // Reply present == the history ENDS IN AN ASSISTANT message. Use the
        // exact 'assistant' role (not "anything but user"): a turn mid-tool-call
        // can end in a 'tool'/'system' entry while the real reply isn't persisted
        // yet, and that must be treated as reply-less so it does not pass the
        // no-blank guard below as if the finished reply had landed.
        final historyHasReply =
            messages.isNotEmpty && messages.last.role == 'assistant';
        // WOR-75 (no-blank): a STALE, reply-less history can still arrive for a
        // conversation whose reply we ALREADY hold in the stream buffer — e.g. a
        // retry-driven or in-flight load_conversation that the server answered
        // BEFORE the reply was persisted, or the recovery poll's re-fetch racing
        // persistence. Letting it reach the apply path below would clear _entries
        // AND drop the buffer and re-render WITHOUT the reply — blanking it with
        // no recovery (the poll is OFF once the buffer is non-empty). Guard: if
        // this history lacks the assistant reply but the service still holds this
        // conversation's reply in its buffer, the on-screen reply (and disk) are
        // already correct, so IGNORE the stale frame and keep the buffer-backed
        // view. Only fires when the buffer is non-empty — buffer-empty +
        // reply-less is the genuine empty/wake load and must pass through.
        if (!historyHasReply &&
            effectiveConvId != null &&
            effectiveConvId.isNotEmpty &&
            _wsService.bufferedText(effectiveConvId).isNotEmpty) {
          if (ws.kOsiaDebugPlaceholder) {
            debugPrint('[OSIA WOR-75] conversation_history for id="${id ?? ""}" '
                '(${messages.length} msgs) STALE reply-less while buffer holds '
                'the reply → IGNORE (keep on-screen reply, no blank)');
          }
          return;
        }
        // The content we were waiting on has arrived — stand down the retry.
        _convLoadRetry?.cancel();
        _pendingConvLoadId = null;
        // The view is being reset to this conversation's persisted state (also
        // reached via the reconnect re-request), so a first-token watchdog for
        // a possibly-lost in-flight turn must not linger.
        _cancelFirstTokenTimer();
        // Feature 2: this view is being rebuilt from persisted history — drop any
        // in-flight typewriter reveal so it can't keep writing into a stale slot.
        _stopTypewriter();
        if (ws.kOsiaDebugPlaceholder) {
          debugPrint('[OSIA WOR-75] conversation_history applied for '
              'id="${id ?? ""}" (${messages.length} msgs) → '
              'renders persisted history');
        }
        // Polish: capture whether this conversation's turn is still in flight
        // BEFORE the apply path below clears its pending flag, so a hydrated
        // pending conversation with no reply yet can re-show the thinking
        // indicator (applied at the end of this setState).
        final bool wasPending = effectiveConvId != null &&
            effectiveConvId.isNotEmpty &&
            _wsService.isPending(effectiveConvId);
        setState(() {
          _entries
            ..clear()
            ..addAll(messages.map((m) => _ChatEntry(
                  content: m.content,
                  isUser: m.role == 'user',
                )));
          _thinking = false;
          _noResponse = false;
          // Feature 2: persisted history is shown in full — reset the reveal
          // counters (a re-attached live bubble below sets them to fully shown).
          _typeTarget = '';
          _typeRevealed = 0;
          if (id != null && id.isNotEmpty) _activeConversationId = id;
          // Feature 1: reconcile the optimistic user message against the
          // authoritative history. If the history already contains this turn's
          // user message (turn persisted), drop the optimistic copy — the server
          // now owns it, so there is no duplicate bubble. If it does NOT yet
          // (in-flight: the reply, or nothing, was persisted before the user
          // turn surfaced here), re-inject it so the question is never missing
          // above the (recovered) reply. Persistence is detected by POSITION
          // (see below), not string match, so a file/image turn isn't duplicated.
          if (effectiveConvId != null && effectiveConvId.isNotEmpty) {
            final opt = _optimisticUser[effectiveConvId];
            if (opt != null) {
              // Detect a persisted user turn by POSITION, not by string match:
              // a user message that sits after the last completed assistant
              // reply IS this turn's question (whether or not its own reply is
              // persisted yet, e.g. a mid-tool-call history ending in tool/
              // system). Content matching would fail for a file/image turn,
              // whose optimistic copy carries a client-only "📎 filename"
              // prefix the server-persisted text never has — re-injecting then
              // would duplicate the bubble. historyHasReply is the done case.
              final lastUserIdx =
                  messages.lastIndexWhere((m) => m.role == 'user');
              final lastAssistantIdx =
                  messages.lastIndexWhere((m) => m.role == 'assistant');
              final userPersisted = historyHasReply ||
                  (lastUserIdx >= 0 && lastUserIdx > lastAssistantIdx);
              if (userPersisted) {
                _optimisticUser.remove(effectiveConvId);
              } else {
                _entries.add(_ChatEntry(content: opt, isUser: true));
              }
            }
          }
          // WOR-53: while a turn is in flight the persisted history doesn't yet
          // include its reply, so blindly reconciling would blank the in-flight
          // background reply we just returned to. Re-attach the live streaming
          // bubble from the service buffer when this conversation's turn is
          // still streaming. BUT the server persists the reply slightly BEFORE
          // it sends the terminal `done` (which is what flips isStreaming
          // false), so there is a window where the just-rebuilt persisted
          // history ALREADY ends with this reply while isStreaming is still
          // true. Guard against duplicating it: if the last persisted entry is
          // already this reply, reuse that entry as the streaming bubble
          // instead of appending a second one.
          final convId =
              (id != null && id.isNotEmpty) ? id : _activeConversationId;
          // WOR-75/WOR-53/WOR-62 (simplified): the persisted history is now the
          // single source of truth for this conversation's finished reply, so
          // drop its streamed-reply buffer (and clear any stuck pending /
          // streaming flag — e.g. a disconnect ate the terminal `done`). This
          // also makes the in-flight re-attach reconcile below a no-op: with no
          // buffer, [liveText] is empty and [streaming] is false, so we render
          // the recovered history cleanly instead of a stale partial bubble.
          if (convId != null) {
            _wsService.clearConvBuffer(convId);
            // WOR-75: clearConvBuffer no longer clears the pending flag, so do it
            // explicitly here — this recovered history IS the finished reply, so
            // the turn is over and no recovery poll should linger (e.g. a
            // disconnect ate the terminal `done`, or it was untagged).
            _wsService.clearPending(convId);
          }
          final liveText =
              convId != null ? _wsService.bufferedText(convId) : '';
          final streaming =
              convId != null && _wsService.isStreaming(convId);
          final lastIsThisReply = _entries.isNotEmpty &&
              !_entries.last.isUser &&
              _entries.last.content == liveText;
          if (streaming && liveText.isNotEmpty && !lastIsThisReply) {
            // In-flight reply not yet in persisted history — show it.
            _entries.add(_ChatEntry(
              content: liveText,
              isUser: false,
              isStreaming: true,
            ));
            _streamingIndex = _entries.length - 1;
            // Feature 2: already on screen in full — reveal continues from here.
            _typeTarget = liveText;
            _typeRevealed = liveText.length;
          } else if (streaming && lastIsThisReply) {
            // Reply already shown via persisted history but the turn hasn't
            // ended — mark that entry streaming so the terminal `done`
            // finalizes it (and any late `response` update lands on it),
            // without a duplicate bubble.
            _entries[_entries.length - 1] =
                _entries.last.copyWith(isStreaming: true);
            _streamingIndex = _entries.length - 1;
            _typeTarget = liveText;
            _typeRevealed = liveText.length;
          } else {
            _streamingIndex = null;
          }
          // Polish: a hydrated conversation whose turn is still pending but
          // whose reply hasn't started rendering — no live streaming bubble was
          // re-attached above AND the persisted history doesn't yet end with the
          // assistant reply — shows the SAME pre-stream thinking indicator as the
          // initial send (returning mid-think looks identical to just having
          // sent). Mid-stream (a streaming bubble) or finished (historyHasReply)
          // keeps it off, so there's never a double indicator or dots over a
          // reply. Dismissed by the first chunk / done like the live-send dots.
          if (wasPending && _streamingIndex == null && !historyHasReply) {
            _thinking = true;
          }
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

  /// Render the ACTIVE conversation's streamed reply (WOR-53). Events for other
  /// conversations are ignored here — their text keeps accumulating in the
  /// service buffer ([ws.WebSocketService.bufferedText] / [isStreaming]) and
  /// hydrates when the user switches to them. The service buffer is the single
  /// source of truth for the streamed text, so hydration on switch and live
  /// rendering never diverge and can't double-append. This performs the
  /// append/finalize the old `response_chunk` / `status`-done message cases did,
  /// now routed by conversation id.
  void _onConvStream(ws.ConvStreamEvent event) {
    if (!mounted) return;
    if (ws.kOsiaDebugPlaceholder && (event.done || event.error)) {
      debugPrint('[OSIA WOR-75] _onConvStream TERMINAL: convId='
          '"${event.conversationId}" done=${event.done} error=${event.error} '
          'untagged=${event.untagged} '
          'active="${_activeConversationId ?? ""}" '
          'forActive=${event.conversationId == _activeConversationId}');
    }
    // WOR-75: an UNTAGGED terminal (done/error with no conversation_id) applies
    // to the conversation on screen — the only turn we could be watching. Clear
    // that conversation's pending so an untagged terminal can't leave it stuck
    // true (and a recovery poll running on its empty buffer), then fall through
    // to finalize the active turn exactly as a tagged terminal for it would.
    // (Untagged events are only ever terminal, so the token-rendering path below
    // is never reached for one.)
    final bool untaggedTerminal = event.untagged && (event.done || event.error);
    if (untaggedTerminal) {
      final active = _activeConversationId;
      if (active != null && active.isNotEmpty) {
        _wsService.clearPending(active);
      }
    } else if (event.conversationId != _activeConversationId) {
      return;
    }

    // Any frame for the active turn is a sign of life — stand the no-response
    // watchdog down (moved here from the old streaming message cases).
    _cancelFirstTokenTimer();

    if (event.done || event.error) {
      // Terminal frame for the active conversation — finalize the streaming
      // bubble (the streaming-finalize the old StatusMessage done/error did).
      final hadBubble = _streamingIndex != null;
      // Feature 2: the turn ended — stop the reveal and FLUSH any buffered text
      // not yet shown so the finalized bubble is always complete (no missing
      // tail), regardless of how far the typewriter had got.
      _stopTypewriter();
      setState(() {
        _awaitingResponse = false;
        _thinking = false;
        final idx = _streamingIndex;
        if (idx != null) {
          final full =
              _typeTarget.isNotEmpty ? _typeTarget : _entries[idx].content;
          _entries[idx] =
              _entries[idx].copyWith(content: full, isStreaming: false);
          _streamingIndex = null;
        }
      });
      _typeTarget = '';
      _typeRevealed = 0;
      // WOR-75: a reply that produced NO streamed text — i.e. no live bubble and
      // an empty per-conversation buffer — leaves nothing on screen on `done`.
      // This is the Live API / voice-to-voice path (audio-only reply, no
      // response_chunk) and also the empty-buffer recovery case (sleep/wake: the
      // chunks were lost): in both the terminal lands here with _streamingIndex
      // null and would otherwise render nothing. Re-fetch so the persisted reply
      // is shown. Tightly guarded so a normal text turn (non-empty buffer or a
      // live bubble) never triggers a spurious reload. Uses the active id
      // (= event id for a tagged terminal; the only turn we watch for untagged).
      final displayed = _activeConversationId;
      if (event.done &&
          !hadBubble &&
          displayed != null &&
          displayed.isNotEmpty &&
          _wsService.bufferedText(displayed).isEmpty) {
        _requestConversationContent(displayed);
      }
      return;
    }

    // A token landed. The conversation's accumulated buffer text is the single
    // source of truth (so the live bubble always matches a hydration on switch).
    // Feature 2: instead of dumping the whole buffer on arrival, snapshot it into
    // [_typeTarget] and let the typewriter timer reveal it at a constant pace.
    final text = _wsService.bufferedText(event.conversationId);
    if (text.isEmpty) return;
    final bool reduced = Motion.reduced(context);
    setState(() {
      _thinking = false;
      _noResponse = false;
      final idx = _streamingIndex;
      if (idx != null) {
        // Existing streaming bubble — extend the reveal target. Under reduced
        // motion show it all at once; otherwise the timer below catches up.
        _typeTarget = text;
        if (reduced) {
          _typeRevealed = text.length;
          _entries[idx] = _entries[idx].copyWith(content: text);
        }
      } else if (_entries.isNotEmpty &&
          !_entries.last.isUser &&
          _entries.last.content == text) {
        // A history reload landed after the server persisted this reply, so
        // _entries already ends with it — reuse that entry rather than append
        // a duplicate streaming bubble (WOR-53). It is already shown in full.
        _entries[_entries.length - 1] =
            _entries.last.copyWith(isStreaming: true);
        _streamingIndex = _entries.length - 1;
        _typeTarget = text;
        _typeRevealed = text.length;
      } else {
        // New streaming bubble. Reduced motion shows the full text immediately;
        // otherwise it starts empty and the typewriter reveals toward the target.
        _entries.add(_ChatEntry(
          content: reduced ? text : '',
          isUser: false,
          isStreaming: true,
        ));
        _streamingIndex = _entries.length - 1;
        _typeTarget = text;
        _typeRevealed = reduced ? text.length : 0;
      }
    });
    if (reduced) {
      // Reduced motion: full text is already shown. Cancel any timer a prior
      // non-reduced token armed so a runtime toggle stops it immediately
      // (otherwise it self-cancels on its next tick a frame later).
      _stopTypewriter();
      _scrollToBottomAnimated();
    } else {
      // Drive the reveal off the timer (it self-pins the scroll while writing).
      _ensureTypewriter();
    }
  }

  /// Feature 2: start the typewriter reveal timer if there is buffered text not
  /// yet shown. Idempotent — a tick that catches up cancels the timer, and the
  /// next token re-arms it, so no timer runs while the reveal is idle. Callers
  /// gate on reduced motion (which shows the full text without a timer).
  void _ensureTypewriter() {
    if (_typewriterTimer != null) return;
    if (_typeRevealed >= _typeTarget.length) return;
    _typewriterTimer =
        Timer.periodic(_typewriterTick, (_) => _onTypewriterTick());
  }

  /// One reveal step: advance the shown prefix of [_typeTarget] toward the full
  /// buffered text at a constant readable pace (~[_typewriterCharsPerSecond]),
  /// accelerating gently when a big burst leaves us far behind so the reveal
  /// never lags. Self-cancels when caught up or the streaming bubble is gone.
  void _onTypewriterTick() {
    final idx = _streamingIndex;
    if (!mounted || idx == null || idx < 0 || idx >= _entries.length) {
      _stopTypewriter();
      return;
    }
    // Honor a runtime reduced-motion toggle: reveal the rest immediately.
    if (Motion.reduced(context)) {
      _typeRevealed = _typeTarget.length;
      setState(() {
        _entries[idx] = _entries[idx].copyWith(content: _typeTarget);
      });
      _stopTypewriter();
      return;
    }
    if (_typeRevealed >= _typeTarget.length) {
      _stopTypewriter(); // caught up — the next token re-arms the timer.
      return;
    }
    final remaining = _typeTarget.length - _typeRevealed;
    // Constant base pace, derived from the single tunable, plus gentle catch-up.
    final base =
        (_typewriterCharsPerSecond * _typewriterTick.inMilliseconds / 1000)
            .round();
    var step = base < 1 ? 1 : base;
    final catchUp = (remaining * _typewriterCatchUpFactor).ceil();
    if (catchUp > step) step = catchUp;
    if (step > remaining) step = remaining;
    _typeRevealed += step;
    final shown = _typeTarget.substring(0, _typeRevealed);
    setState(() {
      _entries[idx] = _entries[idx].copyWith(content: shown);
    });
    // Cheap auto-follow: keep pinned to the bottom only when already near it, so
    // a manual scroll-up to read history isn't yanked back down.
    if (_scrollCtrl.hasClients) {
      final pos = _scrollCtrl.position;
      if (pos.maxScrollExtent - pos.pixels < 120) {
        _scrollCtrl.jumpTo(pos.maxScrollExtent);
      }
    }
  }

  /// Stop the typewriter reveal timer. Idempotent.
  void _stopTypewriter() {
    _typewriterTimer?.cancel();
    _typewriterTimer = null;
  }

  /// Feature 1: record the user's just-sent message (or voice transcript) as the
  /// optimistic copy for the active conversation, keyed by id so a rebuild of
  /// _entries re-injects it until the server's history reconciles it. A brand-new
  /// conversation has no id yet — stash it under [_optimisticUserNoId] and the
  /// ActiveConversationMessage handler migrates it once the id is assigned.
  void _recordOptimisticUser(String content) {
    final convId = _activeConversationId;
    if (convId != null && convId.isNotEmpty) {
      _optimisticUser[convId] = content;
    } else {
      _optimisticUserNoId = content;
    }
  }

  void _loadConversation(ws.Conversation conv) {
    // WOR-53: free the buffer of the conversation we're leaving IF its turn has
    // finished — a still-streaming one is kept so it keeps accumulating in the
    // background and hydrates on return. This bounds the buffer map (the common
    // accumulation path) without breaking the concurrency guarantee.
    final leaving = _activeConversationId;
    // WOR-75: read the leaving conv's streaming state ONCE, before the clear
    // below can drop its buffer.
    final leavingStreaming =
        leaving != null && _wsService.isStreaming(leaving);
    if (leaving != null && leaving != conv.id && !leavingStreaming) {
      // WOR-75 FIX: drop ONLY the disposable stream buffer. clearConvBuffer no
      // longer touches the pending flag, so switching away KEEPS the leaving
      // conv's pending (its turn may still be in flight) — that flag is exactly
      // what drives the recovery poll (and buffer hydration) when the user
      // returns to it. Pending clears only when the turn actually ends (terminal
      // done/error) or its recovered reply arrives via history.
      _wsService.clearConvBuffer(leaving);
    }
    if (ws.kOsiaDebugPlaceholder) {
      final cleared =
          leaving != null && leaving != conv.id && !leavingStreaming;
      debugPrint('[OSIA WOR-75] _loadConversation: leaving="${leaving ?? ""}" '
          'leavingStreaming=$leavingStreaming isPending(leaving)='
          '${leaving != null && _wsService.isPending(leaving)} → '
          '${cleared ? "clearConvBuffer(leaving) — buffer dropped, PENDING KEPT" : "buffer/pending kept"}');
    }
    _requestConversationContent(conv.id);
    // The pending turn (and its watchdog) belonged to the conversation we're
    // leaving — drop them so a late timeout can't fire on the new chat.
    _cancelFirstTokenTimer();
    _pendingTurn = null;
    // Feature 2: a fresh view — stop any reveal aimed at the old streaming slot.
    _stopTypewriter();
    // Feature 1: a no-id optimistic stash belongs to a brand-new conversation
    // we may be leaving before its id was assigned. We can't safely re-key it to
    // an id once we've switched (an inbound active_conversation can't be told
    // apart from an unrelated repoint), so drop it here — the server's history
    // re-fetch restores the question on return. Prevents a stranded/leaked stash.
    _optimisticUserNoId = null;
    // WOR-75/WOR-53/WOR-62: is the conversation we're switching TO mid-turn? If
    // so and its stream buffer is empty (chunks were lost on a dropped socket),
    // the recovery poll below re-fetches its content until the persisted reply
    // lands. When the buffer DOES hold content (the WOR-53 background stream kept
    // accumulating) we hydrate from it immediately in the setState below.
    final pending = _wsService.isPending(conv.id);
    if (ws.kOsiaDebugPlaceholder) {
      debugPrint('[OSIA WOR-75] _loadConversation: target="${conv.id}" '
          'isPending(target)=$pending → recovery poll=$pending');
    }
    setState(() {
      _entries.clear();
      _thinking = false;
      _noResponse = false;
      _streamingIndex = null;
      // Feature 2: reset the reveal counters for the new view (the seed below
      // marks any hydrated text as fully shown so it isn't re-animated).
      _typeTarget = '';
      _typeRevealed = 0;
      _activeConversationId = conv.id;
      _activeConversationTitle = conv.title;
      // Feature 1: seed this conversation's optimistic user message (the
      // just-sent question) FIRST, so it sits above any assistant partial below
      // — returning to a backgrounded turn never shows the reply without the
      // question. Reconciled away when the server's history lands.
      final optUser = _optimisticUser[conv.id];
      if (optUser != null) {
        _entries.add(_ChatEntry(content: optUser, isUser: true));
      }
      // WOR-53/WOR-75: ALWAYS seed the view from this conversation's stream
      // buffer when it holds content — whether the turn is finished OR still in
      // flight (the WOR-53 background stream kept accumulating while we were
      // away). Returning to a conversation that generated in the background
      // therefore immediately shows its accumulated partial/full reply from the
      // buffer instead of a blank view; the
      // load_conversation→conversation_history round-trip reconciles to persisted
      // history right after, and live chunks (if the turn is still streaming)
      // keep updating the bubble via [_onConvStream]. An empty buffer (sleep/wake:
      // chunks were lost) leaves the view to the recovery poll below.
      final buffered = _wsService.bufferedText(conv.id);
      if (buffered.isNotEmpty) {
        final streaming = _wsService.isStreaming(conv.id);
        _entries.add(_ChatEntry(
          content: buffered,
          isUser: false,
          isStreaming: streaming,
        ));
        _streamingIndex = streaming ? _entries.length - 1 : null;
        // Feature 2: the buffered text is already complete on screen — mark it
        // fully revealed so the typewriter only animates NEW chunks from here.
        _typeTarget = buffered;
        _typeRevealed = buffered.length;
      }
      // Polish: returning to a pending conversation whose reply hasn't started
      // rendering yet (no chunks buffered, so no streaming bubble was seeded
      // above) shows the SAME pre-stream thinking indicator as the initial
      // send — user bubble + thinking dots, identical to having just sent the
      // message. When the buffer DID hold content a streaming bubble is on
      // screen instead, so this stays off and the reply (typewriter) renders,
      // not the dots. Dismissed by the first chunk / done exactly like the
      // live-send indicator (see [_onConvStream]).
      if (pending && buffered.isEmpty) {
        _thinking = true;
      }
    });
    // WOR-75/WOR-53/WOR-62 (recovery poll): switching INTO a pending conversation
    // — start the poll so an empty-buffer (sleep/wake) turn whose reply we can't
    // stream live is re-fetched until it lands (the poll self-cancels once the
    // buffer fills or the turn ends). Switching into a settled conversation drops
    // any poll left over from the one we just left.
    if (pending) {
      _startRecoveryPoll();
    } else {
      _stopRecoveryPoll();
    }
    Navigator.of(context).maybePop();
  }

  /// Ask the server for conversation [id]'s messages and remember it as the
  /// in-flight load. The reply ([ws.ConversationHistoryMessage]) clears the
  /// marker and the retry. Conversation content is ONLY ever delivered by this
  /// `load_conversation` → `conversation_history` round-trip — the post-auth
  /// burst carries just the conversation list — so if that single reply is lost
  /// (a dropped frame, or the request crossing a momentary socket blip) the
  /// chat would sit empty until an app restart. The retry re-asks once, and a
  /// (re)connect re-asks too (see the connection listener), so the switch shows
  /// its content reliably.
  void _requestConversationContent(String id) {
    if (id.isEmpty) return;
    _pendingConvLoadId = id;
    _wsService.sendLoadConversation(id);
    _convLoadRetry?.cancel();
    _convLoadRetry = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      // Only re-ask if we're still waiting on THIS conversation and the socket
      // is up (a down socket is handled by the re-request on reconnect).
      if (_pendingConvLoadId != id) return;
      if (_wsService.state != ws.ConnectionState.connected) return;
      debugPrint(
          '[OSIA Chat] no conversation_history for $id after 1.5s — re-requesting');
      _wsService.sendLoadConversation(id);
    });
  }

  /// Forget any in-flight conversation load (and its retry). Called whenever we
  /// move OFF a conversation we were loading — a new chat, or deleting the one
  /// being loaded — so a late retry can't repopulate the chat with stale
  /// history after the user navigated away.
  void _cancelPendingConvLoad() {
    _convLoadRetry?.cancel();
    _convLoadRetry = null;
    _pendingConvLoadId = null;
  }

  void _newConversation() {
    _wsService.sendNewConversation();
    _cancelPendingConvLoad();
    _cancelFirstTokenTimer();
    _stopRecoveryPoll();
    _stopTypewriter(); // Feature 2: no stale reveal into the cleared view.
    _pendingTurn = null;
    // WOR-53: drop the buffer of the conversation we're leaving so the buffer
    // map can't grow unbounded (the new conversation starts fresh; other
    // conversations' background streams are untouched).
    final leaving = _activeConversationId;
    if (leaving != null) {
      _wsService.clearConvBuffer(leaving);
      // WOR-75: starting a new chat abandons the leaving conv from this view;
      // clear its pending too (clearConvBuffer no longer does) so no stale
      // recovery poll lingers. If that conv keeps streaming tagged chunks in the
      // background, _appendConvDelta re-marks it pending.
      _wsService.clearPending(leaving);
    }
    // Feature 1: a brand-new chat — drop the leaving conv's optimistic copy
    // (its history owns the user message now) and any no-id stash.
    if (leaving != null) _optimisticUser.remove(leaving);
    _optimisticUserNoId = null;
    setState(() {
      _entries.clear();
      _thinking = false;
      _noResponse = false;
      _streamingIndex = null;
      _typeTarget = '';
      _typeRevealed = 0;
      _activeConversationId = null;
      _activeConversationTitle = null;
    });
    Navigator.of(context).maybePop();
  }

  /// Handle a `new_chat` push from the PC (WOR-10): reset the chat UI to a
  /// fresh conversation locally. Unlike [_newConversation], it does NOT echo a
  /// `new_conversation` back to the server (the PC already started the chat, so
  /// echoing risks a loop) and doesn't touch navigation. Mirrors the local
  /// clearing those methods perform.
  void _onNewChat() {
    if (!mounted) return;
    _cancelPendingConvLoad();
    _cancelFirstTokenTimer();
    _stopRecoveryPoll();
    _stopTypewriter(); // Feature 2: no stale reveal into the cleared view.
    _pendingTurn = null;
    // WOR-53: drop the buffer of the conversation we're leaving so the buffer
    // map can't grow unbounded (same hygiene as [_newConversation]).
    final leaving = _activeConversationId;
    if (leaving != null) {
      _wsService.clearConvBuffer(leaving);
      // WOR-75: clear its pending too (clearConvBuffer no longer does), same as
      // [_newConversation], so no stale recovery poll lingers for the reset chat.
      _wsService.clearPending(leaving);
    }
    // Feature 1: same optimistic hygiene as [_newConversation].
    if (leaving != null) _optimisticUser.remove(leaving);
    _optimisticUserNoId = null;
    setState(() {
      _entries.clear();
      _thinking = false;
      _noResponse = false;
      _streamingIndex = null;
      _typeTarget = '';
      _typeRevealed = 0;
      _activeConversationId = null;
      _activeConversationTitle = null;
    });
  }

  Future<void> _deleteConversation(ws.Conversation conv) async {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteConversationTitle),
        content: Text(
          strings.deleteConversationBody(conv.title),
          style: TextStyle(color: palette.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel,
                style: TextStyle(color: palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text(strings.delete, style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _wsService.sendDeleteConversation(conv.id);
    if (_pendingConvLoadId == conv.id) _cancelPendingConvLoad();
    // Feature 1: the conversation is gone — drop its optimistic user message.
    _optimisticUser.remove(conv.id);
    final deletingActive = _activeConversationId == conv.id;
    if (deletingActive) {
      // The emptied chat must not keep a recovery poll or a retry payload for a
      // turn that belonged to the now-deleted conversation.
      _cancelFirstTokenTimer();
      _stopRecoveryPoll();
      _stopTypewriter(); // Feature 2: no stale reveal into the emptied view.
      _pendingTurn = null;
    }
    setState(() {
      _conversations =
          _conversations.where((c) => c.id != conv.id).toList();
      if (deletingActive) {
        _entries.clear();
        _thinking = false;
        _noResponse = false;
        _streamingIndex = null;
        _typeTarget = '';
        _typeRevealed = 0;
        _activeConversationId = null;
        _activeConversationTitle = null;
      }
    });
  }

  /// Long-press action sheet for a conversation row (WOR-76): an on-brand
  /// bottom sheet offering Rename and Delete. Delete keeps its existing confirm
  /// dialog and full behaviour; Rename opens the pre-filled rename dialog. Swipe
  /// still deletes a row directly, so no delete path is lost.
  Future<void> _showConversationActions(ws.Conversation conv) async {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: palette.accent),
              title: Text(strings.rename,
                  style: TextStyle(color: palette.textPrimary)),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              leading:
                  Icon(Icons.delete_outline_rounded, color: palette.error),
              title:
                  Text(strings.delete, style: TextStyle(color: palette.error)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'rename') {
      await _renameConversation(conv);
    } else if (action == 'delete') {
      await _deleteConversation(conv);
    }
  }

  /// Rename dialog for a conversation (WOR-76). Pre-fills the current title,
  /// trims, rejects empty/whitespace (confirm stays disabled), caps length at 60
  /// (the server caps too), and on confirm sends `rename_conversation` via the
  /// WS service. The renamed title appears automatically when the server
  /// broadcasts the updated `conversations` list — handled by the existing
  /// [ws.ConversationsMessage] case — so there is no local list mutation here.
  Future<void> _renameConversation(ws.Conversation conv) async {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final controller = TextEditingController(text: conv.title);
    // Pre-select the existing title so the user can overwrite it in one stroke.
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    try {
      final newTitle = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.renameConversationTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: palette.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: strings.renameConversationHint,
              // Keep the dialog compact — no character counter.
              counterText: '',
            ),
            onSubmitted: (_) {
              final t = controller.text.trim();
              if (t.isNotEmpty) Navigator.of(ctx).pop(t);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(strings.cancel,
                  style: TextStyle(color: palette.textMuted)),
            ),
            // Confirm enables only when the trimmed title is non-empty.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) {
                final enabled = value.text.trim().isNotEmpty;
                return TextButton(
                  onPressed: enabled
                      ? () => Navigator.of(ctx).pop(controller.text.trim())
                      : null,
                  child: Text(
                    strings.rename,
                    style: TextStyle(
                      color: enabled
                          ? palette.accent
                          : palette.textMuted.withValues(alpha: 0.4),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
      if (newTitle == null) return;
      final trimmed = newTitle.trim();
      // Defence in depth + skip a no-op rename.
      if (trimmed.isEmpty || trimmed == conv.title) return;
      _wsService.sendRenameConversation(conv.id, trimmed);
      // The broadcast `conversations` frame refreshes the drawer list, but the
      // app-bar title reads [_activeConversationTitle], which that handler does
      // not touch. Keep the header consistent when renaming the conversation
      // currently on screen. Confined to this new feature path — the protected
      // ConversationsMessage handler stays untouched.
      if (mounted && conv.id == _activeConversationId) {
        setState(() => _activeConversationTitle = trimmed);
      }
    } finally {
      controller.dispose();
    }
  }

  String _formatConversationDate(DateTime? date, OsiaStrings strings) {
    if (date == null) return '';
    final now = DateTime.now();
    final local = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays == 0) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '${strings.today} $h:$m';
    }
    if (diffDays == 1) return strings.yesterday;
    if (diffDays < 7) return strings.daysAgo(diffDays);
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
    // Small settle delay so the freshly added entry is laid out before we
    // measure the new max extent.
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      // Reduced motion: jump straight to the bottom, no glide.
      if (Motion.reduced(context)) {
        _scrollCtrl.jumpTo(target);
      } else {
        _scrollCtrl.animateTo(
          target,
          duration: MotionDurations.route,
          curve: MotionCurves.enter,
        );
      }
    });
  }

  /// Measure the floating input bar so the message list can reserve exactly
  /// enough bottom padding to keep the last message clear of it. Called after
  /// every frame; only rebuilds when the height actually changes, so it
  /// converges instead of looping.
  void _measureInputBar() {
    if (!mounted) return;
    final box = _inputBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _inputBarHeight).abs() > 0.5) {
      setState(() => _inputBarHeight = h);
    }
  }

  bool get _canSend =>
      _textCtrl.text.trim().isNotEmpty || _pendingFileBytes != null;

  /// True when OSIA pauses to think *mid-stream*: the thinking flag is set
  /// while a streaming assistant bubble already holds some text. Mirrors the
  /// requested `_isThinking && _streamingMessage.isNotEmpty` — here the
  /// "streaming message" is the entry at [_streamingIndex]. Drives the inline
  /// [_MiniThinkingDots]; distinct from the full pre-stream [ThinkingIndicator].
  bool get _isThinkingMidStream {
    final idx = _streamingIndex;
    return _thinking &&
        idx != null &&
        idx >= 0 &&
        idx < _entries.length &&
        _entries[idx].content.isNotEmpty;
  }

  /// Whether the standalone pre-stream [ThinkingIndicator] occupies the
  /// trailing list slot: thinking, but not yet streaming (a mid-stream pause
  /// is shown inline on the bubble via [_MiniThinkingDots] instead). When this
  /// is false and [_noResponse] is true, that slot holds the retry tile
  /// instead — the two are mutually exclusive (arming the error clears
  /// [_thinking]).
  bool get _showThinkingTrailer => _thinking && !_isThinkingMidStream;

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

    final strings = OsiaL10n.of(context);
    final prompt = text.isNotEmpty
        ? text
        : (isImage
            ? strings.analyzeImagePrompt
            : strings.hereIsFile(filename ?? ''));
    _wsService.sendText(prompt);
    // WOR-75/WOR-53/WOR-62: mark this conversation's turn in flight at send
    // time (when its id is known) so switching away and straight back arms the
    // recovery poll (and, once chunks have accumulated, buffer hydration) even
    // before the first chunk arrives. A brand-new conversation has no id yet —
    // its first streamed chunk carries the id and marks it then.
    final sendingConv = _activeConversationId;
    if (ws.kOsiaDebugPlaceholder) {
      debugPrint('[OSIA WOR-75] _sendText: activeConversationId='
          '${sendingConv == null ? "null" : "id=$sendingConv"} → '
          '${(sendingConv != null && sendingConv.isNotEmpty) ? "markPending called" : "NO markPending (empty id)"}');
    }
    if (sendingConv != null && sendingConv.isNotEmpty) {
      _wsService.markPending(sendingConv);
    }
    // Feature 1: retain the just-sent message in memory (keyed by conv id, or
    // stashed until a brand-new conversation learns its id) so a switch-away /
    // disconnect re-fetch re-injects it above the reply — it's never missing.
    _recordOptimisticUser(displayContent);

    // Remember this exact turn so a no-response timeout can re-send it verbatim
    // without the user retyping (see [_retryLastTurn]).
    _pendingTurn = _PendingTurn(
      prompt: prompt,
      filename: hasFile ? filename : null,
      fileBytes: hasFile ? bytes : null,
      isImage: isImage,
    );

    _textCtrl.clear();
    setState(() {
      _pendingFilename = null;
      _pendingFileBytes = null;
      _pendingIsImage = false;
      _awaitingResponse = true;
      // Optimistic, local thinking indicator — shown immediately, before the
      // first token, to mask network + agent-construction latency.
      _thinking = true;
      _noResponse = false;
    });
    // WOR-75/WOR-53/WOR-62: the user is now engaged LIVE on this conversation, so
    // any recovery poll left over from a prior switch-back / wake stands down —
    // the live stream renders chunks as they arrive, and if the socket later
    // drops mid-turn the reconnect branch re-arms the poll. (Deliberately NOT
    // started here: while the buffer is still empty pre-first-token the poll
    // would spuriously re-fetch a reply-less history and clear the thinking
    // indicator / cancel the no-response watchdog mid-turn.)
    _stopRecoveryPoll();
    // Arm the 12s no-response watchdog (cancelled at the first sign of life
    // from the server for this turn — see [_onMessage]).
    _armFirstTokenTimer();
    // A new turn supersedes any stale read-aloud request — never let an
    // old speak tap unlock this turn's response audio.
    _speakRequested = false;
  }

  /// Arm (or re-arm) the no-response watchdog. Fires [_onFirstTokenTimeout]
  /// after [_firstTokenTimeout] unless cancelled by the first sign of life
  /// from the server for this turn (any turn-progress frame: a status
  /// thinking / tool-status update, an audio frame, the voice transcript, or
  /// the first response_chunk / full response — see [_onMessage]).
  void _armFirstTokenTimer() {
    _firstTokenTimer?.cancel();
    _firstTokenTimer = Timer(_firstTokenTimeout, _onFirstTokenTimeout);
  }

  /// Cancel the no-response watchdog. Idempotent — safe to call when no timer
  /// is armed. Invoked at the first sign of life from the server for the turn
  /// (any turn-progress frame: status thinking / tool-status, audio, voice
  /// transcript, response chunk / full response), on conversation switch / new
  /// chat, on history reload, and on dispose so a late timeout can never fire
  /// on a chat the turn no longer belongs to.
  void _cancelFirstTokenTimer() {
    _firstTokenTimer?.cancel();
    _firstTokenTimer = null;
  }

  /// WOR-75/WOR-53/WOR-62 recovery poll. Start (or restart) the periodic
  /// re-fetch of the DISPLAYED conversation's content. Each tick re-checks the
  /// gate and self-cancels the moment it no longer holds — the poll is active
  /// ONLY while a concrete conversation is displayed, its turn is still pending,
  /// and its stream buffer is EMPTY (chunks were lost, e.g. sleep/wake, so we
  /// cannot render the reply live and must re-fetch). The instant chunks flow the
  /// buffer is non-empty, so the poll stops itself and the live stream renders
  /// instead — it never runs during normal live streaming. It reads
  /// [_activeConversationId] inside the tick so a conversation switch is picked
  /// up, and only ever re-requests the displayed conversation's own content
  /// (never re-routes the view — the conversation_history view-guard owns that).
  void _startRecoveryPoll() {
    _recoveryPoll?.cancel();
    _recoveryPoll = Timer.periodic(const Duration(seconds: 3), (_) {
      final active = _activeConversationId;
      final shouldPoll = mounted &&
          active != null &&
          active.isNotEmpty &&
          _wsService.isPending(active) &&
          _wsService.bufferedText(active).isEmpty;
      if (!shouldPoll) {
        // Gate no longer holds (turn ended / buffer filled / switched away /
        // unmounted) — stop polling. No leaked timer.
        _recoveryPoll?.cancel();
        _recoveryPoll = null;
        return;
      }
      if (ws.kOsiaDebugPlaceholder) {
        debugPrint('[OSIA WOR-75] recovery poll: pending + empty buffer for '
            '"$active" → re-fetch conversation content');
      }
      // Reuse the existing load round-trip; the conversation_history handler
      // reconciles non-destructively (no-blank guard keeps a buffer-backed view,
      // and a complete post-done history renders the reply).
      _requestConversationContent(active);
    });
  }

  /// Stop the recovery poll. Idempotent.
  void _stopRecoveryPoll() {
    _recoveryPoll?.cancel();
    _recoveryPoll = null;
  }

  /// The watchdog elapsed with TOTAL silence from the server — not a single
  /// turn-progress frame (status / tool-status / audio / transcript / response)
  /// arrived in [_firstTokenTimeout]. Replace the thinking dots with the inline
  /// "no response" + Réessayer tile — but only if the turn is still genuinely
  /// waiting over a healthy socket. A dropped connection is left to the
  /// connection banner (don't show a misleading "no response" error when it's
  /// actually a disconnect).
  void _onFirstTokenTimeout() {
    _firstTokenTimer = null;
    if (!mounted) return;
    // Resolved already: turn done, streaming started, or the user moved off it.
    if (!_awaitingResponse) return;
    if (_streamingIndex != null) return;
    // Connection-state handling takes precedence over the no-response error.
    if (_wsService.state != ws.ConnectionState.connected) {
      setState(() => _thinking = false);
      return;
    }
    setState(() {
      _thinking = false;
      _noResponse = true;
    });
    _scrollToBottomAnimated();
  }

  /// Re-send the last turn verbatim after a no-response timeout (the
  /// "Réessayer" button). The user's original message bubble stays — we only
  /// replay the wire payload (file first, then prompt), then re-show thinking
  /// and re-arm the watchdog. Mirrors [_sendText]'s send sequence.
  void _retryLastTurn() {
    final turn = _pendingTurn;
    if (turn == null) return;
    if (turn.hasFile) {
      _wsService.sendFile(
        turn.filename!,
        base64Encode(turn.fileBytes!),
        isImage: turn.isImage,
      );
    }
    _wsService.sendText(turn.prompt);
    // WOR-75/WOR-53/WOR-62: re-mark the displayed conversation's turn in flight
    // (see [_sendText]) so a switch-away-and-back arms the recovery poll / buffer
    // hydration.
    final retryConv = _activeConversationId;
    if (retryConv != null && retryConv.isNotEmpty) {
      _wsService.markPending(retryConv);
    }
    setState(() {
      _awaitingResponse = true;
      _thinking = true;
      _noResponse = false;
    });
    // WOR-75/WOR-53/WOR-62: user engaged LIVE on this conversation — stand any
    // recovery poll down (the live stream renders chunks; a later mid-turn
    // disconnect re-arms it via the reconnect branch). Deliberately NOT started
    // here, so the no-response watchdog below stays the sole send-path safety net.
    _stopRecoveryPoll();
    _speakRequested = false;
    _armFirstTokenTimer();
    _scrollToBottomAnimated();
  }

  void _clearPendingFile() {
    setState(() {
      _pendingFilename = null;
      _pendingFileBytes = null;
      _pendingIsImage = false;
    });
  }

  /// Ask the server to read one assistant message aloud (speaker button on
  /// the bubble). The server synthesizes TTS and sends the audio back to
  /// the phone. Always allowed, regardless of the auto-TTS preference.
  void _speakMessage(String content) {
    if (content.isEmpty) return;
    final connState = _wsService.state;
    debugPrint('[OSIA Chat] read-aloud tapped: connState=$connState, '
        '${content.length} chars');
    if (connState != ws.ConnectionState.connected) {
      // Surface why nothing will happen instead of failing silently.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(OsiaL10n.of(context).disconnected)),
      );
      return;
    }
    _speakRequested = true;
    _wsService.sendSpeak(content);
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
        // WOR-75/WOR-53/WOR-62: mark the displayed conversation's turn in flight
        // (see [_sendText]).
        final voiceConv = _activeConversationId;
        if (voiceConv != null && voiceConv.isNotEmpty) {
          _wsService.markPending(voiceConv);
        }
        // WOR-75/WOR-53/WOR-62: user engaged LIVE — stand any recovery poll down
        // (the live stream renders chunks; a later mid-turn disconnect re-arms it
        // via the reconnect branch). Deliberately NOT started here.
        _stopRecoveryPoll();
        // Same as _sendText: a new turn invalidates stale speak requests.
        _speakRequested = false;
      }
      setState(() {});
    } else {
      try {
        await _audioService.startRecording();
        setState(() {});
      } catch (e) {
        if (mounted) {
          final strings = OsiaL10n.of(context);
          final msg = _audioService.isPermissionPermanentlyDenied
              ? strings.micPermissionDenied
              : strings.micUnavailable;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              action: _audioService.isPermissionPermanentlyDenied
                  ? SnackBarAction(
                      label: strings.openSettingsAction,
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
          SnackBar(content: Text(OsiaL10n.of(context).filePickFailed('$e'))),
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
            SnackBar(
                content: Text(OsiaL10n.of(context).fileReadFailed('$e'))),
          );
        }
        return;
      }
    }
    if (bytes == null || bytes.isEmpty) {
      debugPrint('[OSIA Attach] empty / null bytes after load');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(OsiaL10n.of(context).fileEmpty)),
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
      final strings = OsiaL10n.of(context);
      _wsService.sendGetModels();
      _modelLoadTimeout = Timer(const Duration(seconds: 5), () {
        if (_modelSelectorNotifier != notifier) return;
        if (notifier.value.models.isNotEmpty) return;
        notifier.value = ModelSelectorState(
          models: const [],
          isLoading: false,
          errorMessage: strings.modelsLoadFailed,
        );
      });
    }

    try {
      final chosen = await showModelSelector(
        context: context,
        stateListenable: notifier,
        currentModel: _selectedModel,
        hierarchyActive: _aiHierarchyEnabled,
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

  /// Settings is pushed directly (not via a named route) so it can borrow
  /// the live WebSocket service for the "restart server" action. When it
  /// pops, the connection is rebuilt from scratch in case anything changed.
  Future<void> _openSettings() async {
    await Navigator.of(context).push(slideFadeRoute(
      SettingsScreen(
        storage: widget.storage,
        themeController: widget.themeController,
        languageController: widget.languageController,
        wsService: _wsService,
      ),
    ));
    // If settings disconnected us, this whole screen was removed from the
    // navigator — don't touch state in that case.
    if (!mounted) return;
    _msgSub?.cancel();
    _convStreamSub?.cancel();
    _connSub?.cancel();
    _errSub?.cancel();
    _newChatSub?.cancel();
    _configSub?.cancel();
    _cancelPendingConvLoad();
    _cancelFirstTokenTimer();
    _stopRecoveryPoll();
    _stopTypewriter(); // Feature 2: the connection is being rebuilt.
    _pendingTurn = null;
    // Feature 1: the service (and its buffers) is rebuilt below — drop the
    // in-memory optimistic copies; the re-fetched history restores everything.
    _optimisticUser.clear();
    _optimisticUserNoId = null;
    _wsService.dispose();
    setState(() {
      _initialized = false;
      _entries.clear();
      _thinking = false;
      _noResponse = false;
      _connError = null;
      _conversations = [];
      _activeConversationId = null;
      _activeConversationTitle = null;
      _streamingIndex = null;
      _typeTarget = '';
      _typeRevealed = 0;
    });
    _initConnection();
  }

  /// Full label of the active model for the input-bar pill. Falls back to
  /// the raw id until the server's models_list gives us a pretty label.
  String _currentModelLabel(OsiaStrings strings) {
    final id = _selectedModel;
    if (id == null || id.isEmpty) return strings.model;
    final found = _models.where((m) => m.id == id).toList();
    return found.isNotEmpty ? found.first.label : id;
  }

  @override
  void dispose() {
    _modelLoadTimeout?.cancel();
    _convLoadRetry?.cancel();
    _firstTokenTimer?.cancel();
    _recoveryPoll?.cancel();
    _typewriterTimer?.cancel(); // Feature 2: no leaked reveal timer.
    _modelSelectorNotifier?.dispose();
    _msgSub?.cancel();
    _convStreamSub?.cancel();
    _connSub?.cancel();
    _errSub?.cancel();
    _newChatSub?.cancel();
    _configSub?.cancel();
    _wsService.dispose();
    _audioService.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    if (!_initialized && _connState == ws.ConnectionState.disconnected) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
      );
    }

    // Reserve space at the bottom of the message list for the floating input
    // bar so the last message is never hidden behind it. `padding.bottom`
    // matches the bar's own bottom offset so the reservation tracks the
    // safe-area inset and the keyboard; `_inputBarHeight` is the bar's measured
    // height (falls back to an approximate single-line height until the first
    // measurement lands), plus a small gap above the bar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureInputBar());
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    final double inputBarReserve = _inputBarHeight > 0 ? _inputBarHeight : 112;
    final double listBottomPadding = bottomSafe + 10 + inputBarReserve + 16;

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
          tooltip: strings.conversations,
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
            icon: const Icon(Icons.all_inclusive_rounded),
            onPressed: () => Navigator.of(context).push(
              slideFadeRoute(AutonomousScreen(wsService: _wsService)),
            ),
            tooltip: strings.autonomousTitle,
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openSettings,
            tooltip: strings.settingsTooltip,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _entries.isEmpty && !_thinking && !_noResponse
                    ? _buildEmptyState(palette, strings)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        // Rubber-band overscroll on both iOS and Android;
                        // AlwaysScrollable so even a short history can bounce.
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        // Dynamic bottom inset so the last message clears the
                        // floating input bar (which grows with attachments /
                        // multi-line text) on every device.
                        padding:
                            EdgeInsets.fromLTRB(0, 12, 0, listBottomPadding),
                        itemCount: _entries.length +
                            ((_showThinkingTrailer || _noResponse) ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Trailing slot: the pre-stream thinking indicator,
                          // or — after a 12s no-first-token timeout — the
                          // inline "no response" + Réessayer tile. The two are
                          // mutually exclusive (arming the error clears
                          // _thinking). Once a streaming bubble exists, a
                          // mid-stream pause is shown inline via
                          // [_MiniThinkingDots] on that bubble instead, so the
                          // standalone indicator is skipped to avoid two.
                          if (index == _entries.length) {
                            return _showThinkingTrailer
                                ? const ThinkingIndicator()
                                : _buildNoResponseTile(palette, strings);
                          }
                          final entry = _entries[index];
                          final isAssistant =
                              !entry.isUser && !entry.isSystem;
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
                            // Mid-stream pause: tiny dots inline at the end of
                            // the streaming text (separate from the full
                            // ThinkingIndicator). Only on the streaming bubble.
                            inlineTrailing:
                                entry.isStreaming && _isThinkingMidStream
                                    ? const _MiniThinkingDots()
                                    : null,
                            onSpeak: isAssistant
                                ? () => _speakMessage(entry.content)
                                : null,
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
              duration: Motion.duration(context, MotionDurations.medium),
              switchInCurve: MotionCurves.enter,
              switchOutCurve: MotionCurves.exit,
              // NB: the `_bannerSeq` unique keys below (WOR-64 fix) are kept
              // intact — only the duration/curve are tokenized here.
              child: (_connError != null &&
                      _connState != ws.ConnectionState.connected)
                  ? _buildErrorBanner(palette, strings)
                  : SizedBox.shrink(key: ValueKey('no-banner-$_bannerSeq')),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 10,
            child: GlassInputBar(
              key: _inputBarKey,
              textController: _textCtrl,
              isRecording: _audioService.isRecording,
              hasText: _canSend,
              onSend: _sendText,
              onMicTap: _toggleRecording,
              onAttach: _onAttach,
              modelLabel: _currentModelLabel(strings),
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

  Widget _buildEmptyState(OsiaPalette palette, OsiaStrings strings) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // OSIA logo, shown directly — no disc, no glow. Centred square asset.
          SizedBox(
            width: 64,
            height: 64,
            child: Image.asset(
              'assets/osia_logo_mark.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strings.sayHello,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: palette.textPrimary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.typeMessageOrMic,
            style: TextStyle(
              fontSize: 13,
              color: palette.textMuted.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// Inline thread tile shown in the trailing slot when a sent turn produced
  /// no first token within [_firstTokenTimeout]. Replaces the thinking dots
  /// and offers a "Réessayer" button that re-sends the same message via
  /// [_retryLastTurn] (the user's original bubble stays). Styled to match the
  /// connection error banner's error palette.
  Widget _buildNoResponseTile(OsiaPalette palette, OsiaStrings strings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.error.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: palette.error, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  strings.noResponseError,
                  style: TextStyle(
                    color: palette.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: _retryLastTurn,
                style: TextButton.styleFrom(
                  foregroundColor: palette.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  strings.retry,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsDrawer(OsiaPalette palette) {
    final strings = OsiaL10n.of(context);
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
                      strings.conversations,
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
                  child: PressableScale(
                    child: ElevatedButton.icon(
                      onPressed: _newConversation,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(strings.newChat),
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
                            strings.noConversationsYet,
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
                          // Subtle staggered cascade as the drawer opens. Key
                          // by conversation id so entrance state follows the
                          // conversation (a freshly inserted one animates;
                          // shifted ones stay settled).
                          return StaggeredAppear(
                            key: ValueKey('stagger_${conv.id}'),
                            index: index,
                            child: _buildConversationTile(conv, palette),
                          );
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
    final strings = OsiaL10n.of(context);
    final isActive = conv.id == _activeConversationId;
    final dateLabel = _formatConversationDate(conv.date, strings);

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
          // Material implicitly animates its color, so the active background
          // tint fades in/out instead of snapping when the selection changes.
          animationDuration: MotionDurations.medium,
          color: isActive
              ? palette.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _loadConversation(conv),
            onLongPress: () => _showConversationActions(conv),
            child: AnimatedContainer(
              duration: MotionDurations.medium,
              curve: MotionCurves.enter,
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
                          conv.title.isEmpty ? strings.untitled : conv.title,
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

  Widget _buildErrorBanner(OsiaPalette palette, OsiaStrings strings) {
    return Container(
      key: ValueKey('error-banner-$_bannerSeq'),
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
            child: Text(strings.retry,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
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

/// The exact wire payload of the last text turn, captured at send so the
/// no-response "Réessayer" button can re-send it verbatim — file (if any) plus
/// prompt — without the user retyping. See [_ChatScreenState._retryLastTurn].
class _PendingTurn {
  final String prompt;
  final String? filename;
  final Uint8List? fileBytes;
  final bool isImage;

  const _PendingTurn({
    required this.prompt,
    this.filename,
    this.fileBytes,
    this.isImage = false,
  });

  bool get hasFile => filename != null && fileBytes != null;
}

/// Carries a live, already-authenticated [ws.WebSocketService] from the
/// connection screen to the chat screen, together with the server frames the
/// connection screen buffered during token validation (the initial
/// conversations / active conversation / history / models burst). Reusing the
/// validated socket — instead of closing it and opening a new one — avoids the
/// race that previously left the chat screen stuck "Connecting"; replaying the
/// buffered frames means the chat screen doesn't miss the data it subscribed
/// too late to receive live.
class ChatHandoff {
  final ws.WebSocketService service;
  final List<ws.OsiaMessage> bufferedMessages;
  const ChatHandoff({required this.service, required this.bufferedMessages});
}

/// Tiny three-dot indicator appended inline at the end of a streaming bubble
/// when OSIA pauses to think mid-stream (see
/// [_ChatScreenState._isThinkingMidStream]). Each dot is a 6px violet circle
/// that fades and scales on a staggered loop. Deliberately distinct from the
/// full [ThinkingIndicator] shown before streaming begins.
class _MiniThinkingDots extends StatefulWidget {
  const _MiniThinkingDots();

  @override
  State<_MiniThinkingDots> createState() => _MiniThinkingDotsState();
}

class _MiniThinkingDotsState extends State<_MiniThinkingDots>
    with SingleTickerProviderStateMixin {
  /// OSIA's voice violet — fixed, independent of the active theme.
  static const Color _violet = Color(0xFFC4B5F5);
  static const double _dotSize = 6;
  static const double _gap = 3;
  static const int _dotCount = 3;

  late final AnimationController _ctrl;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionDurations.pulse,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-sync on every dependency change so a runtime reduced-motion toggle is
    // honored: stop the ticker (and show steady dots) when reduced, otherwise
    // keep the soft pulse looping.
    _reduced = Motion.reduced(context);
    if (_reduced) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Build the three-dot row given an easing value per dot index (0 → 1).
  Widget _dots(double Function(int index) easedFor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_dotCount, (i) {
        final eased = easedFor(i);
        final opacity = 0.3 + 0.7 * eased;
        final scale = 0.6 + 0.4 * eased;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : _gap),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: _dotSize,
                height: _dotSize,
                decoration: const BoxDecoration(
                  color: _violet,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Small gap so the dots don't crowd the blinking cursor / last glyph.
      padding: const EdgeInsets.only(left: 4),
      child: _reduced
          // Static, fully-shown dots — no continuous loop under reduced motion.
          ? _dots((_) => 1.0)
          : AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => _dots((i) {
                // Each dot is offset along the loop so they pulse in sequence.
                // Dart's `%` keeps a positive result here, so the negative
                // stagger wraps cleanly into [0, 1).
                final phase = (_ctrl.value - i * 0.18) % 1.0;
                // Triangle wave 0 → 1 → 0 over the loop, eased for a soft pulse.
                final tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
                return MotionCurves.loop
                    .transform(tri.clamp(0.0, 1.0).toDouble());
              }),
            ),
    );
  }
}

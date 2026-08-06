import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n.dart';
import '../motion.dart';
import '../services/attachment_service.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';
import '../widgets/model_selector_sheet.dart';
import '../widgets/thinking_indicator.dart';

/// Autonomous runs — the mobile mirror of the PC's dedicated "autonomous"
/// section (WOR-45 Phase 5).
///
/// Enter an objective, pick a CONFIGURED-only model, Start, then watch live
/// progress (phase name, X / Y tasks, a status line) pushed by the PC on
/// `autonomous_progress` frames. Interrupt pauses the run (resumable); Abandon
/// stops it entirely.
///
/// All traffic rides the existing WebSocket service additively:
///   - outbound: `autonomous_start` / `autonomous_interrupt` /
///     `autonomous_abort` / `get_autonomous_status`;
///   - inbound: `autonomous_progress` on [ws.WebSocketService.autonomousStream].
///
/// The model list and "configured" rule reuse the same data as the rest of the
/// app — the PC-authoritative configured catalogue delivered by `get_models`
/// (`models_list` on the shared message stream). Mobile never invents provider
/// availability from a static list or credential metadata.
class AutonomousScreen extends StatefulWidget {
  /// Live connection to the OSIA server, owned by the chat screen and threaded
  /// down so this screen can drive autonomous runs.
  final ws.WebSocketService wsService;

  const AutonomousScreen({super.key, required this.wsService});

  @override
  State<AutonomousScreen> createState() => _AutonomousScreenState();
}

/// Lifecycle of an autonomous run, derived from the latest `event` marker.
enum _RunPhase {
  idle,
  planning,
  authorizationPending,
  running,
  actionStarting,
  actionInProgress,
  waitingTool,
  verifyingTool,
  resuming,
  cancellationRequested,
  blockedUnknownEffect,
  cancelledProven,
  scopeExtension,
  revoked,
  outcomeUnknown,
  paused,
  done,
  failed,
  aborted,
}

const Set<String> _explicitDurableRunEvents = <String>{
  'action_starting',
  'action_in_progress',
  'waiting_tool',
  'verifying_tool',
  'resuming',
  'cancellation_requested',
  'blocked_unknown_effect',
  'cancelled_proven',
};

String _canonicalRunLifecycle(ws.AutonomousProgressMessage message) {
  final event = (message.event ?? '').toLowerCase();
  if (message.terminal == true &&
      const <String>{
        'done',
        'failed',
        'plan_failed',
        'aborted',
        'cancelled',
      }.contains(event)) {
    return event;
  }
  final durableState = (message.durableState ?? '').toLowerCase();
  if (_explicitDurableRunEvents.contains(durableState)) {
    return durableState;
  }
  if (const {'paused', 'interrupt', 'interrupted'}.contains(event) ||
      _explicitDurableRunEvents.contains(event)) {
    return event;
  }
  return (message.runState ?? event).toLowerCase();
}

@visibleForTesting
String autonomousRunLifecycleForTest(ws.AutonomousProgressMessage message) =>
    _canonicalRunLifecycle(message);

@visibleForTesting
String autonomousDurableStateLabel(OsiaStrings strings, String state) {
  if (strings.languageCode == 'fr') {
    return switch (state) {
      'action_starting' => 'Démarrage de l’action…',
      'action_in_progress' => 'Action en cours…',
      'waiting_tool' => 'En attente de vérification du résultat…',
      'verifying_tool' => 'Vérification du résultat…',
      'resuming' => 'Reprise de la mission…',
      'cancellation_requested' =>
        'Annulation demandée — vérification du résultat…',
      'blocked_unknown_effect' =>
        'Résultat impossible à établir — mission bloquée, sans répétition de l’action.',
      'cancelled_proven' => 'Action annulée avant tout effet confirmé.',
      _ => strings.autonomousRunning,
    };
  }
  return switch (state) {
    'action_starting' => 'Starting the action…',
    'action_in_progress' => 'Action in progress…',
    'waiting_tool' => 'Waiting to verify the result…',
    'verifying_tool' => 'Verifying the result…',
    'resuming' => 'Resuming the mission…',
    'cancellation_requested' => 'Cancellation requested — checking the result…',
    'blocked_unknown_effect' =>
      'The result could not be established — mission blocked without repeating the action.',
    'cancelled_proven' =>
      'The action was cancelled before any effect was confirmed.',
    _ => strings.autonomousRunning,
  };
}

@visibleForTesting
bool shouldShowAutonomousBrowserProgress(ws.BrowserProgressMessage? progress) {
  return progress != null && progress.phase != 'snapshot';
}

@visibleForTesting
bool sameAutonomousModelIdentity(ws.OsiaModel? left, ws.OsiaModel? right) {
  if (left == null || right == null) return left == right;
  return (left.provider ?? '').trim().toLowerCase() ==
          (right.provider ?? '').trim().toLowerCase() &&
      left.id.trim() == right.id.trim();
}

@visibleForTesting
String autonomousModelWireValue(ws.OsiaModel model) {
  final provider = (model.provider ?? '').trim().toLowerCase();
  final modelId = model.id.trim();
  if (provider.isEmpty || modelId.isEmpty) return '';
  return '$provider:$modelId';
}

@visibleForTesting
bool autonomousMobileScopeCanApprove(
  Map<String, dynamic>? request, {
  required bool originMatches,
}) {
  if (request == null || !originMatches) return false;
  return request['local_pc_review_required'] != true &&
      (request['universal_barrier'] ?? '').toString().isEmpty &&
      request['can_approve_mobile'] == true;
}

@visibleForTesting
bool autonomousMobileInitialCanApprove(
  List<Map<String, dynamic>> capabilities, {
  required bool originMatches,
}) {
  if (!originMatches) return false;
  final delegable = capabilities.where((item) => item['delegable'] == true);
  return delegable.isNotEmpty &&
      delegable.every(
        (item) =>
            item['can_approve_mobile'] == true &&
            (item['universal_barrier'] ?? '').toString().isEmpty,
      );
}

@visibleForTesting
class AutonomousModelResolution {
  final ws.OsiaModel? selected;
  final bool fallbackOccurred;

  const AutonomousModelResolution(this.selected, this.fallbackOccurred);
}

class _AutonomousAttachmentEntry {
  _AutonomousAttachmentEntry(this.file);

  final PreparedAttachment file;
  AutonomousSourceCapability? capability;
  String transferState = 'uploading';
}

@visibleForTesting
bool autonomousAttachmentSelectionCanStart({
  required Iterable<bool> ready,
  required bool busy,
  required bool hasFailure,
}) => !busy && !hasFailure && ready.every((value) => value);

@visibleForTesting
AutonomousModelResolution resolveAutonomousModelSelection(
  List<ws.OsiaModel> models, {
  ws.OsiaModel? current,
  String? serverProvider,
  String? serverModel,
  bool userPicked = false,
}) {
  ws.OsiaModel? exact(String? provider, String? modelId) {
    final wantedProvider = (provider ?? '').trim().toLowerCase();
    final wantedModel = (modelId ?? '').trim();
    if (wantedProvider.isEmpty || wantedModel.isEmpty) return null;
    for (final model in models) {
      if ((model.provider ?? '').trim().toLowerCase() == wantedProvider &&
          model.id.trim() == wantedModel) {
        return model;
      }
    }
    return null;
  }

  final currentMatch = current == null
      ? null
      : exact(current.provider, current.id);
  if (userPicked && currentMatch != null) {
    return AutonomousModelResolution(currentMatch, false);
  }

  ws.OsiaModel? selected;
  final wantedServerModel = (serverModel ?? '').trim();
  if ((serverProvider ?? '').trim().isNotEmpty) {
    selected = exact(serverProvider, wantedServerModel);
  } else if (wantedServerModel.isNotEmpty) {
    final matches = models
        .where((model) => model.id.trim() == wantedServerModel)
        .toList();
    if (matches.length == 1) selected = matches.single;
  }
  selected ??= currentMatch;
  selected ??= models.isEmpty ? null : models.first;
  final fallback = current != null && currentMatch == null;
  return AutonomousModelResolution(selected, fallback);
}

class _AutonomousScreenState extends State<AutonomousScreen> {
  final TextEditingController _objectiveCtrl = TextEditingController();

  /// All models the server exposes (via `models_list`). Filtered to
  /// configured-only before display.
  List<ws.OsiaModel> _models = const [];

  /// The chosen exact provider/model entry.
  ws.OsiaModel? _selectedModel;

  /// The server's currently-active exact pair (from `models_list`), remembered
  /// separately so auto-selection can prefer it when it is in the catalogue.
  String? _serverCurrentModel;
  String? _serverCurrentProvider;
  bool _modelsLoaded = false;

  /// Set once the user explicitly picks a model in the selector, so the
  /// auto-selection stops overriding their choice when later frames arrive.
  bool _userPickedModel = false;
  ws.OsiaReasoningConfig _reasoning = const ws.OsiaReasoningConfig();

  /// Latest progress frame, or null before the first one arrives.
  ws.AutonomousProgressMessage? _latest;
  ws.BrowserProgressMessage? _browserProgress;
  final List<_AutonomousAttachmentEntry> _attachments = [];
  final Map<String, ws.DocumentProgressMessage> _documentProgress = {};
  AttachmentProgress? _attachmentProgress;
  AttachmentCancellation? _attachmentCancellation;
  String? _attachmentFailure;
  bool _sourcesSubmitted = false;

  /// Derived run state. Starts idle; flips to [_RunPhase.planning] the instant
  /// the user taps Start (optimistic) until the first frame refines it.
  _RunPhase _runPhase = _RunPhase.idle;

  StreamSubscription<ws.ConfigData>? _configSub;
  StreamSubscription<ws.OsiaMessage>? _msgSub;
  StreamSubscription<ws.AutonomousProgressMessage>? _autoSub;
  StreamSubscription<ws.BrowserProgressMessage>? _browserSub;
  StreamSubscription<ws.DocumentProgressMessage>? _documentSub;
  StreamSubscription<ws.ConnectionState>? _connectionSub;

  /// Live notifier for an open model-selector sheet, so a late `models_list`
  /// (or config) flips it from spinner → list.
  ValueNotifier<ModelSelectorState>? _selectorNotifier;
  Timer? _modelLoadTimeout;

  @override
  void initState() {
    super.initState();
    // Subscribe BEFORE requesting: the broadcast streams don't replay, so a
    // reply must not be able to land before we're listening.
    _configSub = widget.wsService.configStream.listen((cfg) {
      if (!mounted) return;
      setState(() {
        _reasoning = cfg.reasoning;
      });
      _syncModelSelection();
    });
    _msgSub = widget.wsService.messageStream.listen((msg) {
      if (msg is ws.ModelsListMessage && mounted) {
        setState(() {
          _models = msg.models;
          _modelsLoaded = true;
          // Remember the server's exact current pair; _syncModelSelection keeps
          // duplicate model ids under different providers distinct.
          if (msg.current != null && msg.current!.isNotEmpty) {
            _serverCurrentModel = msg.current;
          }
          _serverCurrentProvider = msg.currentProvider;
        });
        _syncModelSelection();
      }
    });
    _autoSub = widget.wsService.autonomousStream.listen(_onProgress);
    _browserSub = widget.wsService.browserProgressStream.listen((progress) {
      if (!mounted) return;
      setState(() => _browserProgress = progress);
    });
    _documentSub = widget.wsService.documentProgressStream.listen((progress) {
      if (!mounted || progress.scopeType != 'autonomous') return;
      setState(() => _documentProgress[progress.itemId] = progress);
    });
    _connectionSub = widget.wsService.connectionStream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
    _browserProgress = widget.wsService.browserProgress;
    final cachedProgress = widget.wsService.autonomousProgress;
    if (cachedProgress != null) {
      _latest = cachedProgress;
      final lifecycle = _canonicalRunLifecycle(cachedProgress);
      _runPhase = _phaseFor(lifecycle, _runPhase);
      final runId = cachedProgress.runId;
      if (runId != null && runId.isNotEmpty) {
        for (final progress in widget.wsService.documentProgressForScope(
          'autonomous',
          runId,
        )) {
          _documentProgress[progress.itemId] = progress;
        }
      }
    }

    // Pull everything the screen needs. get_autonomous_status lets a client
    // that opens mid-run render the live progress immediately (the server
    // replies with a snapshot, or an event:"idle" frame).
    widget.wsService.sendGetConfig();
    widget.wsService.sendGetModels();
    widget.wsService.sendGetAutonomousStatus();
    widget.wsService.sendGetDocumentStatus();
  }

  @override
  void dispose() {
    _attachmentCancellation?.cancel();
    _configSub?.cancel();
    _msgSub?.cancel();
    _autoSub?.cancel();
    _browserSub?.cancel();
    _documentSub?.cancel();
    _connectionSub?.cancel();
    _modelLoadTimeout?.cancel();
    _selectorNotifier?.dispose();
    _objectiveCtrl.dispose();
    _releaseUnboundAttachments();
    super.dispose();
  }

  // ── Progress handling ────────────────────────────────────────────────────

  void _onProgress(ws.AutonomousProgressMessage msg) {
    if (!mounted) return;
    final event = (msg.event ?? '').toLowerCase();

    // "busy" means our start was rejected because a run is already active —
    // inform the user and ask the server for the real running snapshot rather
    // than overwriting state with this rejection frame.
    if (event == 'busy') {
      final strings = OsiaL10n.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(strings.autonomousBusy)));
      widget.wsService.sendGetAutonomousStatus();
      return;
    }

    if (_sourcesSubmitted &&
        const {
          'authorization_pending',
          'running',
          'task_done',
          'state_updated',
        }.contains(event)) {
      _adoptSubmittedAttachments();
    } else if (_sourcesSubmitted &&
        const {'busy', 'plan_failed', 'aborted', 'cancelled'}.contains(event)) {
      _sourcesSubmitted = false;
    }

    setState(() {
      final previousRunId = _latest?.runId;
      if (previousRunId != null &&
          previousRunId.isNotEmpty &&
          msg.runId != null &&
          msg.runId!.isNotEmpty &&
          msg.runId != previousRunId) {
        _documentProgress.clear();
      }
      _latest = msg;
      final lifecycle = _canonicalRunLifecycle(msg);
      // Older servers used `idle` for an unavailable resume checkpoint. Keep
      // that event compatible while honoring WOR-173's additive typed failure.
      _runPhase = event == 'idle' && msg.errorCategory != null
          ? _RunPhase.failed
          : _phaseFor(lifecycle, _runPhase);
    });
  }

  /// Map a server `event` marker to a run phase, defaulting to "running" for an
  /// unrecognized non-empty event (so progress still shows), or keeping the
  /// current phase when the event is absent.
  _RunPhase _phaseFor(String event, _RunPhase current) {
    switch (event) {
      case 'idle':
        return _RunPhase.idle;
      case 'planning':
      case 'plan':
        return _RunPhase.planning;
      case 'authorization_pending':
        return _RunPhase.authorizationPending;
      case 'action_starting':
        return _RunPhase.actionStarting;
      case 'action_in_progress':
        return _RunPhase.actionInProgress;
      case 'waiting_tool':
        return _RunPhase.waitingTool;
      case 'verifying_tool':
        return _RunPhase.verifyingTool;
      case 'resuming':
        return _RunPhase.resuming;
      case 'cancellation_requested':
        return _RunPhase.cancellationRequested;
      case 'blocked_unknown_effect':
        return _RunPhase.blockedUnknownEffect;
      case 'cancelled_proven':
        return _RunPhase.cancelledProven;
      case 'suspended_scope_extension':
      case 'scope_extension_denied':
        return _RunPhase.scopeExtension;
      case 'suspended_authorization_revoked':
        return _RunPhase.revoked;
      case 'blocked_outcome_unknown':
        return _RunPhase.outcomeUnknown;
      case 'paused':
      case 'interrupt':
      case 'interrupted':
        return _RunPhase.paused;
      case 'done':
      case 'completed':
      case 'complete':
      case 'finished':
      case 'success':
        return _RunPhase.done;
      case 'failed':
      case 'fail':
      case 'error':
      case 'plan_failed':
        return _RunPhase.failed;
      case 'aborted':
      case 'abort':
      case 'abandoned':
      case 'cancelled':
      case 'canceled':
        return _RunPhase.aborted;
      case 'phase':
      case 'progress':
      case 'task':
      case 'running':
      case 'started':
      case 'start':
      case 'step':
        return _RunPhase.running;
      case '':
        return current == _RunPhase.idle ? _RunPhase.running : current;
      default:
        return _RunPhase.running;
    }
  }

  bool get _isActive =>
      _runPhase == _RunPhase.planning ||
      _runPhase == _RunPhase.authorizationPending ||
      _runPhase == _RunPhase.running ||
      _runPhase == _RunPhase.actionStarting ||
      _runPhase == _RunPhase.actionInProgress ||
      _runPhase == _RunPhase.waitingTool ||
      _runPhase == _RunPhase.verifyingTool ||
      _runPhase == _RunPhase.resuming ||
      _runPhase == _RunPhase.cancellationRequested ||
      _runPhase == _RunPhase.blockedUnknownEffect ||
      _runPhase == _RunPhase.scopeExtension ||
      _runPhase == _RunPhase.revoked ||
      _runPhase == _RunPhase.outcomeUnknown;

  bool get _attachmentBusy => switch (_attachmentProgress?.phase) {
    AttachmentPhase.preparing ||
    AttachmentPhase.hashing ||
    AttachmentPhase.uploading ||
    AttachmentPhase.verifying => true,
    _ => false,
  };

  bool get _attachmentsReady => autonomousAttachmentSelectionCanStart(
    ready: _attachments.map((entry) => entry.capability != null),
    busy: _attachmentBusy,
    hasFailure: _attachmentFailure != null,
  );

  // ── Configured-only model filter ─────────────────────────────────────────

  /// The configured-only model list (the only models offered for a run).
  List<ws.OsiaModel> get _configuredModels {
    return _models
        .where(
          (model) =>
              model.selectable &&
              (model.provider ?? '').trim().isNotEmpty &&
              model.id.trim().isNotEmpty,
        )
        .toList();
  }

  /// Resolve [_selectedModel] against the configured-only list, and push a
  /// fresh state into an open model-selector sheet.
  ///
  /// It preserves a manual exact pair, otherwise prefers the server's exact
  /// current pair and finally the first deterministic catalogue entry.
  void _syncModelSelection() {
    final configured = _configuredModels;
    if (_modelsLoaded) {
      final resolution = resolveAutonomousModelSelection(
        configured,
        current: _selectedModel,
        serverProvider: _serverCurrentProvider,
        serverModel: _serverCurrentModel,
        userPicked: _userPickedModel,
      );
      if (!sameAutonomousModelIdentity(resolution.selected, _selectedModel)) {
        setState(() => _selectedModel = resolution.selected);
      } else if (resolution.selected != null &&
          !identical(resolution.selected, _selectedModel)) {
        setState(() => _selectedModel = resolution.selected);
      }
      if (resolution.fallbackOccurred) {
        _showModelFallbackNotice();
      }
    }
    final notifier = _selectorNotifier;
    if (notifier != null) {
      _modelLoadTimeout?.cancel();
      notifier.value = ModelSelectorState(
        models: configured,
        isLoading: !_modelsLoaded,
        errorMessage: (_modelsLoaded && configured.isEmpty)
            ? OsiaL10n.of(context).autonomousNoConfiguredModels
            : null,
        reasoning: _reasoning,
      );
    }
  }

  void _showModelFallbackNotice() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final strings = OsiaL10n.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.autonomousModelFallback)),
        );
    });
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _openModelSelector() async {
    final strings = OsiaL10n.of(context);
    final configured = _configuredModels;
    // No config yet → spin and (re)request; config present but nothing
    // configured → show the explicit "no configured model" message.
    final notifier = ValueNotifier<ModelSelectorState>(
      ModelSelectorState(
        models: configured,
        isLoading: !_modelsLoaded,
        errorMessage: (_modelsLoaded && configured.isEmpty)
            ? strings.autonomousNoConfiguredModels
            : null,
        reasoning: _reasoning,
      ),
    );
    _selectorNotifier = notifier;
    _modelLoadTimeout?.cancel();

    if (!_modelsLoaded) {
      widget.wsService.sendGetConfig();
      widget.wsService.sendGetModels();
      _modelLoadTimeout = Timer(const Duration(seconds: 5), () {
        if (_selectorNotifier != notifier) return;
        if (notifier.value.models.isNotEmpty) return;
        notifier.value = ModelSelectorState(
          models: const [],
          isLoading: false,
          errorMessage: _modelsLoaded
              ? strings.autonomousNoConfiguredModels
              : strings.modelsLoadFailed,
          reasoning: _reasoning,
        );
      });
    }

    try {
      ws.OsiaModel? pickedModel;
      final chosen = await showModelSelector(
        context: context,
        stateListenable: notifier,
        currentModel: _selectedModel?.id,
        currentProvider: _selectedModel?.provider,
        // The run uses the explicitly chosen model — the AI-hierarchy override
        // note doesn't apply here.
        hierarchyActive: false,
        onReasoningChanged: _setReasoningForModel,
        onModelSelected: (model) => pickedModel = model,
      );
      if (chosen != null && pickedModel != null) {
        // A manual pick wins over auto-selection from here on.
        _userPickedModel = true;
        if (!sameAutonomousModelIdentity(pickedModel, _selectedModel)) {
          setState(() => _selectedModel = pickedModel);
        }
      }
    } finally {
      _modelLoadTimeout?.cancel();
      _modelLoadTimeout = null;
      _selectorNotifier = null;
      notifier.dispose();
    }
  }

  void _setReasoningForModel(ws.OsiaModel model, String optionId) {
    final provider = (model.provider ?? '').trim();
    if (provider.isEmpty) return;
    final key = provider == 'chatgpt_account'
        ? 'chatgpt_account:${model.id}'
        : model.id;
    final next = _reasoning.withModelOverride(key, optionId);
    setState(() => _reasoning = next);
    final notifier = _selectorNotifier;
    if (notifier != null) {
      final current = notifier.value;
      notifier.value = ModelSelectorState(
        models: current.models,
        isLoading: current.isLoading,
        errorMessage: current.errorMessage,
        reasoning: next,
      );
    }
    widget.wsService.sendSetModelReasoning(provider, model.id, optionId);
    widget.wsService.sendGetConfig();
  }

  Future<void> _addDocuments() async {
    if (_isActive ||
        _attachmentBusy ||
        _attachments.length >= attachmentMaxFiles) {
      return;
    }
    if (_attachments.any((entry) => entry.transferState == 'failed')) return;
    if (_attachmentFailure != null) setState(() => _attachmentFailure = null);

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: false,
        withReadStream: true,
      );
    } on Object {
      if (mounted) setState(() => _attachmentFailure = 'picker_failed');
      return;
    }
    if (result == null || result.files.isEmpty) return;

    final sources = <AttachmentSource>[];
    for (final picked in result.files) {
      final capturedStream = picked.readStream;
      final capturedPath = picked.path;
      sources.add(
        AttachmentSource(
          displayName: picked.name,
          declaredSize: picked.size,
          openRead: () {
            if (capturedStream != null) return capturedStream;
            if (capturedPath == null || capturedPath.isEmpty) {
              throw const AttachmentException('source_expired');
            }
            return File(capturedPath).openRead();
          },
        ),
      );
    }

    final cancellation = AttachmentCancellation();
    _attachmentCancellation = cancellation;
    setState(() {
      _attachmentProgress = AttachmentProgress(
        phase: AttachmentPhase.preparing,
        totalFiles: _attachments.length + sources.length,
      );
    });
    final newEntries = <_AutonomousAttachmentEntry>[];
    try {
      final temporary = await getTemporaryDirectory();
      final preparer = AttachmentPreparer(
        root: Directory(
          '${temporary.path}${Platform.pathSeparator}osia_attachment_staging',
        ),
      );
      final prepared = await preparer.prepare(
        sources,
        existing: _attachments.map((entry) => entry.file).toList(),
        cancellation: cancellation,
        onProgress: (progress) {
          if (mounted) setState(() => _attachmentProgress = progress);
        },
      );
      for (final candidate in prepared) {
        if (attachmentIsDuplicate(
          _attachments.map((entry) => entry.file),
          candidate,
        )) {
          await candidate.delete();
        } else {
          newEntries.add(_AutonomousAttachmentEntry(candidate));
        }
      }
      if (!mounted) {
        for (final entry in newEntries) {
          await entry.file.delete();
        }
        return;
      }
      if (newEntries.isEmpty) {
        setState(() {
          _attachmentCancellation = null;
          _attachmentProgress = null;
        });
        return;
      }
      setState(() {
        _attachments.addAll(newEntries);
        _attachmentProgress = AttachmentProgress(
          phase: AttachmentPhase.uploading,
          totalFiles: newEntries.length,
          totalBytes: newEntries.fold<int>(
            0,
            (sum, entry) => sum + entry.file.byteSize,
          ),
        );
      });
      await ensureAttachmentTransportReady(
        ensureConnected: () => widget.wsService.ensureConnected(
          reason: 'autonomous_attachment_upload',
        ),
        transportSession: () => widget.wsService.attachmentTransportSession,
      );
      final transfer = AttachmentTransferClient(
        sendFrame: widget.wsService.sendAttachmentEvent,
        events: widget.wsService.attachmentProtocolStream.map(
          (message) => message.data,
        ),
        transportSession: () => widget.wsService.attachmentTransportSession,
      );
      final uploaded = await transfer.upload(
        files: newEntries.map((entry) => entry.file).toList(),
        conversationId: '',
        clientRequestId: ws.WebSocketService.newClientRequestId(),
        attachmentPurpose: 'autonomous',
        cancellation: cancellation,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _attachmentProgress = progress;
            final state = switch (progress.phase) {
              AttachmentPhase.verifying => 'verifying',
              AttachmentPhase.ready => 'ready',
              AttachmentPhase.failed || AttachmentPhase.canceled => 'failed',
              _ => 'uploading',
            };
            for (final entry in newEntries) {
              entry.transferState = state;
            }
          });
        },
      );
      if (!mounted) return;
      setState(() {
        for (var index = 0; index < newEntries.length; index++) {
          newEntries[index]
            ..capability = uploaded.autonomousSources[index]
            ..transferState = 'ready';
        }
        _attachmentCancellation = null;
        _attachmentFailure = null;
        _attachmentProgress = AttachmentProgress(
          phase: AttachmentPhase.ready,
          totalFiles: newEntries.length,
          completedFiles: newEntries.length,
        );
      });
    } on AttachmentException {
      if (!mounted) return;
      setState(() {
        _attachmentCancellation = null;
        _attachmentFailure = 'upload_failed';
        _attachmentProgress = AttachmentProgress(
          phase: AttachmentPhase.failed,
          totalFiles: newEntries.length,
        );
        for (final entry in newEntries) {
          entry.transferState = 'failed';
        }
      });
    }
  }

  Future<void> _removeDocument(_AutonomousAttachmentEntry entry) async {
    if (_isActive || _attachmentBusy) return;
    final capability = entry.capability;
    if (capability != null) {
      widget.wsService.sendAutonomousReleaseSources([capability.sourceRef]);
    }
    await entry.file.delete();
    if (!mounted) return;
    setState(() {
      _attachments.remove(entry);
      if (!_attachments.any((item) => item.transferState == 'failed')) {
        _attachmentFailure = null;
      }
      _attachmentProgress = _attachments.isEmpty
          ? null
          : AttachmentProgress(
              phase: AttachmentPhase.ready,
              totalFiles: _attachments.length,
              completedFiles: _attachments.length,
            );
    });
  }

  void _adoptSubmittedAttachments() {
    final adopted = List<_AutonomousAttachmentEntry>.of(_attachments);
    _sourcesSubmitted = false;
    if (mounted) setState(_attachments.clear);
    for (final entry in adopted) {
      unawaited(entry.file.delete());
    }
  }

  void _releaseUnboundAttachments() {
    final entries = List<_AutonomousAttachmentEntry>.of(_attachments);
    if (!_sourcesSubmitted) {
      final refs = entries
          .map((entry) => entry.capability?.sourceRef)
          .whereType<String>()
          .toList(growable: false);
      if (refs.isNotEmpty) widget.wsService.sendAutonomousReleaseSources(refs);
    }
    for (final entry in entries) {
      unawaited(entry.file.delete());
    }
    _attachments.clear();
  }

  void _start() {
    final objective = _objectiveCtrl.text.trim();
    final strings = OsiaL10n.of(context);
    if (!_attachmentsReady) return;
    if (objective.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.autonomousObjectiveRequired)),
        );
      return;
    }
    final selectedModel = _selectedModel;
    final model = selectedModel == null
        ? ''
        : autonomousModelWireValue(selectedModel);
    if (model.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.autonomousModelRequired)),
        );
      return;
    }
    FocusScope.of(context).unfocus();
    widget.wsService.setClientLocale(strings.languageCode);
    final sourceRefs = _attachments
        .map((entry) => entry.capability!.sourceRef)
        .toList(growable: false);
    final bool sent;
    if (sourceRefs.isEmpty) {
      widget.wsService.sendAutonomousStart(objective, model);
      sent = true;
    } else {
      sent = widget.wsService.sendAutonomousStartWithSources(
        objective,
        model,
        sourceRefs,
      );
    }
    if (!sent) return;
    _sourcesSubmitted = _attachments.isNotEmpty;
    // Do not retain private objective text in the visible mobile widget tree.
    // Authorization review is reconstructed from structural plan labels and
    // safe capability summaries returned by the PC.
    _objectiveCtrl.clear();
    // Optimistic "Planning…" until the first progress frame refines the state.
    setState(() {
      _latest = const ws.AutonomousProgressMessage();
      _runPhase = _RunPhase.planning;
      _documentProgress.clear();
    });
  }

  void _interrupt() {
    widget.wsService.sendAutonomousInterrupt();
  }

  void _resume() {
    widget.wsService.sendAutonomousResume();
    // Optimistic flip to running so the UI responds before the server's running
    // frame lands. _latest is deliberately left intact — the progress card
    // keeps its snapshot and continues from where the run paused.
    setState(() {
      _runPhase = _RunPhase.running;
    });
  }

  void _authorizeAndStart() {
    final latest = _latest;
    if (latest == null) return;
    final selected = latest.capabilitySummary
        .where(
          (item) =>
              item['delegable'] == true &&
              item['can_approve_mobile'] == true &&
              (item['universal_barrier'] ?? '').toString().isEmpty,
        )
        .map((item) => (item['capability_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    widget.wsService.sendAutonomousAuthorizationResponse(
      latest,
      'approve',
      selectedCapabilityIds: selected,
    );
  }

  void _denyAuthorization() {
    final latest = _latest;
    if (latest == null) return;
    widget.wsService.sendAutonomousAuthorizationResponse(latest, 'deny');
  }

  void _approveScopeExtension() {
    final latest = _latest;
    if (latest == null) return;
    widget.wsService.sendAutonomousScopeExtensionResponse(
      latest,
      'approve_exact',
    );
  }

  void _denyScopeExtension() {
    final latest = _latest;
    if (latest == null) return;
    widget.wsService.sendAutonomousScopeExtensionResponse(latest, 'deny');
  }

  void _revokeAuthorization() {
    final latest = _latest;
    if (latest == null) return;
    widget.wsService.sendAutonomousAuthorizationRevoke(latest);
  }

  Future<void> _abort() async {
    final strings = OsiaL10n.of(context);
    final palette = OsiaTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.autonomousAbort),
        content: Text(
          strings.autonomousAborted,
          style: TextStyle(color: palette.textMuted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              strings.cancel,
              style: TextStyle(color: palette.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              strings.autonomousAbort,
              style: TextStyle(color: palette.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (widget.wsService.requestAutonomousCancellation() && mounted) {
      setState(() {});
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    final configuredCount = _configuredModels.length;
    final canStart =
        !_isActive &&
        _attachmentsReady &&
        _objectiveCtrl.text.trim().isNotEmpty &&
        _selectedModel != null &&
        autonomousModelWireValue(_selectedModel!).isNotEmpty &&
        configuredCount > 0;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(strings.autonomousTitle),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Objective ──
              StaggeredAppear(
                index: 0,
                child: _SectionLabel(
                  label: strings.autonomousObjectiveLabel,
                  palette: palette,
                ),
              ),
              StaggeredAppear(
                index: 1,
                child: _OsiaCard(
                  palette: palette,
                  child: TextField(
                    controller: _objectiveCtrl,
                    enabled: !_isActive,
                    minLines: 3,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    cursorColor: palette.accent,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: palette.surfaceElevated,
                      hintText: strings.autonomousObjectiveHint,
                      hintStyle: TextStyle(
                        color: palette.textMuted,
                        fontSize: 14.5,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: palette.border.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: palette.accent,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Model (configured-only) ──
              StaggeredAppear(
                index: 2,
                child: _SectionLabel(
                  label: strings.autonomousDocuments,
                  palette: palette,
                ),
              ),
              StaggeredAppear(
                index: 3,
                child: _OsiaCard(
                  palette: palette,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: const Key('autonomous-add-documents'),
                          onPressed:
                              !_isActive &&
                                  !_attachmentBusy &&
                                  _attachments.length < attachmentMaxFiles &&
                                  !_attachments.any(
                                    (entry) => entry.transferState == 'failed',
                                  )
                              ? _addDocuments
                              : null,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(strings.autonomousAddDocuments),
                        ),
                      ),
                      for (
                        var index = 0;
                        index < _attachments.length;
                        index++
                      ) ...[
                        if (index > 0)
                          Divider(color: palette.border, height: 18),
                        _buildAttachmentRow(
                          _attachments[index],
                          palette,
                          strings,
                        ),
                      ],
                      if (_attachmentFailure != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          strings.documentTransferFailed,
                          key: const Key('autonomous-document-upload-failure'),
                          style: TextStyle(
                            color: palette.error,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              StaggeredAppear(
                index: 4,
                child: _SectionLabel(label: strings.model, palette: palette),
              ),
              StaggeredAppear(
                index: 5,
                child: _ModelPickerTile(
                  palette: palette,
                  label: _selectedModelLabel(strings),
                  enabled: !_isActive,
                  onTap: _isActive ? null : _openModelSelector,
                ),
              ),
              // "No configured model" hint once config has arrived and the
              // filtered list is empty.
              if (_modelsLoaded && configuredCount == 0) ...[
                const SizedBox(height: 10),
                _InlineNote(
                  icon: Icons.info_outline_rounded,
                  text: strings.autonomousNoConfiguredModels,
                  palette: palette,
                ),
              ],
              const SizedBox(height: 20),

              // ── Start ──
              StaggeredAppear(
                index: 6,
                child: PressableScale(
                  enabled: canStart,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: canStart ? _start : null,
                      icon: Icon(
                        _runPhase == _RunPhase.planning
                            ? Icons.hourglass_top_rounded
                            : Icons.rocket_launch_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _runPhase == _RunPhase.planning
                            ? strings.autonomousPlanning
                            : strings.autonomousStart,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: palette.isDark
                            ? palette.background
                            : Colors.white,
                        disabledBackgroundColor: palette.accent.withValues(
                          alpha: 0.4,
                        ),
                        disabledForegroundColor:
                            (palette.isDark ? palette.background : Colors.white)
                                .withValues(alpha: 0.7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Live progress ──
              AnimatedSize(
                duration: Motion.duration(context, MotionDurations.medium),
                curve: Motion.curve(context, MotionCurves.enter),
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: Motion.duration(context, MotionDurations.medium),
                  switchInCurve: Motion.curve(context, MotionCurves.enter),
                  switchOutCurve: Motion.curve(context, MotionCurves.exit),
                  child: KeyedSubtree(
                    key: ValueKey(_runPhase),
                    child: _buildStatus(palette, strings),
                  ),
                ),
              ),

              if (shouldShowAutonomousBrowserProgress(_browserProgress)) ...[
                const SizedBox(height: 16),
                _buildBrowserProgressCard(palette, strings),
              ],

              // ── Interrupt / Abandon ──
              if (_runPhase == _RunPhase.authorizationPending ||
                  _runPhase == _RunPhase.scopeExtension) ...[
                const SizedBox(height: 16),
                _buildAuthorizationReview(palette, strings),
              ],

              if (_isActive ||
                  _runPhase == _RunPhase.paused ||
                  widget.wsService.canAbandonAutonomousWork) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_runPhase == _RunPhase.running)
                      Expanded(
                        child: PressableScale(
                          child: OutlinedButton.icon(
                            onPressed: _interrupt,
                            icon: const Icon(Icons.pause_rounded, size: 19),
                            label: Text(strings.autonomousInterrupt),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.accent,
                              side: BorderSide(color: palette.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_runPhase == _RunPhase.running)
                      const SizedBox(width: 12),
                    if (_runPhase == _RunPhase.paused)
                      Expanded(
                        child: PressableScale(
                          child: OutlinedButton.icon(
                            onPressed: _resume,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 19,
                            ),
                            label: Text(strings.autonomousResume),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.accent,
                              side: BorderSide(color: palette.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_runPhase == _RunPhase.paused)
                      const SizedBox(width: 12),
                    if (_runPhase == _RunPhase.running ||
                        _runPhase == _RunPhase.scopeExtension) ...[
                      Expanded(
                        child: PressableScale(
                          child: OutlinedButton.icon(
                            onPressed: _revokeAuthorization,
                            icon: const Icon(
                              Icons.lock_reset_rounded,
                              size: 19,
                            ),
                            label: Text(strings.autonomousRevoke),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.error,
                              side: BorderSide(color: palette.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: PressableScale(
                        child: OutlinedButton.icon(
                          onPressed: _abort,
                          icon: const Icon(Icons.stop_rounded, size: 19),
                          label: Text(strings.autonomousAbort),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.error,
                            side: BorderSide(
                              color: palette.error.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Pretty label for the selected model — its server label when known, else
  /// the raw id, else the "choose a model" prompt.
  Widget _buildAttachmentRow(
    _AutonomousAttachmentEntry entry,
    OsiaPalette palette,
    OsiaStrings strings,
  ) {
    final safeType =
        entry.capability?.typeLabel ??
        (entry.file.extension.isEmpty ? 'document' : entry.file.extension);
    return Row(
      key: ValueKey('autonomous-document-${entry.file.fileId}'),
      children: [
        Icon(Icons.description_outlined, color: palette.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.file.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$safeType · ${_attachmentStateLabel(entry, strings)}',
                style: TextStyle(
                  color: entry.transferState == 'failed'
                      ? palette.error
                      : palette.textMuted,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: strings.autonomousRemoveDocument,
          onPressed: !_isActive && !_attachmentBusy
              ? () => _removeDocument(entry)
              : null,
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ],
    );
  }

  String _attachmentStateLabel(
    _AutonomousAttachmentEntry entry,
    OsiaStrings strings,
  ) => switch (entry.transferState) {
    'ready' => strings.documentTransferReady,
    'verifying' => strings.documentTransferVerifying,
    'failed' => strings.documentTransferFailed,
    _ => strings.documentTransferUploading,
  };

  String _selectedModelLabel(OsiaStrings strings) {
    final model = _selectedModel;
    if (model == null || model.id.isEmpty) {
      return strings.autonomousPickModel;
    }
    return model.label;
  }

  /// Minimal, display-only browser status using the existing OSIA card system.
  Widget _buildBrowserProgressCard(OsiaPalette palette, OsiaStrings strings) {
    final progress = _browserProgress;
    if (progress == null) return const SizedBox.shrink();
    final artifact = progress.artifactSafeSummary;
    final size = artifact?['size'];
    final detailLines = <String>[
      if (progress.safeSiteDisplay.isNotEmpty) progress.safeSiteDisplay,
      if (artifact?['private'] == true)
        size is int
            ? 'Private artifact · ${_formatPrivateBytes(size)}'
            : 'Private artifact',
    ];
    final live = widget.wsService.browserProgressLive;
    return _OsiaCard(
      key: const Key('browser-progress-card'),
      palette: palette,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            progress.phase == 'complete'
                ? Icons.lock_rounded
                : Icons.language_rounded,
            color: palette.accent,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.safeProgressText,
                  key: const Key('browser-progress-text'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!live) ...[
                  const SizedBox(height: 3),
                  Text(
                    strings.disconnected,
                    key: const Key('browser-progress-last-known'),
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                ],
                for (final line in detailLines) ...[
                  const SizedBox(height: 4),
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textMuted, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrivateBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB';
  }

  Widget _buildAuthorizationReview(OsiaPalette palette, OsiaStrings strings) {
    final latest = _latest;
    if (latest == null) return const SizedBox.shrink();
    final isInitial = _runPhase == _RunPhase.authorizationPending;
    final request = isInitial
        ? latest.authorizationRequest
        : latest.pendingScopeExtension;
    final canRespond = widget.wsService.canRespondToAutonomousRequest(request);
    final localOnly = request?['local_pc_review_required'] == true;
    final barrier = (request?['universal_barrier'] ?? '').toString();
    final canApproveExtension = autonomousMobileScopeCanApprove(
      request,
      originMatches: canRespond,
    );
    final canApproveInitial =
        isInitial &&
        autonomousMobileInitialCanApprove(
          latest.capabilitySummary,
          originMatches: canRespond,
        );
    final initialPcOnly =
        isInitial &&
        !canApproveInitial &&
        latest.capabilitySummary.any(
          (item) =>
              item['can_approve_mobile'] != true ||
              (item['universal_barrier'] ?? '').toString().isNotEmpty,
        );

    final planLines = <String>[];
    for (final phase in latest.planSummary) {
      final name = (phase['name'] ?? '').toString().trim();
      if (name.isNotEmpty) planLines.add(name);
      final tasks = phase['tasks'];
      if (tasks is List) {
        planLines.addAll(
          tasks
              .map((task) => task.toString().trim())
              .where((task) => task.isNotEmpty)
              .map((task) => '• $task'),
        );
      }
    }
    final capabilityLines = latest.capabilitySummary
        .map((item) {
          final label = (item['label'] ?? '').toString();
          final effect = (item['effect_class'] ?? '').toString();
          final precision = (item['target_precision'] ?? 'unknown').toString();
          final uses = item['expected_use_count'];
          final ttl = item['grant_ttl_seconds'];
          final bounds = <String>[];
          if (uses is int && uses > 0) bounds.add('$uses×');
          if (ttl is int && ttl > 0) bounds.add('${(ttl / 60).ceil()} min');
          final universal = (item['universal_barrier'] ?? '').toString();
          final suffix = universal.isEmpty
              ? ''
              : ' · ${strings.autonomousPcOnly}';
          final boundsText = bounds.isEmpty ? '' : ' · ${bounds.join(' · ')}';
          return '• $label · $effect · $precision$boundsText$suffix';
        })
        .toList(growable: false);

    return _OsiaCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isInitial
                ? strings.autonomousReviewPlan
                : strings.autonomousAdditionalPermission,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (planLines.isNotEmpty && isInitial) ...[
            const SizedBox(height: 10),
            Text(
              planLines.join('\n'),
              style: TextStyle(color: palette.textMuted, height: 1.4),
            ),
          ],
          if (capabilityLines.isNotEmpty && isInitial) ...[
            const SizedBox(height: 12),
            Text(
              strings.autonomousRequestedCapabilities,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              capabilityLines.join('\n'),
              style: TextStyle(color: palette.textMuted, height: 1.4),
            ),
          ],
          if (!isInitial) ...[
            const SizedBox(height: 10),
            Text(
              '${request?['safe_category'] ?? ''} · '
              '${request?['effect_class'] ?? ''} · '
              '${request?['requested_use_count'] ?? 1}×'
              '${_requestTtlMinutes(request)}',
              style: TextStyle(color: palette.textMuted, height: 1.4),
            ),
          ],
          if (localOnly ||
              barrier.isNotEmpty ||
              !canRespond ||
              initialPcOnly) ...[
            const SizedBox(height: 12),
            _InlineNote(
              icon: Icons.desktop_windows_outlined,
              text: strings.autonomousPcOnly,
              palette: palette,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (canApproveInitial || canApproveExtension)
                Expanded(
                  child: ElevatedButton(
                    onPressed: isInitial
                        ? _authorizeAndStart
                        : _approveScopeExtension,
                    child: Text(
                      isInitial
                          ? strings.autonomousAuthorizeAndStart
                          : strings.autonomousApproveExact,
                    ),
                  ),
                ),
              if (canApproveInitial || canApproveExtension)
                const SizedBox(width: 10),
              if (canRespond)
                Expanded(
                  child: OutlinedButton(
                    onPressed: isInitial
                        ? _denyAuthorization
                        : _denyScopeExtension,
                    child: Text(strings.autonomousDeny),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _requestTtlMinutes(Map<String, dynamic>? request) {
    final issued = request?['issued_at'];
    final expires = request?['expires_at'];
    if (issued is! num || expires is! num || expires <= issued) return '';
    return ' · ${((expires - issued) / 60).ceil()} min';
  }

  Widget _buildStatus(OsiaPalette palette, OsiaStrings strings) {
    if (_runPhase == _RunPhase.idle) {
      return _InlineNote(
        key: const ValueKey('idle'),
        icon: Icons.bedtime_outlined,
        text: strings.autonomousIdle,
        palette: palette,
      );
    }

    final latest = _latest;
    final objective = (latest?.objective ?? '').trim();
    final phaseName = (latest?.phaseName ?? '').trim();
    final runProvider = (latest?.provider ?? '').trim();
    final runModel = (latest?.model ?? '').trim();
    final errorCategory = latest?.errorCategory;
    final diagnosticMessage = errorCategory == null
        ? ''
        : strings.autonomousFailureDiagnostic(errorCategory.wireValue);
    final diagnosticMetadata = errorCategory == null
        ? ''
        : strings.autonomousDiagnosticMetadata(
            attempt: latest?.attempt,
            maxAttempts: latest?.maxAttempts,
            replanCount: latest?.stage == ws.AutonomousFailureStage.replan
                ? latest?.replanCount
                : null,
            maxReplans: latest?.stage == ws.AutonomousFailureStage.replan
                ? latest?.maxReplans
                : null,
          );
    final done = latest?.tasksDone;
    final total = latest?.tasksTotal;
    final finalAnswer = (latest?.finalAnswer ?? '').trim();

    return _OsiaCard(
      key: const ValueKey('status'),
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: state label + colored dot.
          Row(
            children: [
              Icon(_runIcon(), size: 18, color: _runColor(palette)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _runLabel(strings),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _runColor(palette),
                  ),
                ),
              ),
            ],
          ),
          if (objective.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              objective,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: palette.textPrimary,
              ),
            ),
          ],
          if (runProvider.isNotEmpty && runModel.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MetaRow(
              key: const ValueKey('autonomous-run-model'),
              label: strings.model,
              value: '$runProvider — $runModel',
              palette: palette,
            ),
          ],
          if (_runPhase != _RunPhase.failed &&
              errorCategory == null &&
              phaseName.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MetaRow(
              label: strings.autonomousPhase,
              value: phaseName,
              palette: palette,
            ),
          ],
          if (done != null && total != null) ...[
            const SizedBox(height: 8),
            // Pre-formatted "X / Y tasks" line (its own template — no label).
            _MetaRow(
              label: '',
              value: strings.autonomousTasks(done, total),
              palette: palette,
              valueOnly: true,
            ),
            const SizedBox(height: 8),
            _TaskProgressBar(done: done, total: total, palette: palette),
          ],
          for (final document in _documentProgress.values) ...[
            const SizedBox(height: 10),
            Row(
              key: ValueKey('autonomous-document-progress-${document.itemId}'),
              children: [
                Icon(
                  document.phase == 'failed'
                      ? Icons.error_outline_rounded
                      : document.phase == 'ready'
                      ? Icons.check_circle_outline_rounded
                      : Icons.description_outlined,
                  size: 18,
                  color: document.phase == 'failed'
                      ? palette.error
                      : palette.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    document.phase == 'failed'
                        ? '${document.documentType} · '
                              '${strings.documentProcessingFailed}'
                        : '${document.documentType} · '
                              '${strings.documentPhase(document.phase)}',
                    style: TextStyle(
                      color: document.phase == 'failed'
                          ? palette.error
                          : palette.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (diagnosticMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              diagnosticMessage,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: _runColor(palette),
              ),
            ),
          ],
          if (diagnosticMetadata.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              diagnosticMetadata,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: palette.textMuted,
              ),
            ),
          ],
          if (_runPhase == _RunPhase.done && finalAnswer.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(
              finalAnswer,
              key: const Key('autonomous-final-answer'),
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: palette.textPrimary,
              ),
            ),
          ],
          // Active runs show the choreographed thinking indicator.
          if (_runPhase == _RunPhase.planning ||
              _runPhase == _RunPhase.running ||
              _runPhase == _RunPhase.actionStarting ||
              _runPhase == _RunPhase.actionInProgress ||
              _runPhase == _RunPhase.waitingTool ||
              _runPhase == _RunPhase.verifyingTool ||
              _runPhase == _RunPhase.resuming ||
              _runPhase == _RunPhase.cancellationRequested) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: ThinkingIndicator(),
            ),
          ],
        ],
      ),
    );
  }

  IconData _runIcon() {
    switch (_runPhase) {
      case _RunPhase.done:
        return Icons.check_circle_rounded;
      case _RunPhase.failed:
        return Icons.error_rounded;
      case _RunPhase.aborted:
      case _RunPhase.cancelledProven:
        return Icons.stop_circle_rounded;
      case _RunPhase.paused:
        return Icons.pause_circle_rounded;
      case _RunPhase.authorizationPending:
        return Icons.fact_check_outlined;
      case _RunPhase.scopeExtension:
        return Icons.add_moderator_outlined;
      case _RunPhase.revoked:
        return Icons.lock_outline_rounded;
      case _RunPhase.outcomeUnknown:
      case _RunPhase.blockedUnknownEffect:
        return Icons.help_outline_rounded;
      case _RunPhase.waitingTool:
        return Icons.hourglass_top_rounded;
      case _RunPhase.verifyingTool:
        return Icons.verified_outlined;
      case _RunPhase.resuming:
        return Icons.play_circle_outline_rounded;
      case _RunPhase.cancellationRequested:
        return Icons.pending_actions_rounded;
      case _RunPhase.planning:
      case _RunPhase.actionStarting:
      case _RunPhase.actionInProgress:
      case _RunPhase.running:
      case _RunPhase.idle:
        return Icons.rocket_launch_rounded;
    }
  }

  Color _runColor(OsiaPalette palette) {
    switch (_runPhase) {
      case _RunPhase.failed:
      case _RunPhase.aborted:
      case _RunPhase.blockedUnknownEffect:
        return palette.error;
      case _RunPhase.paused:
        return palette.textMuted;
      case _RunPhase.revoked:
      case _RunPhase.outcomeUnknown:
        return palette.error;
      case _RunPhase.done:
      case _RunPhase.cancelledProven:
      case _RunPhase.planning:
      case _RunPhase.authorizationPending:
      case _RunPhase.scopeExtension:
      case _RunPhase.actionStarting:
      case _RunPhase.actionInProgress:
      case _RunPhase.waitingTool:
      case _RunPhase.verifyingTool:
      case _RunPhase.resuming:
      case _RunPhase.cancellationRequested:
      case _RunPhase.running:
      case _RunPhase.idle:
        return palette.accent;
    }
  }

  String _runLabel(OsiaStrings strings) {
    switch (_runPhase) {
      case _RunPhase.planning:
        return strings.autonomousPlanning;
      case _RunPhase.running:
        return strings.autonomousRunning;
      case _RunPhase.actionStarting:
        return autonomousDurableStateLabel(strings, 'action_starting');
      case _RunPhase.actionInProgress:
        return autonomousDurableStateLabel(strings, 'action_in_progress');
      case _RunPhase.waitingTool:
        return autonomousDurableStateLabel(strings, 'waiting_tool');
      case _RunPhase.verifyingTool:
        return autonomousDurableStateLabel(strings, 'verifying_tool');
      case _RunPhase.resuming:
        return autonomousDurableStateLabel(strings, 'resuming');
      case _RunPhase.cancellationRequested:
        return autonomousDurableStateLabel(strings, 'cancellation_requested');
      case _RunPhase.blockedUnknownEffect:
        return autonomousDurableStateLabel(strings, 'blocked_unknown_effect');
      case _RunPhase.cancelledProven:
        return autonomousDurableStateLabel(strings, 'cancelled_proven');
      case _RunPhase.authorizationPending:
        return strings.autonomousReviewPlan;
      case _RunPhase.scopeExtension:
        return strings.autonomousAdditionalPermission;
      case _RunPhase.revoked:
        return strings.autonomousAuthorizationRevoked;
      case _RunPhase.outcomeUnknown:
        return strings.autonomousOutcomeUnknown;
      case _RunPhase.paused:
        return strings.autonomousInterrupted;
      case _RunPhase.done:
        return strings.autonomousDone;
      case _RunPhase.failed:
        return strings.autonomousFailed;
      case _RunPhase.aborted:
        return strings.autonomousAborted;
      case _RunPhase.idle:
        return strings.autonomousIdle;
    }
  }
}

// ── Small building blocks (local to this screen) ───────────────────────────

/// Section label above a card — small, muted, letter-spaced (matches the
/// providers screen's section headers).
class _SectionLabel extends StatelessWidget {
  final String label;
  final OsiaPalette palette;
  const _SectionLabel({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: palette.textMuted,
        ),
      ),
    );
  }
}

/// Rounded surface card matching the rest of the app.
class _OsiaCard extends StatelessWidget {
  final OsiaPalette palette;
  final Widget child;
  const _OsiaCard({super.key, required this.palette, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border, width: 0.5),
      ),
      child: child,
    );
  }
}

/// Tappable tile showing the chosen model; opens the model selector.
class _ModelPickerTile extends StatelessWidget {
  final OsiaPalette palette;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  const _ModelPickerTile({
    required this.palette,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: enabled
                      ? palette.accent
                      : palette.accent.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: enabled ? palette.textPrimary : palette.textMuted,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: enabled
                      ? palette.accent
                      : palette.accent.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A "label: value" line inside the status card. With [valueOnly] the label is
/// dropped (used for the pre-formatted tasks line).
class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final OsiaPalette palette;
  final bool valueOnly;
  const _MetaRow({
    super.key,
    required this.label,
    required this.value,
    required this.palette,
    this.valueOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (valueOnly) {
      return Text(
        value,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
      );
    }
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: palette.textMuted,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim determinate progress bar for the X / Y task count.
class _TaskProgressBar extends StatelessWidget {
  final int done;
  final int total;
  final OsiaPalette palette;
  const _TaskProgressBar({
    required this.done,
    required this.total,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        backgroundColor: palette.surfaceElevated,
        valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
      ),
    );
  }
}

/// A muted inline note with a leading icon (used for "idle" / "no configured
/// model" hints).
class _InlineNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final OsiaPalette palette;
  const _InlineNote({
    super.key,
    required this.icon,
    required this.text,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: palette.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: palette.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

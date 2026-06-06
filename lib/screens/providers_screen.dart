import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../nav.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';

/// Configure APIs & Providers — the mobile mirror of the PC's settings.
///
/// Reachable from the settings screen (i.e. after a successful connection).
/// On open it pulls the full config snapshot from the PC (`get_config`) and
/// the model list (`get_models`) so every section is pre-filled with what is
/// actually configured. Seven categories:
///   - voice-to-voice (Live API), AI providers, voice providers (TTS),
///     Whisper providers (STT) — API-key editors (with a "configured" badge
///     reflecting `api_keys_set`);
///   - Scheduled Tasks (cron), AI Hierarchy, Personality & Skills — full
///     mirrors of the desktop GUI's panels.
///
/// All writes go to the PC over the live WebSocket (`set_api_key`,
/// `set_setting`, `set_personality`, `set_skill`, `create_skill`,
/// `delete_skill`).
///
/// Design follows the rest of the app: dark #0d0b12 background, violet
/// #c4b5f5 accent, rounded surface cards.

/// Display names for provider ids (mirrors the PC's `PROVIDERS[*].name`).
/// Used by the AI-hierarchy editor to label `"provider:model"` chain entries.
const Map<String, String> _kProviderNames = {
  'anthropic': 'Anthropic',
  'openai': 'OpenAI',
  'deepseek': 'DeepSeek',
  'google': 'Google',
  'xai': 'xAI',
  'groq': 'Groq',
  'ollama': 'Local (Ollama)',
};

// ── Vision capability (WOR-25) ──────────────────────────────────────────
//
// Mirrors of the PC's `osia.models` helpers so the mobile vision-companion UI
// classifies models identically. Vision-capable: Anthropic Claude, Google
// Gemini, xAI Grok and the OpenAI GPT-4o/4.1/5.x/o-series families. Text-only:
// DeepSeek, Groq-hosted Llama/Qwen/Kimi/GPT-OSS, Mistral.

/// Canonical provider display order for the vision-companion pickers (mirrors
/// the AI-providers list / the PC's `_AI_PROVIDER_ORDER`).
const List<String> _kVisionProviderOrder = [
  'anthropic',
  'openai',
  'google',
  'deepseek',
  'xai',
  'groq',
  'ollama',
];

/// Whether `(provider, model)` can process images/screenshots — the heuristic
/// half of the PC's `osia.models.model_has_vision`. The mobile only ever asks
/// about models the server actually exposes, so the registry's exact-match
/// pass isn't needed: the provider/name rules below decide every selector model
/// identically (GPT-4o/Gemini/Claude/Grok → true; DeepSeek/Groq/Llama/Mistral →
/// false).
bool _modelHasVision(String provider, String model) {
  if (model.isEmpty) return false;
  final prov = provider.toLowerCase();
  final lid = model.toLowerCase();
  if (prov == 'anthropic' || prov == 'google' || prov == 'xai') return true;
  if (lid.contains('claude') || lid.contains('gemini') || lid.contains('grok')) {
    return true;
  }
  if (prov == 'openai') {
    const tags = ['gpt-4o', 'gpt-4.1', 'gpt-5', 'gpt-4-turbo', 'o1', 'o3', 'o4'];
    return tags.any((t) => lid.contains(t));
  }
  return false;
}

/// Provider id for a model, preferring an exact match in [models] (the server's
/// `models_list`) and falling back to the same name heuristic as the PC's
/// `osia.models.provider_for_model`. Used to resolve the selected main model's
/// provider before the vision check.
String _providerForModel(String modelId, List<ws.OsiaModel> models) {
  for (final m in models) {
    if (m.id == modelId) return m.provider ?? '';
  }
  final lower = modelId.toLowerCase();
  if (lower.contains('claude')) return 'anthropic';
  if (lower.startsWith('meta-llama/') ||
      lower.startsWith('moonshotai/') ||
      lower.startsWith('qwen/') ||
      lower.startsWith('groq/') ||
      lower.startsWith('playai/') ||
      lower.contains('gpt-oss') ||
      lower.contains('kimi') ||
      lower.endsWith('-versatile') ||
      lower.endsWith('-instant')) {
    return 'groq';
  }
  if (lower.contains('gpt') ||
      lower.startsWith('o1') ||
      lower.startsWith('o3')) {
    return 'openai';
  }
  if (lower.contains('deepseek')) return 'deepseek';
  if (lower.contains('gemini')) return 'google';
  if (lower.contains('grok')) return 'xai';
  return 'ollama';
}

// ── Provider model ──────────────────────────────────────────────────────

/// The four provider categories shown on the landing screen.
enum ProviderCategory { voiceToVoice, ai, tts, stt }

/// One configurable provider entry.
class ProviderEntry {
  /// Brand display name — a proper noun, shown verbatim (not localized).
  final String name;

  /// The `provider` value sent in `set_api_key`. `null` for local
  /// providers that need no key (Kokoro, faster-whisper, Ollama). Several
  /// entries can share one provider id (e.g. "Claude Live" and
  /// "Anthropic" both map to `anthropic`) — the PC reuses the same key.
  final String? apiProvider;

  /// Official page where the user obtains the key. `null` for local
  /// providers.
  final String? apiKeyUrl;

  const ProviderEntry(this.name, this.apiProvider, this.apiKeyUrl);

  /// Local providers run on the PC and require no API key.
  bool get isLocal => apiProvider == null;
}

// Official "Get API key" pages, by provider id.
const String _kUrlAnthropic = 'https://console.anthropic.com/settings/keys';
const String _kUrlOpenAi = 'https://platform.openai.com/api-keys';
const String _kUrlGoogle = 'https://aistudio.google.com/app/apikey';
const String _kUrlDeepSeek = 'https://platform.deepseek.com/api_keys';
const String _kUrlXai = 'https://console.x.ai';
const String _kUrlGroq = 'https://console.groq.com/keys';

/// The providers shown under each category.
List<ProviderEntry> providersFor(ProviderCategory category) {
  switch (category) {
    case ProviderCategory.voiceToVoice:
      return const [
        ProviderEntry('Google Gemini Live', 'google', _kUrlGoogle),
        ProviderEntry('OpenAI Realtime', 'openai', _kUrlOpenAi),
        ProviderEntry('Claude Live', 'anthropic', _kUrlAnthropic),
      ];
    case ProviderCategory.ai:
      return const [
        ProviderEntry('Anthropic', 'anthropic', _kUrlAnthropic),
        ProviderEntry('OpenAI', 'openai', _kUrlOpenAi),
        ProviderEntry('Google', 'google', _kUrlGoogle),
        ProviderEntry('DeepSeek', 'deepseek', _kUrlDeepSeek),
        ProviderEntry('xAI', 'xai', _kUrlXai),
        ProviderEntry('Groq', 'groq', _kUrlGroq),
        ProviderEntry('Ollama', null, null),
      ];
    case ProviderCategory.tts:
      return const [
        ProviderEntry('Kokoro', null, null),
        ProviderEntry('OpenAI TTS', 'openai', _kUrlOpenAi),
        ProviderEntry('Google TTS (Gemini)', 'google', _kUrlGoogle),
      ];
    case ProviderCategory.stt:
      return const [
        ProviderEntry('faster-whisper', null, null),
        ProviderEntry('Groq Whisper', 'groq', _kUrlGroq),
      ];
  }
}

String _categoryTitle(ProviderCategory category, OsiaStrings s) {
  switch (category) {
    case ProviderCategory.voiceToVoice:
      return s.catVoiceToVoice;
    case ProviderCategory.ai:
      return s.catAiProviders;
    case ProviderCategory.tts:
      return s.catTtsProviders;
    case ProviderCategory.stt:
      return s.catSttProviders;
  }
}

IconData _categoryIcon(ProviderCategory category) {
  switch (category) {
    case ProviderCategory.voiceToVoice:
      return Icons.graphic_eq_rounded;
    case ProviderCategory.ai:
      return Icons.smart_toy_rounded;
    case ProviderCategory.tts:
      return Icons.volume_up_rounded;
    case ProviderCategory.stt:
      return Icons.mic_rounded;
  }
}

/// Coerce the server's `api_key_fallbacks` blob (`{provider: [key, ...]}`, part
/// of the config snapshot — WOR-29) into a typed map. Tolerates nulls and
/// unexpected shapes, and drops empty key strings.
Map<String, List<String>> _readFallbacks(Object? raw) {
  final out = <String, List<String>>{};
  if (raw is Map) {
    raw.forEach((key, value) {
      if (value is List) {
        out[key.toString()] = value
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    });
  }
  return out;
}

// ── Landing screen: the four categories ─────────────────────────────────

class ProvidersScreen extends StatefulWidget {
  /// Live connection to the OSIA server, owned by the chat screen and
  /// threaded down so provider editors can push their changes.
  final ws.WebSocketService wsService;

  const ProvidersScreen({super.key, required this.wsService});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  /// Latest config snapshot from the PC. `null` until the first reply lands —
  /// the screen shows a loader until then so nothing is edited "blind".
  ws.ConfigData? _config;

  /// Available models, used by the AI-hierarchy editor. Arrives via the
  /// shared message stream (`models_list`); may land slightly after config.
  List<ws.OsiaModel> _models = const [];

  /// Latest raw API keys from the PC (real key strings, for pre-filling the
  /// editors). Pulled right after each config snapshot lands.
  Map<String, String> _apiKeys = const {};

  /// Optimistic time-format selection ("12h"/"24h"); falls back to the value
  /// in [_config] until the user picks one.
  String? _timeFormatOverride;

  StreamSubscription<ws.ConfigData>? _configSub;
  StreamSubscription<ws.ApiKeysMessage>? _apiKeysSub;
  StreamSubscription<ws.OsiaMessage>? _msgSub;

  @override
  void initState() {
    super.initState();
    // Subscribe BEFORE requesting so the (broadcast, non-replaying) reply
    // can't slip through before we're listening.
    _configSub = widget.wsService.configStream.listen((data) {
      if (mounted) setState(() => _config = data);
      // The PC ships the real API keys on a separate channel; pull them in
      // lockstep with each config snapshot — so editors pre-fill, and badges
      // refresh after an edit (the landing re-pulls config on every pop).
      widget.wsService.sendGetApiKeys();
    });
    _apiKeysSub = widget.wsService.apiKeysStream.listen((msg) {
      if (mounted) setState(() => _apiKeys = msg.keys);
    });
    _msgSub = widget.wsService.messageStream.listen((msg) {
      if (msg is ws.ModelsListMessage && mounted) {
        setState(() => _models = msg.models);
      }
    });
    widget.wsService.sendGetConfig();
    widget.wsService.sendGetModels();
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _apiKeysSub?.cancel();
    _msgSub?.cancel();
    super.dispose();
  }

  /// Current time format, preferring the user's just-made choice over the
  /// (possibly slightly stale) config snapshot. Defaults to 24h.
  String get _timeFormat =>
      _timeFormatOverride ??
      (_config?.settings['time_format']?.toString()) ??
      '24h';

  void _setTimeFormat(String value) {
    setState(() => _timeFormatOverride = value);
    widget.wsService.sendSetSetting('time_format', value);
  }

  void _open(Widget screen) {
    // Re-pull the config when the sub-screen pops so the landing (and the
    // next entry into any section) reflects edits made there — otherwise a
    // stale snapshot could be re-seeded and overwrite server-side changes.
    Navigator.of(context).push(slideFadeRoute(screen)).then((_) {
      if (mounted) widget.wsService.sendGetConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final config = _config;

    // ── Vision companion (WOR-25) ──
    // The selected main model, and whether it can already process images. When
    // it can't, the vision-companion card is shown under the AI tile so the
    // user can pair a vision-capable model. Companions are the vision-capable
    // entries of the server's model list (`models_list` ships them regardless
    // of which providers have a key, so the dropdown is populated even when only
    // a text-only provider is configured).
    final mainModel =
        (config?.settings['selected_model'] ?? '').toString().trim();
    final visionModels =
        _models.where((m) => _modelHasVision(m.provider ?? '', m.id)).toList();
    final showVisionCard = mainModel.isNotEmpty &&
        !_modelHasVision(_providerForModel(mainModel, _models), mainModel) &&
        visionModels.isNotEmpty;

    // Fallback API keys (WOR-29): per-provider ordered backup keys shipped in
    // the config snapshot. Threaded into the AI providers list so each provider
    // editor can manage its own list.
    final apiKeyFallbacks =
        _readFallbacks(config?.settings['api_key_fallbacks']);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(strings.providersTitle),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: config == null
            ? _LoadingBody(palette: palette, label: strings.loading)
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── General (time format) ──
                    _SectionLabel(
                        label: strings.sectionGeneral, palette: palette),
                    _OsiaCard(
                      palette: palette,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              strings.timeFormatLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 150,
                            child: _SegmentedToggle(
                              labels: const ['24 h', '12 h'],
                              index: _timeFormat == '12h' ? 1 : 0,
                              palette: palette,
                              onChanged: (i) =>
                                  _setTimeFormat(i == 1 ? '12h' : '24h'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── The four API-key categories ──
                    for (final category in ProviderCategory.values) ...[
                      _CategoryTile(
                        icon: _categoryIcon(category),
                        title: _categoryTitle(category, strings),
                        // Subtitle is the comma-joined brand list —
                        // language-neutral proper nouns, so it isn't localized.
                        subtitle:
                            providersFor(category).map((p) => p.name).join(', '),
                        palette: palette,
                        onTap: () => _open(
                          _ProviderListScreen(
                            category: category,
                            wsService: widget.wsService,
                            apiKeysSet: config.apiKeysSet,
                            apiKeys: _apiKeys,
                            // Fallback keys (WOR-29) — only the AI providers
                            // screen renders the editor (see _ProviderListScreen).
                            apiKeyFallbacks: apiKeyFallbacks,
                            // Vision companion (WOR-25): rendered as a
                            // sub-section inside the AI providers screen, only
                            // when the selected main model can't process images.
                            // Inert for the other categories.
                            showVisionCard: category == ProviderCategory.ai &&
                                showVisionCard,
                            visionModels: visionModels,
                            visionProvider:
                                (config.settings['vision_provider'] ?? '')
                                    .toString(),
                            visionModel: (config.settings['vision_model'] ?? '')
                                .toString(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Scheduled tasks (cron) ──
                    _CategoryTile(
                      icon: Icons.schedule_rounded,
                      title: strings.catScheduledTasks,
                      subtitle: strings.catScheduledTasksSub,
                      palette: palette,
                      onTap: () => _open(
                        _CronScreen(
                          wsService: widget.wsService,
                          jobs: config.cronJobs,
                          timeFormat: _timeFormat,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── AI hierarchy ──
                    _CategoryTile(
                      icon: Icons.account_tree_rounded,
                      title: strings.catAiHierarchy,
                      subtitle: strings.catAiHierarchySub,
                      palette: palette,
                      onTap: () => _open(
                        _HierarchyScreen(
                          wsService: widget.wsService,
                          config: config,
                          models: _models,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Personality & skills ──
                    _CategoryTile(
                      icon: Icons.auto_awesome_rounded,
                      title: strings.catPersonalitySkills,
                      subtitle: strings.catPersonalitySkillsSub,
                      palette: palette,
                      onTap: () => _open(
                        _PersonalityScreen(
                          wsService: widget.wsService,
                          config: config,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── System status (heartbeat) — 8th tile ──
                    _CategoryTile(
                      icon: Icons.monitor_heart_rounded,
                      title: strings.catSystemStatus,
                      subtitle: strings.catSystemStatusSub,
                      palette: palette,
                      onTap: () => _open(
                        _HeartbeatScreen(
                          wsService: widget.wsService,
                          config: config,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Centered loader shown while the first config snapshot is in flight.
class _LoadingBody extends StatelessWidget {
  final OsiaPalette palette;
  final String label;
  const _LoadingBody({required this.palette, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child:
                CircularProgressIndicator(strokeWidth: 2.4, color: palette.accent),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(fontSize: 13.5, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Vision companion card (WOR-25) ──────────────────────────────────────

/// Inline card shown under the AI providers tile when the selected main model
/// can't process images. Mirrors the desktop's vision-companion row: pick a
/// vision-capable provider + model (persisted via `set_setting`
/// vision_provider / vision_model) and set that provider's API key — the same
/// per-provider key store the main editors use, written with `set_api_key`.
class _VisionCompanionCard extends StatefulWidget {
  final ws.WebSocketService wsService;

  /// Vision-capable companions, already filtered from the server's model list
  /// via [_modelHasVision].
  final List<ws.OsiaModel> visionModels;

  /// Current `vision_provider` / `vision_model` from the config snapshot, used
  /// to pre-select the dropdowns.
  final String initialProvider;
  final String initialModel;

  /// `{provider: hasKey}` for the "configured" check and `{provider: key}` to
  /// pre-fill the key field.
  final Map<String, bool> apiKeysSet;
  final Map<String, String> apiKeys;

  const _VisionCompanionCard({
    required this.wsService,
    required this.visionModels,
    required this.initialProvider,
    required this.initialModel,
    required this.apiKeysSet,
    required this.apiKeys,
  });

  @override
  State<_VisionCompanionCard> createState() => _VisionCompanionCardState();
}

class _VisionCompanionCardState extends State<_VisionCompanionCard> {
  final TextEditingController _keyCtrl = TextEditingController();
  late String _provider;
  late String _model;
  bool _obscured = true;
  bool _hasText = false;
  // The last value we wrote into the key field programmatically. Lets an
  // incoming api_keys refresh re-prefill the field only while the user hasn't
  // edited it (i.e. the current text still equals what we set).
  String _prefilledKey = '';

  /// Vision models grouped by provider.
  Map<String, List<ws.OsiaModel>> get _byProvider {
    final map = <String, List<ws.OsiaModel>>{};
    for (final m in widget.visionModels) {
      map.putIfAbsent(m.provider ?? '', () => <ws.OsiaModel>[]).add(m);
    }
    return map;
  }

  /// Providers with at least one vision model, in canonical order (any unknown
  /// provider appended last, defensively).
  List<String> get _providers {
    final by = _byProvider;
    final ordered = <String>[
      for (final p in _kVisionProviderOrder)
        if (by.containsKey(p)) p,
    ];
    for (final p in by.keys) {
      if (!ordered.contains(p)) ordered.add(p);
    }
    return ordered;
  }

  @override
  void initState() {
    super.initState();
    final providers = _providers;
    _provider = providers.contains(widget.initialProvider)
        ? widget.initialProvider
        : (providers.isNotEmpty ? providers.first : '');
    _model = _resolveModel(_provider, widget.initialModel);
    // Pre-fill the key BEFORE attaching the listener, so this initial set
    // doesn't fire _onKeyChanged (which calls setState) during initState.
    final key = widget.apiKeys[_provider] ?? '';
    _keyCtrl.text = key;
    _prefilledKey = key;
    _hasText = key.trim().isNotEmpty;
    _keyCtrl.addListener(_onKeyChanged);
  }

  @override
  void didUpdateWidget(covariant _VisionCompanionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh models_list can change the companion set — keep the selection
    // valid so the dropdowns never hold an absent value.
    if (!identical(oldWidget.visionModels, widget.visionModels)) {
      final providers = _providers;
      final p = providers.contains(_provider)
          ? _provider
          : (providers.isNotEmpty ? providers.first : '');
      final m = _resolveModel(p, _model);
      if (p != _provider || m != _model) {
        setState(() {
          _provider = p;
          _model = m;
        });
      }
    }
    // Re-prefill the key once the real keys arrive (or after a save refreshes
    // the snapshot), but never clobber an in-progress edit.
    if (!identical(oldWidget.apiKeys, widget.apiKeys) &&
        _keyCtrl.text == _prefilledKey) {
      final key = widget.apiKeys[_provider] ?? '';
      if (key != _keyCtrl.text) {
        setState(() {
          _keyCtrl.text = key;
          _prefilledKey = key;
          _hasText = key.trim().isNotEmpty;
        });
      }
    }
  }

  @override
  void dispose() {
    _keyCtrl.removeListener(_onKeyChanged);
    _keyCtrl.dispose();
    super.dispose();
  }

  void _onKeyChanged() {
    final has = _keyCtrl.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  /// [preferred] if it belongs to [provider]'s vision models, else that
  /// provider's first model (or '' when the provider has none).
  String _resolveModel(String provider, String preferred) {
    final models = _byProvider[provider] ?? const <ws.OsiaModel>[];
    if (models.any((m) => m.id == preferred)) return preferred;
    return models.isNotEmpty ? models.first.id : '';
  }

  void _onProviderChanged(String provider) {
    final model = _resolveModel(provider, '');
    final key = widget.apiKeys[provider] ?? '';
    setState(() {
      _provider = provider;
      _model = model;
      _keyCtrl.text = key;
      _prefilledKey = key;
      _hasText = key.trim().isNotEmpty;
    });
    // Mirror the desktop: switching provider resets the paired model to that
    // provider's first vision model, and both are persisted.
    widget.wsService.sendSetSetting('vision_provider', provider);
    widget.wsService.sendSetSetting('vision_model', model);
  }

  void _onModelChanged(String model) {
    setState(() => _model = model);
    widget.wsService.sendSetSetting('vision_model', model);
  }

  void _saveKey() {
    final key = _keyCtrl.text.trim();
    if (_provider.isEmpty || key.isEmpty) return;
    widget.wsService.sendSetApiKey(_provider, key);
    // Refresh the snapshot so the "configured" check reflects the new key.
    widget.wsService.sendGetConfig();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(OsiaL10n.of(context).apiKeySaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    final providers = _providers;
    final byProvider = _byProvider;
    // Clamp the rendered values so DropdownButton always finds its value among
    // the items (its "exactly one match" invariant).
    final provider = providers.contains(_provider)
        ? _provider
        : (providers.isNotEmpty ? providers.first : '');
    final models = byProvider[provider] ?? const <ws.OsiaModel>[];
    final modelId = models.any((m) => m.id == _model)
        ? _model
        : (models.isNotEmpty ? models.first.id : '');
    final keyConfigured = widget.apiKeysSet[provider] ?? false;

    return _OsiaCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Heading
          Row(
            children: [
              Icon(Icons.visibility_rounded, size: 18, color: palette.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.visionAssociated,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Hint (mirrors the PC's sub-label): clarifies when pairing a vision
          // model helps — i.e. when the main model is text-only.
          Text(
            strings.visionHint,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF9D9AAD),
            ),
          ),
          const SizedBox(height: 16),
          // Provider
          _FieldLabel(strings.visionProvider, palette),
          const SizedBox(height: 8),
          _dropdown<String>(
            palette: palette,
            value: provider.isNotEmpty ? provider : null,
            items: [
              for (final p in providers)
                DropdownMenuItem(
                  value: p,
                  child: Text(
                    _kProviderNames[p] ?? p,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 14.5, color: palette.textPrimary),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null && v != _provider) _onProviderChanged(v);
            },
          ),
          const SizedBox(height: 14),
          // Model
          _FieldLabel(strings.visionModel, palette),
          const SizedBox(height: 8),
          _dropdown<String>(
            palette: palette,
            value: modelId.isNotEmpty ? modelId : null,
            items: [
              for (final m in models)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(
                    m.label,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 14.5, color: palette.textPrimary),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null && v != _model) _onModelChanged(v);
            },
          ),
          const SizedBox(height: 14),
          // API key for the chosen vision provider
          _FieldLabel(strings.apiKey, palette),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyCtrl,
                  obscureText: _obscured,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _hasText ? _saveKey() : null,
                  cursorColor: palette.accent,
                  style: TextStyle(color: palette.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: palette.surfaceElevated,
                    hintText: keyConfigured
                        ? strings.apiKeyReplaceHint
                        : strings.apiKeyHint,
                    hintStyle:
                        TextStyle(color: palette.textMuted, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: palette.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: palette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: palette.accent, width: 1.4),
                    ),
                    suffixIcon: IconButton(
                      tooltip:
                          _obscured ? strings.showApiKey : strings.hideApiKey,
                      onPressed: () => setState(() => _obscured = !_obscured),
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 18,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _hasText ? _saveKey : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor:
                        palette.isDark ? palette.background : Colors.white,
                    disabledBackgroundColor:
                        palette.accent.withValues(alpha: 0.4),
                    disabledForegroundColor:
                        (palette.isDark ? palette.background : Colors.white)
                            .withValues(alpha: 0.7),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  child: Text(strings.save),
                ),
              ),
            ],
          ),
          // "Configured" check — the chosen provider already has a key on the PC.
          if (keyConfigured) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 15, color: palette.accent),
                const SizedBox(width: 8),
                Text(
                  strings.apiKeyConfigured,
                  style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Styled dropdown matching the screen's inset fields (elevated fill so it
  /// reads against the card's surface).
  Widget _dropdown<T>({
    required OsiaPalette palette,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: palette.accent),
          style: TextStyle(color: palette.textPrimary, fontSize: 14.5),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Provider list for one category ──────────────────────────────────────

class _ProviderListScreen extends StatelessWidget {
  final ProviderCategory category;
  final ws.WebSocketService wsService;

  /// `{provider: hasKey}` from the latest config snapshot, used to show a
  /// "configured" check next to providers whose key is already set on the PC.
  final Map<String, bool> apiKeysSet;

  /// `{provider: key}` real keys, used to pre-fill the editor. May be empty if
  /// the keys haven't arrived yet (the editor then just shows a placeholder).
  final Map<String, String> apiKeys;

  /// Per-provider fallback API keys (WOR-29), `{provider: [key, ...]}` from the
  /// config snapshot. Only the AI providers screen surfaces the editor — each
  /// AI provider's config screen gets a "fallback keys" sub-section seeded from
  /// this map. Empty / unused for the other categories.
  final Map<String, List<String>> apiKeyFallbacks;

  /// Vision companion (WOR-25). When [showVisionCard] is true — the AI category
  /// and a selected main model that can't process images — a "paired vision
  /// model" sub-section renders below the provider list. The remaining fields
  /// feed it: the vision-capable models, and the current `vision_provider` /
  /// `vision_model` for pre-selection. All inert (card unbuilt) otherwise.
  final bool showVisionCard;
  final List<ws.OsiaModel> visionModels;
  final String visionProvider;
  final String visionModel;

  const _ProviderListScreen({
    required this.category,
    required this.wsService,
    required this.apiKeysSet,
    required this.apiKeys,
    this.apiKeyFallbacks = const {},
    this.showVisionCard = false,
    this.visionModels = const [],
    this.visionProvider = '',
    this.visionModel = '',
  });

  bool _isKeySet(ProviderEntry entry) =>
      entry.apiProvider != null && (apiKeysSet[entry.apiProvider] ?? false);

  /// The stored key for [entry]'s provider, or null when unknown / local.
  String? _keyFor(ProviderEntry entry) =>
      entry.apiProvider == null ? null : apiKeys[entry.apiProvider];

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final providers = providersFor(category);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(_categoryTitle(category, strings)),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OsiaCard(
                palette: palette,
                child: Column(
                  children: [
                    for (var i = 0; i < providers.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: palette.border.withValues(alpha: 0.5),
                          indent: 16,
                        ),
                      _ProviderRow(
                        entry: providers[i],
                        localLabel: strings.localLabel,
                        keyConfigured: _isKeySet(providers[i]),
                        palette: palette,
                        onTap: () => Navigator.of(context).push(
                          slideFadeRoute(
                            _ProviderConfigScreen(
                              entry: providers[i],
                              wsService: wsService,
                              keyConfigured: _isKeySet(providers[i]),
                              initialKey: _keyFor(providers[i]),
                              // Fallback keys (WOR-29): only in the AI flow, and
                              // only for providers that take a key (not local).
                              showFallbackKeys:
                                  category == ProviderCategory.ai &&
                                      providers[i].apiProvider != null,
                              fallbackKeys: apiKeyFallbacks[
                                      providers[i].apiProvider] ??
                                  const [],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // ── Vision companion (WOR-25) ──
              // A clearly separated sub-section under the AI providers list,
              // shown only when the selected main model can't process images.
              // Same provider + model + key controls as before — relocated here
              // from the providers landing screen.
              if (showVisionCard) ...[
                const SizedBox(height: 20),
                _VisionCompanionCard(
                  wsService: wsService,
                  visionModels: visionModels,
                  initialProvider: visionProvider,
                  initialModel: visionModel,
                  apiKeysSet: apiKeysSet,
                  apiKeys: apiKeys,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── API-key editor for one provider ─────────────────────────────────────

class _ProviderConfigScreen extends StatefulWidget {
  final ProviderEntry entry;
  final ws.WebSocketService wsService;

  /// Whether the PC has a key stored for this provider (from `api_keys_set`).
  /// Drives the "configured" badge and the "remove key" action.
  final bool keyConfigured;

  /// The real key currently stored on the PC, used to pre-fill the field
  /// (masked by default, revealed with the eye toggle). Null/empty when no key
  /// is set yet (or not yet received) — the field then shows a placeholder.
  final String? initialKey;

  /// Fallback keys (WOR-29). When [showFallbackKeys] is true (AI providers flow,
  /// non-local provider) a "fallback keys" sub-section renders below the main
  /// key editor; [fallbackKeys] seeds its list from the config snapshot.
  final bool showFallbackKeys;
  final List<String> fallbackKeys;

  const _ProviderConfigScreen({
    required this.entry,
    required this.wsService,
    required this.keyConfigured,
    this.initialKey,
    this.showFallbackKeys = false,
    this.fallbackKeys = const [],
  });

  @override
  State<_ProviderConfigScreen> createState() => _ProviderConfigScreenState();
}

class _ProviderConfigScreenState extends State<_ProviderConfigScreen> {
  final TextEditingController _keyCtrl = TextEditingController();
  bool _obscured = true;
  // Drives the Save button's enabled state — only a non-empty key saves.
  bool _hasText = false;
  // Local mirror of widget.keyConfigured so the "configured" badge can flip to
  // unconfigured immediately after a delete (optimistic), before the next
  // config snapshot lands.
  late bool _configured;

  @override
  void initState() {
    super.initState();
    _configured = widget.keyConfigured;
    // Pre-fill with the real key when the PC sent one. It stays masked until
    // the user taps the eye toggle; _hasText keeps the Save button enabled.
    final initial = widget.initialKey ?? '';
    _keyCtrl.text = initial;
    _hasText = initial.trim().isNotEmpty;
    _keyCtrl.addListener(() {
      final has = _keyCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    if (!mounted) return;
    _keyCtrl.text = text;
  }

  Future<void> _openKeyPage() async {
    final url = widget.entry.apiKeyUrl;
    if (url == null) return;
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(OsiaL10n.of(context).linkOpenFailed)),
      );
    }
  }

  void _save() {
    final provider = widget.entry.apiProvider;
    final key = _keyCtrl.text.trim();
    if (provider == null || key.isEmpty) return;
    widget.wsService.sendSetApiKey(provider, key);
    // Refresh the snapshot so the landing screen's "configured" badges
    // reflect the new key on the next visit.
    widget.wsService.sendGetConfig();
    final strings = OsiaL10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.apiKeySaved)),
    );
    Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final provider = widget.entry.apiProvider;
    if (provider == null) return;
    final strings = OsiaL10n.of(context);
    final palette = OsiaTheme.of(context);
    // Confirm before deleting — the key is wiped from the PC entirely.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.removeApiKey),
        content: Text(
          widget.entry.name,
          style: TextStyle(color: palette.textMuted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text(strings.cancel, style: TextStyle(color: palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.delete, style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Dedicated delete path — removes the key entirely on the PC (not the
    // set_api_key empty-string path).
    widget.wsService.sendDeleteApiKey(provider);
    // Refresh the snapshot so the landing's badges reflect the removal.
    widget.wsService.sendGetConfig();
    // Optimistic UI: clear the field and flip the "configured" badge now,
    // staying on screen so the change is visible immediately.
    setState(() {
      _keyCtrl.clear();
      _configured = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.apiKeyRemoved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(widget.entry.name),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: widget.entry.isLocal
              ? _buildLocalNotice(palette, strings)
              : _buildKeyEditor(palette, strings),
        ),
      ),
    );
  }

  Widget _buildLocalNotice(OsiaPalette palette, OsiaStrings strings) {
    return _OsiaCard(
      palette: palette,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.computer_rounded, size: 18, color: palette.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              strings.localProviderNoKey,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyEditor(OsiaPalette palette, OsiaStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Configured" banner — the PC has a key set for this provider.
        if (_configured) ...[
          _OsiaCard(
            palette: palette,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: palette.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.apiKeyConfigured,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          strings.apiKey,
          style: TextStyle(fontSize: 13, color: palette.textMuted),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _keyCtrl,
          obscureText: _obscured,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _hasText ? _save() : null,
          cursorColor: palette.accent,
          style: TextStyle(color: palette.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.surface,
            hintText: _configured
                ? strings.apiKeyReplaceHint
                : strings.apiKeyHint,
            hintStyle: TextStyle(color: palette.textMuted, fontSize: 14.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: palette.accent, width: 1.4),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: _obscured ? strings.showApiKey : strings.hideApiKey,
                  onPressed: () => setState(() => _obscured = !_obscured),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 18,
                    color: palette.textMuted,
                  ),
                ),
                IconButton(
                  onPressed: _pasteKey,
                  icon: Icon(
                    Icons.content_paste_rounded,
                    size: 18,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // "Get API key" — opens the provider's official key page.
        if (widget.entry.apiKeyUrl != null)
          OutlinedButton.icon(
            onPressed: _openKeyPage,
            icon: Icon(Icons.open_in_new_rounded, size: 17, color: palette.accent),
            label: Text(strings.getApiKey),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.accent,
              side: BorderSide(color: palette.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _hasText ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.isDark ? palette.background : Colors.white,
              disabledBackgroundColor: palette.accent.withValues(alpha: 0.4),
              disabledForegroundColor:
                  (palette.isDark ? palette.background : Colors.white)
                      .withValues(alpha: 0.7),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
            ),
            child: Text(strings.save),
          ),
        ),
        // "Remove key" — only when a key is currently stored on the PC.
        if (_configured) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _remove,
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: palette.error),
            label: Text(
              strings.removeApiKey,
              style: TextStyle(color: palette.error, fontSize: 14),
            ),
          ),
        ],
        // ── Fallback keys (WOR-29) ──
        // Backup keys the agent rotates to when the primary is rate-limited or
        // exhausted. A self-contained, optimistically-updated sub-section.
        if (widget.showFallbackKeys) ...[
          const SizedBox(height: 28),
          _FallbackKeysSection(
            wsService: widget.wsService,
            provider: widget.entry.apiProvider!,
            initialKeys: widget.fallbackKeys,
          ),
        ],
      ],
    );
  }
}

// ── API fallback keys (WOR-29) ──────────────────────────────────────────

/// Per-provider editor for the ordered list of backup API keys
/// (`settings.json` `api_key_fallbacks[provider]`). The agent rotates through
/// these when the primary key is rate-limited or exhausted. Rendered as a
/// sub-section under a provider's key editor, inside the AI-providers flow.
///
/// Each key is masked by default (eye toggle to reveal), editable in place, or
/// removable behind a confirmation. "Add" appends a new key. Every action
/// updates the local list optimistically and writes to the PC over the
/// WebSocket: `set_api_fallback_key` (index ≥ 0 replaces a slot, -1 appends)
/// and `delete_api_fallback_key`.
class _FallbackKeysSection extends StatefulWidget {
  final ws.WebSocketService wsService;
  final String provider;
  final List<String> initialKeys;

  const _FallbackKeysSection({
    required this.wsService,
    required this.provider,
    required this.initialKeys,
  });

  @override
  State<_FallbackKeysSection> createState() => _FallbackKeysSectionState();
}

class _FallbackKeysSectionState extends State<_FallbackKeysSection> {
  /// Local, optimistically-updated copy of the provider's fallback keys.
  late List<String> _keys;

  /// Indices currently shown in clear text (the rest stay masked).
  final Set<int> _revealed = {};

  /// Which slot the inline editor targets: null = closed, -1 = adding a new
  /// key, ≥ 0 = editing that slot. Only one editor is open at a time.
  int? _editIndex;
  final TextEditingController _editCtrl = TextEditingController();
  bool _editObscured = true;
  bool _editHasText = false;

  @override
  void initState() {
    super.initState();
    _keys = List<String>.from(widget.initialKeys);
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  void _openEditor(int index) {
    final initial = index >= 0 ? _keys[index] : '';
    setState(() {
      _editIndex = index;
      _editObscured = true;
      _editCtrl.text = initial;
      _editHasText = initial.trim().isNotEmpty;
    });
  }

  void _closeEditor() {
    FocusScope.of(context).unfocus();
    setState(() => _editIndex = null);
  }

  void _saveEditor() {
    final index = _editIndex;
    if (index == null) return;
    final key = _editCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() {
      if (index == -1) {
        _keys.add(key);
      } else if (index >= 0 && index < _keys.length) {
        _keys[index] = key;
      }
      _editIndex = null;
    });
    // -1 appends on the server; an in-range index replaces that slot.
    widget.wsService.sendSetApiFallbackKey(widget.provider, index, key);
    // Refresh the snapshot so the landing reflects the change on the next visit.
    widget.wsService.sendGetConfig();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(OsiaL10n.of(context).apiKeySaved)),
    );
  }

  Future<void> _delete(int index) async {
    final strings = OsiaL10n.of(context);
    final palette = OsiaTheme.of(context);
    // Confirm before deleting — the key is wiped from the PC.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteFallbackKey),
        content: Text(
          strings.fallbackKeyIndex.replaceFirst('{n}', '${index + 1}'),
          style: TextStyle(color: palette.textMuted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text(strings.cancel, style: TextStyle(color: palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.delete, style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _keys.removeAt(index);
      // Row indices shift after a removal — drop reveal state so a masked row
      // can't surface the wrong key in clear text.
      _revealed.clear();
      _editIndex = null;
    });
    widget.wsService.sendDeleteApiFallbackKey(widget.provider, index);
    widget.wsService.sendGetConfig();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.apiKeyRemoved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: strings.fallbackKeys, palette: palette),
        if (_keys.isNotEmpty)
          _OsiaCard(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _keys.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 20,
                      color: palette.border.withValues(alpha: 0.5),
                    ),
                  _editIndex == i
                      ? _buildEditor(palette, strings, i)
                      : _buildKeyRow(palette, strings, i),
                ],
              ],
            ),
          ),
        const SizedBox(height: 10),
        // "Add a fallback key" — an inline editor opens in place of the button.
        _editIndex == -1
            ? _OsiaCard(
                palette: palette,
                child: _buildEditor(palette, strings, -1),
              )
            : _AddButton(
                label: strings.addFallbackKey,
                palette: palette,
                onTap: () => _openEditor(-1),
              ),
      ],
    );
  }

  /// One stored key: index chip, masked/revealed value, and reveal/edit/delete
  /// actions.
  Widget _buildKeyRow(OsiaPalette palette, OsiaStrings strings, int i) {
    final revealed = _revealed.contains(i);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border, width: 0.6),
          ),
          child: Text(
            strings.fallbackKeyIndex.replaceFirst('{n}', '${i + 1}'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            // Mask with a fixed run of dots so the key's length never leaks.
            revealed ? _keys[i] : '••••••••••••',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: palette.textPrimary,
              letterSpacing: revealed ? 0 : 2,
            ),
          ),
        ),
        _MiniIconButton(
          icon: revealed
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          tooltip: revealed ? strings.hideApiKey : strings.showApiKey,
          palette: palette,
          onTap: () => setState(() =>
              revealed ? _revealed.remove(i) : _revealed.add(i)),
        ),
        _MiniIconButton(
          icon: Icons.edit_rounded,
          tooltip: strings.editFallbackKey,
          palette: palette,
          onTap: () => _openEditor(i),
        ),
        _MiniIconButton(
          icon: Icons.delete_outline_rounded,
          tooltip: strings.deleteFallbackKey,
          palette: palette,
          danger: true,
          onTap: () => _delete(i),
        ),
      ],
    );
  }

  /// Inline add/edit field for a fallback key ([index] == -1 when adding).
  Widget _buildEditor(OsiaPalette palette, OsiaStrings strings, int index) {
    final isNew = index == -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(
          isNew ? strings.addFallbackKey : strings.editFallbackKey,
          palette,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _editCtrl,
          obscureText: _editObscured,
          autocorrect: false,
          enableSuggestions: false,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (v) {
            final has = v.trim().isNotEmpty;
            if (has != _editHasText) setState(() => _editHasText = has);
          },
          onSubmitted: (_) => _editHasText ? _saveEditor() : null,
          cursorColor: palette.accent,
          style: TextStyle(color: palette.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.surfaceElevated,
            hintText: strings.apiKeyHint,
            hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.accent, width: 1.4),
            ),
            suffixIcon: IconButton(
              tooltip: _editObscured ? strings.showApiKey : strings.hideApiKey,
              onPressed: () => setState(() => _editObscured = !_editObscured),
              icon: Icon(
                _editObscured
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 18,
                color: palette.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _closeEditor,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textMuted,
                    side: BorderSide(color: palette.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w500),
                  ),
                  child: Text(strings.cancel),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _editHasText ? _saveEditor : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor:
                        palette.isDark ? palette.background : Colors.white,
                    disabledBackgroundColor:
                        palette.accent.withValues(alpha: 0.4),
                    disabledForegroundColor:
                        (palette.isDark ? palette.background : Colors.white)
                            .withValues(alpha: 0.7),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  child: Text(strings.save),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Reusable primitives (mirror the settings-screen aesthetic) ──────────

class _OsiaCard extends StatelessWidget {
  final Widget child;
  final OsiaPalette palette;
  final EdgeInsets padding;
  const _OsiaCard({
    required this.child,
    required this.palette,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border, width: 0.6),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final OsiaPalette palette;
  final VoidCallback onTap;
  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _OsiaCard(
      palette: palette,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accent.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 19, color: palette.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: palette.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  final ProviderEntry entry;
  final String localLabel;

  /// Whether the PC has a key stored for this provider — shows a check.
  final bool keyConfigured;
  final OsiaPalette palette;
  final VoidCallback onTap;
  const _ProviderRow({
    required this.entry,
    required this.localLabel,
    required this.keyConfigured,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.name,
                style: TextStyle(fontSize: 14.5, color: palette.textPrimary),
              ),
            ),
            if (entry.isLocal) ...[
              Text(
                localLabel,
                style: TextStyle(fontSize: 12, color: palette.textMuted),
              ),
              const SizedBox(width: 8),
            ] else if (keyConfigured) ...[
              Icon(Icons.check_circle_rounded, size: 16, color: palette.accent),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Scheduled tasks (cron)
// ══════════════════════════════════════════════════════════════════════════

/// Lists the PC's cron jobs and lets the user add / edit / toggle / delete
/// them. The local list is the source of truth; every change rewrites the
/// whole `cron_jobs` array via `set_setting` (mirrors the desktop GUI).
class _CronScreen extends StatefulWidget {
  final ws.WebSocketService wsService;
  final List<Map<String, dynamic>> jobs;
  // Current time format ('12h'/'24h'), resolved by the parent. Display-only:
  // the schedule strings saved to the PC stay canonical 24h.
  final String timeFormat;
  const _CronScreen(
      {required this.wsService, required this.jobs, required this.timeFormat});

  @override
  State<_CronScreen> createState() => _CronScreenState();
}

class _CronScreenState extends State<_CronScreen> {
  late List<Map<String, dynamic>> _jobs;

  @override
  void initState() {
    super.initState();
    // Deep-ish copy so edits don't mutate the parent's snapshot in place.
    _jobs = widget.jobs.map((j) => Map<String, dynamic>.from(j)).toList();
  }

  void _persist() => widget.wsService.sendSetSetting('cron_jobs', _jobs);

  void _toggle(int index, bool value) {
    setState(() => _jobs[index]['enabled'] = value);
    _persist();
  }

  void _delete(int index) {
    setState(() => _jobs.removeAt(index));
    _persist();
  }

  Future<void> _edit({int? index}) async {
    final existing = index != null ? _jobs[index] : null;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      slideFadeRoute(
        _CronEditScreen(
          initialJob: existing,
          timeFormat: widget.timeFormat,
          wsService: widget.wsService,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _jobs[index] = result;
      } else {
        _jobs.add(result);
      }
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(strings.cronTitle),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.cronSubtitle,
                style: TextStyle(
                    fontSize: 12.5, height: 1.4, color: palette.textMuted),
              ),
              const SizedBox(height: 16),
              if (_jobs.isEmpty)
                _EmptyHint(label: strings.cronEmpty, palette: palette)
              else
                for (var i = 0; i < _jobs.length; i++) ...[
                  _CronRow(
                    job: _jobs[i],
                    palette: palette,
                    strings: strings,
                    timeFormat: widget.timeFormat,
                    onToggle: (v) => _toggle(i, v),
                    onDelete: () => _delete(i),
                    onTap: () => _edit(index: i),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 6),
              _AddButton(
                label: strings.cronAddTask,
                palette: palette,
                onTap: () => _edit(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CronRow extends StatelessWidget {
  final Map<String, dynamic> job;
  final OsiaPalette palette;
  final OsiaStrings strings;
  final String timeFormat;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  const _CronRow({
    required this.job,
    required this.palette,
    required this.strings,
    required this.timeFormat,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final task = (job['task'] ?? '').toString().trim();
    final schedule = (job['schedule'] ?? '').toString();
    final enabled = job['enabled'] == true;
    return _OsiaCard(
      palette: palette,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.isEmpty ? strings.cronTaskHint : task,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: task.isEmpty
                            ? palette.textMuted
                            : palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _cronSummary(schedule, strings, timeFormat),
                      style: TextStyle(fontSize: 12, color: palette.accent),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: palette.accent,
                activeThumbColor:
                    palette.isDark ? palette.background : Colors.white,
                inactiveTrackColor: palette.border.withValues(alpha: 0.5),
                inactiveThumbColor: palette.textMuted,
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: strings.delete,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 20, color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add / edit form for a single cron job. Returns the job map via
/// `Navigator.pop`, or null on cancel. Composes the canonical schedule
/// string the PC's `osia.cron` parser expects.
class _CronEditScreen extends StatefulWidget {
  final Map<String, dynamic>? initialJob;
  // Display-only time format ('12h'/'24h'); the picker still stores 24h.
  final String timeFormat;
  // Live connection — used to fetch the conversation list for the "linked
  // conversation" picker (WOR-24). Read-only here; no writes happen until save.
  final ws.WebSocketService wsService;
  const _CronEditScreen({
    this.initialJob,
    required this.timeFormat,
    required this.wsService,
  });

  @override
  State<_CronEditScreen> createState() => _CronEditScreenState();
}

class _CronEditScreenState extends State<_CronEditScreen> {
  final TextEditingController _taskCtrl = TextEditingController();
  final TextEditingController _intervalCtrl = TextEditingController(text: '5');
  _CronType _type = _CronType.repeat;
  _RepeatUnit _unit = _RepeatUnit.minutes;
  TimeOfDay? _dailyTime;
  DateTime? _onceDate;
  TimeOfDay? _onceTime;
  // Carried through unchanged (the row toggle owns the on/off state).
  bool _enabled = true;

  // ── Linked conversation (WOR-24) ──
  // Selected conversation id, or null for "new conversation". Pre-filled from
  // the job's existing conversation_id and written back on save.
  String? _conversationId;
  // The list fetched from the PC; null while still loading (drives the loader).
  List<ws.ConversationItem>? _conversations;
  StreamSubscription<ws.ConversationsListMessage>? _convSub;

  @override
  void initState() {
    super.initState();
    final job = widget.initialJob;
    if (job != null) {
      _taskCtrl.text = (job['task'] ?? '').toString();
      _enabled = job['enabled'] == true;
      // Pre-fill the linked conversation (null/empty → "new conversation").
      final cid = job['conversation_id'];
      if (cid is String && cid.isNotEmpty) _conversationId = cid;
      final spec = _parseCron((job['schedule'] ?? '').toString());
      if (spec != null) {
        if (spec.isOnce) {
          _type = _CronType.once;
          _onceDate = DateTime(spec.year!, spec.month!, spec.day!);
          _onceTime = TimeOfDay(hour: spec.hour, minute: spec.minute);
        } else if (spec.unit == _RepeatUnit.daily) {
          _unit = _RepeatUnit.daily;
          _dailyTime = TimeOfDay(hour: spec.hour, minute: spec.minute);
        } else {
          _unit = spec.unit;
          _intervalCtrl.text = '${spec.interval}';
        }
      }
    }
    // Subscribe BEFORE requesting so the (broadcast, non-replaying) reply can't
    // slip through before we're listening, then pull the conversation list.
    _convSub = widget.wsService.conversationsListStream.listen((msg) {
      if (mounted) setState(() => _conversations = msg.conversations);
    });
    widget.wsService.sendGetConversations();
  }

  @override
  void dispose() {
    _convSub?.cancel();
    _taskCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _onceDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) setState(() => _onceDate = picked);
  }

  Future<void> _pickTime(bool once) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (once ? _onceTime : _dailyTime) ??
          const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() {
        if (once) {
          _onceTime = picked;
        } else {
          _dailyTime = picked;
        }
      });
    }
  }

  /// Compose the canonical schedule string, or null if the inputs are
  /// incomplete/invalid.
  String? _composeSchedule() {
    if (_type == _CronType.once) {
      final d = _onceDate;
      final t = _onceTime;
      if (d == null || t == null) return null;
      return 'once:${_d4(d.year)}-${_d2(d.month)}-${_d2(d.day)}'
          'T${_d2(t.hour)}:${_d2(t.minute)}';
    }
    if (_unit == _RepeatUnit.daily) {
      final t = _dailyTime;
      if (t == null) return null;
      return 'at ${_d2(t.hour)}:${_d2(t.minute)}';
    }
    final n = int.tryParse(_intervalCtrl.text.trim());
    if (n == null || n <= 0) return null;
    final unit = switch (_unit) {
      _RepeatUnit.minutes => 'minutes',
      _RepeatUnit.hours => 'hours',
      _RepeatUnit.days => 'days',
      _RepeatUnit.daily => 'minutes', // unreachable (handled above)
    };
    return 'every $n $unit';
  }

  void _save() {
    final strings = OsiaL10n.of(context);
    final task = _taskCtrl.text.trim();
    final schedule = _composeSchedule();
    if (task.isEmpty || schedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.cronInvalid)),
      );
      return;
    }
    final job = <String, dynamic>{
      // Preserve any other server-side fields; conversation_id below overrides
      // the preserved value with the user's current selection (WOR-24).
      ...?widget.initialJob,
      'task': task,
      'schedule': schedule,
      'enabled': _enabled,
      // null when "Aucune (nouvelle conversation)" is chosen — matches the PC's
      // `{..., "conversation_id": null}` job shape.
      'conversation_id': _conversationId,
    };
    Navigator.of(context).pop(job);
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final editing = widget.initialJob != null;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(editing ? strings.cronEditTask : strings.cronAddTask),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel(strings.cronTaskLabel, palette),
              const SizedBox(height: 8),
              _OsiaTextField(
                controller: _taskCtrl,
                hint: strings.cronTaskHint,
                palette: palette,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _FieldLabel(strings.cronType, palette),
              const SizedBox(height: 8),
              _SegmentedToggle(
                labels: [strings.cronTypeRepeat, strings.cronTypeOnce],
                index: _type == _CronType.repeat ? 0 : 1,
                palette: palette,
                onChanged: (i) => setState(
                    () => _type = i == 0 ? _CronType.repeat : _CronType.once),
              ),
              const SizedBox(height: 20),
              if (_type == _CronType.repeat)
                ..._buildRepeat(palette, strings)
              else
                ..._buildOnce(palette, strings),
              const SizedBox(height: 24),
              _buildConversationField(palette, strings),
              const SizedBox(height: 28),
              _PrimaryButton(
                  label: strings.save, onTap: _save, palette: palette),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRepeat(OsiaPalette palette, OsiaStrings strings) {
    return [
      _FieldLabel(strings.cronFrequency, palette),
      const SizedBox(height: 8),
      _OsiaCard(
        palette: palette,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_RepeatUnit>(
            value: _unit,
            isExpanded: true,
            dropdownColor: palette.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: palette.accent),
            style: TextStyle(color: palette.textPrimary, fontSize: 14.5),
            items: [
              DropdownMenuItem(
                  value: _RepeatUnit.minutes,
                  child: Text(strings.cronUnitMinutes)),
              DropdownMenuItem(
                  value: _RepeatUnit.hours, child: Text(strings.cronUnitHours)),
              DropdownMenuItem(
                  value: _RepeatUnit.days, child: Text(strings.cronUnitDays)),
              DropdownMenuItem(
                  value: _RepeatUnit.daily, child: Text(strings.cronModeDaily)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _unit = v);
            },
          ),
        ),
      ),
      const SizedBox(height: 14),
      if (_unit == _RepeatUnit.daily)
        _PickerButton(
          icon: Icons.access_time_rounded,
          label: strings.cronTime,
          value: _dailyTime == null
              ? null
              : _formatCronTime(_hmOfDay(_dailyTime!), widget.timeFormat),
          palette: palette,
          onTap: () => _pickTime(false),
        )
      else
        Row(
          children: [
            SizedBox(
              width: 110,
              child: _OsiaTextField(
                controller: _intervalCtrl,
                hint: '5',
                palette: palette,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _unitWord(strings),
                style: TextStyle(fontSize: 14, color: palette.textMuted),
              ),
            ),
          ],
        ),
    ];
  }

  List<Widget> _buildOnce(OsiaPalette palette, OsiaStrings strings) {
    return [
      Row(
        children: [
          Expanded(
            child: _PickerButton(
              icon: Icons.calendar_today_rounded,
              label: strings.cronDate,
              value: _onceDate == null ? null : _dateStr(_onceDate!),
              palette: palette,
              onTap: _pickDate,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PickerButton(
              icon: Icons.access_time_rounded,
              label: strings.cronTime,
              value: _onceTime == null
                  ? null
                  : _formatCronTime(_hmOfDay(_onceTime!), widget.timeFormat),
              palette: palette,
              onTap: () => _pickTime(true),
            ),
          ),
        ],
      ),
    ];
  }

  String _unitWord(OsiaStrings s) => switch (_unit) {
        _RepeatUnit.minutes => s.cronUnitMinutes,
        _RepeatUnit.hours => s.cronUnitHours,
        _RepeatUnit.days => s.cronUnitDays,
        _RepeatUnit.daily => s.cronModeDaily,
      };

  /// "Linked conversation" picker (WOR-24): a loader until the PC's list lands,
  /// then a dropdown of "None (new conversation)" + every conversation by title.
  Widget _buildConversationField(OsiaPalette palette, OsiaStrings strings) {
    final convs = _conversations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(strings.cronLinkedConversation, palette),
        const SizedBox(height: 8),
        if (convs == null)
          // Still in flight — small inline loader so nothing is picked "blind".
          _OsiaCard(
            palette: palette,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: palette.accent),
                ),
                const SizedBox(width: 12),
                Text(
                  strings.cronLoadingConversations,
                  style: TextStyle(fontSize: 14, color: palette.textMuted),
                ),
              ],
            ),
          )
        else
          _OsiaCard(
            palette: palette,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _conversationId,
                isExpanded: true,
                dropdownColor: palette.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: palette.accent),
                style: TextStyle(color: palette.textPrimary, fontSize: 14.5),
                items: _conversationItems(convs, strings, palette),
                onChanged: (v) => setState(() => _conversationId = v),
              ),
            ),
          ),
      ],
    );
  }

  /// Build the dropdown items: a leading "None" (null value) entry, then each
  /// conversation by title. A stored id that is no longer in the list (deleted
  /// conversation) is kept as a trailing entry so the dropdown stays valid and
  /// the link isn't silently dropped — mirrors the hierarchy editor.
  List<DropdownMenuItem<String?>> _conversationItems(
      List<ws.ConversationItem> convs,
      OsiaStrings strings,
      OsiaPalette palette) {
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Text(
          strings.cronNoConversation,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14.5, color: palette.textPrimary),
        ),
      ),
    ];
    for (final c in convs) {
      // A conversation with no id can't be linked, and two empty-id entries
      // would give the dropdown two items with the same value '' — which
      // violates DropdownButton's "exactly one item per value" invariant the
      // moment one is selected. Skip them outright.
      if (c.id.isEmpty) continue;
      final title = c.title.trim().isEmpty ? strings.untitled : c.title;
      items.add(DropdownMenuItem<String?>(
        value: c.id,
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14.5, color: palette.textPrimary),
        ),
      ));
    }
    final id = _conversationId;
    if (id != null && !convs.any((c) => c.id == id)) {
      items.add(DropdownMenuItem<String?>(
        value: id,
        child: Text(
          strings.untitled,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14.5, color: palette.textMuted),
        ),
      ));
    }
    return items;
  }
}

// ── Cron schedule parsing/formatting (mirrors osia.cron) ────────────────

enum _CronType { repeat, once }

enum _RepeatUnit { minutes, hours, days, daily }

/// Parsed view of a canonical schedule string.
class _CronSpec {
  final bool isOnce;
  final _RepeatUnit unit;
  final int interval; // for minutes/hours/days
  final int hour;
  final int minute;
  final int? year;
  final int? month;
  final int? day;
  const _CronSpec({
    required this.isOnce,
    required this.unit,
    required this.interval,
    required this.hour,
    required this.minute,
    this.year,
    this.month,
    this.day,
  });
}

/// Parse a canonical schedule string, or null when unrecognised. Accepts the
/// same forms as the PC: `every N minutes|hours|days`, `at HH:MM` (24h or
/// 12h am/pm), and `once:YYYY-MM-DDTHH:MM`.
_CronSpec? _parseCron(String schedule) {
  final s = schedule.trim().toLowerCase();
  if (s.isEmpty) return null;

  final once = RegExp(
          r'^once:(\d{4})-(\d{2})-(\d{2})t([01]?\d|2[0-3]):([0-5]\d)$')
      .firstMatch(s);
  if (once != null) {
    return _CronSpec(
      isOnce: true,
      unit: _RepeatUnit.minutes,
      interval: 0,
      year: int.parse(once.group(1)!),
      month: int.parse(once.group(2)!),
      day: int.parse(once.group(3)!),
      hour: int.parse(once.group(4)!),
      minute: int.parse(once.group(5)!),
    );
  }

  final every =
      RegExp(r'^every\s+(\d+)\s*(minute|hour|day)s?$').firstMatch(s);
  if (every != null) {
    final n = int.parse(every.group(1)!);
    final u = switch (every.group(2)!) {
      'minute' => _RepeatUnit.minutes,
      'hour' => _RepeatUnit.hours,
      _ => _RepeatUnit.days,
    };
    return _CronSpec(
        isOnce: false, unit: u, interval: n, hour: 0, minute: 0);
  }

  final daily = RegExp(r'^(?:at\s+)?([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(s);
  if (daily != null) {
    return _CronSpec(
      isOnce: false,
      unit: _RepeatUnit.daily,
      interval: 0,
      hour: int.parse(daily.group(1)!),
      minute: int.parse(daily.group(2)!),
    );
  }

  final daily12 =
      RegExp(r'^(?:at\s+)?(1[0-2]|0?[1-9]):([0-5]\d)\s*(am|pm)$').firstMatch(s);
  if (daily12 != null) {
    var h = int.parse(daily12.group(1)!) % 12;
    if (daily12.group(3) == 'pm') h += 12;
    return _CronSpec(
      isOnce: false,
      unit: _RepeatUnit.daily,
      interval: 0,
      hour: h,
      minute: int.parse(daily12.group(2)!),
    );
  }
  return null;
}

/// Human-readable, localized one-line summary of a schedule string. Times are
/// shown in the user's [timeFormat] ('12h'/'24h').
String _cronSummary(String schedule, OsiaStrings s, String timeFormat) {
  final spec = _parseCron(schedule);
  if (spec == null) return schedule.trim().isEmpty ? '—' : schedule;
  if (spec.isOnce) {
    return s.cronOnce(
      '${_d4(spec.year!)}-${_d2(spec.month!)}-${_d2(spec.day!)}',
      _formatCronTime(_hm(spec.hour, spec.minute), timeFormat),
    );
  }
  return switch (spec.unit) {
    _RepeatUnit.minutes => s.cronEveryMinutes(spec.interval),
    _RepeatUnit.hours => s.cronEveryHours(spec.interval),
    _RepeatUnit.days => s.cronEveryDays(spec.interval),
    _RepeatUnit.daily =>
      s.cronDailyAt(_formatCronTime(_hm(spec.hour, spec.minute), timeFormat)),
  };
}

String _d2(int n) => n.toString().padLeft(2, '0');
String _d4(int n) => n.toString().padLeft(4, '0');
String _hm(int h, int m) => '${_d2(h)}:${_d2(m)}';
String _hmOfDay(TimeOfDay t) => _hm(t.hour, t.minute);
String _dateStr(DateTime d) => '${_d4(d.year)}-${_d2(d.month)}-${_d2(d.day)}';

/// Render a canonical 24h `HH:MM` cron time for display in the user's chosen
/// format. With [timeFormat] '12h' converts to `h:MM AM/PM`; for any other
/// value (default '24h') the string is returned unchanged. Falls back to the
/// input on parse failure. Display-only — saved schedules stay canonical 24h.
String _formatCronTime(String timeStr, String timeFormat) {
  if (timeFormat != '12h') return timeStr;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeStr.trim());
  if (m == null) return timeStr;
  final h = int.parse(m.group(1)!);
  final period = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.group(2)!} $period';
}

// ══════════════════════════════════════════════════════════════════════════
// AI hierarchy
// ══════════════════════════════════════════════════════════════════════════

/// Editor for the two ordered `"provider:model"` fallback chains (heavy /
/// medium) plus the master enable switch. Mirrors the desktop GUI: each
/// change rewrites the chain via `set_setting heavy_chain|medium_chain`.
class _HierarchyScreen extends StatefulWidget {
  final ws.WebSocketService wsService;
  final ws.ConfigData config;
  final List<ws.OsiaModel> models;
  const _HierarchyScreen({
    required this.wsService,
    required this.config,
    required this.models,
  });

  @override
  State<_HierarchyScreen> createState() => _HierarchyScreenState();
}

class _HierarchyScreenState extends State<_HierarchyScreen> {
  late List<String> _heavy;
  late List<String> _medium;
  late bool _enabled;
  late List<ws.OsiaModel> _models;
  late Map<String, bool> _apiKeysSet;
  StreamSubscription<ws.OsiaMessage>? _msgSub;

  @override
  void initState() {
    super.initState();
    _heavy = List<String>.from(widget.config.heavyChain);
    _medium = List<String>.from(widget.config.mediumChain);
    _enabled = widget.config.aiHierarchyEnabled;
    _models = List<ws.OsiaModel>.from(widget.models);
    _apiKeysSet = widget.config.apiKeysSet;
    _msgSub = widget.wsService.messageStream.listen((msg) {
      if (msg is ws.ModelsListMessage && mounted) {
        setState(() => _models = msg.models);
      }
    });
    if (_models.isEmpty) widget.wsService.sendGetModels();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  /// Configured model choices: models whose provider has a key set, plus
  /// keyless Ollama. Mirrors the desktop's `_hier_model_choices`.
  List<_ModelChoice> get _choices {
    final out = <_ModelChoice>[];
    for (final m in _models) {
      final provider = m.provider ?? '';
      final configured =
          provider == 'ollama' || (_apiKeysSet[provider] ?? false);
      if (!configured) continue;
      final pname = _kProviderNames[provider] ?? provider;
      out.add(_ModelChoice('$provider:${m.id}', '$pname · ${m.label}'));
    }
    out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return out;
  }

  /// Display label for a stored `"provider:model"` value.
  String _labelFor(String value) {
    final i = value.indexOf(':');
    if (i < 0) return value;
    final provider = value.substring(0, i);
    final id = value.substring(i + 1);
    final pname = _kProviderNames[provider] ?? provider;
    var modelLabel = id;
    for (final m in _models) {
      if (m.provider == provider && m.id == id) {
        modelLabel = m.label;
        break;
      }
    }
    return '$pname · $modelLabel';
  }

  void _persist(bool heavy) => widget.wsService
      .sendSetSetting(heavy ? 'heavy_chain' : 'medium_chain',
          heavy ? _heavy : _medium);

  void _toggleEnabled(bool v) {
    setState(() => _enabled = v);
    widget.wsService.sendSetSetting('ai_hierarchy_enabled', v);
  }

  void _add(bool heavy) {
    final choices = _choices;
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(OsiaL10n.of(context).hierarchyNoProviders)),
      );
      return;
    }
    setState(() => (heavy ? _heavy : _medium).add(choices.first.value));
    _persist(heavy);
  }

  void _removeAt(bool heavy, int i) {
    setState(() => (heavy ? _heavy : _medium).removeAt(i));
    _persist(heavy);
  }

  void _move(bool heavy, int i, int delta) {
    final list = heavy ? _heavy : _medium;
    final j = i + delta;
    if (j < 0 || j >= list.length) return;
    setState(() {
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    });
    _persist(heavy);
  }

  void _changeAt(bool heavy, int i, String value) {
    setState(() => (heavy ? _heavy : _medium)[i] = value);
    _persist(heavy);
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(strings.hierarchyTitle),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.hierarchySubtitle,
                style: TextStyle(
                    fontSize: 12.5, height: 1.4, color: palette.textMuted),
              ),
              const SizedBox(height: 14),
              _OsiaCard(
                palette: palette,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.hierarchyEnable,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: _toggleEnabled,
                      activeTrackColor: palette.accent,
                      activeThumbColor:
                          palette.isDark ? palette.background : Colors.white,
                      inactiveTrackColor:
                          palette.border.withValues(alpha: 0.5),
                      inactiveThumbColor: palette.textMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildChain(palette, strings, true, strings.hierarchyHeavy,
                  strings.hierarchyHeavySub, _heavy),
              const SizedBox(height: 24),
              _buildChain(palette, strings, false, strings.hierarchyMedium,
                  strings.hierarchyMediumSub, _medium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChain(OsiaPalette palette, OsiaStrings strings, bool heavy,
      String title, String sub, List<String> list) {
    final choices = _choices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 12, color: palette.textMuted)),
        const SizedBox(height: 10),
        if (list.isEmpty)
          _EmptyHint(label: strings.hierarchyEmpty, palette: palette)
        else
          for (var i = 0; i < list.length; i++) ...[
            _HierarchyRow(
              value: list[i],
              displayLabel: _labelFor(list[i]),
              choices: choices,
              palette: palette,
              strings: strings,
              isFirst: i == 0,
              isLast: i == list.length - 1,
              onChanged: (v) => _changeAt(heavy, i, v),
              onUp: () => _move(heavy, i, -1),
              onDown: () => _move(heavy, i, 1),
              onRemove: () => _removeAt(heavy, i),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 4),
        _AddButton(
          label: strings.hierarchyAddModel,
          palette: palette,
          onTap: () => _add(heavy),
        ),
      ],
    );
  }
}

/// One selectable `(value, label)` model entry for the hierarchy dropdowns.
class _ModelChoice {
  final String value; // "provider:model"
  final String label; // "Provider · Model"
  const _ModelChoice(this.value, this.label);
}

class _HierarchyRow extends StatelessWidget {
  final String value;
  final String displayLabel;
  final List<_ModelChoice> choices;
  final OsiaPalette palette;
  final OsiaStrings strings;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<String> onChanged;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onRemove;
  const _HierarchyRow({
    required this.value,
    required this.displayLabel,
    required this.choices,
    required this.palette,
    required this.strings,
    required this.isFirst,
    required this.isLast,
    required this.onChanged,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Keep the current value selectable even if its provider is no longer
    // configured, so the chain isn't silently dropped on open.
    final items = <DropdownMenuItem<String>>[];
    final hasCurrent = choices.any((c) => c.value == value);
    if (!hasCurrent && value.isNotEmpty) {
      items.add(DropdownMenuItem(
        value: value,
        child: Text(displayLabel,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, color: palette.textPrimary)),
      ));
    }
    for (final c in choices) {
      items.add(DropdownMenuItem(
        value: c.value,
        child: Text(c.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, color: palette.textPrimary)),
      ));
    }
    return _OsiaCard(
      palette: palette,
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value.isNotEmpty ? value : null,
                isExpanded: true,
                dropdownColor: palette.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: palette.accent, size: 20),
                items: items,
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
          _MiniIconButton(
            icon: Icons.keyboard_arrow_up_rounded,
            tooltip: strings.moveUp,
            palette: palette,
            onTap: isFirst ? null : onUp,
          ),
          _MiniIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: strings.moveDown,
            palette: palette,
            onTap: isLast ? null : onDown,
          ),
          _MiniIconButton(
            icon: Icons.close_rounded,
            tooltip: strings.delete,
            palette: palette,
            onTap: onRemove,
            danger: true,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Personality & skills
// ══════════════════════════════════════════════════════════════════════════

/// Two tabs: the personality document editor and the skills manager.
/// Subscribes to `configStream` so the skills list refreshes after a
/// create/delete/edit round-trip, without disturbing unsaved personality text.
class _PersonalityScreen extends StatefulWidget {
  final ws.WebSocketService wsService;
  final ws.ConfigData config;
  const _PersonalityScreen({required this.wsService, required this.config});

  @override
  State<_PersonalityScreen> createState() => _PersonalityScreenState();
}

class _PersonalityScreenState extends State<_PersonalityScreen> {
  final TextEditingController _personalityCtrl = TextEditingController();
  late List<ws.ConfigSkill> _skills;
  int _tab = 0;
  StreamSubscription<ws.ConfigData>? _configSub;

  @override
  void initState() {
    super.initState();
    _personalityCtrl.text = widget.config.personality;
    _skills = List<ws.ConfigSkill>.from(widget.config.skills);
    _configSub = widget.wsService.configStream.listen((data) {
      // Refresh skills only — never clobber the personality editor, which may
      // hold unsaved edits.
      if (mounted) setState(() => _skills = data.skills);
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _personalityCtrl.dispose();
    super.dispose();
  }

  void _savePersonality() {
    widget.wsService.sendSetPersonality(_personalityCtrl.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(OsiaL10n.of(context).personalitySaved)),
    );
  }

  void _toggleSkill(ws.ConfigSkill skill, bool value) {
    setState(() {
      _skills = [
        for (final s in _skills)
          s.name == skill.name
              ? ws.ConfigSkill(name: s.name, enabled: value, text: s.text)
              : s,
      ];
    });
    widget.wsService.sendSetSkill(skill.name, enabled: value);
  }

  Future<void> _editSkill(ws.ConfigSkill skill) async {
    await Navigator.of(context).push(
      slideFadeRoute(
        _SkillEditScreen(wsService: widget.wsService, skill: skill),
      ),
    );
    // Re-sync so the in-memory prose matches what was just saved.
    widget.wsService.sendGetConfig();
  }

  Future<void> _deleteSkill(ws.ConfigSkill skill) async {
    final strings = OsiaL10n.of(context);
    final palette = OsiaTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.skillDeleteTitle),
        content: Text(
          strings.skillDeleteBody(_skillDisplay(skill.name)),
          style: TextStyle(color: palette.textMuted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text(strings.cancel, style: TextStyle(color: palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.delete, style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _skills = _skills.where((s) => s.name != skill.name).toList());
    widget.wsService.sendDeleteSkill(skill.name);
    widget.wsService.sendGetConfig();
  }

  Future<void> _addSkill() async {
    final strings = OsiaL10n.of(context);
    final palette = OsiaTheme.of(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.skillNewTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          cursorColor: palette.accent,
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(hintText: strings.skillNewHint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                Text(strings.cancel, style: TextStyle(color: palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(strings.add, style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    widget.wsService.sendCreateSkill(name);
    widget.wsService.sendGetConfig();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(strings.personalitySkillsTitle),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: _SegmentedToggle(
                labels: [strings.tabPersonality, strings.tabSkills],
                index: _tab,
                palette: palette,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                sizing: StackFit.expand,
                children: [
                  _buildPersonalityTab(palette, strings),
                  _buildSkillsTab(palette, strings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalityTab(OsiaPalette palette, OsiaStrings strings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _personalityCtrl,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: palette.accent,
              style: TextStyle(
                  color: palette.textPrimary, fontSize: 14.5, height: 1.4),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.surface,
                hintText: strings.personalityHint,
                hintStyle: TextStyle(color: palette.textMuted, fontSize: 14.5),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: palette.accent, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PrimaryButton(
              label: strings.save, onTap: _savePersonality, palette: palette),
        ],
      ),
    );
  }

  Widget _buildSkillsTab(OsiaPalette palette, OsiaStrings strings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_skills.isEmpty)
            _EmptyHint(label: strings.skillsEmpty, palette: palette)
          else
            for (final skill in _skills) ...[
              _SkillRow(
                skill: skill,
                palette: palette,
                strings: strings,
                onToggle: (v) => _toggleSkill(skill, v),
                onEdit: () => _editSkill(skill),
                onDelete: () => _deleteSkill(skill),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 6),
          _AddButton(
              label: strings.skillAdd, palette: palette, onTap: _addSkill),
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final ws.ConfigSkill skill;
  final OsiaPalette palette;
  final OsiaStrings strings;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SkillRow({
    required this.skill,
    required this.palette,
    required this.strings,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _OsiaCard(
      palette: palette,
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _skillDisplay(skill.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
          ),
          Switch(
            value: skill.enabled,
            onChanged: onToggle,
            activeTrackColor: palette.accent,
            activeThumbColor:
                palette.isDark ? palette.background : Colors.white,
            inactiveTrackColor: palette.border.withValues(alpha: 0.5),
            inactiveThumbColor: palette.textMuted,
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: strings.edit,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, size: 19, color: palette.textMuted),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: strings.delete,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded,
                size: 19, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Full-screen Markdown editor for one skill's prose.
class _SkillEditScreen extends StatefulWidget {
  final ws.WebSocketService wsService;
  final ws.ConfigSkill skill;
  const _SkillEditScreen({required this.wsService, required this.skill});

  @override
  State<_SkillEditScreen> createState() => _SkillEditScreenState();
}

class _SkillEditScreenState extends State<_SkillEditScreen> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.skill.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.wsService.sendSetSkill(widget.skill.name, text: _ctrl.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(OsiaL10n.of(context).skillSaved)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(_skillDisplay(widget.skill.name)),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  cursorColor: palette.accent,
                  style: TextStyle(
                      color: palette.textPrimary, fontSize: 14, height: 1.4),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: palette.surface,
                    hintText: strings.skillContentHint,
                    hintStyle: TextStyle(color: palette.textMuted),
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: palette.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: palette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: palette.accent, width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _PrimaryButton(
                  label: strings.save, onTap: _save, palette: palette),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skill filenames carry a `.md` suffix on disk; show the bare stem.
String _skillDisplay(String name) =>
    name.toLowerCase().endsWith('.md') ? name.substring(0, name.length - 3) : name;

// ══════════════════════════════════════════════════════════════════════════
// System status (heartbeat)
// ══════════════════════════════════════════════════════════════════════════

/// Live system-metrics dashboard plus the two heartbeat settings. The toggle
/// and interval are pre-filled from `config.settings` and written back via
/// `set_setting heartbeat_enabled|heartbeat_interval_seconds`; the metrics
/// refresh in real time from `heartbeat_data` pushes on [heartbeatStream].
class _HeartbeatScreen extends StatefulWidget {
  final ws.WebSocketService wsService;
  final ws.ConfigData config;
  const _HeartbeatScreen({required this.wsService, required this.config});

  @override
  State<_HeartbeatScreen> createState() => _HeartbeatScreenState();
}

class _HeartbeatScreenState extends State<_HeartbeatScreen> {
  static const int _minInterval = 10;
  static const int _maxInterval = 300;
  static const int _defaultInterval = 30;

  late bool _enabled;
  late final TextEditingController _intervalCtrl;
  late final FocusNode _intervalFocus;
  ws.HeartbeatDataMessage? _latest;
  StreamSubscription<ws.HeartbeatDataMessage>? _hbSub;

  @override
  void initState() {
    super.initState();
    final s = widget.config.settings;
    _enabled = s['heartbeat_enabled'] == true;
    _intervalCtrl = TextEditingController(text: '${_readInterval(s)}');
    _intervalFocus = FocusNode();
    // Persist a clamped interval when the field loses focus — covers the case
    // where the user edits then navigates away without pressing "done".
    _intervalFocus.addListener(() {
      if (!_intervalFocus.hasFocus) _persistInterval();
    });
    _hbSub = widget.wsService.heartbeatStream.listen((msg) {
      if (mounted) setState(() => _latest = msg);
    });
  }

  int _readInterval(Map<String, dynamic> s) {
    final raw = s['heartbeat_interval_seconds'];
    final n = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    return (n ?? _defaultInterval).clamp(_minInterval, _maxInterval).toInt();
  }

  @override
  void dispose() {
    _hbSub?.cancel();
    _intervalFocus.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  void _toggle(bool v) {
    setState(() => _enabled = v);
    widget.wsService.sendSetSetting('heartbeat_enabled', v);
  }

  void _persistInterval() {
    final parsed = int.tryParse(_intervalCtrl.text.trim());
    final int clamped =
        (parsed ?? _defaultInterval).clamp(_minInterval, _maxInterval).toInt();
    // Reflect the clamped value back so the user sees what was actually saved.
    final text = '$clamped';
    if (_intervalCtrl.text != text) _intervalCtrl.text = text;
    widget.wsService.sendSetSetting('heartbeat_interval_seconds', clamped);
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final hb = _latest;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(strings.catSystemStatus),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Enable monitoring ──
              _OsiaCard(
                palette: palette,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.heartbeatMonitoring,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: _toggle,
                      activeTrackColor: palette.accent,
                      activeThumbColor:
                          palette.isDark ? palette.background : Colors.white,
                      inactiveTrackColor:
                          palette.border.withValues(alpha: 0.5),
                      inactiveThumbColor: palette.textMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // ── Interval (seconds) ──
              _FieldLabel(strings.heartbeatInterval, palette),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _intervalCtrl,
                      focusNode: _intervalFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onSubmitted: (_) => _persistInterval(),
                      cursorColor: palette.accent,
                      style:
                          TextStyle(color: palette.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: palette.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: palette.accent, width: 1.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      strings.heartbeatIntervalRange,
                      style:
                          TextStyle(fontSize: 12.5, color: palette.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── Live metrics dashboard ──
              _SectionLabel(
                  label: strings.systemMetricsHeader, palette: palette),
              const SizedBox(height: 4),
              if (hb == null)
                _EmptyHint(label: strings.heartbeatWaiting, palette: palette)
              else
                _OsiaCard(
                  palette: palette,
                  child: Column(
                    children: [
                      _MetricBar(
                        label: strings.metricCpu,
                        value: hb.cpuPercent,
                        unit: '%',
                        palette: palette,
                      ),
                      _MetricBar(
                        label: strings.metricRam,
                        value: hb.ramPercent,
                        unit: '%',
                        palette: palette,
                      ),
                      _MetricBar(
                        label: strings.metricDisk,
                        value: hb.diskPercent,
                        unit: '%',
                        palette: palette,
                      ),
                      // Temperatures only when the PC could read them.
                      if (hb.cpuTemp != null)
                        _MetricBar(
                          label: strings.metricCpuTemp,
                          value: hb.cpuTemp,
                          unit: '°C',
                          palette: palette,
                        ),
                      if (hb.gpuTemp != null)
                        _MetricBar(
                          label: strings.metricGpuTemp,
                          value: hb.gpuTemp,
                          unit: '°C',
                          palette: palette,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colored horizontal bar for one system metric. Green &lt; 60, orange 60–85,
/// red &gt; 85 — applied on the value's own scale (percent for usage, °C for
/// temperatures, which share the same comfortable/warm/hot thresholds).
class _MetricBar extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final OsiaPalette palette;
  const _MetricBar({
    required this.label,
    required this.value,
    required this.unit,
    required this.palette,
  });

  static const Color _green = Color(0xFF22C55E);
  static const Color _orange = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFEF4444);

  Color get _color {
    final v = value;
    if (v == null) return palette.textMuted;
    if (v < 60) return _green;
    if (v <= 85) return _orange;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    final double fraction =
        v == null ? 0.0 : (v / 100).clamp(0.0, 1.0).toDouble();
    final readout = v == null ? '—' : '${v.round()}$unit';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style:
                      TextStyle(fontSize: 13.5, color: palette.textPrimary),
                ),
              ),
              Text(
                readout,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: v == null ? palette.textMuted : _color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: palette.border.withValues(alpha: 0.6),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 8, color: _color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Shared building blocks for the config sections
// ══════════════════════════════════════════════════════════════════════════

/// Small muted field label (mirrors the key-editor's "API key" caption).
class _FieldLabel extends StatelessWidget {
  final String label;
  final OsiaPalette palette;
  const _FieldLabel(this.label, this.palette);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(fontSize: 13, color: palette.textMuted),
      );
}

/// Small uppercase section label (mirrors the settings screen's section
/// headers). Titles the General section and the live-metrics dashboard.
class _SectionLabel extends StatelessWidget {
  final String label;
  final OsiaPalette palette;
  const _SectionLabel({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.textMuted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Styled single/multi-line text field matching the API-key editor.
class _OsiaTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final OsiaPalette palette;
  final int maxLines;
  final TextInputType? keyboardType;
  const _OsiaTextField({
    required this.controller,
    required this.hint,
    required this.palette,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      cursorColor: palette.accent,
      style: TextStyle(color: palette.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: palette.surface,
        hintText: hint,
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.accent, width: 1.4),
        ),
      ),
    );
  }
}

/// Date/time picker trigger showing the chosen value or a placeholder label.
class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final OsiaPalette palette;
  final VoidCallback onTap;
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: palette.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? label,
                style: TextStyle(
                  fontSize: 14.5,
                  color: value == null ? palette.textMuted : palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-segment pill toggle (Repeat/Once, Personality/Skills).
class _SegmentedToggle extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final OsiaPalette palette;
  const _SegmentedToggle({
    required this.labels,
    required this.index,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border, width: 0.6),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? palette.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: i == index
                          ? (palette.isDark ? palette.background : Colors.white)
                          : palette.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Filled accent primary action button (Save).
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final OsiaPalette palette;
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.isDark ? palette.background : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle:
              const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Outlined "+ Add …" button used by the cron / hierarchy / skills lists.
class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final OsiaPalette palette;
  const _AddButton({
    required this.label,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.add_rounded, size: 18, color: palette.accent),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.accent,
        side: BorderSide(color: palette.border),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Compact icon button with a disabled (dimmed) and a danger variant.
class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final OsiaPalette palette;
  final VoidCallback? onTap;
  final bool danger;
  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? palette.textMuted.withValues(alpha: 0.3)
        : danger
            ? palette.error
            : palette.textMuted;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      icon: Icon(icon, color: color),
    );
  }
}

/// Muted, centered "nothing here yet" placeholder card.
class _EmptyHint extends StatelessWidget {
  final String label;
  final OsiaPalette palette;
  const _EmptyHint({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border, width: 0.6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: palette.textMuted),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../heartbeat_settings.dart';
import '../l10n.dart';
import '../motion.dart';
import '../nav.dart';
import '../services/websocket_service.dart' as ws;
import '../skill_activation_guard.dart';
import '../theme.dart';
import '../widgets/model_selector_sheet.dart';

const String osiaOAuthRelayRedirectUri =
    'https://relay.osia.space/oauth/callback';

/// Accept only the stable callback or the exact temporary old-PC rendezvous URI.
bool isTrustedOsiaMobileOAuthRedirect(String value) {
  if (value == osiaOAuthRelayRedirectUri) return true;
  // Temporary WOR-203 migration overlap. New PCs never generate this form.
  return RegExp(
    r'^https://osia-rendezvous\.aymengherbi06\.workers\.dev/oauth/cb/[0-9a-f]{64}$',
  ).hasMatch(value);
}

bool isTrustedMcpAuthorizationUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return false;
  }
  final redirects = uri.queryParametersAll['redirect_uri'];
  final states = uri.queryParametersAll['state'];
  if (redirects == null ||
      redirects.length != 1 ||
      !isTrustedOsiaMobileOAuthRedirect(redirects.single) ||
      states == null ||
      states.length != 1 ||
      states.single.isEmpty) {
    return false;
  }
  return true;
}

bool isTrustedGmailAuthorizationUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'accounts.google.com' ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty ||
      uri.path != '/o/oauth2/v2/auth' ||
      uri.fragment.isNotEmpty) {
    return false;
  }
  final query = uri.queryParametersAll;
  String? one(String name) {
    final values = query[name];
    return values != null && values.length == 1 ? values.single : null;
  }

  final redirect = one('redirect_uri');
  return one('response_type') == 'code' &&
      one('code_challenge_method') == 'S256' &&
      (one('client_id') ?? '').isNotEmpty &&
      (one('state') ?? '').isNotEmpty &&
      (one('code_challenge') ?? '').isNotEmpty &&
      redirect != null &&
      isTrustedOsiaMobileOAuthRedirect(redirect);
}

/// Configure APIs & Providers — the mobile mirror of the PC's provider panels.
///
/// Reachable from the settings screen (i.e. after a successful connection).
/// On open it pulls the full config snapshot from the PC (`get_config`) and
/// the model list (`get_models`) so provider sections are pre-filled with what
/// is actually configured:
///   - voice-to-voice (Live API), AI providers, voice providers (TTS),
///     Whisper providers (STT) — API-key editors (with a "configured" badge
///     reflecting `api_keys_set`).
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
  'chatgpt_account': 'ChatGPT',
  'anthropic': 'Anthropic',
  'openai': 'OpenAI',
  'deepseek': 'DeepSeek',
  'google': 'Google',
  'xai': 'xAI',
  'groq': 'Groq',
  'mistral': 'Mistral',
  'ollama': 'Local (Ollama)',
};

/// Resolve a model id to its provider using the PC catalogue, with a conservative name fallback for older snapshots.
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
  if (lower.startsWith('mistral') || lower.startsWith('codestral')) {
    return 'mistral';
  }
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
const String _kUrlAnthropic = 'https://platform.claude.com/settings/keys';
const String _kUrlOpenAi = 'https://platform.openai.com/api-keys';
const String _kUrlGoogle = 'https://aistudio.google.com/app/apikey';
const String _kUrlDeepSeek = 'https://platform.deepseek.com/api_keys';
const String _kUrlXai = 'https://console.x.ai';
const String _kUrlGroq = 'https://console.groq.com/keys';
const String _kUrlMistral = 'https://console.mistral.ai/api-keys';
bool get _liveApiAvailable => false;

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
        ProviderEntry('Claude API', 'anthropic', _kUrlAnthropic),
        ProviderEntry('OpenAI', 'openai', _kUrlOpenAi),
        ProviderEntry('Google', 'google', _kUrlGoogle),
        ProviderEntry('DeepSeek', 'deepseek', _kUrlDeepSeek),
        ProviderEntry('xAI', 'xai', _kUrlXai),
        ProviderEntry('Groq', 'groq', _kUrlGroq),
        ProviderEntry('Mistral', 'mistral', _kUrlMistral),
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

// ── TTS / STT selectors (WOR-78.2) ──────────────────────────────────────
//
// Mirror of the PC's voice/speech selectors. The chosen TTS provider + voice
// and the STT provider are plain settings (`tts_provider`, `tts_voice`,
// `stt_provider`) written with `set_setting` — the server's whitelist already
// accepts them, so this is purely additive on the mobile side. The stored
// value is the dropdown key; the label is a brand proper noun (not localized).

/// TTS provider value → display label (mirrors the `providersFor(tts)` names).
const Map<String, String> _kTtsProviderLabels = {
  'local': 'Local (Kokoro)',
  'openai': 'OpenAI',
  'google': 'Google Cloud',
};

/// TTS provider dropdown order (default: `local` / Kokoro).
const List<String> _kTtsProviderOrder = ['local', 'openai', 'google'];

/// OpenAI TTS voices, mirroring the PC list exactly. Default: `nova`.
const List<String> _kOpenAiVoices = [
  'alloy',
  'ash',
  'coral',
  'echo',
  'fable',
  'marin',
  'nova',
  'onyx',
  'sage',
  'shimmer',
];

/// Google (Gemini) TTS voices, mirroring the PC list exactly. Default: `Kore`.
const List<String> _kGoogleVoices = [
  'Zephyr',
  'Puck',
  'Charon',
  'Kore',
  'Fenrir',
  'Leda',
  'Orus',
  'Aoede',
  'Callirrhoe',
  'Autonoe',
  'Enceladus',
  'Iapetus',
  'Umbriel',
  'Algieba',
  'Despina',
  'Erinome',
  'Algenib',
  'Rasalgethi',
  'Laomedeia',
  'Achernar',
  'Alnilam',
  'Schedar',
  'Gacrux',
  'Pulcherrima',
  'Achird',
  'Zubenelgenubi',
  'Vindemiatrix',
  'Sadachbia',
  'Sadaltager',
  'Sulafat',
];

/// Selectable voices for a TTS provider — empty when the provider has none
/// (Kokoro/local has no user-selectable voice, matching the PC).
List<String> _ttsVoicesFor(String provider) {
  switch (provider) {
    case 'openai':
      return _kOpenAiVoices;
    case 'google':
      return _kGoogleVoices;
    default:
      return const [];
  }
}

/// Default voice for a TTS provider ('' when the provider has none).
String _defaultTtsVoice(String provider) {
  switch (provider) {
    case 'openai':
      return 'nova';
    case 'google':
      return 'Kore';
    default:
      return '';
  }
}

/// STT provider value → display label (brand proper nouns, not localized).
const Map<String, String> _kSttProviderLabels = {
  'local': 'faster-whisper (local)',
  'groq': 'Groq Whisper',
};

/// STT provider dropdown order (default: `local` / faster-whisper).
const List<String> _kSttProviderOrder = ['local', 'groq'];
const List<String> _kSttFallbackProviderOrder = ['local', 'groq', 'none'];

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

/// The short (~5-7 word) subtitle shown on each API-key category card
/// (WOR-78 point 1) — replaces the comma-joined brand list.
String _categorySub(ProviderCategory category, OsiaStrings s) {
  switch (category) {
    case ProviderCategory.voiceToVoice:
      return s.catVoiceToVoiceSub;
    case ProviderCategory.ai:
      return s.catAiProvidersSub;
    case ProviderCategory.tts:
      return s.catTtsProvidersSub;
    case ProviderCategory.stt:
      return s.catSttProvidersSub;
  }
}

/// The ~2-sentence description shown at the top of each provider config
/// screen (WOR-78 point 1).
String _categoryDesc(ProviderCategory category, OsiaStrings s) {
  switch (category) {
    case ProviderCategory.voiceToVoice:
      return s.liveapiDesc;
    case ProviderCategory.ai:
      return s.aiProvidersDesc;
    case ProviderCategory.tts:
      return s.voiceProvidersDesc;
    case ProviderCategory.stt:
      return s.whisperProvidersDesc;
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

/// Coerce safe fallback-slot status (`{provider: [bool, ...]}`) into counts.
/// Credential values are never read or retained by Mobile.
Map<String, int> _readFallbackCounts(Object? raw) {
  final out = <String, int>{};
  if (raw is Map) {
    raw.forEach((key, value) {
      if (value is List) {
        out[key.toString()] = value.where((slot) => slot == true).length;
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

  late ws.ChatGptAccountState _chatGptAccount;

  StreamSubscription<ws.ConfigData>? _configSub;
  StreamSubscription<ws.ConnectionState>? _connSub;
  StreamSubscription<ws.ChatGptAccountState>? _chatGptSub;

  @override
  void initState() {
    super.initState();
    _chatGptAccount = widget.wsService.chatGptAccountState;
    // Subscribe BEFORE requesting so the (broadcast, non-replaying) reply
    // can't slip through before we're listening.
    _configSub = widget.wsService.configStream.listen((data) {
      if (mounted) setState(() => _config = data);
    });
    _chatGptSub = widget.wsService.chatGptAccountStream.listen((state) {
      if (mounted) setState(() => _chatGptAccount = state);
    });
    _connSub = widget.wsService.connectionStream.listen((state) {
      if (state == ws.ConnectionState.connected) {
        _refreshServerState();
      }
    });
    _recoverConnection();
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _connSub?.cancel();
    _chatGptSub?.cancel();
    super.dispose();
  }

  void _recoverConnection() {
    unawaited(widget.wsService.ensureConnected(reason: 'providers_open'));
    if (widget.wsService.state == ws.ConnectionState.connected) {
      _refreshServerState();
    }
  }

  void _refreshServerState() {
    widget.wsService.sendGetConfig();
    widget.wsService.sendGetModels();
    widget.wsService.sendGetChatGptAccount();
  }

  void _open(Widget screen) {
    // Re-pull the config when the sub-screen pops so the landing (and the
    // next entry into any section) reflects edits made there — otherwise a
    // stale snapshot could be re-seeded and overwrite server-side changes.
    Navigator.of(context).push(slideFadeRoute(screen)).then((_) {
      if (mounted) {
        widget.wsService.sendGetConfig();
        widget.wsService.sendGetModels();
        widget.wsService.sendGetChatGptAccount();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final config = _config;

    // Fallback key values remain on the PC; Mobile receives slot counts only.
    final apiKeyFallbackCounts = _readFallbackCounts(
      config?.settings['api_key_fallbacks_set'],
    );

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
                    // ── The four API-key categories ──
                    for (final category in ProviderCategory.values) ...[
                      _CategoryTile(
                        icon: _categoryIcon(category),
                        title: _categoryTitle(category, strings),
                        // Short localized description (WOR-78 point 1). The
                        // brand list now lives only on the config screen.
                        subtitle: _categorySub(category, strings),
                        trailingLabel:
                            category == ProviderCategory.voiceToVoice &&
                                !_liveApiAvailable
                            ? strings.comingSoon
                            : null,
                        palette: palette,
                        onTap: () => _open(
                          _ProviderListScreen(
                            category: category,
                            wsService: widget.wsService,
                            apiKeysSet: config.apiKeysSet,
                            apiKeyFallbackCounts: apiKeyFallbackCounts,
                            // TTS / STT selectors (WOR-78.2) — read from the
                            // same config snapshot; only the matching screen
                            // (tts / stt) renders and uses these.
                            ttsProvider: (config.settings['tts_provider'] ?? '')
                                .toString(),
                            ttsVoice: (config.settings['tts_voice'] ?? '')
                                .toString(),
                            sttProvider: (config.settings['stt_provider'] ?? '')
                                .toString(),
                            sttFallbackProvider:
                                (config.settings['stt_fallback_provider'] ??
                                        'local')
                                    .toString(),
                            sttLocalModel:
                                (config.settings['stt_local_model'] ?? 'small')
                                    .toString(),
                            sttGroqModel:
                                (config.settings['stt_groq_model'] ??
                                        'whisper-large-v3-turbo')
                                    .toString(),
                            sttLocalModelsAvailable:
                                config.settings['stt_local_models_available']
                                    is List
                                ? (config.settings['stt_local_models_available']
                                          as List)
                                      .whereType<String>()
                                      .toList()
                                : const <String>[],
                            chatGptAccount: _chatGptAccount,
                            anthropicWorkspaceId:
                                (config.settings['anthropic_workspace_id'] ??
                                        '')
                                    .toString(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// General/system settings embedded in the base Settings screen.
///
/// These panels still live in this library so they can reuse the existing
/// private screen classes and card widgets without changing their design.
class SystemSettingsSection extends StatefulWidget {
  final ws.WebSocketService wsService;
  final bool showHeader;
  final Future<bool> Function(Uri uri)? oauthUrlLauncher;

  const SystemSettingsSection({
    super.key,
    required this.wsService,
    this.showHeader = true,
    this.oauthUrlLauncher,
  });

  @override
  State<SystemSettingsSection> createState() => _SystemSettingsSectionState();
}

class _SystemSettingsSectionState extends State<SystemSettingsSection> {
  ws.ConfigData? _config;
  List<ws.OsiaModel> _models = const [];
  String? _timeFormatOverride;

  StreamSubscription<ws.ConfigData>? _configSub;
  StreamSubscription<ws.OsiaMessage>? _msgSub;
  StreamSubscription<ws.ConnectionState>? _connSub;

  @override
  void initState() {
    super.initState();
    _configSub = widget.wsService.configStream.listen((data) {
      if (mounted) {
        setState(() {
          _config = data;
          _timeFormatOverride = null;
        });
      }
    });
    _msgSub = widget.wsService.messageStream.listen((msg) {
      if (msg is ws.ModelsListMessage && mounted) {
        setState(() => _models = msg.models);
      }
    });
    _connSub = widget.wsService.connectionStream.listen((state) {
      if (state == ws.ConnectionState.connected) {
        _refreshServerState();
      }
    });
    _recoverConnection();
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _msgSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  String get _timeFormat =>
      _timeFormatOverride ??
      (_config?.settings['time_format']?.toString()) ??
      '24h';

  void _setTimeFormat(String value) {
    setState(() => _timeFormatOverride = value);
    widget.wsService.sendSetSetting('time_format', value);
  }

  void _recoverConnection() {
    unawaited(widget.wsService.ensureConnected(reason: 'system_settings_open'));
    if (widget.wsService.state == ws.ConnectionState.connected) {
      _refreshServerState();
    }
  }

  void _refreshServerState() {
    widget.wsService.sendGetConfig();
    widget.wsService.sendGetModels();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(slideFadeRoute(screen)).then((_) {
      if (mounted) widget.wsService.sendGetConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final config = _config;

    if (config == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: _LoadingBody(palette: palette, label: strings.loading),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader)
          _SectionLabel(label: strings.sectionGeneral, palette: palette),
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
              models: _models,
              currentModel: (config.settings['selected_model'] ?? '')
                  .toString(),
            ),
          ),
        ),
        const SizedBox(height: 12),
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
        _CategoryTile(
          icon: Icons.auto_awesome_rounded,
          title: strings.catPersonalitySkills,
          subtitle: strings.catPersonalitySkillsSub,
          palette: palette,
          onTap: () => _open(
            _PersonalityScreen(wsService: widget.wsService, config: config),
          ),
        ),
        const SizedBox(height: 12),
        _CategoryTile(
          icon: Icons.monitor_heart_rounded,
          title: strings.catSystemStatus,
          subtitle: strings.catSystemStatusSub,
          palette: palette,
          onTap: () => _open(
            _HeartbeatScreen(wsService: widget.wsService, config: config),
          ),
        ),
        const SizedBox(height: 12),
        _CategoryTile(
          icon: Icons.hub_rounded,
          title: strings.catConnectors,
          subtitle: strings.catConnectorsSub,
          palette: palette,
          onTap: () => _open(
            _McpScreen(
              wsService: widget.wsService,
              config: config,
              oauthUrlLauncher: widget.oauthUrlLauncher,
            ),
          ),
        ),
        const SizedBox(height: 12),
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
                  onChanged: (i) => _setTimeFormat(i == 1 ? '12h' : '24h'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: palette.accent,
            ),
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

// ── TTS and speech selector cards ──

class _TtsSelectorCard extends StatefulWidget {
  final ws.WebSocketService wsService;

  /// Current `tts_provider` / `tts_voice` from the config snapshot.
  final String initialProvider;
  final String initialVoice;

  const _TtsSelectorCard({
    required this.wsService,
    required this.initialProvider,
    required this.initialVoice,
  });

  @override
  State<_TtsSelectorCard> createState() => _TtsSelectorCardState();
}

class _TtsSelectorCardState extends State<_TtsSelectorCard> {
  late String _provider;
  late String _voice;
  StreamSubscription<ws.ConfigData>? _configSub;

  @override
  void initState() {
    super.initState();
    _provider = _kTtsProviderOrder.contains(widget.initialProvider)
        ? widget.initialProvider
        : 'local';
    _voice = _resolveVoice(_provider, widget.initialVoice);
    _configSub = widget.wsService.configStream.listen((config) {
      if (!mounted) return;
      final settings = config.settings;
      final provider = (settings['tts_provider'] ?? 'local').toString();
      final voice = (settings['tts_voice'] ?? '').toString();
      final nextProvider = _kTtsProviderOrder.contains(provider)
          ? provider
          : 'local';
      final nextVoice = _resolveVoice(nextProvider, voice);
      if (_provider != nextProvider || _voice != nextVoice) {
        setState(() {
          _provider = nextProvider;
          _voice = nextVoice;
        });
      }
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  /// [preferred] when it is a valid voice for [provider], else that provider's
  /// default ('' for providers with no selectable voice, i.e. Kokoro).
  String _resolveVoice(String provider, String preferred) {
    final voices = _ttsVoicesFor(provider);
    if (voices.isEmpty) return '';
    if (voices.contains(preferred)) return preferred;
    return _defaultTtsVoice(provider);
  }

  void _onProviderChanged(String provider) {
    final voice = _defaultTtsVoice(provider);
    setState(() {
      _provider = provider;
      _voice = voice;
    });
    widget.wsService.sendSetSetting('tts_provider', provider);
    // PC resets the provider-specific voice to its default. Kokoro has no
    // selectable voice, so clear the previous cloud voice in canonical state.
    widget.wsService.sendSetSetting('tts_voice', voice.isEmpty ? null : voice);
  }

  void _onVoiceChanged(String voice) {
    setState(() => _voice = voice);
    widget.wsService.sendSetSetting('tts_voice', voice);
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    // Clamp the rendered values so DropdownButton always finds its value among
    // the items (its "exactly one match" invariant).
    final provider = _kTtsProviderOrder.contains(_provider)
        ? _provider
        : 'local';
    final voices = _ttsVoicesFor(provider);
    final voice = voices.contains(_voice)
        ? _voice
        : (voices.isNotEmpty ? voices.first : '');

    return _OsiaCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(strings.ttsProviderLabel, palette),
          const SizedBox(height: 8),
          _selectorDropdown<String>(
            palette: palette,
            value: provider,
            items: [
              for (final p in _kTtsProviderOrder)
                DropdownMenuItem(
                  value: p,
                  child: Text(
                    _kTtsProviderLabels[p] ?? p,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null && v != _provider) _onProviderChanged(v);
            },
          ),
          const SizedBox(height: 14),
          _FieldLabel(strings.ttsVoiceLabel, palette),
          const SizedBox(height: 8),
          // Cloud providers expose named voices; Kokoro (local) does not, so it
          // shows a disabled "Automatic" placeholder instead of a picker.
          if (voices.isEmpty)
            _DisabledField(label: strings.ttsVoiceAutomatic, palette: palette)
          else
            _selectorDropdown<String>(
              palette: palette,
              value: voice.isNotEmpty ? voice : null,
              items: [
                for (final v in voices)
                  DropdownMenuItem(
                    value: v,
                    child: Text(
                      v,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null && v != _voice) _onVoiceChanged(v);
              },
            ),
        ],
      ),
    );
  }
}

/// Compact selector shown at the top of the Whisper Providers (STT) screen,
/// above the API-key list. Mirrors the PC's primary/fallback providers and
/// model selectors; all choices are persisted to canonical PC settings.
class _SttSelectorCard extends StatefulWidget {
  final ws.WebSocketService wsService;
  final String initialProvider;
  final String initialFallbackProvider;
  final String initialLocalModel;
  final String initialGroqModel;
  final List<String> availableLocalModels;

  const _SttSelectorCard({
    required this.wsService,
    required this.initialProvider,
    required this.initialFallbackProvider,
    required this.initialLocalModel,
    required this.initialGroqModel,
    required this.availableLocalModels,
  });

  @override
  State<_SttSelectorCard> createState() => _SttSelectorCardState();
}

class _SttSelectorCardState extends State<_SttSelectorCard> {
  late String _provider;
  late String _fallbackProvider;
  late String _localModel;
  late String _groqModel;
  late Set<String> _availableLocalModels;
  StreamSubscription<ws.ConfigData>? _configSub;

  @override
  void initState() {
    super.initState();
    _provider = _kSttProviderOrder.contains(widget.initialProvider)
        ? widget.initialProvider
        : 'local';
    _fallbackProvider =
        _kSttFallbackProviderOrder.contains(widget.initialFallbackProvider)
        ? widget.initialFallbackProvider
        : 'none';
    _localModel = widget.initialLocalModel;
    _groqModel = widget.initialGroqModel;
    _availableLocalModels = widget.availableLocalModels.toSet();
    _configSub = widget.wsService.configStream.listen(_applyConfig);
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  void _applyConfig(ws.ConfigData config) {
    if (!mounted) return;
    final settings = config.settings;
    final provider = (settings['stt_provider'] ?? 'local').toString();
    final fallback = (settings['stt_fallback_provider'] ?? 'local').toString();
    final rawAvailable = settings['stt_local_models_available'];
    setState(() {
      _provider = _kSttProviderOrder.contains(provider) ? provider : 'local';
      _fallbackProvider = _kSttFallbackProviderOrder.contains(fallback)
          ? fallback
          : 'none';
      _localModel = (settings['stt_local_model'] ?? 'small').toString();
      _groqModel = (settings['stt_groq_model'] ?? 'whisper-large-v3-turbo')
          .toString();
      _availableLocalModels = rawAvailable is List
          ? rawAvailable.whereType<String>().toSet()
          : <String>{};
    });
  }

  void _onProviderChanged(String provider) {
    setState(() => _provider = provider);
    widget.wsService.sendSetSetting('stt_provider', provider);
  }

  void _onFallbackProviderChanged(String provider) {
    setState(() => _fallbackProvider = provider);
    widget.wsService.sendSetSetting('stt_fallback_provider', provider);
  }

  void _onModelChanged(String provider, String model) {
    setState(() {
      if (provider == 'groq') {
        _groqModel = model;
      } else {
        _localModel = model;
      }
    });
    widget.wsService.sendSetSetting(
      provider == 'groq' ? 'stt_groq_model' : 'stt_local_model',
      model,
    );
  }

  String? _localModelSelection() {
    if (_availableLocalModels.contains(_localModel)) return _localModel;
    for (final size in const ['small', 'medium']) {
      if (_availableLocalModels.contains(size)) return size;
    }
    return null;
  }

  Widget _modelField({required String provider, required OsiaPalette palette}) {
    final strings = OsiaL10n.of(context);
    if (provider == 'local') {
      final model = _localModelSelection();
      if (_availableLocalModels.isEmpty || model == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldLabel(strings.model, palette),
            const SizedBox(height: 8),
            _DisabledField(label: strings.sttNoLocalModels, palette: palette),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(strings.model, palette),
          const SizedBox(height: 8),
          _selectorDropdown<String>(
            palette: palette,
            value: model,
            items: [
              for (final size in ['small', 'medium'])
                if (_availableLocalModels.contains(size))
                  DropdownMenuItem(
                    value: size,
                    child: Text(
                      size,
                      style: TextStyle(color: palette.textPrimary),
                    ),
                  ),
            ],
            onChanged: (value) {
              if (value != null && value != _localModel) {
                _onModelChanged('local', value);
              }
            },
          ),
        ],
      );
    }
    final groqModel =
        const [
          'whisper-large-v3-turbo',
          'whisper-large-v3',
        ].contains(_groqModel)
        ? _groqModel
        : 'whisper-large-v3-turbo';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(strings.model, palette),
          const SizedBox(height: 8),
          _selectorDropdown<String>(
            palette: palette,
            value: groqModel,
            items: [
              for (final model in const [
                'whisper-large-v3-turbo',
                'whisper-large-v3',
              ])
                DropdownMenuItem(
                  value: model,
                  child: Text(
                    model,
                    style: TextStyle(color: palette.textPrimary),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null && value != _groqModel) {
                _onModelChanged('groq', value);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    final provider = _kSttProviderOrder.contains(_provider)
        ? _provider
        : 'local';
    final fallbackProvider =
        _kSttFallbackProviderOrder.contains(_fallbackProvider)
        ? _fallbackProvider
        : 'none';

    return _OsiaCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(strings.sttProviderLabel, palette),
          const SizedBox(height: 8),
          _selectorDropdown<String>(
            palette: palette,
            value: provider,
            items: [
              for (final p in _kSttProviderOrder)
                DropdownMenuItem(
                  value: p,
                  child: Text(
                    _kSttProviderLabels[p] ?? p,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null && v != _provider) _onProviderChanged(v);
            },
          ),
          const SizedBox(height: 14),
          _modelField(provider: provider, palette: palette),
          const SizedBox(height: 18),
          _FieldLabel(strings.sttFallbackProviderLabel, palette),
          const SizedBox(height: 8),
          _selectorDropdown<String>(
            palette: palette,
            value: fallbackProvider,
            items: [
              for (final fallback in _kSttFallbackProviderOrder)
                DropdownMenuItem(
                  value: fallback,
                  child: Text(
                    fallback == 'none'
                        ? strings.sttNoFallback
                        : (_kSttProviderLabels[fallback] ?? fallback),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null && value != _fallbackProvider) {
                _onFallbackProviderChanged(value);
              }
            },
          ),
          if (fallbackProvider != 'none') ...[
            const SizedBox(height: 14),
            _modelField(provider: fallbackProvider, palette: palette),
          ],
        ],
      ),
    );
  }
}

/// Disabled, dropdown-shaped field used when a provider exposes no
/// user-selectable value (e.g. Kokoro's voice → "Automatic"). Reads as inert:
/// muted text, no chevron, not tappable.
class _DisabledField extends StatelessWidget {
  final String label;
  final OsiaPalette palette;
  const _DisabledField({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: palette.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 14.5, color: palette.textMuted),
      ),
    );
  }
}

/// Styled dropdown for the TTS/STT selector cards — mirrors the vision card's
/// inset-field dropdown (elevated fill so it reads against the card surface).
Widget _selectorDropdown<T>({
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

// ── Provider list for one category ──────────────────────────────────────

class _ProviderListScreen extends StatelessWidget {
  final ProviderCategory category;
  final ws.WebSocketService wsService;

  /// `{provider: hasKey}` from the latest config snapshot, used to show a
  /// "configured" check next to providers whose key is already set on the PC.
  final Map<String, bool> apiKeysSet;

  /// Per-provider fallback slot counts. Fallback credentials stay on the PC.
  final Map<String, int> apiKeyFallbackCounts;

  /// Current `tts_provider` / `tts_voice` / `stt_provider` from the config
  /// snapshot (WOR-78.2). Only the TTS screen reads the first two; only the STT
  /// screen reads the third. Empty for the other categories / when unset — the
  /// selector cards then fall back to their local defaults.
  final String ttsProvider;
  final String ttsVoice;
  final String sttProvider;
  final String sttFallbackProvider;
  final String sttLocalModel;
  final String sttGroqModel;
  final List<String> sttLocalModelsAvailable;
  final ws.ChatGptAccountState chatGptAccount;
  final String anthropicWorkspaceId;

  const _ProviderListScreen({
    required this.category,
    required this.wsService,
    required this.apiKeysSet,
    this.apiKeyFallbackCounts = const {},
    this.ttsProvider = '',
    this.ttsVoice = '',
    this.sttProvider = '',
    this.sttFallbackProvider = 'local',
    this.sttLocalModel = 'small',
    this.sttGroqModel = 'whisper-large-v3-turbo',
    this.sttLocalModelsAvailable = const [],
    this.chatGptAccount = const ws.ChatGptAccountState(),
    this.anthropicWorkspaceId = '',
  });

  bool _isKeySet(ProviderEntry entry) =>
      entry.apiProvider != null && (apiKeysSet[entry.apiProvider] ?? false);

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
              Text(
                _categoryDesc(category, strings),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              // ── TTS / STT selector (WOR-78.2) ──
              // Mirrors the PC's voice/speech selectors. Sits above the API-key
              // list (which stays untouched below). Only built for its category.
              if (category == ProviderCategory.tts) ...[
                _TtsSelectorCard(
                  wsService: wsService,
                  initialProvider: ttsProvider,
                  initialVoice: ttsVoice,
                ),
                const SizedBox(height: 16),
              ],
              if (category == ProviderCategory.stt) ...[
                _SttSelectorCard(
                  wsService: wsService,
                  initialProvider: sttProvider,
                  initialFallbackProvider: sttFallbackProvider,
                  initialLocalModel: sttLocalModel,
                  initialGroqModel: sttGroqModel,
                  availableLocalModels: sttLocalModelsAvailable,
                ),
                const SizedBox(height: 16),
              ],
              if (category == ProviderCategory.ai) ...[
                _ChatGptAccountCard(
                  wsService: wsService,
                  initialState: chatGptAccount,
                ),
                const SizedBox(height: 16),
              ],
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
                              initialWorkspaceId: anthropicWorkspaceId,
                              showFallbackKeys:
                                  category == ProviderCategory.ai &&
                                  providers[i].apiProvider != null,
                              fallbackKeyCount:
                                  apiKeyFallbackCounts[providers[i]
                                      .apiProvider] ??
                                  0,
                            ),
                          ),
                        ),
                      ),
                    ],
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

// ── API-key editor for one provider ─────────────────────────────────────

class _ChatGptAccountCard extends StatefulWidget {
  final ws.WebSocketService wsService;
  final ws.ChatGptAccountState initialState;

  const _ChatGptAccountCard({
    required this.wsService,
    required this.initialState,
  });

  @override
  State<_ChatGptAccountCard> createState() => _ChatGptAccountCardState();
}

class _ChatGptAccountCardState extends State<_ChatGptAccountCard> {
  late ws.ChatGptAccountState _state;
  StreamSubscription<ws.ChatGptAccountState>? _sub;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _sub = widget.wsService.chatGptAccountStream.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    widget.wsService.sendGetChatGptAccount();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _openLogin() async {
    final value = _state.verificationUrl.trim();
    if (value.isEmpty) return;
    try {
      await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(OsiaL10n.of(context).linkOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final details = <String>[
      if (_state.email.trim().isNotEmpty) _state.email.trim(),
      if (_state.plan.trim().isNotEmpty && _state.plan != 'unknown')
        _state.plan.replaceAll('_', ' '),
    ];
    return _OsiaCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ChatGPT',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Tooltip(
                message: strings.chatGptInfo,
                child: Icon(
                  Icons.info_outline_rounded,
                  color: palette.textMuted,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_state.connected) ...[
            Text(
              strings.connected,
              style: TextStyle(color: palette.accent, fontSize: 13),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                details.join(' · '),
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
            ],
            for (final window in _state.quotaWindows) ...[
              const SizedBox(height: 4),
              Text(
                strings.chatGptQuotaRemaining(
                  window.label,
                  window.remainingPercent,
                ),
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
            ],
            if (_state.quotaWindows.isEmpty && _state.usagePercent != null) ...[
              const SizedBox(height: 4),
              Text(
                strings.chatGptUsage(_state.usagePercent!),
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: widget.wsService.sendChatGptAccountLogout,
                child: Text(strings.chatGptDisconnect),
              ),
            ),
          ] else if (_state.connecting) ...[
            Text(
              strings.connectingStatus,
              style: TextStyle(color: palette.accent, fontSize: 13),
            ),
            if (_state.userCode.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                strings.chatGptEnterCode,
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _state.userCode,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  fontSize: 16,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_state.verificationUrl.isNotEmpty)
                  FilledButton(
                    onPressed: _openLogin,
                    child: Text(strings.chatGptOpenLogin),
                  ),
                if (_state.loginCancellable)
                  OutlinedButton(
                    onPressed: widget.wsService.sendCancelChatGptAccountLogin,
                    child: Text(strings.cancel),
                  ),
              ],
            ),
          ] else ...[
            if (_state.error.isNotEmpty && _state.error != 'disconnected') ...[
              Text(
                strings.chatGptError(_state.error),
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: widget.wsService.sendChatGptAccountLogin,
                child: Text(strings.chatGptConnect),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderConfigScreen extends StatefulWidget {
  final ProviderEntry entry;
  final ws.WebSocketService wsService;

  /// Whether the PC has a key stored for this provider (from `api_keys_set`).
  /// Drives the "configured" badge and the "remove key" action.
  final bool keyConfigured;
  final String initialWorkspaceId;

  /// Fallback keys remain on the PC. Mobile only receives the slot count.
  final bool showFallbackKeys;
  final int fallbackKeyCount;

  const _ProviderConfigScreen({
    required this.entry,
    required this.wsService,
    required this.keyConfigured,
    this.initialWorkspaceId = '',
    this.showFallbackKeys = false,
    this.fallbackKeyCount = 0,
  });

  @override
  State<_ProviderConfigScreen> createState() => _ProviderConfigScreenState();
}

class _ProviderConfigScreenState extends State<_ProviderConfigScreen> {
  final TextEditingController _keyCtrl = TextEditingController();
  final TextEditingController _workspaceCtrl = TextEditingController();
  late String _workspaceBaseline;
  bool get _isClaude => widget.entry.apiProvider == 'anthropic';
  bool get _workspaceDirty =>
      _isClaude && _workspaceCtrl.text.trim() != _workspaceBaseline;
  bool get _canSave => _hasText || _workspaceDirty;
  bool _obscured = true;
  // Drives the Save button's enabled state — only a non-empty key saves.
  bool _hasText = false;
  // Local mirror of widget.keyConfigured so the "configured" badge can flip to
  // unconfigured immediately after a delete (optimistic), before the next
  // config snapshot lands.
  late bool _configured;
  late int _fallbackKeyCount;
  StreamSubscription<ws.ConfigData>? _configSub;

  @override
  void initState() {
    super.initState();
    _configured = widget.keyConfigured;
    _workspaceBaseline = widget.initialWorkspaceId;
    _workspaceCtrl.text = _workspaceBaseline;
    _workspaceCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _fallbackKeyCount = widget.fallbackKeyCount;
    _keyCtrl.addListener(() {
      final has = _keyCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _configSub = widget.wsService.configStream.listen((config) {
      if (!mounted) return;
      if (_isClaude && !_workspaceDirty) {
        _workspaceBaseline = (config.settings['anthropic_workspace_id'] ?? '')
            .toString();
        _workspaceCtrl.text = _workspaceBaseline;
      }
      final provider = widget.entry.apiProvider;
      final configured =
          provider != null && config.apiKeysSet[provider] == true;
      final fallbackCount = provider == null
          ? 0
          : _readFallbackCounts(
                  config.settings['api_key_fallbacks_set'],
                )[provider] ??
                0;
      if (configured != _configured || fallbackCount != _fallbackKeyCount) {
        setState(() {
          _configured = configured;
          _fallbackKeyCount = fallbackCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _keyCtrl.dispose();
    _workspaceCtrl.dispose();
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
    if (provider == null || !_canSave) return;
    // Persist the workspace before a key change rebuilds the canonical client.
    if (_workspaceDirty) {
      widget.wsService.sendSetSetting(
        'anthropic_workspace_id',
        _workspaceCtrl.text.trim(),
      );
    }
    if (key.isNotEmpty) widget.wsService.sendSetApiKey(provider, key);
    // Refresh the snapshot so the landing screen's "configured" badges
    // reflect the new key on the next visit.
    widget.wsService.sendGetConfig();
    final strings = OsiaL10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          key.isEmpty ? strings.claudeWorkspaceSaved : strings.apiKeySaved,
        ),
      ),
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
            child: Text(
              strings.cancel,
              style: TextStyle(color: palette.textMuted),
            ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.apiKeyRemoved)));
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
        if (_isClaude) ...[
          Text(
            strings.claudeApiInfo,
            style: TextStyle(color: palette.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('claude_api_workspace'),
            controller: _workspaceCtrl,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: strings.claudeWorkspace),
          ),
          const SizedBox(height: 16),
        ],
        // "Configured" banner — the PC has a key set for this provider.
        if (_configured) ...[
          _OsiaCard(
            palette: palette,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: palette.accent,
                ),
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
          onSubmitted: (_) => _canSave ? _save() : null,
          cursorColor: palette.accent,
          style: TextStyle(color: palette.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.surface,
            hintText: _configured
                ? strings.apiKeyReplaceHint
                : strings.apiKeyHint,
            hintStyle: TextStyle(color: palette.textMuted, fontSize: 14.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
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
            icon: Icon(
              Icons.open_in_new_rounded,
              size: 17,
              color: palette.accent,
            ),
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
            onPressed: _canSave ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.isDark
                  ? palette.background
                  : Colors.white,
              disabledBackgroundColor: palette.accent.withValues(alpha: 0.4),
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
            child: Text(strings.save),
          ),
        ),
        // "Remove key" — only when a key is currently stored on the PC.
        if (_configured) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _remove,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: palette.error,
            ),
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
            initialCount: _fallbackKeyCount,
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
/// Existing values stay on the PC. Mobile can replace a slot with a newly
/// entered key, append a slot, or remove a slot using safe slot-count metadata.
class _FallbackKeysSection extends StatefulWidget {
  final ws.WebSocketService wsService;
  final String provider;
  final int initialCount;

  const _FallbackKeysSection({
    required this.wsService,
    required this.provider,
    required this.initialCount,
  });

  @override
  State<_FallbackKeysSection> createState() => _FallbackKeysSectionState();
}

class _FallbackKeysSectionState extends State<_FallbackKeysSection> {
  late int _count;

  /// Which slot the inline editor targets: null = closed, -1 = adding a new
  /// key, ≥ 0 = editing that slot. Only one editor is open at a time.
  int? _editIndex;
  final TextEditingController _editCtrl = TextEditingController();
  bool _editObscured = true;
  bool _editHasText = false;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount.clamp(0, 64).toInt();
  }

  @override
  void didUpdateWidget(covariant _FallbackKeysSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editIndex == null && oldWidget.initialCount != widget.initialCount) {
      setState(() => _count = widget.initialCount.clamp(0, 64).toInt());
    }
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  void _openEditor(int index) {
    if (index < -1 || index >= _count) return;
    setState(() {
      _editIndex = index;
      _editObscured = true;
      _editCtrl.clear();
      _editHasText = false;
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
      if (index == -1) _count++;
      _editIndex = null;
      _editCtrl.clear();
      _editHasText = false;
    });
    // -1 appends on the server; an in-range index replaces that slot.
    widget.wsService.sendSetApiFallbackKey(widget.provider, index, key);
    // Refresh the snapshot so the landing reflects the change on the next visit.
    widget.wsService.sendGetConfig();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(OsiaL10n.of(context).apiKeySaved)));
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
            child: Text(
              strings.cancel,
              style: TextStyle(color: palette.textMuted),
            ),
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
      if (_count > 0) _count--;
      _editIndex = null;
    });
    widget.wsService.sendDeleteApiFallbackKey(widget.provider, index);
    widget.wsService.sendGetConfig();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.apiKeyRemoved)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: strings.fallbackKeys, palette: palette),
        if (_count > 0)
          _OsiaCard(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _count; i++) ...[
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

  /// One configured fallback slot. Its key value never leaves the PC.
  Widget _buildKeyRow(OsiaPalette palette, OsiaStrings strings, int i) {
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
            strings.apiKeyConfigured,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: palette.textPrimary),
          ),
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
            hintText: isNew ? strings.apiKeyHint : strings.apiKeyReplaceHint,
            hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
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
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
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
  final String? trailingLabel;
  final OsiaPalette palette;
  final VoidCallback onTap;
  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingLabel,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = trailingLabel == null;
    final titleColor = enabled ? palette.textPrimary : palette.textMuted;
    final iconColor = enabled ? palette.accent : palette.textMuted;
    return _OsiaCard(
      palette: palette,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: enabled ? onTap : null,
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
                  color: iconColor.withValues(alpha: enabled ? 0.12 : 0.08),
                ),
                child: Icon(icon, size: 19, color: iconColor),
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
                        color: titleColor,
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
              if (trailingLabel != null) ...[
                _SoonPill(label: trailingLabel!, palette: palette),
              ] else
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

class _SoonPill extends StatelessWidget {
  final String label;
  final OsiaPalette palette;

  const _SoonPill({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.textMuted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.textMuted.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.textMuted,
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
  final List<ws.OsiaModel> models;
  final String? currentModel;
  const _CronScreen({
    required this.wsService,
    required this.jobs,
    required this.timeFormat,
    required this.models,
    required this.currentModel,
  });

  @override
  State<_CronScreen> createState() => _CronScreenState();
}

class _CronScreenState extends State<_CronScreen> {
  late List<Map<String, dynamic>> _jobs;
  StreamSubscription<ws.ConfigData>? _configSub;
  StreamSubscription<ws.ConnectionState>? _connSub;

  @override
  void initState() {
    super.initState();
    // Deep-ish copy so edits don't mutate the parent's snapshot in place.
    _jobs = widget.jobs.map((j) => Map<String, dynamic>.from(j)).toList();
    _configSub = widget.wsService.configStream.listen((cfg) {
      if (!mounted) return;
      setState(() {
        _jobs = cfg.cronJobs.map((j) => Map<String, dynamic>.from(j)).toList();
      });
    });
    _connSub = widget.wsService.connectionStream.listen((state) {
      if (state == ws.ConnectionState.connected) {
        _refreshServerState();
      }
    });
    _recoverConnection();
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  void _persist() => widget.wsService.sendSetSetting('cron_jobs', _jobs);

  void _recoverConnection() {
    unawaited(widget.wsService.ensureConnected(reason: 'cron_open'));
    if (widget.wsService.state == ws.ConnectionState.connected) {
      _refreshServerState();
    }
  }

  void _refreshServerState() {
    widget.wsService.sendGetConfig();
  }

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
          models: widget.models,
          currentModel: widget.currentModel,
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
                  fontSize: 12.5,
                  height: 1.4,
                  color: palette.textMuted,
                ),
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
                    models: widget.models,
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
  final List<ws.OsiaModel> models;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  const _CronRow({
    required this.job,
    required this.palette,
    required this.strings,
    required this.timeFormat,
    required this.models,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final task = (job['task'] ?? '').toString().trim();
    final schedule = (job['schedule'] ?? '').toString();
    final modelLabel = cronModelDisplayLabel(
      job['model'],
      models,
      strings.cronModelDefault,
    );
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
                    const SizedBox(height: 2),
                    Text(
                      '${strings.model}: $modelLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: palette.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: palette.accent,
                activeThumbColor: palette.isDark
                    ? palette.background
                    : Colors.white,
                inactiveTrackColor: palette.border.withValues(alpha: 0.5),
                inactiveThumbColor: palette.textMuted,
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: strings.delete,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic>? _cronModelFromRaw(Object? raw) {
  if (raw is! Map) return null;
  final id = (raw['id'] ?? raw['model'] ?? raw['model_id'] ?? '')
      .toString()
      .trim();
  if (id.isEmpty) return null;
  final provider = (raw['provider'] ?? raw['model_provider'] ?? '')
      .toString()
      .trim();
  final label = (raw['label'] ?? raw['name'] ?? id).toString().trim();
  return {'provider': provider, 'id': id, 'label': label.isEmpty ? id : label};
}

@visibleForTesting
Map<String, dynamic>? cronModelMetadataForModelId(
  String? modelId,
  List<ws.OsiaModel> models,
) {
  final id = (modelId ?? '').trim();
  if (id.isEmpty) return null;
  for (final m in models) {
    if (m.id == id) {
      final provider = (m.provider ?? '').trim();
      return {
        'provider': provider.isEmpty ? _providerForModel(id, models) : provider,
        'id': id,
        'label': m.label.trim().isEmpty ? id : m.label,
      };
    }
  }
  return {'provider': _providerForModel(id, models), 'id': id, 'label': id};
}

@visibleForTesting
String cronModelDisplayLabel(
  Object? rawModel,
  List<ws.OsiaModel> models,
  String fallback,
) {
  final meta = _cronModelFromRaw(rawModel);
  if (meta == null) return fallback;
  final id = (meta['id'] ?? '').toString();
  final storedProvider = (meta['provider'] ?? '').toString();
  var provider = storedProvider;
  var label = (meta['label'] ?? id).toString();
  for (final m in models) {
    if (m.id == id &&
        (storedProvider.isEmpty || m.provider == storedProvider)) {
      provider = (m.provider ?? provider).trim();
      label = m.label.trim().isEmpty ? label : m.label;
      break;
    }
  }
  provider = provider.trim().isEmpty ? _providerForModel(id, models) : provider;
  final providerLabel = _kProviderNames[provider] ?? provider;
  return providerLabel.trim().isEmpty ? label : '$providerLabel · $label';
}

@visibleForTesting
Map<String, dynamic> buildCronJobForSettingsSave({
  Map<String, dynamic>? initialJob,
  required String task,
  required String schedule,
  required bool enabled,
  required String? conversationId,
  required Map<String, dynamic>? model,
}) {
  final job = <String, dynamic>{
    ...?initialJob,
    'task': task,
    'schedule': schedule,
    'enabled': enabled,
    'conversation_id': conversationId,
  };
  for (final obsoleteField in const <String>[
    'grant_refs',
    'authorization_status',
    'authorization_expires_at',
    'authorization_bounds',
    'authorization_request',
    'migration_state',
  ]) {
    job.remove(obsoleteField);
  }
  final cleanModel = _cronModelFromRaw(model);
  if (cleanModel == null) {
    job.remove('model');
  } else {
    job['model'] = cleanModel;
  }
  return job;
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
  final List<ws.OsiaModel> models;
  final String? currentModel;
  const _CronEditScreen({
    this.initialJob,
    required this.timeFormat,
    required this.wsService,
    required this.models,
    required this.currentModel,
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
  late List<ws.OsiaModel> _models;
  Map<String, dynamic>? _selectedModel;
  ValueNotifier<ModelSelectorState>? _modelSelectorNotifier;
  Timer? _modelLoadTimeout;
  StreamSubscription<ws.OsiaMessage>? _modelSub;

  // ── Linked conversation (WOR-24) ──
  // Selected conversation id, or null for "new conversation". Pre-filled from
  // the job's existing conversation_id and written back on save.
  String? _conversationId;
  // The list fetched from the PC; null while still loading (drives the loader).
  List<ws.ConversationItem>? _conversations;
  StreamSubscription<ws.ConversationsListMessage>? _convSub;
  StreamSubscription<ws.ConnectionState>? _connSub;

  bool get _instructionRedacted => widget.initialJob?['task_redacted'] == true;

  @override
  void initState() {
    super.initState();
    _models = List<ws.OsiaModel>.from(widget.models);
    final job = widget.initialJob;
    if (job != null) {
      _taskCtrl.text = (job['task'] ?? '').toString();
      _enabled = job['enabled'] == true;
      _selectedModel = _cronModelFromRaw(job['model']);
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
        } else if (spec.unit == _RepeatUnit.daysAt) {
          _unit = _RepeatUnit.daysAt;
          _intervalCtrl.text = '${spec.interval}';
          _dailyTime = TimeOfDay(hour: spec.hour, minute: spec.minute);
        } else {
          _unit = spec.unit;
          _intervalCtrl.text = '${spec.interval}';
        }
      }
    } else {
      _selectedModel = cronModelMetadataForModelId(
        widget.currentModel,
        _models,
      );
    }
    _modelSub = widget.wsService.messageStream.listen((msg) {
      if (msg is ws.ModelsListMessage && mounted) {
        setState(() => _models = msg.models);
        final notifier = _modelSelectorNotifier;
        if (notifier != null) {
          notifier.value = ModelSelectorState(
            models: msg.models,
            isLoading: false,
          );
        }
        if (widget.initialJob == null &&
            _selectedModel == null &&
            (widget.currentModel ?? '').trim().isNotEmpty) {
          setState(() {
            _selectedModel = cronModelMetadataForModelId(
              widget.currentModel,
              msg.models,
            );
          });
        }
      }
    });
    // Subscribe BEFORE requesting so the (broadcast, non-replaying) reply can't
    // slip through before we're listening, then pull the conversation list.
    _convSub = widget.wsService.conversationsListStream.listen((msg) {
      if (mounted) setState(() => _conversations = msg.conversations);
    });
    _connSub = widget.wsService.connectionStream.listen((state) {
      if (state == ws.ConnectionState.connected) {
        _refreshServerState();
      }
    });
    _recoverConnection();
  }

  @override
  void dispose() {
    _modelLoadTimeout?.cancel();
    final notifier = _modelSelectorNotifier;
    _modelSelectorNotifier = null;
    notifier?.dispose();
    _modelSub?.cancel();
    _convSub?.cancel();
    _connSub?.cancel();
    _taskCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  void _recoverConnection() {
    unawaited(widget.wsService.ensureConnected(reason: 'cron_edit_open'));
    if (widget.wsService.state == ws.ConnectionState.connected) {
      _refreshServerState();
    }
  }

  void _refreshServerState() {
    widget.wsService.sendGetModels();
    widget.wsService.sendGetConversations();
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
      initialTime:
          (once ? _onceTime : _dailyTime) ??
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

  Future<void> _pickModel() async {
    final strings = OsiaL10n.of(context);
    final notifier = ValueNotifier<ModelSelectorState>(
      ModelSelectorState(models: _models, isLoading: _models.isEmpty),
    );
    _modelSelectorNotifier = notifier;
    _modelLoadTimeout?.cancel();
    if (_models.isEmpty) {
      widget.wsService.sendGetModels();
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
      final currentId = (_selectedModel?['id'] ?? '').toString();
      final chosen = await showModelSelector(
        context: context,
        stateListenable: notifier,
        currentModel: currentId.isEmpty ? null : currentId,
        hierarchyActive: false,
      );
      if (chosen == null) return;
      final meta = cronModelMetadataForModelId(chosen, _models);
      if (meta == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.cronModelInvalid)));
        return;
      }
      if (mounted) setState(() => _selectedModel = meta);
    } finally {
      _modelLoadTimeout?.cancel();
      _modelLoadTimeout = null;
      if (_modelSelectorNotifier == notifier) {
        _modelSelectorNotifier = null;
        notifier.dispose();
      }
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
    if (_unit == _RepeatUnit.daysAt) {
      final t = _dailyTime;
      if (t == null) return null;
      return 'every $n days at ${_d2(t.hour)}:${_d2(t.minute)}';
    }
    final unit = switch (_unit) {
      _RepeatUnit.minutes => 'minutes',
      _RepeatUnit.hours => 'hours',
      _RepeatUnit.days => 'days',
      _RepeatUnit.daysAt => 'days', // handled above
      _RepeatUnit.daily => 'minutes', // unreachable (handled above)
    };
    return 'every $n $unit';
  }

  void _save() {
    final strings = OsiaL10n.of(context);
    final task = _taskCtrl.text.trim();
    final schedule = _composeSchedule();
    if (task.isEmpty || schedule == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.cronInvalid)));
      return;
    }
    final job = buildCronJobForSettingsSave(
      // Preserve any other server-side fields; conversation_id below overrides
      // the preserved value with the user's current selection (WOR-24).
      initialJob: widget.initialJob,
      task: task,
      schedule: schedule,
      enabled: _enabled,
      // null when "Aucune (nouvelle conversation)" is chosen — matches the PC's
      // `{..., "conversation_id": null}` job shape.
      conversationId: _conversationId,
      model: _selectedModel,
    );
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
              if (_instructionRedacted)
                _EmptyHint(
                  label: strings.scheduledInstructionPrivate,
                  palette: palette,
                )
              else
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
                  () => _type = i == 0 ? _CronType.repeat : _CronType.once,
                ),
              ),
              const SizedBox(height: 20),
              if (_type == _CronType.repeat)
                ..._buildRepeat(palette, strings)
              else
                ..._buildOnce(palette, strings),
              const SizedBox(height: 24),
              _buildModelField(palette, strings),
              const SizedBox(height: 24),
              _buildConversationField(palette, strings),
              const SizedBox(height: 28),
              _PrimaryButton(
                label: strings.save,
                onTap: _save,
                palette: palette,
              ),
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
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: palette.accent,
            ),
            style: TextStyle(color: palette.textPrimary, fontSize: 14.5),
            items: [
              DropdownMenuItem(
                value: _RepeatUnit.minutes,
                child: Text(strings.cronUnitMinutes),
              ),
              DropdownMenuItem(
                value: _RepeatUnit.hours,
                child: Text(strings.cronUnitHours),
              ),
              DropdownMenuItem(
                value: _RepeatUnit.days,
                child: Text(strings.cronUnitDays),
              ),
              DropdownMenuItem(
                value: _RepeatUnit.daysAt,
                child: Text('${strings.cronUnitDays} + ${strings.cronTime}'),
              ),
              DropdownMenuItem(
                value: _RepeatUnit.daily,
                child: Text(strings.cronModeDaily),
              ),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            if (_unit == _RepeatUnit.daysAt) ...[
              const SizedBox(height: 14),
              _PickerButton(
                icon: Icons.access_time_rounded,
                label: strings.cronTime,
                value: _dailyTime == null
                    ? null
                    : _formatCronTime(_hmOfDay(_dailyTime!), widget.timeFormat),
                palette: palette,
                onTap: () => _pickTime(false),
              ),
            ],
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
    _RepeatUnit.daysAt => s.cronUnitDays,
    _RepeatUnit.daily => s.cronModeDaily,
  };

  Widget _buildModelField(OsiaPalette palette, OsiaStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(strings.model, palette),
        const SizedBox(height: 8),
        _PickerButton(
          icon: Icons.tune_rounded,
          label: strings.model,
          value: cronModelDisplayLabel(
            _selectedModel,
            _models,
            strings.cronModelDefault,
          ),
          palette: palette,
          onTap: _pickModel,
        ),
      ],
    );
  }

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
                    strokeWidth: 2,
                    color: palette.accent,
                  ),
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
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: palette.accent,
                ),
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
    OsiaPalette palette,
  ) {
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
      items.add(
        DropdownMenuItem<String?>(
          value: c.id,
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14.5, color: palette.textPrimary),
          ),
        ),
      );
    }
    final id = _conversationId;
    if (id != null && !convs.any((c) => c.id == id)) {
      items.add(
        DropdownMenuItem<String?>(
          value: id,
          child: Text(
            strings.untitled,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14.5, color: palette.textMuted),
          ),
        ),
      );
    }
    return items;
  }
}

// ── Cron schedule parsing/formatting (mirrors osia.cron) ────────────────

enum _CronType { repeat, once }

enum _RepeatUnit { minutes, hours, days, daysAt, daily }

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
    r'^once:(\d{4})-(\d{2})-(\d{2})t([01]?\d|2[0-3]):([0-5]\d)$',
  ).firstMatch(s);
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

  final daysAt = RegExp(
    r'^every\s+(\d+)\s*days?\s+at\s+([01]?\d|2[0-3]):([0-5]\d)$',
  ).firstMatch(s);
  if (daysAt != null) {
    return _CronSpec(
      isOnce: false,
      unit: _RepeatUnit.daysAt,
      interval: int.parse(daysAt.group(1)!),
      hour: int.parse(daysAt.group(2)!),
      minute: int.parse(daysAt.group(3)!),
    );
  }

  final every = RegExp(r'^every\s+(\d+)\s*(minute|hour|day)s?$').firstMatch(s);
  if (every != null) {
    final n = int.parse(every.group(1)!);
    final u = switch (every.group(2)!) {
      'minute' => _RepeatUnit.minutes,
      'hour' => _RepeatUnit.hours,
      _ => _RepeatUnit.days,
    };
    return _CronSpec(isOnce: false, unit: u, interval: n, hour: 0, minute: 0);
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

  final daily12 = RegExp(
    r'^(?:at\s+)?(1[0-2]|0?[1-9]):([0-5]\d)\s*(am|pm)$',
  ).firstMatch(s);
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
    _RepeatUnit.daysAt =>
      '${s.cronEveryDays(spec.interval)} · ${_formatCronTime(_hm(spec.hour, spec.minute), timeFormat)}',
    _RepeatUnit.daily => s.cronDailyAt(
      _formatCronTime(_hm(spec.hour, spec.minute), timeFormat),
    ),
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
  StreamSubscription<ws.OsiaMessage>? _msgSub;

  @override
  void initState() {
    super.initState();
    _heavy = List<String>.from(widget.config.heavyChain);
    _medium = List<String>.from(widget.config.mediumChain);
    _enabled = widget.config.aiHierarchyEnabled;
    _models = List<ws.OsiaModel>.from(widget.models);
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

  /// PC-authoritative usable model choices from the sanitized catalogue.
  List<_ModelChoice> get _choices {
    final out = <_ModelChoice>[];
    for (final m in _models) {
      final provider = m.provider ?? '';
      if (provider.isEmpty || !m.selectable) continue;
      final pname = _kProviderNames[provider] ?? provider;
      out.add(
        _ModelChoice(
          value: '$provider:${m.id}',
          providerName: pname,
          modelLabel: m.label,
        ),
      );
    }
    // Cluster by provider (so the grouped picker's section headers come out in
    // a stable order) then by model name within each provider.
    out.sort((a, b) {
      final byProvider = a.providerName.toLowerCase().compareTo(
        b.providerName.toLowerCase(),
      );
      if (byProvider != 0) return byProvider;
      return a.modelLabel.toLowerCase().compareTo(b.modelLabel.toLowerCase());
    });
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

  void _persist(bool heavy) => widget.wsService.sendSetSetting(
    heavy ? 'heavy_chain' : 'medium_chain',
    heavy ? _heavy : _medium,
  );

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
                  fontSize: 12.5,
                  height: 1.4,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              _OsiaCard(
                palette: palette,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
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
                      activeThumbColor: palette.isDark
                          ? palette.background
                          : Colors.white,
                      inactiveTrackColor: palette.border.withValues(alpha: 0.5),
                      inactiveThumbColor: palette.textMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildChain(
                palette,
                strings,
                true,
                strings.hierarchyHeavy,
                strings.hierarchyHeavySub,
                _heavy,
              ),
              const SizedBox(height: 24),
              _buildChain(
                palette,
                strings,
                false,
                strings.hierarchyMedium,
                strings.hierarchyMediumSub,
                _medium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChain(
    OsiaPalette palette,
    OsiaStrings strings,
    bool heavy,
    String title,
    String sub,
    List<String> list,
  ) {
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

/// One selectable model entry for the hierarchy picker. Carries the stored
/// `"provider:model"` [value] plus the two pieces the grouped picker renders
/// separately: the provider's display [providerName] (its section header) and
/// the bare [modelLabel] (shown in full, never truncated, under that header).
class _ModelChoice {
  final String value; // "provider:model"
  final String providerName; // "Groq" / "Local (Ollama)" — section header
  final String modelLabel; // "Llama 3.3 70B Versatile" — shown complete
  const _ModelChoice({
    required this.value,
    required this.providerName,
    required this.modelLabel,
  });
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
    return _OsiaCard(
      palette: palette,
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      child: Row(
        children: [
          Expanded(
            // Tapping the current selection opens the grouped model picker
            // (provider section headers + full model names). The closed-state
            // display stays compact and may ellipsize — the picker shows every
            // name in full.
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: choices.isEmpty
                  ? null
                  : () async {
                      final picked = await _showHierarchyModelPicker(
                        context: context,
                        choices: choices,
                        currentValue: value,
                      );
                      if (picked != null && picked != value) onChanged(picked);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: palette.accent,
                      size: 20,
                    ),
                  ],
                ),
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

// ── Grouped model picker (shared by both hierarchy chains) ───────────────

/// Modal bottom-sheet model picker for the AI-hierarchy chains. Mirrors the
/// chat's model selector (lib/widgets/model_selector_sheet.dart): a violet
/// provider section header over that provider's models, each shown with its
/// COMPLETE name (wrapping rather than truncating) so long ids like
/// "Llama 3.3 70B Versatile" stay distinguishable — replacing the old flat,
/// provider-mixing dropdown. Returns the chosen "provider:model" value, or
/// null on dismiss.
Future<String?> _showHierarchyModelPicker({
  required BuildContext context,
  required List<_ModelChoice> choices,
  required String currentValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final content = _HierarchyModelPickerSheet(
        choices: choices,
        currentValue: currentValue,
      );
      // Reduced motion: skip the added fade + spring-scale (modal slide only).
      if (Motion.reduced(ctx)) return content;
      // Ride the modal's slide-up with a fade + light spring-scale, matching
      // the chat model sheet. Fade on [enter] (opacity-safe), scale on the
      // [spring] (transform — overshoot is fine).
      final routeAnim =
          ModalRoute.of(ctx)?.animation ?? kAlwaysCompleteAnimation;
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: routeAnim,
          curve: MotionCurves.enter,
          reverseCurve: MotionCurves.exit,
        ),
        child: ScaleTransition(
          alignment: Alignment.bottomCenter,
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(
              parent: routeAnim,
              curve: MotionCurves.spring,
              reverseCurve: MotionCurves.exit,
            ),
          ),
          child: content,
        ),
      );
    },
  );
}

class _HierarchyModelPickerSheet extends StatelessWidget {
  final List<_ModelChoice> choices;
  final String currentValue;
  const _HierarchyModelPickerSheet({
    required this.choices,
    required this.currentValue,
  });

  /// Flatten the choices into section-header + model rows, one group per
  /// provider (groups already clustered by the caller's sort).
  List<_PickerEntry> _entries() {
    final groups = <String, List<_ModelChoice>>{};
    for (final c in choices) {
      groups.putIfAbsent(c.providerName, () => <_ModelChoice>[]).add(c);
    }
    return [
      for (final group in groups.entries) ...[
        _PickerEntry.section(group.key),
        for (final c in group.value) _PickerEntry.item(c),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final entries = _entries();
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        // Cap the height so a long grouped list scrolls inside the sheet.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.border, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_rounded,
                    color: palette.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    strings.availableModels,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                itemCount: entries.length,
                separatorBuilder: (context, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  if (entry.providerName != null) {
                    return _PickerProviderHeader(
                      name: entry.providerName!,
                      palette: palette,
                    );
                  }
                  final c = entry.choice!;
                  return _PickerModelTile(
                    label: c.modelLabel,
                    isActive: c.value == currentValue,
                    palette: palette,
                    onTap: () => Navigator.of(context).pop(c.value),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// A row in the picker: a provider section header ([providerName] set) or a
/// selectable model ([choice] set).
class _PickerEntry {
  final String? providerName;
  final _ModelChoice? choice;
  const _PickerEntry.section(this.providerName) : choice = null;
  const _PickerEntry.item(this.choice) : providerName = null;
}

/// Provider section header — small uppercase violet (#c4b5f5 accent) label
/// between two faint accent lines. Non-selectable; titles the picker's groups.
class _PickerProviderHeader extends StatelessWidget {
  final String name;
  final OsiaPalette palette;
  const _PickerProviderHeader({required this.name, required this.palette});

  @override
  Widget build(BuildContext context) {
    final line = Container(
      height: 1,
      color: palette.accent.withValues(alpha: 0.18),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Row(
        children: [
          Expanded(child: line),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              name.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: palette.accent,
              ),
            ),
          ),
          Expanded(child: line),
        ],
      ),
    );
  }
}

/// One selectable model in the picker. Shows the model's COMPLETE name —
/// wrapping to a second line instead of truncating — so long names stay
/// readable. The active entry is accent-tinted with a trailing check.
class _PickerModelTile extends StatelessWidget {
  final String label;
  final bool isActive;
  final OsiaPalette palette;
  final VoidCallback onTap;
  const _PickerModelTile({
    required this.label,
    required this.isActive,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? palette.accent.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
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
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? palette.accent : palette.textPrimary,
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 10),
                Icon(Icons.check_rounded, color: palette.accent, size: 18),
              ],
            ],
          ),
        ),
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
  late final SkillActivationGuard _skillActivationGuard;
  int _tab = 0;
  bool _personalityDirty = false;
  bool _applyingRemotePersonality = false;
  String? _pendingPersonalitySave;
  StreamSubscription<ws.ConfigData>? _configSub;

  @override
  void initState() {
    super.initState();
    _personalityCtrl.text = widget.config.personality;
    _personalityCtrl.addListener(_onPersonalityEdited);
    _skills = List<ws.ConfigSkill>.from(widget.config.skills);
    _skillActivationGuard = SkillActivationGuard(
      initialRevision: _skillStateRevision(widget.config),
    );
    _configSub = widget.wsService.configStream.listen((data) {
      if (!mounted) return;
      if (_pendingPersonalitySave == data.personality &&
          _personalityCtrl.text == data.personality) {
        _pendingPersonalitySave = null;
        _personalityDirty = false;
      }
      if (!_personalityDirty && _personalityCtrl.text != data.personality) {
        _applyingRemotePersonality = true;
        _personalityCtrl.text = data.personality;
        _applyingRemotePersonality = false;
      }
      final revision = _skillStateRevision(data);
      if (_skillActivationGuard.acceptSnapshot(revision)) {
        final requested = _requestedSkillStates(data);
        var activationRejected = false;
        final reconciled = <ws.ConfigSkill>[
          for (final skill in data.skills)
            () {
              final decision = _skillActivationGuard.reconcile(
                name: skill.name,
                requested: requested[skill.name] ?? true,
                effective: skill.enabled,
              );
              activationRejected = activationRejected || decision.rejected;
              return ws.ConfigSkill(
                name: skill.name,
                enabled: decision.enabled,
                text: skill.text,
              );
            }(),
        ];
        _skillActivationGuard.retainSkills(
          reconciled.map((skill) => skill.name),
        );
        setState(() => _skills = reconciled);
        if (activationRejected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(OsiaL10n.of(context).skillActivationRejected),
            ),
          );
        }
      }
    });
  }

  static int _skillStateRevision(ws.ConfigData data) {
    final raw = data.settings['skills_state_revision'];
    return raw is int && raw >= 0 ? raw : 0;
  }

  static Map<String, bool> _requestedSkillStates(ws.ConfigData data) {
    final raw = data.settings['skills_enabled'];
    if (raw is! Map) return const <String, bool>{};
    return <String, bool>{
      for (final entry in raw.entries)
        if (entry.key.toString().isNotEmpty)
          entry.key.toString(): entry.value == true,
    };
  }

  void _onPersonalityEdited() {
    if (!_applyingRemotePersonality) {
      _personalityDirty = true;
      if (_pendingPersonalitySave != _personalityCtrl.text) {
        _pendingPersonalitySave = null;
      }
    }
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _personalityCtrl.removeListener(_onPersonalityEdited);
    _personalityCtrl.dispose();
    super.dispose();
  }

  void _savePersonality() {
    _pendingPersonalitySave = _personalityCtrl.text;
    _personalityDirty = true;
    widget.wsService.sendSetPersonality(_personalityCtrl.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(OsiaL10n.of(context).personalitySaved)),
    );
  }

  void _toggleSkill(ws.ConfigSkill skill, bool value) {
    _skillActivationGuard.begin(skill.name, value);
    setState(() {
      _skills = [
        for (final s in _skills)
          s.name == skill.name
              ? ws.ConfigSkill(name: s.name, enabled: value, text: s.text)
              : s,
      ];
    });
    widget.wsService.sendSetSkill(skill.name, enabled: value);
    widget.wsService.sendGetConfig();
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
            child: Text(
              strings.cancel,
              style: TextStyle(color: palette.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.delete, style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(
      () => _skills = _skills.where((s) => s.name != skill.name).toList(),
    );
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
            child: Text(
              strings.cancel,
              style: TextStyle(color: palette.textMuted),
            ),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                strings.personalityDesc,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: palette.textMuted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                color: palette.textPrimary,
                fontSize: 14.5,
                height: 1.4,
              ),
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
            label: strings.save,
            onTap: _savePersonality,
            palette: palette,
          ),
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
            label: strings.skillAdd,
            palette: palette,
            onTap: _addSkill,
          ),
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
            activeThumbColor: palette.isDark
                ? palette.background
                : Colors.white,
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
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 19,
              color: palette.textMuted,
            ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(OsiaL10n.of(context).skillSaved)));
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
                    color: palette.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
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
                label: strings.save,
                onTap: _save,
                palette: palette,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skill filenames carry a `.md` suffix on disk; show the bare stem.
String _skillDisplay(String name) => name.toLowerCase().endsWith('.md')
    ? name.substring(0, name.length - 3)
    : name;

// ══════════════════════════════════════════════════════════════════════════
// System status (heartbeat)
// ══════════════════════════════════════════════════════════════════════════

/// Live system-metrics dashboard plus heartbeat alert settings. The toggle,
/// interval and per-metric checks are pre-filled from `config.settings` and
/// written back via `set_setting`; the metrics refresh in real time from
/// `heartbeat_data` pushes on [heartbeatStream].
class _HeartbeatScreen extends StatefulWidget {
  final ws.WebSocketService wsService;
  final ws.ConfigData config;
  const _HeartbeatScreen({required this.wsService, required this.config});

  @override
  State<_HeartbeatScreen> createState() => _HeartbeatScreenState();
}

class _HeartbeatScreenState extends State<_HeartbeatScreen> {
  late HeartbeatSettings _heartbeat;
  late final TextEditingController _intervalCtrl;
  late final FocusNode _intervalFocus;
  late final Map<String, TextEditingController> _thresholdCtrls;
  late final Map<String, FocusNode> _thresholdFocus;
  ws.HeartbeatDataMessage? _latest;
  StreamSubscription<ws.ConfigData>? _configSub;
  StreamSubscription<ws.HeartbeatDataMessage>? _hbSub;

  @override
  void initState() {
    super.initState();
    _heartbeat = HeartbeatSettings.fromSettings(widget.config.settings);
    _intervalCtrl = TextEditingController(
      text: '${_heartbeat.intervalSeconds}',
    );
    _intervalFocus = FocusNode();
    // Persist a clamped interval when the field loses focus — covers the case
    // where the user edits then navigates away without pressing "done".
    _intervalFocus.addListener(() {
      if (!_intervalFocus.hasFocus) _persistInterval();
    });
    _thresholdCtrls = {
      for (final metric in heartbeatThresholdMetricIds)
        metric: TextEditingController(
          text: '${_heartbeat.checks[metric]?.threshold}',
        ),
    };
    _thresholdFocus = {
      for (final metric in heartbeatThresholdMetricIds) metric: FocusNode(),
    };
    for (final metric in heartbeatThresholdMetricIds) {
      _thresholdFocus[metric]!.addListener(() {
        if (!_thresholdFocus[metric]!.hasFocus) _persistThreshold(metric);
      });
    }
    _configSub = widget.wsService.configStream.listen((cfg) {
      _applyConfigSettings(cfg.settings);
    });
    _hbSub = widget.wsService.heartbeatStream.listen((msg) {
      if (mounted) setState(() => _latest = msg);
    });
  }

  void _applyConfigSettings(Map<String, dynamic> settings) {
    final next = HeartbeatSettings.fromSettings(settings);
    if (!mounted) return;
    setState(() {
      _heartbeat = next;
      _syncFieldText(next, overwriteFocused: false);
    });
  }

  void _syncFieldText(
    HeartbeatSettings settings, {
    required bool overwriteFocused,
  }) {
    if (overwriteFocused || !_intervalFocus.hasFocus) {
      _setControllerText(_intervalCtrl, '${settings.intervalSeconds}');
    }
    for (final metric in heartbeatThresholdMetricIds) {
      final focus = _thresholdFocus[metric];
      if (overwriteFocused || focus?.hasFocus != true) {
        final value =
            settings.checks[metric]?.threshold ??
            HeartbeatSettings.defaultThresholds[metric]!;
        _setControllerText(_thresholdCtrls[metric]!, '$value');
      }
    }
  }

  void _setControllerText(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _hbSub?.cancel();
    _intervalFocus.dispose();
    _intervalCtrl.dispose();
    for (final focus in _thresholdFocus.values) {
      focus.dispose();
    }
    for (final controller in _thresholdCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggle(bool v) {
    setState(() => _heartbeat = _heartbeat.copyWith(enabled: v));
    widget.wsService.sendSetSetting(heartbeatEnabledSettingKey, v);
  }

  void _persistInterval() {
    final clamped = HeartbeatSettings.sanitizeInterval(_intervalCtrl.text);
    // Reflect the clamped value back so the user sees what was actually saved.
    setState(() {
      _heartbeat = _heartbeat.copyWith(intervalSeconds: clamped);
      _setControllerText(_intervalCtrl, '$clamped');
    });
    widget.wsService.sendSetSetting(heartbeatIntervalSettingKey, clamped);
  }

  void _toggleMetric(String metric, bool enabled) {
    final next = _heartbeat.withMetricEnabled(metric, enabled);
    setState(() => _heartbeat = next);
    _persistHeartbeatChecks(next);
  }

  void _persistThreshold(String metric) {
    final controller = _thresholdCtrls[metric];
    if (controller == null) return;
    final next = _heartbeat.withThreshold(metric, controller.text);
    final value =
        next.checks[metric]?.threshold ??
        HeartbeatSettings.defaultThresholds[metric]!;
    setState(() {
      _heartbeat = next;
      _setControllerText(controller, '$value');
    });
    _persistHeartbeatChecks(next);
  }

  void _persistHeartbeatChecks(HeartbeatSettings settings) {
    widget.wsService.sendSetSetting(
      heartbeatChecksSettingKey,
      settings.checksForSettings(),
    );
  }

  String _metricLabel(String metric, OsiaStrings strings) {
    return switch (metric) {
      'cpu' => strings.metricCpu,
      'ram' => strings.metricRam,
      'disk' => strings.metricDisk,
      'network' => strings.metricNetwork,
      _ => metric,
    };
  }

  String _metricHint(String metric, OsiaStrings strings) {
    return switch (metric) {
      'disk' => strings.heartbeatDiskThresholdHint,
      'network' => strings.heartbeatNetworkHint,
      _ => strings.heartbeatUsageThresholdHint,
    };
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
              Text(
                strings.heartbeatDesc,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              // ── Enable monitoring ──
              _OsiaCard(
                palette: palette,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
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
                      value: _heartbeat.enabled,
                      onChanged: _toggle,
                      activeTrackColor: palette.accent,
                      activeThumbColor: palette.isDark
                          ? palette.background
                          : Colors.white,
                      inactiveTrackColor: palette.border.withValues(alpha: 0.5),
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
                      key: const ValueKey('heartbeat_interval_seconds'),
                      controller: _intervalCtrl,
                      focusNode: _intervalFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) => _persistInterval(),
                      cursorColor: palette.accent,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: palette.surface,
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      strings.heartbeatIntervalRange,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel(
                label: strings.heartbeatChecksHeader,
                palette: palette,
              ),
              const SizedBox(height: 4),
              for (final metric in heartbeatMetricIds) ...[
                _HeartbeatCheckRow(
                  metric: metric,
                  label: _metricLabel(metric, strings),
                  hint: _metricHint(metric, strings),
                  enabled: _heartbeat.checks[metric]?.enabled ?? false,
                  thresholdController: _thresholdCtrls[metric],
                  thresholdFocus: _thresholdFocus[metric],
                  palette: palette,
                  onEnabledChanged: (v) => _toggleMetric(metric, v),
                  onThresholdSubmitted: () => _persistThreshold(metric),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 14),
              // ── Live metrics dashboard ──
              _SectionLabel(
                label: strings.systemMetricsHeader,
                palette: palette,
              ),
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

/// One desktop heartbeat alert check mirrored onto mobile.
class _HeartbeatCheckRow extends StatelessWidget {
  final String metric;
  final String label;
  final String hint;
  final bool enabled;
  final TextEditingController? thresholdController;
  final FocusNode? thresholdFocus;
  final OsiaPalette palette;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onThresholdSubmitted;

  const _HeartbeatCheckRow({
    required this.metric,
    required this.label,
    required this.hint,
    required this.enabled,
    required this.thresholdController,
    required this.thresholdFocus,
    required this.palette,
    required this.onEnabledChanged,
    required this.onThresholdSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final controller = thresholdController;
    return _OsiaCard(
      palette: palette,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Switch(
                key: ValueKey('heartbeat_${metric}_enabled'),
                value: enabled,
                onChanged: onEnabledChanged,
                activeTrackColor: palette.accent,
                activeThumbColor: palette.isDark
                    ? palette.background
                    : Colors.white,
                inactiveTrackColor: palette.border.withValues(alpha: 0.5),
                inactiveThumbColor: palette.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (controller != null) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 76,
                  child: TextField(
                    key: ValueKey('heartbeat_${metric}_threshold'),
                    controller: controller,
                    focusNode: thresholdFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => onThresholdSubmitted(),
                    textAlign: TextAlign.center,
                    cursorColor: palette.accent,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: palette.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 11,
                      ),
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
                        borderSide: BorderSide(
                          color: palette.accent,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '%',
                  style: TextStyle(fontSize: 13, color: palette.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 66),
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 12.2,
                height: 1.35,
                color: palette.textMuted,
              ),
            ),
          ),
        ],
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
    final double fraction = v == null
        ? 0.0
        : (v / 100).clamp(0.0, 1.0).toDouble();
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
                  style: TextStyle(fontSize: 13.5, color: palette.textPrimary),
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
  Widget build(BuildContext context) =>
      Text(label, style: TextStyle(fontSize: 13, color: palette.textMuted));
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
                  color: value == null
                      ? palette.textMuted
                      : palette.textPrimary,
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
                  duration: MotionDurations.medium,
                  curve: MotionCurves.enter,
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
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
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

// ─────────────────────────────────────────────────────────────────────────
// MCP / Connectors (WOR-44 Phase 4)
//
// A dedicated category mirroring the PC's "MCP / Connectors" panel: a single
// "Connector" dropdown selects which connector's panel shows below
// (description, token / extra-env fields, a live status pill, and a
// Connect/Disconnect button). OAuth / HTTP connectors render a disabled "soon"
// button. Custom stdio servers the user adds appear after the catalog in the
// dropdown.
//
// Contract (all additive — the server side is already done):
//   - server-provided catalog/saved entries drive the list; local catalog values
//     are fallback metadata for older servers;
//   - the saved server LIST round-trips through `set_setting mcp_servers`
//     (env ALWAYS {} — never a token);
//   - the token is stored separately via `set_api_key` under `mcp:<id>`;
//   - Connect/Disconnect send `mcp_connect` / `mcp_disconnect`; live status
//     arrives on [ws.WebSocketService.mcpStatusStream] (requested on open).

/// One non-secret extra env field a connector needs (e.g. Slack's team id).
class _McpExtraField {
  final String varName;
  final bool required;
  const _McpExtraField({required this.varName, this.required = false});
}

/// A connector definition — a catalog entry or a user's custom stdio server.
class _McpConnector {
  final String id;
  final String name;

  /// Catalog description selector ('github'…'gmail'); empty for custom servers
  /// (which show "transport · command" instead).
  final String descField;
  final String transport; // 'stdio' | 'streamable_http'
  final String? command;
  final List<String> args;
  final String? url;
  final String authType; // 'token' | 'oauth' | 'none'
  final String? tokenEnv;
  final List<_McpExtraField> extraEnv;
  final bool custom;
  final String? nativeIntegration;

  const _McpConnector({
    required this.id,
    required this.name,
    this.descField = '',
    required this.transport,
    this.command,
    this.args = const [],
    this.url,
    required this.authType,
    this.tokenEnv,
    this.extraEnv = const [],
    this.custom = false,
    this.nativeIntegration,
  });

  bool get isGmailRest =>
      id == _nativeGmailRestId &&
      nativeIntegration == _nativeGmailRestIntegration;

  /// Token-auth connectors (stdio OR streamable-HTTP) can be connected today —
  /// the server now supports the streamable-HTTP transport (e.g. Notion). Only
  /// OAuth connectors remain gated and show "soon".
  bool get connectable => !isGmailRest && authType != 'oauth';

  /// A connectable connector that authenticates with a token in [tokenEnv].
  bool get needsToken => connectable && authType == 'token';

  bool get hasOauthEndpoint => (url?.trim().isNotEmpty ?? false);
}

const String _nativeGmailRestId = 'gmail';
const String _nativeGmailRestIntegration = 'gmail-rest';
const String _legacyGmailMcpId = 'gmail-mcp-legacy';
const String _legacyGmailMcpHost = 'gmailmcp.googleapis.com';

/// The preconfigured catalog — parity with the PC `_MCP_CATALOG`. GitHub and
/// Slack are stdio/token and Notion is streamable-HTTP/token (all connectable
/// now); Linear/Google Drive are OAuth. Gmail is shown separately from the
/// native REST mirror, not as an MCP OAuth connector.
/// Filesystem and Brave Search are intentionally absent (each duplicates a
/// native OSIA capability).
const List<_McpConnector> _mcpCatalog = [
  _McpConnector(
    id: 'github',
    name: 'GitHub',
    descField: 'github',
    transport: 'stdio',
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-github'],
    authType: 'token',
    tokenEnv: 'GITHUB_PERSONAL_ACCESS_TOKEN',
  ),
  _McpConnector(
    id: 'slack',
    name: 'Slack',
    descField: 'slack',
    transport: 'stdio',
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-slack'],
    authType: 'token',
    tokenEnv: 'SLACK_BOT_TOKEN',
    extraEnv: [_McpExtraField(varName: 'SLACK_TEAM_ID', required: true)],
  ),
  _McpConnector(
    id: 'notion',
    name: 'Notion',
    descField: 'notion',
    transport: 'streamable_http',
    url: 'https://mcp.notion.com/mcp',
    authType: 'token',
  ),
  _McpConnector(
    id: 'linear',
    name: 'Linear',
    descField: 'linear',
    transport: 'streamable_http',
    url: 'https://mcp.linear.app/mcp',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'google-drive',
    name: 'Google Drive',
    descField: 'gdrive',
    transport: 'streamable_http',
    url: 'https://drivemcp.googleapis.com/mcp/v1',
    authType: 'oauth',
  ),
  _McpConnector(
    id: _nativeGmailRestId,
    name: 'Gmail',
    descField: 'gmail',
    transport: 'native',
    authType: 'native_oauth',
    nativeIntegration: _nativeGmailRestIntegration,
  ),
  _McpConnector(
    id: 'sentry',
    name: 'Sentry',
    transport: 'streamable_http',
    url: 'https://mcp.sentry.dev/mcp',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'stripe',
    name: 'Stripe',
    transport: 'streamable_http',
    url: 'https://mcp.stripe.com',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'vercel',
    name: 'Vercel',
    transport: 'streamable_http',
    url: 'https://mcp.vercel.com',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'supabase',
    name: 'Supabase',
    transport: 'streamable_http',
    url: 'https://mcp.supabase.com/mcp',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'neon',
    name: 'Neon',
    transport: 'streamable_http',
    url: 'https://mcp.neon.tech/mcp',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'atlassian',
    name: 'Atlassian',
    transport: 'streamable_http',
    url: 'https://mcp.atlassian.com/v1/mcp',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'canva',
    name: 'Canva',
    transport: 'streamable_http',
    url: 'https://mcp.canva.com/mcp',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'paypal',
    name: 'PayPal',
    transport: 'streamable_http',
    url: 'https://mcp.paypal.com/mcp',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'asana',
    name: 'Asana',
    transport: 'streamable_http',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'hubspot',
    name: 'HubSpot',
    transport: 'streamable_http',
    authType: 'oauth',
  ),
  _McpConnector(
    id: 'figma',
    name: 'Figma',
    transport: 'streamable_http',
    authType: 'oauth',
  ),
];

const Set<String> _mcpCatalogIds = {
  'github',
  'slack',
  'notion',
  'linear',
  'google-drive',
  'gmail',
  'sentry',
  'stripe',
  'vercel',
  'supabase',
  'neon',
  'atlassian',
  'canva',
  'paypal',
  'asana',
  'hubspot',
  'figma',
};

const Set<String> _reservedGmailMcpIds = {
  _nativeGmailRestId,
  'gmail-mcp-legacy',
};

class _McpScreen extends StatefulWidget {
  final ws.WebSocketService wsService;
  final ws.ConfigData config;
  final Future<bool> Function(Uri uri)? oauthUrlLauncher;

  const _McpScreen({
    required this.wsService,
    required this.config,
    this.oauthUrlLauncher,
  });

  @override
  State<_McpScreen> createState() => _McpScreenState();
}

class _McpScreenState extends State<_McpScreen> {
  /// Persisted server list (non-secret) — the `mcp_servers` setting. Seeded from
  /// the config snapshot, re-seeded on every config push, and replace-written
  /// wholesale via `set_setting` (the server forces env={} on each entry).
  late List<Map<String, dynamic>> _servers;
  late List<Map<String, dynamic>> _serverCatalog;

  /// Which providers have a key set on the PC (`mcp:<id>` → bool).
  late Map<String, bool> _apiKeysSet;

  /// Live connector status per id, merged from `mcp_status` pushes.
  final Map<String, ws.McpServerStatus> _statuses = {};

  /// Native Gmail REST state from the config snapshot. Gmail auth, tokens and
  /// REST calls stay server-side; Mobile only requests safe connector actions.
  ws.GmailRestConfig? _gmailRest;
  bool _gmailRestConnecting = false;
  bool _gmailRestAttemptExpired = false;
  bool _gmailRestDisconnecting = false;
  String? _gmailRestDisconnectError;
  String? _pendingGmailRequestId;
  String? _pendingGmailAttemptId;
  Timer? _gmailRestAttemptTimer;
  final Set<String> _openedGmailAttemptIds = <String>{};

  /// The connector currently shown in the panel.
  String _selectedId = _mcpCatalog.first.id;

  /// Token field obscured (masked) — toggled by the eye button.
  bool _obscureToken = true;

  /// Lazily-created field controllers, keyed by connector id. Disposed in
  /// [dispose].
  final Map<String, TextEditingController> _tokenCtrls = {};
  final Map<String, Map<String, TextEditingController>> _extraCtrls = {};

  StreamSubscription<ws.ConfigData>? _configSub;
  StreamSubscription<ws.McpStatusMessage>? _statusSub;
  StreamSubscription<ws.McpOauthUrl>? _oauthSub;
  StreamSubscription<ws.ConnectionState>? _connSub;

  /// The OAuth connector the user just tapped Connect on (WOR-96 PART 2b) — so
  /// the arriving `mcp_oauth_url` (which carries the same id) opens the browser
  /// for THIS tap, and a stale / non-matching id is ignored.
  String? _pendingOauthId;

  @override
  void initState() {
    super.initState();
    _servers = _readServers(widget.config);
    _serverCatalog = _readServerCatalog(widget.config);
    _apiKeysSet = Map<String, bool>.from(widget.config.apiKeysSet);
    _gmailRest = widget.config.gmailRest;
    _gmailRestConnecting = _gmailRest?.connecting == true;
    _syncGmailAttemptTimer(_gmailRest);

    // Stay live while open: canonical config and connector status can change
    // on the PC, while credential values remain there.
    _configSub = widget.wsService.configStream.listen((cfg) {
      if (!mounted) return;
      setState(() {
        _servers = _readServers(cfg);
        _serverCatalog = _readServerCatalog(cfg);
        _apiKeysSet = Map<String, bool>.from(cfg.apiKeysSet);
        final nextGmail = cfg.gmailRest;
        _gmailRest = nextGmail;
        _gmailRestConnecting = nextGmail?.connecting == true;
        _gmailRestAttemptExpired = false;
        if (!_gmailRestConnecting) {
          _pendingGmailRequestId = null;
          _pendingGmailAttemptId = null;
        }
        if (_gmailRestDisconnecting && nextGmail?.connected != true) {
          _gmailRestDisconnecting = false;
          _gmailRestDisconnectError = null;
        } else if (_gmailRestDisconnecting &&
            (nextGmail?.status ?? '').trim().toLowerCase() == 'failed') {
          final reason = nextGmail?.reason?.trim() ?? '';
          _gmailRestDisconnecting = false;
          _gmailRestDisconnectError = reason.isEmpty
              ? OsiaL10n.of(context).mcpStatusFailed
              : reason;
        }
        _syncGmailAttemptTimer(nextGmail);
      });
    });
    _statusSub = widget.wsService.mcpStatusStream.listen((msg) {
      if (!mounted) return;
      // Merge: a transition push is scoped to one server; a poll reply is the
      // full set — so a single-server broadcast can't wipe the others.
      setState(() {
        _statuses.addAll(msg.servers);
        final gmailStatus =
            msg.servers[_nativeGmailRestIntegration] ??
            msg.servers[_nativeGmailRestId];
        final raw = gmailStatus?.status.trim().toLowerCase() ?? '';
        if (raw == 'failed') {
          final error = gmailStatus?.error.trim() ?? '';
          _gmailRestDisconnecting = false;
          _gmailRestDisconnectError = error.isEmpty
              ? OsiaL10n.of(context).mcpStatusFailed
              : error;
        }
      });
    });
    _oauthSub = widget.wsService.mcpOauthUrlStream.listen((evt) {
      if (!mounted) return;
      if (evt.id == _nativeGmailRestIntegration) {
        final expectedRequest = _pendingGmailRequestId;
        if (expectedRequest == null || evt.requestId != expectedRequest) {
          return;
        }
        if (!_isTrustedGmailAuthorizationUrl(evt.url)) {
          widget.wsService.sendMcpOauthCancel(
            _nativeGmailRestIntegration,
            requestId: ws.WebSocketService.newClientRequestId(),
            attemptId: evt.attemptId,
          );
          setState(() {
            _pendingGmailRequestId = null;
            _pendingGmailAttemptId = null;
            _gmailRestConnecting = false;
            _gmailRestDisconnectError = OsiaL10n.of(context).linkOpenFailed;
          });
          widget.wsService.sendGetConfig();
          return;
        }
        final attemptId = evt.attemptId ?? evt.url;
        if (!_openedGmailAttemptIds.add(attemptId)) return;
        setState(() {
          _pendingGmailRequestId = null;
          _pendingGmailAttemptId = evt.attemptId;
          _gmailRestConnecting = true;
          _gmailRestAttemptExpired = false;
        });
        _scheduleGmailAttemptExpiry(evt.expiresAt);
        _openOauthUrl(evt.url);
        return;
      }
      // Correlate by id: only open the browser for the connector the user just
      // tapped Connect on; ignore a stale / non-matching id.
      if (evt.id != _pendingOauthId) return;
      if (!isTrustedMcpAuthorizationUrl(evt.url)) {
        widget.wsService.sendMcpOauthCancel(evt.id);
        _pendingOauthId = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(OsiaL10n.of(context).linkOpenFailed)),
        );
        return;
      }
      _pendingOauthId = null;
      _openOauthUrl(evt.url);
    });

    _connSub = widget.wsService.connectionStream.listen((state) {
      if (state == ws.ConnectionState.connected) {
        _refreshServerState();
      }
    });
    _recoverConnection();
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _statusSub?.cancel();
    _oauthSub?.cancel();
    _connSub?.cancel();
    _gmailRestAttemptTimer?.cancel();
    for (final c in _tokenCtrls.values) {
      c.dispose();
    }
    for (final m in _extraCtrls.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _syncGmailAttemptTimer(ws.GmailRestConfig? gmail) {
    if (gmail?.connecting != true) {
      _gmailRestAttemptTimer?.cancel();
      _gmailRestAttemptTimer = null;
      return;
    }
    _pendingGmailAttemptId = gmail?.attemptId ?? _pendingGmailAttemptId;
    _scheduleGmailAttemptExpiry(gmail?.attemptExpiresAt);
  }

  void _scheduleGmailAttemptExpiry(double? expiresAt) {
    _gmailRestAttemptTimer?.cancel();
    if (expiresAt == null) return;
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      (expiresAt * 1000).round(),
      isUtc: true,
    );
    final delay = expiry.difference(DateTime.now().toUtc());
    _gmailRestAttemptTimer = Timer(
      delay.isNegative ? Duration.zero : delay + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        setState(() {
          _gmailRestConnecting = false;
          _gmailRestAttemptExpired = true;
          _pendingGmailRequestId = null;
          _pendingGmailAttemptId = null;
        });
        widget.wsService.sendGetConfig();
      },
    );
  }

  // ── Reads ──

  void _recoverConnection() {
    unawaited(widget.wsService.ensureConnected(reason: 'mcp_open'));
    if (widget.wsService.state == ws.ConnectionState.connected) {
      _refreshServerState();
    }
  }

  void _refreshServerState() {
    widget.wsService.sendGetConfig();
    widget.wsService.sendMcpStatus();
  }

  List<Map<String, dynamic>> _readServers(ws.ConfigData cfg) {
    final raw = cfg.settings['mcp_servers'];
    return raw is List
        ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _readServerCatalog(ws.ConfigData cfg) {
    final raw =
        cfg.settings['mcp_catalog'] ??
        cfg.settings['mcp_connector_catalog'] ??
        cfg.settings['connectors_catalog'];
    return raw is List
        ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
  }

  /// Read a bool setting, falling back to [dflt] when absent or non-bool.
  bool _readBool(Object? raw, bool dflt) => raw is bool ? raw : dflt;

  String? _readString(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  List<String> _readStringList(Object? raw) {
    return raw is List
        ? raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const [];
  }

  bool _isLegacyGmailMcpEntry(Map<String, dynamic> entry) {
    final id = _readString(entry['id'])?.toLowerCase() ?? '';
    final url = _readString(entry['url'])?.toLowerCase() ?? '';
    return id == _legacyGmailMcpId || url.contains(_legacyGmailMcpHost);
  }

  bool _isVisibleConnectorEntry(Map<String, dynamic> entry) {
    final id = _readString(entry['id']);
    if (id == null) return false;
    return !_readBool(entry['hidden'], false) &&
        !_readBool(entry['disabled'], false) &&
        !_isLegacyGmailMcpEntry(entry);
  }

  _McpConnector? _catalogFor(String id) {
    for (final c in _mcpCatalog) {
      if (c.id == id) return c;
    }
    return null;
  }

  _McpConnector _connectorFromEntry(
    Map<String, dynamic> entry, {
    _McpConnector? base,
    bool custom = false,
  }) {
    final id = _readString(entry['id']) ?? base?.id ?? '';
    final nativeIntegration = entry.containsKey('native_integration')
        ? _readString(entry['native_integration'])
        : base?.nativeIntegration;
    final isGmailRest =
        id == _nativeGmailRestId &&
        nativeIntegration == _nativeGmailRestIntegration;
    return _McpConnector(
      id: id,
      name: _readString(entry['name']) ?? base?.name ?? id,
      descField: base?.descField ?? (isGmailRest ? 'gmail' : ''),
      transport: _readString(entry['transport']) ?? base?.transport ?? 'stdio',
      command: entry.containsKey('command')
          ? _readString(entry['command'])
          : base?.command,
      args: entry.containsKey('args')
          ? _readStringList(entry['args'])
          : (base?.args ?? const []),
      url: entry.containsKey('url') ? _readString(entry['url']) : base?.url,
      authType:
          _readString(entry['auth_type']) ??
          base?.authType ??
          (isGmailRest ? 'native_oauth' : 'none'),
      tokenEnv: entry.containsKey('token_env')
          ? _readString(entry['token_env'])
          : base?.tokenEnv,
      extraEnv: base?.extraEnv ?? const [],
      custom: custom || entry['custom'] == true || (base?.custom ?? false),
      nativeIntegration: nativeIntegration,
    );
  }

  Map<String, dynamic>? _savedFor(String id) {
    for (final s in _servers) {
      if (s['id'] == id) return s;
    }
    return null;
  }

  /// All connectors for the dropdown: PC catalog/fallback metadata, overwritten
  /// by visible saved server entries. Unknown saved MCPs render generically.
  List<_McpConnector> _allConnectors() {
    final byId = <String, _McpConnector>{};
    final order = <String>[];

    void put(_McpConnector c) {
      if (c.id.isEmpty) return;
      if (!order.contains(c.id)) order.add(c.id);
      byId[c.id] = c;
    }

    final catalogSource = _serverCatalog.isNotEmpty
        ? _serverCatalog
              .where(_isVisibleConnectorEntry)
              .map(
                (entry) => _connectorFromEntry(
                  entry,
                  base: _catalogFor(_readString(entry['id']) ?? ''),
                ),
              )
        : _mcpCatalog;
    for (final c in catalogSource) {
      if (c.id == _legacyGmailMcpId) continue;
      put(c);
    }
    if (!byId.containsKey(_nativeGmailRestId)) {
      final gmail = _catalogFor(_nativeGmailRestId);
      if (gmail != null) put(gmail);
    }

    for (final s in _servers) {
      final id = _readString(s['id']) ?? '';
      if (!_isVisibleConnectorEntry(s)) {
        continue;
      }
      if (id == _nativeGmailRestId &&
          _readString(s['native_integration']) != _nativeGmailRestIntegration) {
        continue;
      }
      put(
        _connectorFromEntry(
          s,
          base: _catalogFor(id),
          custom: !_mcpCatalogIds.contains(id),
        ),
      );
    }
    return order.map((id) => byId[id]!).toList();
  }

  TextEditingController _tokenCtrlFor(_McpConnector c) {
    return _tokenCtrls.putIfAbsent(c.id, TextEditingController.new);
  }

  TextEditingController _extraCtrlFor(_McpConnector c, String varName) {
    final byVar = _extraCtrls.putIfAbsent(c.id, () => {});
    return byVar.putIfAbsent(varName, () {
      final extra = _savedFor(c.id)?['extra_env'];
      final initial = (extra is Map) ? (extra[varName]?.toString() ?? '') : '';
      return TextEditingController(text: initial);
    });
  }

  String _statusOf(String id) {
    if (id == _nativeGmailRestId) return _gmailRestStatus();
    return _statuses[id]?.status ?? 'disconnected';
  }

  String _gmailRestStatus() {
    final gmail = _gmailRest;
    if (_gmailRestDisconnecting ||
        _gmailRestConnecting ||
        (gmail?.connecting == true && !_gmailRestAttemptExpired)) {
      return 'connecting';
    }
    if (_gmailRestDisconnectError != null) return 'failed';
    final actionStatus =
        _statuses[_nativeGmailRestIntegration]?.status.trim().toLowerCase() ??
        '';
    if (actionStatus == 'failed') return actionStatus;
    if (gmail?.connected == true) return 'connected';
    final status = gmail?.status?.trim().toLowerCase() ?? '';
    if (status == 'connecting' || status == 'failed') return status;
    return 'disconnected';
  }

  bool _configured(String id) => _apiKeysSet['mcp:$id'] == true;

  String _descFor(OsiaStrings s, _McpConnector c) {
    switch (c.descField) {
      case 'github':
        return s.mcpDescGithub;
      case 'slack':
        return s.mcpDescSlack;
      case 'notion':
        return s.mcpDescNotion;
      case 'linear':
        return s.mcpDescLinear;
      case 'gdrive':
        return s.mcpDescGdrive;
      case 'gmail':
        return s.mcpDescGmail;
      default:
        // Custom server — show its transport and command/url.
        final detail = (c.command?.isNotEmpty ?? false)
            ? c.command!
            : (c.url ?? '');
        return detail.isEmpty ? c.transport : '${c.transport} · $detail';
    }
  }

  String _extraLabel(OsiaStrings s, String varName) =>
      varName == 'SLACK_TEAM_ID' ? s.mcpSlackTeam : varName;

  String _extraHint(OsiaStrings s, String varName) =>
      varName == 'SLACK_TEAM_ID' ? s.mcpSlackTeamPh : '';

  bool _canConnect(_McpConnector c) {
    if (!c.connectable) return false;
    // A token-auth connector needs a token in the field OR one already stored.
    if (c.needsToken &&
        _tokenCtrlFor(c).text.trim().isEmpty &&
        !_configured(c.id)) {
      return false;
    }
    for (final f in c.extraEnv) {
      if (f.required && _extraCtrlFor(c, f.varName).text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  // ── Writes ──

  void _upsert(Map<String, dynamic> entry) {
    final i = _servers.indexWhere((s) => s['id'] == entry['id']);
    if (i >= 0) {
      _servers[i] = entry;
    } else {
      _servers.add(entry);
    }
  }

  /// Build the persisted (non-secret) entry for [c]. `env` is ALWAYS {} — the
  /// token never travels in this list (it goes via `set_api_key`).
  Map<String, dynamic> _buildEntry(_McpConnector c, {required bool enabled}) {
    final extra = <String, dynamic>{};
    for (final f in c.extraEnv) {
      final v = _extraCtrlFor(c, f.varName).text.trim();
      if (v.isNotEmpty) extra[f.varName] = v;
    }
    // Carry forward extra_env saved for custom connectors (whose fields aren't
    // rendered here) so a reconnect keeps them.
    final saved = _savedFor(c.id);
    if (c.extraEnv.isEmpty && saved?['extra_env'] is Map) {
      (saved!['extra_env'] as Map).forEach((k, v) => extra[k.toString()] = v);
    }
    return {
      'id': c.id,
      'name': c.name,
      'transport': c.transport,
      'command': c.command,
      'args': c.args,
      'url': c.url,
      'env': <String, dynamic>{}, // never a token — server forces this anyway
      'auth_type': c.authType,
      'enabled': enabled,
      'token_env': c.tokenEnv,
      'extra_env': extra,
      'custom': c.custom,
    };
  }

  void _connect(_McpConnector c) {
    _upsert(_buildEntry(c, enabled: true));
    widget.wsService.sendSetSetting('mcp_servers', _servers);
    if (c.needsToken) {
      final token = _tokenCtrlFor(c).text.trim();
      // Only write when the user supplied one — an empty field with a token
      // already stored keeps the existing secret rather than clearing it.
      if (token.isNotEmpty) {
        widget.wsService.sendSetApiKey('mcp:${c.id}', token);
      }
    }
    widget.wsService.sendMcpConnect(c.id);
    // Optimistic pill — flips on the pushed/polled status (non-blocking).
    setState(
      () => _statuses[c.id] = const ws.McpServerStatus(status: 'connecting'),
    );
    widget.wsService.sendGetConfig();
  }

  void _disconnect(
    _McpConnector c, {
    String? actionId,
    String? statusId,
    bool updateSavedEntry = true,
    ws.McpServerStatus optimisticStatus = const ws.McpServerStatus(
      status: 'disconnected',
    ),
  }) {
    final saved = _savedFor(c.id);
    if (updateSavedEntry && saved != null) {
      final entry = Map<String, dynamic>.from(saved);
      entry['enabled'] = false;
      entry['env'] = <String, dynamic>{};
      _upsert(entry);
      widget.wsService.sendSetSetting('mcp_servers', _servers);
    }
    widget.wsService.sendMcpDisconnect(actionId ?? c.id);
    setState(() => _statuses[statusId ?? c.id] = optimisticStatus);
    widget.wsService.sendGetConfig();
  }

  void _connectGmailRest() {
    final strings = OsiaL10n.of(context);
    final gmail = _gmailRest;
    final supported = gmail?.mobileOAuthConfigured == true;
    final connecting =
        _gmailRestConnecting ||
        (gmail?.connecting == true && !_gmailRestAttemptExpired) ||
        _pendingGmailRequestId != null;
    final reconnecting = gmail?.connected == true;
    if (!supported || connecting) return;
    if (reconnecting && gmail?.canReconnect != true) return;
    if (!reconnecting &&
        gmail?.canConnect != true &&
        !_gmailRestAttemptExpired) {
      return;
    }
    if (widget.wsService.state != ws.ConnectionState.connected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.pcOffline)));
      return;
    }

    final requestId = ws.WebSocketService.newClientRequestId();
    setState(() {
      _pendingGmailRequestId = requestId;
      _pendingGmailAttemptId = null;
      _gmailRestConnecting = true;
      _gmailRestAttemptExpired = false;
      _gmailRestDisconnectError = null;
    });
    widget.wsService.sendMcpConnect(
      _nativeGmailRestIntegration,
      requestId: requestId,
    );
    widget.wsService.sendGetConfig();
  }

  void _cancelGmailRestConnect() {
    final gmail = _gmailRest;
    if (!(_gmailRestConnecting || gmail?.connecting == true)) return;
    final requestId = ws.WebSocketService.newClientRequestId();
    widget.wsService.sendMcpOauthCancel(
      _nativeGmailRestIntegration,
      requestId: requestId,
      attemptId: _pendingGmailAttemptId ?? gmail?.attemptId,
    );
    _gmailRestAttemptTimer?.cancel();
    setState(() {
      _gmailRestConnecting = false;
      _gmailRestAttemptExpired = false;
      _pendingGmailRequestId = null;
      _pendingGmailAttemptId = null;
    });
    widget.wsService.sendGetConfig();
  }

  void _disconnectGmailRest(_McpConnector c) {
    final strings = OsiaL10n.of(context);
    final gmail = _gmailRest;
    final connected = gmail?.connected == true;
    final blockedByServer =
        connected &&
        gmail?.canDisconnectProvided == true &&
        gmail?.canDisconnect == false;
    if (!connected || blockedByServer || _gmailRestDisconnecting) return;
    if (widget.wsService.state != ws.ConnectionState.connected) {
      setState(() {
        _gmailRestDisconnecting = false;
        _gmailRestDisconnectError = strings.pcOffline;
        _statuses[_nativeGmailRestIntegration] = ws.McpServerStatus(
          status: 'failed',
          error: strings.pcOffline,
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.pcOffline)));
      return;
    }

    debugPrint(
      '[OSIA MCP] action=mcp_disconnect id=$_nativeGmailRestIntegration',
    );
    setState(() {
      _gmailRestDisconnecting = true;
      _gmailRestDisconnectError = null;
    });
    _disconnect(
      c,
      actionId: _nativeGmailRestIntegration,
      statusId: _nativeGmailRestIntegration,
      updateSavedEntry: false,
      optimisticStatus: const ws.McpServerStatus(status: 'connecting'),
    );
  }

  void _toggle(_McpConnector c) {
    if (_statusOf(c.id) == 'connected') {
      _disconnect(c);
    } else {
      _connect(c);
    }
  }

  /// OAuth connectors (WOR-96 PART 2b). Connect reuses the existing send path:
  /// `_connect` sends `mcp_connect{id}`, the server drives the tunnel OAuth
  /// flow and replies with a standalone `mcp_oauth_url` on [mcpOauthUrlStream]
  /// — which [_openOauthUrl] opens in an external browser. The PC captures the
  /// callback via the tunnel; completion flips the pill via the `mcp_status`
  /// broadcast. Disconnect is the plain, silent path (`mcp_disconnect{id}`,
  /// token kept) — sign-out / switch-account revoke instead.
  void _toggleOauth(_McpConnector c) {
    if (_statusOf(c.id) == 'connected') {
      _disconnect(c);
    } else {
      _pendingOauthId = c.id;
      _connect(c);
    }
  }

  /// Cancel an in-flight OAuth connect (WOR-97): send `mcp_oauth_cancel{id}`.
  /// Server-side this is a no-op unless the connector is `connecting`; it
  /// carries no secret and leaves the saved `enabled` flag untouched. We flip
  /// the pill optimistically to `disconnected` and clear [_pendingOauthId] so a
  /// late `mcp_oauth_url` won't auto-open the browser after cancel. The
  /// authoritative `disconnected` arrives via the `mcp_status` broadcast
  /// (mirrors [_disconnect]).
  void _cancelOauth(_McpConnector c) {
    widget.wsService.sendMcpOauthCancel(c.id);
    if (_pendingOauthId == c.id) _pendingOauthId = null;
    setState(
      () => _statuses[c.id] = const ws.McpServerStatus(status: 'disconnected'),
    );
    widget.wsService.sendGetConfig();
  }

  /// Open the OAuth authorization [url] in an external browser / Custom Tab.
  /// The phone does NOT capture the callback — the PC does, via the tunnel —
  /// so an external launch (not an in-app web-auth session) is all we need.
  Future<void> _openOauthUrl(String url) async {
    var opened = false;
    try {
      final uri = Uri.parse(url);
      final injected = widget.oauthUrlLauncher;
      opened = injected != null
          ? await injected(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    final strings = OsiaL10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened ? strings.mcpOpeningBrowser : strings.linkOpenFailed,
        ),
      ),
    );
  }

  bool _isTrustedGmailAuthorizationUrl(String url) {
    return isTrustedGmailAuthorizationUrl(url);
  }

  /// Switch account on an OAuth connector: revoke AND forget the client
  /// (`mcp_disconnect{id,revoke:true,forget_client:true}`) so a re-connect can
  /// pick a different account. (A sticky browser SSO cookie can still re-pick
  /// the same account unless the provider shows an account chooser.)
  void _switchOauthAccount(_McpConnector c) {
    widget.wsService.sendMcpSignOut(c.id, forgetClient: true);
    setState(
      () => _statuses[c.id] = const ws.McpServerStatus(status: 'disconnected'),
    );
    widget.wsService.sendGetConfig();
  }

  Future<void> _removeCustom(_McpConnector c) async {
    final strings = OsiaL10n.of(context);
    final palette = OsiaTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          strings.mcpRemove,
          style: TextStyle(fontSize: 16, color: palette.textPrimary),
        ),
        content: Text(
          c.name,
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
            child: Text(strings.delete, style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.wsService.sendMcpDisconnect(c.id);
    widget.wsService.sendDeleteApiKey('mcp:${c.id}');
    setState(() {
      _servers.removeWhere((s) => s['id'] == c.id);
      _statuses.remove(c.id);
      _selectedId = _mcpCatalog.first.id;
    });
    widget.wsService.sendSetSetting('mcp_servers', _servers);
    widget.wsService.sendGetConfig();
  }

  String _slugify(String name) {
    var s = name
        .replaceAll(RegExp(r'[^A-Za-z0-9.-]+'), '-')
        .replaceAll('__', '-')
        .toLowerCase()
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'server' : s;
  }

  String _uniqueId(String base) {
    final taken = {
      ..._mcpCatalogIds,
      ..._reservedGmailMcpIds,
      ..._servers.map((s) => (s['id'] ?? '').toString()),
    };
    if (!taken.contains(base)) return base;
    var n = 2;
    while (taken.contains('$base-$n')) {
      n++;
    }
    return '$base-$n';
  }

  Future<void> _addCustom() async {
    final result = await showDialog<_McpCustomResult>(
      context: context,
      builder: (ctx) => const _McpCustomDialog(),
    );
    if (result == null || !mounted) return;
    final id = _uniqueId(_slugify(result.name));
    final parts = result.command
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final hasToken = result.token.trim().isNotEmpty;
    final entry = <String, dynamic>{
      'id': id,
      'name': result.name.trim(),
      'transport': 'stdio',
      'command': parts.isNotEmpty ? parts.first : '',
      'args': parts.length > 1 ? parts.sublist(1) : <String>[],
      'url': null,
      'env': <String, dynamic>{},
      'auth_type': hasToken ? 'token' : 'none',
      'enabled': false, // adding does NOT connect — connect it explicitly
      'token_env': result.tokenEnv.trim().isEmpty
          ? null
          : result.tokenEnv.trim(),
      'extra_env': <String, dynamic>{},
      'custom': true,
    };
    setState(() {
      _upsert(entry);
      _selectedId = id; // land the dropdown on the new server's panel
    });
    widget.wsService.sendSetSetting('mcp_servers', _servers);
    if (hasToken) {
      widget.wsService.sendSetApiKey('mcp:$id', result.token.trim());
    }
    widget.wsService.sendGetConfig();
  }

  Future<void> _pasteInto(TextEditingController ctrl) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    ctrl.text = text;
    setState(() {});
  }

  /// Copy the real token to the clipboard (the underlying value, never the
  /// masked display) and confirm with a brief SnackBar.
  Future<void> _copyToken(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(OsiaL10n.of(context).mcpTokenCopied)),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final connectors = _allConnectors();
    // Clamp the selection so the dropdown value always matches an item.
    if (!connectors.any((c) => c.id == _selectedId)) {
      _selectedId = connectors.first.id;
    }
    final selected = connectors.firstWhere((c) => c.id == _selectedId);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(strings.catConnectors),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.connectorsDesc,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _FieldLabel(strings.connectorLabel, palette),
              const SizedBox(height: 8),
              _selectorDropdown<String>(
                palette: palette,
                value: _selectedId,
                items: [
                  for (final c in connectors)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedId = v);
                },
              ),
              const SizedBox(height: 16),
              _buildPanel(palette, strings, selected),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _addCustom,
                icon: Icon(Icons.add_rounded, size: 18, color: palette.accent),
                label: Text(strings.mcpAddCustom),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGmailRestPanel(
    OsiaPalette palette,
    OsiaStrings strings,
    _McpConnector c,
  ) {
    final gmail = _gmailRest;
    final connected = gmail?.connected == true;
    final connecting =
        _gmailRestConnecting ||
        (gmail?.connecting == true && !_gmailRestAttemptExpired) ||
        _pendingGmailRequestId != null;
    final caps = gmail?.capabilities ?? const ws.GmailRestCapabilities();
    final email = gmail?.emailAddress?.trim() ?? '';
    final mobileConfigured = gmail?.mobileOAuthConfigured == true;
    final disconnectBlockedByServer =
        connected &&
        gmail?.canDisconnectProvided == true &&
        gmail?.canDisconnect == false;
    final canConnect =
        !connected &&
        !connecting &&
        mobileConfigured &&
        (gmail?.canConnect == true || _gmailRestAttemptExpired);
    final canReconnect =
        connected &&
        !connecting &&
        mobileConfigured &&
        gmail?.canReconnect == true;
    final canDisconnect =
        connected && !connecting && !disconnectBlockedByServer;
    final showConfigureOnPc =
        gmail == null || !mobileConfigured || gmail.configureOnPc;
    final showElevateOnPc = gmail?.elevateOnPc == true;
    final showGuide = gmail?.guideAvailable == true && showConfigureOnPc;
    final showDisconnectOnPc = disconnectBlockedByServer && !showElevateOnPc;
    final disconnectError = _gmailRestDisconnectError;

    return _OsiaCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 20,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _McpStatusPill(
                status: _gmailRestStatus(),
                palette: palette,
                strings: strings,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            strings.gmailRestTitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.gmailRestPcHostedAuth,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: palette.textMuted,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.alternate_email_rounded,
                  size: 16,
                  color: palette.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: palette.textPrimary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _gmailRestDetail(strings, gmail),
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _gmailCapabilityChip(
                palette,
                strings.gmailRestReadOnly,
                caps.readonly,
              ),
              _gmailCapabilityChip(
                palette,
                strings.gmailRestDraftsSend,
                caps.compose,
              ),
              _gmailCapabilityChip(
                palette,
                strings.gmailRestMailboxActions,
                caps.modify,
              ),
            ],
          ),
          if (connecting) ...[
            const SizedBox(height: 14),
            _gmailRestActionButton(
              palette,
              strings.mcpStatusConnecting,
              pending: true,
              onPressed: null,
            ),
            const SizedBox(height: 8),
            _gmailRestActionButton(
              palette,
              strings.mcpCancel,
              onPressed: _cancelGmailRestConnect,
            ),
          ] else if (canConnect) ...[
            const SizedBox(height: 14),
            _gmailRestActionButton(
              palette,
              '${strings.mcpConnect} ${strings.gmailRestName}',
              primary: true,
              onPressed: _connectGmailRest,
            ),
          ] else if (canReconnect) ...[
            const SizedBox(height: 14),
            _gmailRestActionButton(
              palette,
              strings.gmailRestReconnect,
              primary: true,
              onPressed: _connectGmailRest,
            ),
          ],
          if (canDisconnect) ...[
            const SizedBox(height: 14),
            _gmailRestDisconnectButton(
              palette,
              strings,
              c,
              pending: _gmailRestDisconnecting,
              onPressed: () => _disconnectGmailRest(c),
            ),
          ],
          if (disconnectError != null) ...[
            const SizedBox(height: 8),
            Text(
              disconnectError,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: palette.error,
              ),
            ),
          ],
          if (showConfigureOnPc) ...[
            const SizedBox(height: 14),
            _gmailPcNotice(palette, strings.gmailRestConfigureOnPc),
          ],
          if (showElevateOnPc) ...[
            const SizedBox(height: 14),
            _gmailPcNotice(palette, strings.gmailRestElevateOnPc),
          ],
          if (showGuide) ...[
            const SizedBox(height: 14),
            _gmailPcNotice(palette, strings.gmailRestSetupGuideOnPc),
          ],
          if (showDisconnectOnPc) ...[
            const SizedBox(height: 14),
            _gmailPcNotice(palette, strings.gmailRestDisconnectOnPc),
          ],
        ],
      ),
    );
  }

  String _gmailRestDetail(OsiaStrings strings, ws.GmailRestConfig? gmail) {
    if (gmail?.errorCategory == 'configuration_missing') {
      return strings.gmailRestConfigureOnPc;
    }
    final reason = gmail?.message?.trim().isNotEmpty == true
        ? gmail!.message!.trim()
        : (gmail?.reason?.trim() ?? '');
    if (reason.isNotEmpty) return reason;
    final status = gmail?.status?.trim() ?? '';
    if (status.isNotEmpty &&
        status != 'connected' &&
        status != 'disconnected') {
      return status;
    }
    return strings.mcpDescGmail;
  }

  Widget _gmailCapabilityChip(OsiaPalette palette, String label, bool enabled) {
    final color = enabled ? palette.accent : palette.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: enabled
            ? palette.accent.withValues(alpha: 0.12)
            : palette.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_rounded : Icons.remove_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gmailRestActionButton(
    OsiaPalette palette,
    String label, {
    bool pending = false,
    bool primary = false,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: pending ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? palette.accent : palette.surfaceElevated,
          foregroundColor: primary ? palette.background : palette.textPrimary,
          disabledBackgroundColor: palette.surfaceElevated,
          disabledForegroundColor: palette.textMuted,
          elevation: 0,
          side: BorderSide(color: primary ? palette.accent : palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: pending
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(label),
                ],
              )
            : Text(label),
      ),
    );
  }

  Widget _gmailRestDisconnectButton(
    OsiaPalette palette,
    OsiaStrings strings,
    _McpConnector c, {
    required bool pending,
    required VoidCallback onPressed,
  }) {
    final label = '${strings.mcpDisconnect} ${c.name}';
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: pending ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.surfaceElevated,
          foregroundColor: palette.textPrimary,
          disabledBackgroundColor: palette.surfaceElevated,
          disabledForegroundColor: palette.textMuted,
          elevation: 0,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: pending
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(label),
                ],
              )
            : Text(label),
      ),
    );
  }

  Widget _gmailPcNotice(OsiaPalette palette, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.computer_rounded, size: 18, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(
    OsiaPalette palette,
    OsiaStrings strings,
    _McpConnector c,
  ) {
    if (c.isGmailRest) {
      return _buildGmailRestPanel(palette, strings, c);
    }
    final status = _statusOf(c.id);
    final children = <Widget>[
      // Header: connector name + live status pill.
      Row(
        children: [
          Expanded(
            child: Text(
              c.name,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _McpStatusPill(status: status, palette: palette, strings: strings),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        _descFor(strings, c),
        style: TextStyle(fontSize: 13, height: 1.4, color: palette.textMuted),
      ),
    ];

    if (c.connectable) {
      if (c.needsToken) children.addAll(_tokenField(palette, strings, c));
      for (final f in c.extraEnv) {
        children.add(const SizedBox(height: 14));
        children.add(_FieldLabel(_extraLabel(strings, f.varName), palette));
        children.add(const SizedBox(height: 8));
        children.add(
          _OsiaTextField(
            controller: _extraCtrlFor(c, f.varName),
            hint: _extraHint(strings, f.varName),
            palette: palette,
          ),
        );
      }
      children.add(const SizedBox(height: 18));
      children.add(_actionButton(palette, strings, c, status));
      if (c.custom) {
        children.add(const SizedBox(height: 4));
        children.add(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _removeCustom(c),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: palette.error,
              ),
              label: Text(
                strings.mcpRemove,
                style: TextStyle(color: palette.error, fontSize: 14),
              ),
            ),
          ),
        );
      }
    } else {
      // OAuth connectors (WOR-96 PART 2b): tapping Connect sends `mcp_connect`
      // and the server drives the tunnel OAuth flow, replying with the auth URL
      // we open in a browser; the PC captures the callback and the status pill
      // flips via the `mcp_status` broadcast. (`_soonButton` is kept for any
      // future non-OAuth gated transport.)
      children.add(const SizedBox(height: 18));
      children.add(
        c.authType == 'oauth' && c.hasOauthEndpoint
            ? _oauthActions(palette, strings, c, status)
            : _soonButton(palette, strings, c),
      );
    }

    return _OsiaCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  List<Widget> _tokenField(
    OsiaPalette palette,
    OsiaStrings strings,
    _McpConnector c,
  ) {
    final ctrl = _tokenCtrlFor(c);
    final configured = _configured(c.id);
    return [
      const SizedBox(height: 16),
      if (configured) ...[
        Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: palette.accent),
            const SizedBox(width: 8),
            Text(
              strings.apiKeyConfigured,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
      _FieldLabel(strings.mcpTokenLabel, palette),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        obscureText: _obscureToken,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (_) => setState(() {}), // refresh Connect's enabled state
        cursorColor: palette.accent,
        style: TextStyle(color: palette.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          filled: true,
          fillColor: palette.surface,
          hintText: configured
              ? strings.apiKeyReplaceHint
              : strings.mcpTokenHint,
          hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: palette.accent, width: 1.4),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ctrl.text.trim().isNotEmpty)
                IconButton(
                  tooltip: strings.mcpCopyToken,
                  onPressed: () => _copyToken(ctrl.text.trim()),
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: palette.textMuted,
                  ),
                ),
              IconButton(
                tooltip: _obscureToken
                    ? strings.showApiKey
                    : strings.hideApiKey,
                onPressed: () => setState(() => _obscureToken = !_obscureToken),
                icon: Icon(
                  _obscureToken
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: 18,
                  color: palette.textMuted,
                ),
              ),
              IconButton(
                onPressed: () => _pasteInto(ctrl),
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
    ];
  }

  Widget _actionButton(
    OsiaPalette palette,
    OsiaStrings strings,
    _McpConnector c,
    String status,
  ) {
    final connected = status == 'connected';
    final enabled = connected || _canConnect(c);
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: enabled ? () => _toggle(c) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: connected ? palette.surfaceElevated : palette.accent,
          foregroundColor: connected
              ? palette.textPrimary
              : (palette.isDark ? palette.background : Colors.white),
          disabledBackgroundColor: palette.accent.withValues(alpha: 0.4),
          disabledForegroundColor:
              (palette.isDark ? palette.background : Colors.white).withValues(
                alpha: 0.7,
              ),
          elevation: 0,
          side: connected ? BorderSide(color: palette.border) : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(connected ? strings.mcpDisconnect : strings.mcpConnect),
      ),
    );
  }

  /// OAuth connector actions (WOR-96 PART 2b): a Connect/Disconnect toggle plus
  /// — when connected — a Sign-out / Switch-account row. Unlike [_actionButton]
  /// there is NO token precondition (OAuth has no token field), so Connect is
  /// always enabled; the provider's own sign-in page gates access. The toggle
  /// mirrors the non-OAuth one ([_actionButton]) for visual parity.
  Widget _oauthActions(
    OsiaPalette palette,
    OsiaStrings strings,
    _McpConnector c,
    String status,
  ) {
    final connected = status == 'connected';
    final connecting = status == 'connecting';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () => _toggleOauth(c),
            style: ElevatedButton.styleFrom(
              backgroundColor: connected
                  ? palette.surfaceElevated
                  : palette.accent,
              foregroundColor: connected
                  ? palette.textPrimary
                  : (palette.isDark ? palette.background : Colors.white),
              elevation: 0,
              side: connected
                  ? BorderSide(color: palette.border)
                  : BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(connected ? strings.mcpDisconnect : strings.mcpConnect),
          ),
        ),
        if (connected) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _switchOauthAccount(c),
            child: Text(
              strings.mcpSwitchAccount,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 13.5),
            ),
          ),
        ],
        // WOR-97: while the OAuth handshake is in flight, offer an explicit
        // "stop waiting" affordance. Tapping it sends `mcp_oauth_cancel` and
        // clears the pending-url guard; the Connect button above still doubles
        // as re-tap (server cancels the zombie and re-issues a fresh URL).
        if (connecting) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _cancelOauth(c),
            child: Text(
              strings.mcpCancel,
              style: TextStyle(color: palette.textMuted, fontSize: 13.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _soonButton(
    OsiaPalette palette,
    OsiaStrings strings,
    _McpConnector c,
  ) {
    final label = c.authType == 'oauth'
        ? strings.mcpOauthSoon
        : strings.mcpHttpSoon;
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: palette.surfaceElevated.withValues(
            alpha: 0.6,
          ),
          disabledForegroundColor: palette.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Live status pill for a connector — parity with the PC `_MCP_PILL_COLORS`.
class _McpStatusPill extends StatelessWidget {
  final String status;
  final OsiaPalette palette;
  final OsiaStrings strings;
  const _McpStatusPill({
    required this.status,
    required this.palette,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, String label) = switch (status) {
      'connected' => (
        const Color(0xFF6FCF97),
        const Color(0xFF10241A),
        strings.mcpStatusConnected,
      ),
      'connecting' => (
        const Color(0xFFE6C878),
        const Color(0xFF2A2410),
        strings.mcpStatusConnecting,
      ),
      'failed' => (
        const Color(0xFFE0A3A3),
        const Color(0xFF2A1414),
        strings.mcpStatusFailed,
      ),
      _ => (
        palette.textMuted,
        palette.surfaceElevated,
        strings.mcpStatusDisconnected,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of the custom-server dialog (a local stdio server).
class _McpCustomResult {
  final String name;
  final String command;
  final String token;
  final String tokenEnv;
  const _McpCustomResult({
    required this.name,
    required this.command,
    required this.token,
    required this.tokenEnv,
  });
}

/// Add-a-custom-stdio-server dialog. Mirrors the PC: a name + command (and
/// optional token / token env var); adding does NOT connect. Remote (HTTP)
/// servers aren't offered yet — stdio only.
class _McpCustomDialog extends StatefulWidget {
  const _McpCustomDialog();

  @override
  State<_McpCustomDialog> createState() => _McpCustomDialogState();
}

class _McpCustomDialogState extends State<_McpCustomDialog> {
  final _nameCtrl = TextEditingController();
  final _commandCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _tokenEnvCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commandCtrl.dispose();
    _tokenCtrl.dispose();
    _tokenEnvCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final strings = OsiaL10n.of(context);
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = strings.mcpErrName);
      return;
    }
    if (_commandCtrl.text.trim().isEmpty) {
      setState(() => _error = strings.mcpErrCommand);
      return;
    }
    Navigator.of(context).pop(
      _McpCustomResult(
        name: _nameCtrl.text,
        command: _commandCtrl.text,
        token: _tokenCtrl.text,
        tokenEnv: _tokenEnvCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        strings.mcpCustomTitle,
        style: TextStyle(fontSize: 16, color: palette.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.mcpCustomHint,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel(strings.mcpFieldName, palette),
            const SizedBox(height: 6),
            _OsiaTextField(
              controller: _nameCtrl,
              hint: strings.mcpFieldNamePh,
              palette: palette,
            ),
            const SizedBox(height: 14),
            _FieldLabel(strings.mcpFieldCommand, palette),
            const SizedBox(height: 6),
            _OsiaTextField(
              controller: _commandCtrl,
              hint: strings.mcpFieldCommandPh,
              palette: palette,
            ),
            const SizedBox(height: 14),
            _FieldLabel(strings.mcpFieldTokenOptional, palette),
            const SizedBox(height: 6),
            _OsiaTextField(
              controller: _tokenCtrl,
              hint: strings.mcpFieldTokenPh,
              palette: palette,
            ),
            const SizedBox(height: 14),
            _FieldLabel(strings.mcpFieldTokenEnvOptional, palette),
            const SizedBox(height: 6),
            _OsiaTextField(
              controller: _tokenEnvCtrl,
              hint: strings.mcpFieldTokenEnvPh,
              palette: palette,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(fontSize: 12.5, color: palette.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            strings.cancel,
            style: TextStyle(color: palette.textMuted),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(strings.mcpAdd, style: TextStyle(color: palette.accent)),
        ),
      ],
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n.dart';
import '../motion.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';

/// Snapshot of the sheet's view-state. Pushed by the chat screen through a
/// [ValueListenable] so the bottom sheet can react to models arriving
/// (or to the load timing out) after it was opened.
class ModelSelectorState {
  final List<ws.OsiaModel> models;
  final bool isLoading;
  final String? errorMessage;
  final ws.OsiaReasoningConfig reasoning;
  final bool reasoningReady;

  const ModelSelectorState({
    required this.models,
    required this.isLoading,
    this.errorMessage,
    this.reasoning = const ws.OsiaReasoningConfig(),
    this.reasoningReady = true,
  });
}

typedef ModelReasoningChanged = void Function(String modelId, String optionId);

class ModelReasoningOption {
  final String id;
  final bool isDefault;

  const ModelReasoningOption(this.id, {this.isDefault = false});

  String label(OsiaStrings strings) {
    switch (id) {
      case 'auto':
        return strings.reasoningDefault;
      case 'off':
        return strings.reasoningOff;
      case 'normal':
        return strings.reasoningNormal;
      case 'max':
        return strings.reasoningMax;
      case 'minimal':
        return strings.reasoningMinimal;
      case 'low':
        return strings.reasoningLow;
      case 'medium':
        return strings.reasoningMedium;
      case 'high':
        return strings.reasoningHigh;
      case 'xhigh':
        return strings.reasoningXhigh;
    }
    return id;
  }
}

const ModelReasoningOption _defaultReasoningOption = ModelReasoningOption(
  'auto',
  isDefault: true,
);

const Set<String> _googleReasoningModels = {
  'gemini-3.5-flash',
  'gemini-3.1-pro-preview',
  'gemini-3-flash-preview',
  'gemini-3.1-flash-lite',
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
};

const Set<String> _googleOffReasoningModels = {
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
};

const Set<String> _deepSeekReasoningModels = {
  'deepseek-v4-pro',
  'deepseek-v4-flash',
};

const Set<String> _openAiReasoningModels = {
  'gpt-5.5',
  'gpt-5.4',
  'gpt-5.4-mini',
};

const Set<String> _claudeReasoningModels = {
  'claude-opus-4-8',
  'claude-opus-4-7',
  'claude-opus-4-6',
  'claude-sonnet-4-6',
};

const Set<String> _claudeXhighReasoningModels = {
  'claude-opus-4-8',
  'claude-opus-4-7',
};

@visibleForTesting
List<ModelReasoningOption> reasoningOptionsForModel(ws.OsiaModel model) {
  final provider = _reasoningProviderFor(model);
  final modelId = model.id.trim();
  if (provider.isEmpty || modelId.isEmpty) return const [];

  if (provider == 'deepseek' && _deepSeekReasoningModels.contains(modelId)) {
    return const [
      _defaultReasoningOption,
      ModelReasoningOption('off'),
      ModelReasoningOption('normal'),
      ModelReasoningOption('max'),
    ];
  }

  if (provider == 'openai' && _openAiReasoningModels.contains(modelId)) {
    return const [
      _defaultReasoningOption,
      ModelReasoningOption('off'),
      ModelReasoningOption('minimal'),
      ModelReasoningOption('low'),
      ModelReasoningOption('medium'),
      ModelReasoningOption('high'),
      ModelReasoningOption('xhigh'),
    ];
  }

  if ((provider == 'anthropic' || provider == 'claude') &&
      _claudeReasoningModels.contains(modelId)) {
    return [
      _defaultReasoningOption,
      const ModelReasoningOption('off'),
      const ModelReasoningOption('low'),
      const ModelReasoningOption('medium'),
      const ModelReasoningOption('high'),
      if (_claudeXhighReasoningModels.contains(modelId))
        const ModelReasoningOption('xhigh'),
      const ModelReasoningOption('max'),
    ];
  }

  if (provider == 'google' && _googleReasoningModels.contains(modelId)) {
    return [
      _defaultReasoningOption,
      if (_googleOffReasoningModels.contains(modelId))
        const ModelReasoningOption('off'),
      const ModelReasoningOption('minimal'),
      const ModelReasoningOption('low'),
      const ModelReasoningOption('medium'),
      const ModelReasoningOption('high'),
    ];
  }

  if (provider == 'groq' && modelId.startsWith('openai/gpt-oss-')) {
    return const [
      _defaultReasoningOption,
      ModelReasoningOption('low'),
      ModelReasoningOption('medium'),
      ModelReasoningOption('high'),
    ];
  }

  if (provider == 'mistral' && modelId == 'mistral-medium-3-5') {
    return const [
      _defaultReasoningOption,
      ModelReasoningOption('off'),
      ModelReasoningOption('minimal'),
      ModelReasoningOption('low'),
      ModelReasoningOption('medium'),
      ModelReasoningOption('high'),
      ModelReasoningOption('xhigh'),
    ];
  }

  return const [];
}

String _reasoningProviderFor(ws.OsiaModel model) {
  final tagged = (model.provider ?? '').trim().toLowerCase();
  if (tagged.isNotEmpty) return tagged;
  final id = model.id.trim().toLowerCase();
  if (id.contains('deepseek')) return 'deepseek';
  if (id.contains('gemini')) return 'google';
  if (id.startsWith('openai/gpt-oss-') || id.contains('gpt-oss')) {
    return 'groq';
  }
  if (id.startsWith('gpt-')) return 'openai';
  if (id.startsWith('claude-')) return 'anthropic';
  if (id.startsWith('mistral-') || id == 'codestral-2508') return 'mistral';
  return '';
}

/// Bottom sheet that displays the list of models reported by the server.
///
/// Returns the chosen model id from [showModalBottomSheet] when the user
/// picks one; returns null on dismiss.
Future<String?> showModelSelector({
  required BuildContext context,
  required ValueListenable<ModelSelectorState> stateListenable,
  required String? currentModel,
  required bool hierarchyActive,
  ModelReasoningChanged? onReasoningChanged,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final content = ValueListenableBuilder<ModelSelectorState>(
        valueListenable: stateListenable,
        builder: (ctx, state, _) => _ModelSelectorSheet(
          models: state.models,
          currentModel: currentModel,
          isLoading: state.isLoading,
          errorMessage: state.errorMessage,
          hierarchyActive: hierarchyActive,
          reasoning: state.reasoning,
          reasoningReady: state.reasoningReady,
          onReasoningChanged: onReasoningChanged,
        ),
      );
      // Reduced motion: skip the added fade + spring-scale; the modal route's
      // own slide is the platform-minimal transition.
      if (Motion.reduced(ctx)) return content;
      // The modal route already slides the sheet up; riding the same animation
      // with a fade + a light spring-scale gives a smooth slide-and-pop open.
      // The fade rides [enter] (opacity must stay in [0,1]); the scale is a
      // transform, so the spring's ≈6.5% overshoot is safe and reads as a
      // tasteful settle.
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

class _ModelSelectorSheet extends StatelessWidget {
  final List<ws.OsiaModel> models;
  final String? currentModel;
  final bool isLoading;
  final String? errorMessage;
  final ws.OsiaReasoningConfig reasoning;
  final bool reasoningReady;
  final ModelReasoningChanged? onReasoningChanged;

  /// When true, the PC's AI hierarchy is on, so the chosen model is overridden
  /// by the configured chain — the sheet shows an explanatory note.
  final bool hierarchyActive;

  const _ModelSelectorSheet({
    required this.models,
    required this.currentModel,
    required this.isLoading,
    this.errorMessage,
    required this.hierarchyActive,
    required this.reasoning,
    required this.reasoningReady,
    this.onReasoningChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                  Icon(Icons.tune_rounded, color: palette.accent, size: 18),
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
            // When the AI hierarchy is active, the picked model is overridden
            // by the configured chain — note it under the title.
            if (hierarchyActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  strings.hierarchyActive,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: palette.accent,
                  ),
                ),
              ),
            Flexible(
              // Smooth the height change + cross-fade when the body flips
              // from spinner to model list (or to an error message).
              child: AnimatedSize(
                duration: MotionDurations.medium,
                curve: MotionCurves.enter,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: MotionDurations.medium,
                  switchInCurve: MotionCurves.enter,
                  switchOutCurve: MotionCurves.exit,
                  child: KeyedSubtree(
                    key: ValueKey(_bodyKind),
                    child: _buildBody(palette, strings),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Discriminates which body variant is showing so the AnimatedSwitcher
  /// only animates on real state flips, not on every rebuild.
  String get _bodyKind {
    if (isLoading && models.isEmpty) return 'loading';
    if (errorMessage != null && models.isEmpty) return 'error';
    if (models.isEmpty) return 'empty';
    return 'list';
  }

  Widget _buildBody(OsiaPalette palette, OsiaStrings strings) {
    // Loading but no cached list to fall back on — spinner.
    if (isLoading && models.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator(color: palette.accent)),
      );
    }
    // Error and no cached list to fall back on — explicit message.
    if (errorMessage != null && models.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Text(
          errorMessage!,
          style: TextStyle(color: palette.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (models.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Text(
          strings.noModelsReceived,
          style: TextStyle(color: palette.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    final entries = _buildEntries(strings);
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      itemCount: entries.length,
      separatorBuilder: (context, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry.providerName != null) {
          return _ProviderHeader(name: entry.providerName!, palette: palette);
        }
        final m = entry.model!;
        final isActive = m.id == currentModel;
        return _ModelTile(
          model: m,
          isActive: isActive,
          palette: palette,
          reasoning: reasoning,
          reasoningReady: reasoningReady,
          onReasoningChanged: onReasoningChanged,
          onTap: () => Navigator.of(context).pop(m.id),
        );
      },
    );
  }

  /// Flattens [models] into list entries: one section header per provider
  /// (groups ordered by first appearance) followed by that provider's models.
  /// Falls back to a flat list when no model carries provider info.
  List<_SheetEntry> _buildEntries(OsiaStrings strings) {
    final hasProviders = models.any(
      (m) => (m.provider ?? '').trim().isNotEmpty,
    );
    if (!hasProviders) {
      return [for (final m in models) _SheetEntry.item(m)];
    }
    final groups = <String, List<ws.OsiaModel>>{};
    for (final m in models) {
      groups.putIfAbsent(_providerName(m.provider, strings), () => []).add(m);
    }
    return [
      for (final group in groups.entries) ...[
        _SheetEntry.section(group.key),
        for (final m in group.value) _SheetEntry.item(m),
      ],
    ];
  }

  /// Display names for the providers reported by the server; unknown
  /// providers fall back to their uppercased raw id.
  static const Map<String, String> _providerLabels = {
    'anthropic': 'ANTHROPIC',
    'openai': 'OPENAI',
    'google': 'GOOGLE',
    'groq': 'GROQ',
    'ollama': 'LOCAL',
    'xai': 'XAI',
    'deepseek': 'DEEPSEEK',
    'mistral': 'MISTRAL',
  };

  String _providerName(String? provider, OsiaStrings strings) {
    final key = (provider ?? '').trim().toLowerCase();
    if (key.isEmpty) return strings.otherProviders;
    return _providerLabels[key] ?? key.toUpperCase();
  }
}

/// A row in the sheet's model list: either a provider section header
/// (when [providerName] is set) or a selectable model (when [model] is set).
class _SheetEntry {
  final String? providerName;
  final ws.OsiaModel? model;

  const _SheetEntry.section(this.providerName) : model = null;
  const _SheetEntry.item(this.model) : providerName = null;
}

/// Thin section divider labelled with the provider name — small uppercase
/// accent-colored text centered between two subtle horizontal lines.
class _ProviderHeader extends StatelessWidget {
  final String name;
  final OsiaPalette palette;

  const _ProviderHeader({required this.name, required this.palette});

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
              name,
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

class _ModelTile extends StatelessWidget {
  final ws.OsiaModel model;
  final bool isActive;
  final OsiaPalette palette;
  final ws.OsiaReasoningConfig reasoning;
  final bool reasoningReady;
  final ModelReasoningChanged? onReasoningChanged;
  final VoidCallback onTap;

  const _ModelTile({
    required this.model,
    required this.isActive,
    required this.palette,
    required this.reasoning,
    required this.reasoningReady,
    this.onReasoningChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = OsiaL10n.of(context);
    final reasoningOptions = reasoningOptionsForModel(model);
    final reasoningId = _selectedReasoningId(reasoningOptions);
    final reasoningOption = _findReasoningOption(reasoningOptions, reasoningId);
    final showChip = reasoningOption != null && !reasoningOption.isDefault;
    final showReasoningControl =
        reasoningReady &&
        reasoningOptions.isNotEmpty &&
        onReasoningChanged != null;

    return PressableScale(
      child: Material(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        model.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isActive
                              ? palette.accent
                              : palette.textPrimary,
                        ),
                      ),
                      if (model.description != null &&
                          model.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          model.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                      if (showChip) ...[
                        const SizedBox(height: 6),
                        _ReasoningChip(
                          label:
                              '${strings.reasoning}: ${reasoningOption.label(strings)}',
                          palette: palette,
                        ),
                      ],
                    ],
                  ),
                ),
                if (showReasoningControl) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: strings.reasoning,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => _showReasoningSheet(
                      context,
                      options: reasoningOptions,
                      currentId: reasoningId,
                    ),
                    icon: Icon(
                      Icons.settings_rounded,
                      color: showChip ? palette.accent : palette.textMuted,
                      size: 18,
                    ),
                  ),
                ],
                if (isActive) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_rounded, color: palette.accent, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _selectedReasoningId(List<ModelReasoningOption> options) {
    final selected = (reasoning.models[model.id] ?? 'auto')
        .trim()
        .toLowerCase();
    return options.any((option) => option.id == selected) ? selected : 'auto';
  }

  ModelReasoningOption? _findReasoningOption(
    List<ModelReasoningOption> options,
    String id,
  ) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  Future<void> _showReasoningSheet(
    BuildContext context, {
    required List<ModelReasoningOption> options,
    required String currentId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ReasoningOptionsSheet(
        model: model,
        options: options,
        currentId: currentId,
        onSelected: (optionId) {
          onReasoningChanged?.call(model.id, optionId);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _ReasoningChip extends StatelessWidget {
  final String label;
  final OsiaPalette palette;

  const _ReasoningChip({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: palette.accent.withValues(alpha: 0.22)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: palette.accent,
          ),
        ),
      ),
    );
  }
}

class _ReasoningOptionsSheet extends StatelessWidget {
  final ws.OsiaModel model;
  final List<ModelReasoningOption> options;
  final String currentId;
  final ValueChanged<String> onSelected;

  const _ReasoningOptionsSheet({
    required this.model,
    required this.options,
    required this.currentId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(22),
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
                  Icon(Icons.settings_rounded, color: palette.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.reasoning,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  model.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              itemCount: options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final option = options[index];
                final selected = option.id == currentId;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelected(option.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label(strings),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: selected
                                    ? palette.accent
                                    : palette.textPrimary,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_rounded,
                              color: palette.accent,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

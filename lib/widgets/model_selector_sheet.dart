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

typedef ModelReasoningChanged =
    void Function(ws.OsiaModel model, String optionId);
typedef ModelSelected = void Function(ws.OsiaModel model);

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
      case 'ultra':
        return 'Ultra';
    }
    return id;
  }
}

@visibleForTesting
List<ModelReasoningOption> reasoningOptionsForModel(ws.OsiaModel model) {
  return [
    for (final option in model.reasoningOptions)
      ModelReasoningOption(option.id, isDefault: option.isDefault),
  ];
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
  ModelSelected? onModelSelected,
  String? currentProvider,
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
          currentProvider: currentProvider,
          isLoading: state.isLoading,
          errorMessage: state.errorMessage,
          hierarchyActive: hierarchyActive,
          reasoning: state.reasoning,
          reasoningReady: state.reasoningReady,
          onReasoningChanged: onReasoningChanged,
          onModelSelected: onModelSelected,
        ),
      );
      return content;
    },
  );
}

class _ModelSelectorSheet extends StatefulWidget {
  final List<ws.OsiaModel> models;
  final String? currentModel;
  final String? currentProvider;
  final bool isLoading;
  final String? errorMessage;
  final ws.OsiaReasoningConfig reasoning;
  final bool reasoningReady;
  final ModelReasoningChanged? onReasoningChanged;
  final ModelSelected? onModelSelected;

  /// When true, the PC's AI hierarchy is on, so the chosen model is overridden
  /// by the configured chain — the sheet shows an explanatory note.
  final bool hierarchyActive;

  const _ModelSelectorSheet({
    required this.models,
    required this.currentModel,
    this.currentProvider,
    required this.isLoading,
    this.errorMessage,
    required this.hierarchyActive,
    required this.reasoning,
    required this.reasoningReady,
    this.onReasoningChanged,
    this.onModelSelected,
  });

  @override
  State<_ModelSelectorSheet> createState() => _ModelSelectorSheetState();
}

class _ModelSelectorSheetState extends State<_ModelSelectorSheet> {
  String? _provider;
  ws.OsiaModel? _pendingModelSelection;
  bool _modelSelectionScheduled = false;

  void _queueModelSelection(ws.OsiaModel model) {
    _pendingModelSelection = model;
    if (_modelSelectionScheduled) return;
    _modelSelectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _modelSelectionScheduled = false;
      if (!mounted) return;
      final selected = _pendingModelSelection;
      _pendingModelSelection = null;
      if (selected == null ||
          !widget.models.any(
            (model) =>
                model.id == selected.id &&
                model.provider == selected.provider &&
                model.selectable,
          )) {
        return;
      }
      widget.onModelSelected?.call(selected);
      Navigator.of(context).pop(selected.id);
    });
  }

  @override
  void didUpdateWidget(covariant _ModelSelectorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final provider = _provider;
    if (provider != null &&
        !widget.models.any(
          (model) => (model.provider ?? '').trim().toLowerCase() == provider,
        )) {
      _provider = null;
    }
  }

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
                    _provider == null
                        ? strings.availableModels
                        : _providerName(_provider, strings),
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
            if (widget.hierarchyActive)
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
              // One short content-only cross-fade. Stable semantic keys mean a
              // catalogue refresh with unchanged visible content does not
              // replay it, and reduced-motion collapses it to an instant swap.
              child: AnimatedSwitcher(
                duration: Motion.duration(
                  context,
                  MotionDurations.routeReverse,
                ),
                switchInCurve: Motion.curve(context, MotionCurves.enter),
                switchOutCurve: Motion.curve(context, MotionCurves.exit),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[...previousChildren, ?currentChild],
                ),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: KeyedSubtree(
                  key: ValueKey(_bodyKind),
                  child: _buildBody(palette, strings),
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
    if (widget.isLoading && widget.models.isEmpty) return 'loading';
    if (widget.errorMessage != null && widget.models.isEmpty) return 'error';
    if (widget.models.isEmpty) return 'empty';
    return _provider == null ? 'providers' : 'models:$_provider';
  }

  Widget _buildBody(OsiaPalette palette, OsiaStrings strings) {
    // Loading but no cached list to fall back on — spinner.
    if (widget.isLoading && widget.models.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator(color: palette.accent)),
      );
    }
    // Error and no cached list to fall back on — explicit message.
    if (widget.errorMessage != null && widget.models.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Text(
          widget.errorMessage!,
          style: TextStyle(color: palette.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (widget.models.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Text(
          strings.noModelsReceived,
          style: TextStyle(color: palette.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_provider == null) return _buildProviderGrid(palette, strings);
    final models = widget.models
        .where((model) => (model.provider ?? '').toLowerCase() == _provider)
        .toList();
    return ListView.separated(
      key: PageStorageKey<String>('models:$_provider'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      itemCount: models.length + 1,
      separatorBuilder: (context, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey<String>('models-back'),
              onPressed: () => setState(() => _provider = null),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: Text(strings.availableModels),
            ),
          );
        }
        final m = models[index - 1];
        final isActive =
            m.id == widget.currentModel &&
            (widget.currentProvider == null ||
                widget.currentProvider!.isEmpty ||
                m.provider == widget.currentProvider);
        return _ModelTile(
          key: ValueKey<String>('model:${m.provider}:${m.id}'),
          model: m,
          isActive: isActive,
          palette: palette,
          reasoning: widget.reasoning,
          reasoningReady: widget.reasoningReady,
          onReasoningChanged: widget.onReasoningChanged,
          onTap: m.selectable ? () => _queueModelSelection(m) : null,
        );
      },
    );
  }

  Widget _buildProviderGrid(OsiaPalette palette, OsiaStrings strings) {
    final groups = <String, List<ws.OsiaModel>>{};
    for (final model in widget.models) {
      final provider = (model.provider ?? '').trim().toLowerCase();
      if (provider.isEmpty) continue;
      groups.putIfAbsent(provider, () => <ws.OsiaModel>[]).add(model);
    }
    return GridView.builder(
      key: const PageStorageKey<String>('model-providers'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.85,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups.entries.elementAt(index);
        return Material(
          key: ValueKey<String>('provider:${entry.key}'),
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _provider = entry.key),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _providerName(entry.key, strings),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    strings.modelCount(entry.value.length),
                    style: TextStyle(color: palette.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Display names for the providers reported by the server; unknown
  /// providers fall back to their uppercased raw id.
  static const Map<String, String> _providerLabels = {
    'anthropic': 'ANTHROPIC',
    'openai': 'OPENAI',
    'google': 'GOOGLE',
    'groq': 'GROQCLOUD',
    'xai': 'GROK / XAI',
    'ollama': 'LOCAL',
    'deepseek': 'DEEPSEEK',
    'mistral': 'MISTRAL',
    'openrouter': 'OPENROUTER',
    'chatgpt_account': 'CHATGPT',
  };

  String _providerName(String? provider, OsiaStrings strings) {
    final key = (provider ?? '').trim().toLowerCase();
    if (key.isEmpty) return strings.otherProviders;
    return _providerLabels[key] ?? key.toUpperCase();
  }
}

class _ModelTile extends StatelessWidget {
  final ws.OsiaModel model;
  final bool isActive;
  final OsiaPalette palette;
  final ws.OsiaReasoningConfig reasoning;
  final bool reasoningReady;
  final ModelReasoningChanged? onReasoningChanged;
  final VoidCallback? onTap;

  const _ModelTile({
    super.key,
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
        model.selectable &&
        reasoningReady &&
        reasoningOptions.isNotEmpty &&
        onReasoningChanged != null;

    final tile = Material(
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
                        color: !model.selectable
                            ? palette.textMuted
                            : isActive
                            ? palette.accent
                            : palette.textPrimary,
                      ),
                    ),
                    if (!model.selectable)
                      Text(
                        strings.modelUnavailableOnPc,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 11.5,
                        ),
                      )
                    else if (model.description != null &&
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
                    if (model.selectable && showChip) ...[
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
    );
    return onTap == null || Motion.reduced(context)
        ? tile
        : PressableScale(child: tile);
  }

  String _selectedReasoningId(List<ModelReasoningOption> options) {
    final key = ws.OsiaReasoningConfig.modelKey(model.provider, model.id);
    final selected =
        (model.reasoningOptions.isNotEmpty
                ? model.selectedReasoning
                : reasoning.models[key] ?? 'auto')
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
          onReasoningChanged?.call(model, optionId);
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

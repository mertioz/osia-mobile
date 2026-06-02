import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';

/// Snapshot of the sheet's view-state. Pushed by the chat screen through a
/// [ValueListenable] so the bottom sheet can react to models arriving
/// (or to the load timing out) after it was opened.
class ModelSelectorState {
  final List<ws.OsiaModel> models;
  final bool isLoading;
  final String? errorMessage;

  const ModelSelectorState({
    required this.models,
    required this.isLoading,
    this.errorMessage,
  });
}

/// Bottom sheet that displays the list of models reported by the server.
///
/// Returns the chosen model id from [showModalBottomSheet] when the user
/// picks one; returns null on dismiss.
Future<String?> showModelSelector({
  required BuildContext context,
  required ValueListenable<ModelSelectorState> stateListenable,
  required String? currentModel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      // The modal route already slides the sheet up; riding the same
      // animation with a fade gives the smooth slide + fade open/close.
      final routeAnim =
          ModalRoute.of(ctx)?.animation ?? kAlwaysCompleteAnimation;
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: routeAnim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: ValueListenableBuilder<ModelSelectorState>(
          valueListenable: stateListenable,
          builder: (ctx, state, _) => _ModelSelectorSheet(
            models: state.models,
            currentModel: currentModel,
            isLoading: state.isLoading,
            errorMessage: state.errorMessage,
          ),
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

  const _ModelSelectorSheet({
    required this.models,
    required this.currentModel,
    required this.isLoading,
    this.errorMessage,
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
                  Icon(Icons.tune_rounded,
                      color: palette.accent, size: 18),
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
              // Smooth the height change + cross-fade when the body flips
              // from spinner to model list (or to an error message).
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
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
        child: Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
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
          onTap: () => Navigator.of(context).pop(m.id),
        );
      },
    );
  }

  /// Flattens [models] into list entries: one section header per provider
  /// (groups ordered by first appearance) followed by that provider's models.
  /// Falls back to a flat list when no model carries provider info.
  List<_SheetEntry> _buildEntries(OsiaStrings strings) {
    final hasProviders =
        models.any((m) => (m.provider ?? '').trim().isNotEmpty);
    if (!hasProviders) {
      return [for (final m in models) _SheetEntry.item(m)];
    }
    final groups = <String, List<ws.OsiaModel>>{};
    for (final m in models) {
      groups
          .putIfAbsent(_providerName(m.provider, strings), () => [])
          .add(m);
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
  final VoidCallback onTap;

  const _ModelTile({
    required this.model,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      model.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
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
                  ],
                ),
              ),
              if (isActive)
                Icon(Icons.check_rounded,
                    color: palette.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

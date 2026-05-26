import 'package:flutter/material.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';

/// Bottom sheet that displays the list of models reported by the server.
///
/// Returns the chosen model id from [showModalBottomSheet] when the user
/// picks one; returns null on dismiss.
Future<String?> showModelSelector({
  required BuildContext context,
  required List<ws.OsiaModel> models,
  required String? currentModel,
  required bool isLoading,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ModelSelectorSheet(
      models: models,
      currentModel: currentModel,
      isLoading: isLoading,
    ),
  );
}

class _ModelSelectorSheet extends StatelessWidget {
  final List<ws.OsiaModel> models;
  final String? currentModel;
  final bool isLoading;

  const _ModelSelectorSheet({
    required this.models,
    required this.currentModel,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
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
                    'Modèles disponibles',
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
              child: _buildBody(palette),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(OsiaPalette palette) {
    if (isLoading && models.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
      );
    }
    if (models.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Text(
          'Aucun modèle reçu du serveur.',
          style: TextStyle(color: palette.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      itemCount: models.length,
      separatorBuilder: (context, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final m = models[index];
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

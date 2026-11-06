import 'package:flutter/material.dart';

import '../motion.dart';
import '../slash_commands.dart';
import '../theme.dart';

class SlashCommandPaletteController extends ChangeNotifier {
  List<SlashPaletteSelection> _entries = const [];
  List<SlashPaletteSelection> _searchSource = const [];
  int? _limit = slashMaxResults;
  String? _searchHint;
  int _selectedIndex = 0;
  ValueChanged<SlashPaletteSelection>? _onSelected;

  List<SlashPaletteSelection> get entries => _entries;
  int get selectedIndex => _selectedIndex;
  String? get searchHint => _searchHint;
  bool get isOpen => _entries.isNotEmpty || _searchHint != null;

  void show(
    List<SlashPaletteSelection> entries,
    ValueChanged<SlashPaletteSelection> onSelected, {
    int? limit = slashMaxResults,
    String? searchHint,
  }) {
    _limit = limit;
    _searchHint = searchHint;
    _searchSource = searchHint == null ? const [] : List.unmodifiable(entries);
    _entries = List.unmodifiable(limit == null ? entries : entries.take(limit));
    _selectedIndex = 0;
    _onSelected = onSelected;
    notifyListeners();
  }

  void close() {
    if (!isOpen) return;
    _entries = const [];
    _searchSource = const [];
    _searchHint = null;
    _selectedIndex = 0;
    _onSelected = null;
    notifyListeners();
  }

  void filter(String text) {
    if (_searchHint == null) return;
    final query = text.trim().toLowerCase();
    final matches = _searchSource.where(
      (row) =>
          row.title.toLowerCase().contains(query) ||
          row.description.toLowerCase().contains(query) ||
          row.id.toLowerCase().contains(query),
    );
    final limit = _limit;
    _entries = List.unmodifiable(limit == null ? matches : matches.take(limit));
    _selectedIndex = 0;
    notifyListeners();
  }

  void move(int delta) {
    if (_entries.isEmpty) return;
    var next = _selectedIndex;
    for (var checked = 0; checked < _entries.length; checked++) {
      next = (next + delta) % _entries.length;
      if (next < 0) next += _entries.length;
      if (_entries[next].enabled) break;
    }
    _selectedIndex = next;
    notifyListeners();
  }

  bool activate() {
    if (_entries.isEmpty) return false;
    final item = _entries[_selectedIndex];
    if (!item.enabled) return true;
    _onSelected?.call(item);
    return true;
  }

  void activateAt(int index) {
    if (index < 0 || index >= _entries.length || !_entries[index].enabled) {
      return;
    }
    _selectedIndex = index;
    _onSelected?.call(_entries[index]);
  }
}

class SlashCommandPalette extends StatelessWidget {
  final SlashCommandPaletteController controller;
  final String locale;

  const SlashCommandPalette({
    super.key,
    required this.controller,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isOpen) return const SizedBox.shrink();
        final card = Material(
          key: const Key('slash-command-palette'),
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.07),
                  palette.surfaceElevated,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.border.withValues(alpha: 0.72),
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.background.withValues(alpha: 0.40),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Semantics(
                label: locale.startsWith('fr')
                    ? 'Commandes et discussions'
                    : 'Commands and conversations',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.searchHint case final String hint)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 9, 10, 0),
                        child: TextField(
                          key: const Key('slash-model-search'),
                          decoration: InputDecoration(
                            hintText: hint,
                            isDense: true,
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                            ),
                          ),
                          onChanged: controller.filter,
                          onSubmitted: (_) => controller.activate(),
                        ),
                      ),
                    if (controller.entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          locale.startsWith('fr')
                              ? 'Aucun résultat.'
                              : 'No matches.',
                          style: TextStyle(color: palette.textMuted),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shrinkWrap: true,
                          itemCount: controller.entries.length,
                          itemBuilder: (context, index) {
                            final item = controller.entries[index];
                            final selected = index == controller.selectedIndex;
                            final showCategory =
                                index == 0 ||
                                controller.entries[index - 1].type != item.type;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showCategory)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      7,
                                      14,
                                      2,
                                    ),
                                    child: Text(
                                      _categoryLabel(item.type),
                                      style: TextStyle(
                                        color: palette.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                Semantics(
                                  button: item.enabled,
                                  enabled: item.enabled,
                                  selected: selected,
                                  label: item.alias.isEmpty
                                      ? item.title
                                      : '/${item.alias} ${item.title}',
                                  child: InkWell(
                                    onTap: item.enabled
                                        ? () => controller.activateAt(index)
                                        : null,
                                    child: AnimatedContainer(
                                      duration: Motion.duration(
                                        context,
                                        MotionDurations.fast,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      color: selected
                                          ? palette.accent.withValues(
                                              alpha: 0.13,
                                            )
                                          : Colors.transparent,
                                      child: Row(
                                        children: [
                                          Icon(
                                            _iconFor(item.type),
                                            size: 20,
                                            color: item.enabled
                                                ? palette.accent
                                                : palette.textMuted,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.alias.isEmpty
                                                      ? item.title
                                                      : '/${item.alias}  ${item.title}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: item.enabled
                                                        ? palette.textPrimary
                                                        : palette.textMuted,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (item.description.isNotEmpty)
                                                  Text(
                                                    item.description,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: palette.textMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Motion.duration(context, MotionDurations.fast),
          curve: MotionCurves.enter,
          child: card,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 6),
              child: child,
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(SlashPaletteSelectionType type) => switch (type) {
    SlashPaletteSelectionType.connector => Icons.extension_rounded,
    SlashPaletteSelectionType.model => Icons.smart_toy_outlined,
    SlashPaletteSelectionType.reasoning => Icons.psychology_outlined,
    SlashPaletteSelectionType.conversation => Icons.chat_bubble_outline_rounded,
    SlashPaletteSelectionType.skill => Icons.extension_outlined,
    SlashPaletteSelectionType.command => Icons.terminal_rounded,
  };

  String _categoryLabel(SlashPaletteSelectionType type) => switch (type) {
    SlashPaletteSelectionType.connector =>
      locale.startsWith('fr') ? 'CONNECTEURS' : 'CONNECTORS',
    SlashPaletteSelectionType.conversation => 'CONVERSATIONS',
    SlashPaletteSelectionType.skill => 'SKILLS',
    SlashPaletteSelectionType.model =>
      locale.startsWith('fr') ? 'MODÈLES' : 'MODELS',
    SlashPaletteSelectionType.reasoning =>
      locale.startsWith('fr') ? 'RAISONNEMENT' : 'REASONING',
    SlashPaletteSelectionType.command =>
      locale.startsWith('fr') ? 'COMMANDES' : 'COMMANDS',
  };
}

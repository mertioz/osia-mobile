import 'package:flutter/material.dart';

import '../slash_commands.dart';
import '../theme.dart';

class SlashCommandPaletteController extends ChangeNotifier {
  List<SlashPaletteSelection> _entries = const [];
  int _selectedIndex = 0;
  ValueChanged<SlashPaletteSelection>? _onSelected;

  List<SlashPaletteSelection> get entries => _entries;
  int get selectedIndex => _selectedIndex;
  bool get isOpen => _entries.isNotEmpty;

  void show(
    List<SlashPaletteSelection> entries,
    ValueChanged<SlashPaletteSelection> onSelected,
  ) {
    _entries = List.unmodifiable(entries.take(slashMaxResults));
    _selectedIndex = 0;
    _onSelected = onSelected;
    notifyListeners();
  }

  void close() {
    if (_entries.isEmpty) return;
    _entries = const [];
    _selectedIndex = 0;
    _onSelected = null;
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
        return Material(
          key: const Key('slash-command-palette'),
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Semantics(
                label: locale.startsWith('fr')
                    ? 'Palette de commandes slash'
                    : 'Slash command palette',
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
                            padding: const EdgeInsets.fromLTRB(14, 7, 14, 2),
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
                          label: '/${item.alias} ${item.title}',
                          child: InkWell(
                            onTap: item.enabled
                                ? () => controller.activateAt(index)
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              color: selected
                                  ? palette.accent.withValues(alpha: 0.13)
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
                                          overflow: TextOverflow.ellipsis,
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
                                            overflow: TextOverflow.ellipsis,
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
    SlashPaletteSelectionType.command => Icons.terminal_rounded,
  };

  String _categoryLabel(SlashPaletteSelectionType type) => switch (type) {
    SlashPaletteSelectionType.connector =>
      locale.startsWith('fr') ? 'CONNECTEURS' : 'CONNECTORS',
    SlashPaletteSelectionType.conversation => 'CONVERSATIONS',
    SlashPaletteSelectionType.model =>
      locale.startsWith('fr') ? 'MODÈLES' : 'MODELS',
    SlashPaletteSelectionType.reasoning =>
      locale.startsWith('fr') ? 'RAISONNEMENT' : 'REASONING',
    SlashPaletteSelectionType.command =>
      locale.startsWith('fr') ? 'COMMANDES' : 'COMMANDS',
  };
}

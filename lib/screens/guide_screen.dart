import 'package:flutter/material.dart';

import '../guide_content.dart';
import '../guide_progress.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({
    super.key,
    required this.storage,
    required this.languageCode,
    this.automatic = false,
    this.initialProgress,
    this.onAutomaticClosed,
  });

  final StorageService storage;
  final String languageCode;
  final bool automatic;
  final GuideProgress? initialProgress;
  final VoidCallback? onAutomaticClosed;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  late final GuideProgressService _progressService;
  GuideProgress? _progress;
  GuideLesson? _currentLesson;
  String _selectedCategoryId = guideEssentialCategoryId;
  bool _saving = false;
  bool _closing = false;

  bool get _isFrench => widget.languageCode == 'fr';
  String _text(GuideText value) => value.resolve(widget.languageCode);

  @override
  void initState() {
    super.initState();
    _progressService = GuideProgressService(widget.storage);
    _initialize();
  }

  Future<void> _initialize() async {
    final progress = widget.initialProgress ?? await _progressService.load();
    if (!mounted) return;
    final initial = widget.automatic
        ? guideLessonById(progress.currentLessonId) ??
              guideLessonsForCategory(guideEssentialCategoryId).first
        : null;
    final savedLesson = guideLessonById(progress.currentLessonId);
    setState(() {
      _progress = progress;
      _currentLesson = initial;
      _selectedCategoryId =
          initial?.categoryId ??
          savedLesson?.categoryId ??
          guideEssentialCategoryId;
    });
  }

  Future<void> _selectLesson(GuideLesson lesson) async {
    final progress = _progress;
    if (progress == null || _saving) return;
    setState(() {
      _saving = true;
      _selectedCategoryId = lesson.categoryId;
      _currentLesson = lesson;
    });
    final next = await _progressService.selectLesson(progress, lesson.id);
    if (!mounted) return;
    setState(() {
      _progress = next;
      _saving = false;
    });
  }

  void _selectCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _currentLesson = null;
    });
  }

  Future<void> _goTo(int index) async {
    final lessons = guideLessonsForCategory(_selectedCategoryId);
    if (index < 0 || index >= lessons.length) return;
    await _selectLesson(lessons[index]);
  }

  Future<void> _next() async {
    final progress = _progress;
    final lesson = _currentLesson;
    if (progress == null || lesson == null || _saving) return;
    setState(() => _saving = true);
    final completed = await _progressService.completeLesson(progress, lesson);
    final lessons = guideLessonsForCategory(lesson.categoryId);
    final index = lessons.indexWhere((item) => item.id == lesson.id);
    if (!mounted) return;
    if (index < lessons.length - 1) {
      final nextLesson = lessons[index + 1];
      final selected = await _progressService.selectLesson(
        completed,
        nextLesson.id,
      );
      if (!mounted) return;
      setState(() {
        _progress = selected;
        _currentLesson = nextLesson;
        _saving = false;
      });
      return;
    }

    if (lesson.categoryId == guideEssentialCategoryId) {
      final finished = await _progressService.markFinished(completed);
      if (!mounted) return;
      setState(() {
        _progress = finished;
        _saving = false;
      });
    } else {
      setState(() {
        _progress = completed.copyWith(outcome: 'completed');
        _saving = false;
      });
      await _progressService.save(_progress!);
    }
    await _close(markClosed: false);
  }

  Future<void> _previous() async {
    final lesson = _currentLesson;
    if (lesson == null) return;
    final lessons = guideLessonsForCategory(lesson.categoryId);
    final index = lessons.indexWhere((item) => item.id == lesson.id);
    if (index <= 0) return;
    await _goTo(index - 1);
  }

  Future<void> _skip() async {
    final progress = _progress;
    if (progress == null || _saving) return;
    setState(() => _saving = true);
    final skipped = await _progressService.markSkipped(progress);
    if (!mounted) return;
    setState(() {
      _progress = skipped;
      _saving = false;
    });
    await _close(markClosed: false);
  }

  Future<void> _close({bool markClosed = true}) async {
    if (_closing) return;
    _closing = true;
    final progress = _progress;
    if (markClosed && progress != null) {
      await _progressService.markClosed(progress);
    }
    if (!mounted) return;
    if (widget.automatic) {
      widget.onAutomaticClosed?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final progress = _progress;
    return PopScope(
      canPop: !widget.automatic,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          final current = _progress;
          if (current != null) {
            _progressService.markClosed(current);
          }
        } else {
          _close();
        }
      },
      child: Scaffold(
        key: const Key('guide-screen'),
        backgroundColor: palette.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: palette.background,
          titleSpacing: 20,
          title: Row(
            children: [
              Image.asset(
                'assets/osia_logo_mark.png',
                width: 30,
                height: 30,
                semanticLabel: _isFrench ? 'Logo OSIA' : 'OSIA logo',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isFrench ? 'Guide OSIA Mobile' : 'OSIA Mobile guide',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('guide-close'),
              tooltip: _isFrench ? 'Fermer le guide' : 'Close guide',
              onPressed: _closing ? null : _close,
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: progress == null
              ? Center(child: CircularProgressIndicator(color: palette.accent))
              : FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 840;
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 310,
                              child: _buildContentsPane(palette, progress),
                            ),
                            VerticalDivider(width: 1, color: palette.border),
                            Expanded(
                              child: _currentLesson == null
                                  ? _buildGuideHome(palette, progress)
                                  : _buildLesson(palette, progress),
                            ),
                          ],
                        );
                      }
                      return _currentLesson == null
                          ? _buildGuideHome(palette, progress)
                          : _buildLesson(palette, progress);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(OsiaPalette palette) {
    return Semantics(
      container: true,
      label: _isFrench ? 'Catégories du guide' : 'Guide categories',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final category in guideCategories)
            ChoiceChip(
              key: Key('guide-category-${category.id}'),
              selected: _selectedCategoryId == category.id,
              onSelected: (_) => _selectCategory(category.id),
              label: Text(_text(category.title)),
              selectedColor: palette.accent.withValues(alpha: 0.2),
              backgroundColor: palette.surface,
              side: BorderSide(
                color: _selectedCategoryId == category.id
                    ? palette.accent
                    : palette.border,
              ),
              labelStyle: TextStyle(
                color: _selectedCategoryId == category.id
                    ? palette.accent
                    : palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGuideHome(OsiaPalette palette, GuideProgress progress) {
    final category = guideCategories.firstWhere(
      (item) => item.id == _selectedCategoryId,
    );
    final lessons = guideLessonsForCategory(_selectedCategoryId);
    return ListView(
      key: const Key('guide-home'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCategorySelector(palette),
              const SizedBox(height: 24),
              Text(
                _text(category.title),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _text(category.summary),
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _buildProgressBar(palette, progress, lessons),
              const SizedBox(height: 18),
              if (progress.currentLessonId != null &&
                  guideLessonById(progress.currentLessonId)?.categoryId ==
                      _selectedCategoryId)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    key: const Key('guide-resume'),
                    onPressed: () => _selectLesson(
                      guideLessonById(progress.currentLessonId)!,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(_isFrench ? 'Reprendre' : 'Resume'),
                  ),
                ),
              Text(
                _isFrench ? 'Table des matières' : 'Table of contents',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final lesson in lessons)
                _LessonTile(
                  lesson: lesson,
                  languageCode: widget.languageCode,
                  completed: _isCompleted(progress, lesson),
                  selected: false,
                  palette: palette,
                  onTap: () => _selectLesson(lesson),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentsPane(OsiaPalette palette, GuideProgress progress) {
    final lessons = guideLessonsForCategory(_selectedCategoryId);
    return ListView(
      key: const Key('guide-contents-pane'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildCategorySelector(palette),
        const SizedBox(height: 18),
        _buildProgressBar(palette, progress, lessons),
        const SizedBox(height: 12),
        for (final lesson in lessons)
          _LessonTile(
            lesson: lesson,
            languageCode: widget.languageCode,
            completed: _isCompleted(progress, lesson),
            selected: lesson.id == _currentLesson?.id,
            palette: palette,
            onTap: () => _selectLesson(lesson),
          ),
      ],
    );
  }

  Widget _buildProgressBar(
    OsiaPalette palette,
    GuideProgress progress,
    List<GuideLesson> lessons,
  ) {
    final completed = lessons
        .where((lesson) => _isCompleted(progress, lesson))
        .length;
    final value = lessons.isEmpty ? 0.0 : completed / lessons.length;
    return Semantics(
      label: _isFrench
          ? 'Progression : $completed sur ${lessons.length}'
          : 'Progress: $completed of ${lessons.length}',
      value: '${(value * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: value,
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: palette.surfaceElevated,
            color: palette.accent,
          ),
          const SizedBox(height: 6),
          Text(
            _isFrench
                ? '$completed chapitre${completed > 1 ? 's' : ''} sur ${lessons.length}'
                : '$completed of ${lessons.length} chapters',
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLesson(OsiaPalette palette, GuideProgress progress) {
    final lesson = _currentLesson!;
    final lessons = guideLessonsForCategory(lesson.categoryId);
    final index = lessons.indexWhere((item) => item.id == lesson.id);
    final last = index == lessons.length - 1;
    return Column(
      children: [
        if (MediaQuery.sizeOf(context).width < 840)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: palette.background,
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildCategorySelector(palette)),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('guide-toc'),
                  tooltip: _isFrench
                      ? 'Table des matières'
                      : 'Table of contents',
                  onPressed: () => setState(() => _currentLesson = null),
                  icon: const Icon(Icons.list_alt_rounded),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            key: Key('guide-lesson-${lesson.id}'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isFrench
                            ? 'Chapitre ${index + 1} sur ${lessons.length}'
                            : 'Chapter ${index + 1} of ${lessons.length}',
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _text(lesson.title),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _text(lesson.introduction),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 16,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      for (final paragraph in lesson.paragraphs) ...[
                        const SizedBox(height: 14),
                        Text(
                          _text(paragraph),
                          style: TextStyle(
                            color: palette.textPrimary.withValues(alpha: 0.86),
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                      ],
                      if (lesson.asset != null) ...[
                        const SizedBox(height: 22),
                        _buildImage(palette, lesson),
                      ],
                      const SizedBox(height: 22),
                      _GuideCallout(
                        icon: Icons.lightbulb_outline_rounded,
                        title: _text(lesson.exampleTitle),
                        body: _text(lesson.example),
                        palette: palette,
                      ),
                      if (lesson.remember != null) ...[
                        const SizedBox(height: 12),
                        _GuideCallout(
                          icon: Icons.bookmark_outline_rounded,
                          title: _isFrench ? 'À retenir' : 'Remember',
                          body: _text(lesson.remember!),
                          palette: palette,
                          accent: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: palette.background,
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final previous = OutlinedButton(
                  key: const Key('guide-previous'),
                  onPressed: index > 0 && !_saving ? _previous : null,
                  child: Text(_isFrench ? 'Précédent' : 'Previous'),
                );
                final next = FilledButton(
                  key: Key(last ? 'guide-finish' : 'guide-next'),
                  onPressed: _saving ? null : _next,
                  child: Text(
                    last
                        ? (_isFrench ? 'Terminer' : 'Finish')
                        : (_isFrench ? 'Suivant' : 'Next'),
                  ),
                );
                final skip = widget.automatic
                    ? TextButton(
                        key: const Key('guide-skip'),
                        onPressed: _saving ? null : _skip,
                        child: Text(_isFrench ? 'Passer' : 'Skip'),
                      )
                    : null;
                if (constraints.maxWidth < 500) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (skip != null)
                        Align(alignment: Alignment.centerLeft, child: skip),
                      Row(
                        children: [
                          Expanded(child: previous),
                          const SizedBox(width: 10),
                          Expanded(child: next),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    ?skip,
                    const Spacer(),
                    previous,
                    const SizedBox(width: 10),
                    next,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(OsiaPalette palette, GuideLesson lesson) {
    final alt = _text(lesson.altText!);
    return Semantics(
      image: true,
      label: alt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 600),
                child: Image.asset(
                  lesson.asset!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                  errorBuilder: (context, _, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            color: palette.textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isFrench
                                ? 'Capture indisponible. Le texte du chapitre reste complet.'
                                : 'Screenshot unavailable. The chapter text remains complete.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _text(lesson.caption!),
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  bool _isCompleted(GuideProgress progress, GuideLesson lesson) =>
      lesson.categoryId == guideEssentialCategoryId
      ? progress.essentialCompleted.contains(lesson.id)
      : progress.advancedCompleted.contains(lesson.id);
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.languageCode,
    required this.completed,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final GuideLesson lesson;
  final String languageCode;
  final bool completed;
  final bool selected;
  final OsiaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: lesson.title.resolve(languageCode),
        child: InkWell(
          key: Key('guide-toc-${lesson.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? palette.accent.withValues(alpha: 0.12)
                  : palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? palette.accent : palette.border,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: completed
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: 19,
                          color: palette.accent,
                        )
                      : Text(
                          '${lesson.order}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lesson.title.resolve(languageCode),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.textMuted,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideCallout extends StatelessWidget {
  const _GuideCallout({
    required this.icon,
    required this.title,
    required this.body,
    required this.palette,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final OsiaPalette palette;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? palette.accent : palette.textMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent
            ? palette.accent.withValues(alpha: 0.09)
            : palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent
              ? palette.accent.withValues(alpha: 0.45)
              : palette.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: palette.textPrimary.withValues(alpha: 0.84),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

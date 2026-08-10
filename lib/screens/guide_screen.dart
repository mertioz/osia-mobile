import 'dart:async';

import 'package:flutter/material.dart';

import '../guide/guide_catalog.dart';
import '../guide/guide_visuals.dart';
import '../guide_progress.dart';
import '../l10n.dart';
import '../motion.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/accent_logo.dart';

const Duration guidePageTransitionDuration = MotionDurations.medium;
const Duration guideContentTransitionDuration = MotionDurations.fast;
const Duration guideProgressTransitionDuration = MotionDurations.medium;
const Curve guidePageTransitionCurve = MotionCurves.enter;
const Curve guideContentTransitionCurve = MotionCurves.enter;
const Curve guideProgressTransitionCurve = MotionCurves.loop;

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
  PageController? _pageController;
  Future<void> _persistenceQueue = Future<void>.value();
  String _selectedCategoryId = guideEssentialCategoryId;
  int _pageIndex = 0;
  bool _showTableOfContents = false;
  bool _transitioning = false;
  bool _closing = false;

  bool get _isFrench => widget.languageCode == 'fr';
  String _text(GuideText value) => value.resolve(widget.languageCode);

  bool _reducedMotion(BuildContext context) {
    final media = MediaQuery.of(context);
    return Motion.reduced(context) || media.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _progressService = GuideProgressService(widget.storage);
    _initialize();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final progress = widget.initialProgress ?? await _progressService.load();
    if (!mounted) return;
    final savedLesson = guideLessonById(progress.currentLessonId);
    final initial = widget.automatic
        ? savedLesson ?? guideLessonsForCategory(guideEssentialCategoryId).first
        : null;
    if (initial != null) {
      final lessons = guideLessonsForCategory(initial.categoryId);
      _pageIndex = lessons.indexWhere((lesson) => lesson.id == initial.id);
      _pageController = PageController(initialPage: _pageIndex);
    }
    setState(() {
      _progress = progress;
      _currentLesson = initial;
      _selectedCategoryId =
          initial?.categoryId ??
          savedLesson?.categoryId ??
          progress.lastTrackId;
    });
  }

  void _openCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _currentLesson = null;
      _showTableOfContents = true;
    });
  }

  void _openHome() {
    setState(() {
      _currentLesson = null;
      _showTableOfContents = false;
    });
  }

  void _openContents() {
    setState(() {
      _currentLesson = null;
      _showTableOfContents = true;
    });
  }

  Future<void> _openLesson(GuideLesson lesson) async {
    if (_progress == null) return;
    await _persistenceQueue;
    final latest = _progress;
    if (latest == null) return;
    final selected = await _progressService.selectLesson(latest, lesson.id);
    if (!mounted) return;
    final lessons = guideLessonsForCategory(lesson.categoryId);
    final index = lessons.indexWhere((item) => item.id == lesson.id);
    _pageController?.dispose();
    _pageController = PageController(initialPage: index);
    setState(() {
      _progress = selected;
      _selectedCategoryId = lesson.categoryId;
      _currentLesson = lesson;
      _pageIndex = index;
      _showTableOfContents = false;
    });
  }

  void _onPageChanged(int index) {
    final lessons = guideLessonsForCategory(_selectedCategoryId);
    if (index < 0 || index >= lessons.length || index == _pageIndex) return;
    final previousIndex = _pageIndex;
    final lesson = lessons[index];
    setState(() {
      _pageIndex = index;
      _currentLesson = lesson;
    });

    _persistenceQueue = _persistenceQueue.then((_) async {
      var progress = _progress;
      if (progress == null) return;
      GuideProgress nextProgress = progress;
      if (index > previousIndex) {
        final lastReached = index == lessons.length - 1;
        final completedThrough = lastReached ? index : index - 1;
        for (var i = previousIndex; i <= completedThrough; i++) {
          nextProgress = await _progressService.completeLesson(
            nextProgress,
            lessons[i],
          );
        }
        if (lastReached) {
          if (lesson.categoryId == guideEssentialCategoryId) {
            nextProgress = await _progressService.markFinished(nextProgress);
          } else {
            nextProgress = nextProgress.copyWith(outcome: 'completed');
            await _progressService.save(nextProgress);
          }
        }
      }
      nextProgress = await _progressService.selectLesson(
        nextProgress,
        lesson.id,
      );
      if (mounted) setState(() => _progress = nextProgress);
    });
  }

  Future<void> _animateToPage(int index) async {
    final controller = _pageController;
    final lessons = guideLessonsForCategory(_selectedCategoryId);
    if (controller == null ||
        _transitioning ||
        index < 0 ||
        index >= lessons.length) {
      return;
    }
    setState(() => _transitioning = true);
    try {
      if (_reducedMotion(context)) {
        controller.jumpToPage(index);
      } else {
        await controller.animateToPage(
          index,
          duration: guidePageTransitionDuration,
          curve: guidePageTransitionCurve,
        );
      }
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  Future<void> _next() async {
    final lesson = _currentLesson;
    if (_progress == null || lesson == null || _transitioning) {
      return;
    }
    final lessons = guideLessonsForCategory(lesson.categoryId);
    if (_pageIndex < lessons.length - 1) {
      await _animateToPage(_pageIndex + 1);
    }
  }

  Future<void> _previous() => _animateToPage(_pageIndex - 1);

  Future<void> _close({bool markClosed = true}) async {
    if (_closing) return;
    _closing = true;
    await _persistenceQueue;
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
    final strings = OsiaL10n.of(context);
    final progress = _progress;
    final reduceMotion = _reducedMotion(context);
    return PopScope(
      canPop: !widget.automatic,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          final current = _progress;
          if (current != null) unawaited(_progressService.markClosed(current));
        } else {
          unawaited(_close());
        }
      },
      child: Scaffold(
        key: const Key('guide-screen'),
        backgroundColor: palette.background,
        appBar: AppBar(
          toolbarHeight: 52,
          automaticallyImplyLeading: false,
          backgroundColor: palette.background,
          titleSpacing: 16,
          title: Row(
            children: [
              AccentLogo(
                width: 26,
                height: 26,
                semanticLabel: _isFrench ? 'Logo OSIA' : 'OSIA logo',
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  strings.guideTitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('guide-close'),
              tooltip: strings.guideClose,
              onPressed: _closing ? null : _close,
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: progress == null
              ? Center(child: CircularProgressIndicator(color: palette.accent))
              : FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: _currentLesson != null
                      ? _buildJourney(palette, progress, reduceMotion)
                      : AnimatedSwitcher(
                          key: const Key('guide-shell-transition'),
                          duration: reduceMotion
                              ? Duration.zero
                              : guideContentTransitionDuration,
                          switchInCurve: guideContentTransitionCurve,
                          switchOutCurve: MotionCurves.exit,
                          child: _buildHomeOrContents(palette, progress),
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildHomeOrContents(OsiaPalette palette, GuideProgress progress) {
    if (_showTableOfContents) {
      return KeyedSubtree(
        key: ValueKey<String>('guide-toc-$_selectedCategoryId'),
        child: _buildTableOfContents(palette, progress),
      );
    }
    return KeyedSubtree(
      key: const ValueKey<String>('guide-home-shell'),
      child: _buildGuideHome(palette, progress),
    );
  }

  Widget _buildGuideHome(OsiaPalette palette, GuideProgress progress) {
    final strings = OsiaL10n.of(context);
    return ListView(
      key: const Key('guide-home'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.guideChooseJourney,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 27,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.guideHomeIntro,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < guideCategories.length; i++) ...[
                  _CategoryCard(
                    key: Key('guide-category-${guideCategories[i].id}'),
                    category: guideCategories[i],
                    languageCode: widget.languageCode,
                    palette: palette,
                    completed: _completedCount(progress, guideCategories[i].id),
                    total: guideLessonsForCategory(
                      guideCategories[i].id,
                    ).length,
                    resumable: progress.lastSlideByTrack.containsKey(
                      guideCategories[i].id,
                    ),
                    onTap: () => _openCategory(guideCategories[i].id),
                  ),
                  if (i != guideCategories.length - 1)
                    const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableOfContents(OsiaPalette palette, GuideProgress progress) {
    final strings = OsiaL10n.of(context);
    final category = guideCategories.firstWhere(
      (item) => item.id == _selectedCategoryId,
    );
    final lessons = guideLessonsForCategory(_selectedCategoryId);
    final saved = guideLessonById(
      progress.lastSlideByTrack[_selectedCategoryId],
    );
    return ListView(
      key: const Key('guide-table-of-contents'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('guide-home-back'),
                      tooltip: strings.guideHome,
                      onPressed: _openHome,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: _buildCategorySelector(palette)),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  _text(category.title),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _text(category.summary),
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 15),
                _StaticProgress(
                  completed: _completedCount(progress, category.id),
                  total: lessons.length,
                  palette: palette,
                ),
                if (saved?.categoryId == category.id) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const Key('guide-resume'),
                    onPressed: () => _openLesson(saved!),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(strings.guideResume),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  strings.guideSlides,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                for (final lesson in lessons)
                  _LessonTile(
                    lesson: lesson,
                    languageCode: widget.languageCode,
                    completed: _isCompleted(progress, lesson),
                    palette: palette,
                    onTap: () => _openLesson(lesson),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(OsiaPalette palette) {
    final strings = OsiaL10n.of(context);
    return Semantics(
      container: true,
      label: strings.guideCategories,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final category in guideCategories)
            ChoiceChip(
              key: Key('guide-category-${category.id}'),
              selected: _selectedCategoryId == category.id,
              onSelected: (_) => _openCategory(category.id),
              label: Text(_text(category.title)),
              selectedColor: palette.accent.withValues(alpha: 0.18),
              backgroundColor: palette.surface,
              side: BorderSide(
                color: _selectedCategoryId == category.id
                    ? palette.accent.withValues(alpha: 0.75)
                    : palette.border,
              ),
              labelStyle: TextStyle(
                color: _selectedCategoryId == category.id
                    ? palette.accent
                    : palette.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJourney(
    OsiaPalette palette,
    GuideProgress progress,
    bool reduceMotion,
  ) {
    final strings = OsiaL10n.of(context);
    final lessons = guideLessonsForCategory(_selectedCategoryId);
    final category = guideCategories.firstWhere(
      (item) => item.id == _selectedCategoryId,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(category.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.45,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      strings.guideSlideProgress(
                        _pageIndex + 1,
                        lessons.length,
                      ),
                      style: TextStyle(color: palette.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('guide-toc'),
                tooltip: strings.guideContents,
                onPressed: _openContents,
                icon: const Icon(Icons.grid_view_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            label: strings.guideProgressLabel(_pageIndex + 1, lessons.length),
            value: '${(((_pageIndex + 1) / lessons.length) * 100).round()}%',
            child: TweenAnimationBuilder<double>(
              key: const Key('guide-slide-progress'),
              tween: Tween<double>(end: (_pageIndex + 1) / lessons.length),
              duration: reduceMotion
                  ? Duration.zero
                  : guideProgressTransitionDuration,
              curve: guideProgressTransitionCurve,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: palette.surfaceElevated,
                color: palette.accent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_pageIndex == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
            child: Text(
              strings.guideSwipeHint,
              key: const Key('guide-swipe-hint'),
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 11.5),
            ),
          ),
        Expanded(
          child: Semantics(
            key: const Key('guide-slide-semantics'),
            container: true,
            liveRegion: true,
            label: strings.guideSlideAnnouncement(
              _pageIndex + 1,
              lessons.length,
              _text(lessons[_pageIndex].title),
            ),
            onIncrease: _pageIndex < lessons.length - 1
                ? () => unawaited(_next())
                : null,
            onDecrease: _pageIndex > 0 ? () => unawaited(_previous()) : null,
            child: PageView.builder(
              key: const Key('guide-page-view'),
              controller: _pageController,
              itemCount: lessons.length,
              allowImplicitScrolling: true,
              physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _GuideSlide(
                key: Key('guide-lesson-${lessons[index].id}'),
                lesson: lessons[index],
                languageCode: widget.languageCode,
                palette: palette,
                reduceMotion: reduceMotion,
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _completedCount(GuideProgress progress, String categoryId) =>
      guideLessonsForCategory(
        categoryId,
      ).where((lesson) => _isCompleted(progress, lesson)).length;

  bool _isCompleted(GuideProgress progress, GuideLesson lesson) =>
      lesson.categoryId == guideEssentialCategoryId
      ? progress.essentialCompleted.contains(lesson.id)
      : lesson.categoryId == guideMasteryCategoryId
      ? progress.masteryCompleted.contains(lesson.id)
      : progress.advancedCompleted.contains(lesson.id);
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    super.key,
    required this.category,
    required this.languageCode,
    required this.palette,
    required this.completed,
    required this.total,
    required this.resumable,
    required this.onTap,
  });

  final GuideCategory category;
  final String languageCode;
  final OsiaPalette palette;
  final int completed;
  final int total;
  final bool resumable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final advanced = category.id == guideAdvancedCategoryId;
    final strings = OsiaL10n.of(context);
    return Semantics(
      button: true,
      label: category.title.resolve(languageCode),
      value: strings.guideCompletedProgress(completed, total),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              color: advanced
                  ? palette.surface
                  : palette.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: advanced
                    ? palette.border
                    : palette.accent.withValues(alpha: 0.36),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        advanced
                            ? Icons.auto_awesome_rounded
                            : Icons.rocket_launch_rounded,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        category.title.resolve(languageCode),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: palette.accent),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  category.summary.resolve(languageCode),
                  style: TextStyle(
                    color: palette.textMuted,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : completed / total,
                    minHeight: 5,
                    backgroundColor: palette.surfaceElevated,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      strings.guideCompactProgress(completed, total),
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      resumable
                          ? strings.guideResume
                          : strings.guideViewJourney,
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticProgress extends StatelessWidget {
  const _StaticProgress({
    required this.completed,
    required this.total,
    required this.palette,
  });

  final int completed;
  final int total;
  final OsiaPalette palette;

  @override
  Widget build(BuildContext context) {
    final strings = OsiaL10n.of(context);
    return Semantics(
      label: strings.guideProgressLabel(completed, total),
      value: '${total == 0 ? 0 : ((completed / total) * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: total == 0 ? 0 : completed / total,
            minHeight: 5,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: palette.surfaceElevated,
            color: palette.accent,
          ),
          const SizedBox(height: 6),
          Text(
            strings.guideCompletedProgress(completed, total),
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.languageCode,
    required this.completed,
    required this.palette,
    required this.onTap,
  });

  final GuideLesson lesson;
  final String languageCode;
  final bool completed;
  final OsiaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Semantics(
        button: true,
        label: lesson.title.resolve(languageCode),
        child: Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: Key('guide-toc-${lesson.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _GuideSlide extends StatelessWidget {
  const _GuideSlide({
    super.key,
    required this.lesson,
    required this.languageCode,
    required this.palette,
    required this.reduceMotion,
  });

  final GuideLesson lesson;
  final String languageCode;
  final OsiaPalette palette;
  final bool reduceMotion;

  bool get _isFrench => languageCode == 'fr';
  String _text(GuideText value) => value.resolve(languageCode);

  @override
  Widget build(BuildContext context) {
    // Catalog v4 always supplies a visual key. The former renderer remains a
    // compatibility fallback until the legacy content files are retired.
    if (lesson.visual.key.isNotEmpty) {
      return GuideResponsiveSlide(
        key: Key('guide-catalog-slide-${lesson.id}'),
        slide: lesson,
        languageCode: languageCode,
        palette: palette,
        reduceMotion: reduceMotion,
      );
    }
    final size = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactViewport = size.width > size.height;
    final titleFontSize = size.width <= 360 && textScale >= 1.5
        ? 19.5
        : (compactViewport ? 25.0 : 28.0);
    return SingleChildScrollView(
      key: Key('guide-slide-scroll-${lesson.id}'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: TweenAnimationBuilder<double>(
            key: Key('guide-slide-motion-${lesson.id}'),
            tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
            duration: reduceMotion
                ? Duration.zero
                : guideContentTransitionDuration,
            curve: guideContentTransitionCurve,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: reduceMotion ? Offset.zero : Offset(0, 8 * (1 - value)),
                child: Transform.scale(
                  scale: reduceMotion ? 1 : 0.98 + (0.02 * value),
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _text(lesson.title),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: titleFontSize,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (lesson.asset != null)
                  _GuideImage(
                    lesson: lesson,
                    languageCode: languageCode,
                    palette: palette,
                  )
                else
                  _GuideVisual(
                    lesson: lesson,
                    languageCode: languageCode,
                    palette: palette,
                    compact: compactViewport,
                  ),
                const SizedBox(height: 18),
                Text(
                  _text(lesson.introduction),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final paragraph in lesson.paragraphs) ...[
                  const SizedBox(height: 10),
                  Text(
                    _text(paragraph),
                    style: TextStyle(
                      color: palette.textPrimary.withValues(alpha: 0.82),
                      fontSize: 14.5,
                      height: 1.48,
                    ),
                  ),
                ],
                if (lesson.bullets.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  for (final bullet in lesson.bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 8, right: 10),
                            decoration: BoxDecoration(
                              color: palette.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _text(bullet),
                              style: TextStyle(
                                color: palette.textPrimary.withValues(
                                  alpha: 0.86,
                                ),
                                fontSize: 14.5,
                                height: 1.42,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                _GuideCallout(
                  icon: Icons.lightbulb_outline_rounded,
                  title: _text(lesson.exampleTitle),
                  body: _text(lesson.example),
                  palette: palette,
                ),
                if (lesson.remember != null) ...[
                  const SizedBox(height: 9),
                  _GuideCallout(
                    icon: Icons.bookmark_rounded,
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
      ),
    );
  }
}

class _GuideVisual extends StatelessWidget {
  const _GuideVisual({
    required this.lesson,
    required this.languageCode,
    required this.palette,
    required this.compact,
  });

  final GuideLesson lesson;
  final String languageCode;
  final OsiaPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visualSize = compact ? 48.0 : 66.0;
    return Semantics(
      image: true,
      label: lesson.title.resolve(languageCode),
      child: Container(
        height: compact ? 70 : 116,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: visualSize,
            height: visualSize,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
            ),
            child: Icon(
              _iconForLesson(lesson.id),
              color: palette.accent,
              size: compact ? 23 : 30,
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideImage extends StatelessWidget {
  const _GuideImage({
    required this.lesson,
    required this.languageCode,
    required this.palette,
  });

  final GuideLesson lesson;
  final String languageCode;
  final OsiaPalette palette;

  @override
  Widget build(BuildContext context) {
    final french = languageCode == 'fr';
    return Semantics(
      image: true,
      label: lesson.altText!.resolve(languageCode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 170, maxHeight: 330),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.accent.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Image.asset(
                lesson.asset!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
                errorBuilder: (context, _, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          color: palette.textMuted,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          french
                              ? 'Capture indisponible. Le texte reste complet.'
                              : 'Screenshot unavailable. The text remains complete.',
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
          const SizedBox(height: 7),
          Text(
            lesson.caption!.resolve(languageCode),
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 11.5,
              height: 1.35,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: accent
            ? palette.accent.withValues(alpha: 0.09)
            : palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent
              ? palette.accent.withValues(alpha: 0.30)
              : palette.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: accent ? palette.accent : palette.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: palette.textPrimary.withValues(alpha: 0.80),
                    fontSize: 13,
                    height: 1.4,
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

IconData _iconForLesson(String id) {
  if (id.contains('pair') || id.contains('token') || id.contains('trust')) {
    return Icons.key_rounded;
  }
  if (id.contains('lan') || id.contains('connection')) {
    return Icons.lan_rounded;
  }
  if (id.contains('webrtc')) return Icons.device_hub_rounded;
  if (id.contains('relay') || id.contains('reconnect')) {
    return Icons.sync_rounded;
  }
  if (id.contains('voice') || id.contains('tts')) {
    return Icons.graphic_eq_rounded;
  }
  if (id.contains('notification') || id.contains('background')) {
    return Icons.notifications_active_rounded;
  }
  if (id.contains('conversation') || id.contains('message')) {
    return Icons.forum_rounded;
  }
  if (id.contains('model')) return Icons.auto_awesome_rounded;
  if (id.contains('troubleshooting')) return Icons.build_circle_rounded;
  if (id.contains('security')) return Icons.shield_rounded;
  if (id.contains('ready')) return Icons.check_circle_rounded;
  if (id.contains('pages')) return Icons.grid_view_rounded;
  return Icons.phone_android_rounded;
}

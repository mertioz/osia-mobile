import 'dart:async';

import 'package:flutter/material.dart';

import '../guide/onboarding_content.dart';
import '../guide_progress.dart';
import '../l10n.dart';
import '../motion.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/accent_logo.dart';

/// First-launch presentation, using the existing launch claim and storage.
/// Detailed guides remain available from Settings without curriculum changes.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.storage,
    required this.initialProgress,
    required this.onClosed,
  });

  final StorageService storage;
  final GuideProgress initialProgress;
  final VoidCallback onClosed;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _closing = false;
  bool _moving = false;

  bool get _last => _index == onboardingSlides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _close({bool completed = false}) async {
    if (_closing) return;
    setState(() => _closing = true);
    final service = GuideProgressService(widget.storage);
    // Do not mark the full essential manual as read after this introduction.
    final progress = completed
        ? widget.initialProgress.copyWith(finished: true, outcome: 'completed')
        : widget.initialProgress;
    try {
      await service.markClosed(progress);
    } catch (_) {
      // The first-launch claim already prevents automatic replay.
    } finally {
      // The launch claim is already persisted by prepareLaunch. A later write
      // failure must not strand the user before connection, as at bootstrap.
      if (mounted) widget.onClosed();
    }
  }

  Future<void> _move(int target) async {
    if (_moving ||
        _closing ||
        target < 0 ||
        target >= onboardingSlides.length) {
      return;
    }
    _moving = true;
    try {
      if (Motion.reduced(context) ||
          MediaQuery.of(context).accessibleNavigation) {
        _pages.jumpToPage(target);
      } else {
        await _pages.animateToPage(
          target,
          duration: MotionDurations.medium,
          curve: MotionCurves.enter,
        );
      }
    } finally {
      _moving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final languageCode = OsiaL10n.of(context).languageCode;
    final step = OnboardingLabels.progress(
      languageCode,
      _index + 1,
      onboardingSlides.length,
    );
    final slide = onboardingSlides[_index];
    final nextLabel = (_last ? OnboardingLabels.start : OnboardingLabels.next)
        .resolve(languageCode);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        key: const Key('onboarding-screen'),
        backgroundColor: palette.background,
        body: SafeArea(
          child: FocusTraversalGroup(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
                  child: Row(
                    children: [
                      Text(
                        'OSIA',
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('onboarding-close'),
                        tooltip: OnboardingLabels.close.resolve(languageCode),
                        onPressed: _closing ? null : () => unawaited(_close()),
                        color: palette.textMuted,
                        icon: const Icon(Icons.close_rounded, size: 22),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Semantics(
                    key: const Key('onboarding-semantics'),
                    container: true,
                    liveRegion: true,
                    label: '$step: ${slide.title.resolve(languageCode)}',
                    onIncrease: _last
                        ? null
                        : () => unawaited(_move(_index + 1)),
                    onDecrease: _index == 0
                        ? null
                        : () => unawaited(_move(_index - 1)),
                    child: PageView.builder(
                      key: const Key('onboarding-pages'),
                      controller: _pages,
                      itemCount: onboardingSlides.length,
                      allowImplicitScrolling: true,
                      physics: const PageScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      onPageChanged: (index) => setState(() => _index = index),
                      itemBuilder: (context, index) => _Slide(
                        slide: onboardingSlides[index],
                        languageCode: languageCode,
                        palette: palette,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
                  child: Row(
                    children: [
                      Semantics(
                        label: step,
                        child: ExcludeSemantics(
                          child: Text(
                            '${_index + 1} / ${onboardingSlides.length}',
                            key: const Key('onboarding-progress'),
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _index == 0
                            ? Text(
                                OnboardingLabels.swipe.resolve(languageCode),
                                locale: Locale(languageCode),
                                style: TextStyle(
                                  color: palette.textMuted,
                                  fontSize: 12,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      IconButton(
                        key: const Key('onboarding-next'),
                        tooltip: nextLabel,
                        onPressed: _closing
                            ? null
                            : () => _last
                                  ? unawaited(_close(completed: true))
                                  : unawaited(_move(_index + 1)),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: palette.accent,
                          backgroundColor: palette.surfaceElevated,
                        ),
                        icon: Icon(
                          _last
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 22,
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
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.slide,
    required this.languageCode,
    required this.palette,
  });
  final OnboardingSlide slide;
  final String languageCode;
  final OsiaPalette palette;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: Key('onboarding-scroll-${slide.id}'),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 32).clamp(0, double.infinity),
        ),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 180),
                  child: _Illustration(id: slide.id, palette: palette),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                slide.title.resolve(languageCode),
                locale: Locale(languageCode),
                key: Key('onboarding-title-${slide.id}'),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                slide.body.resolve(languageCode),
                locale: Locale(languageCode),
                key: Key('onboarding-body-${slide.id}'),
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Native, accent-aware illustrations: no screenshot text, fake credentials,
/// downloaded assets, or extra animation to distract from the first steps.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.id, required this.palette});
  final String id;
  final OsiaPalette palette;

  Widget _card(Widget child, {double width = 116, double height = 100}) =>
      Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
        ),
        child: child,
      );

  Widget _icon(IconData icon, [double size = 50]) =>
      Icon(icon, size: size, color: palette.accent);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    // The adjacent title/body express the entire meaning of these decorative
    // illustrations. Screen readers encounter the concise text only once.
    child: Container(
      key: Key('onboarding-image-$id'),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: RadialGradient(
          colors: [palette.accent.withValues(alpha: 0.12), palette.background],
          radius: 0.85,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 260,
          height: 180,
          child: switch (id) {
            'welcome' => Center(
              child: _card(
                const AccentLogo(width: 90, height: 90),
                width: 148,
                height: 148,
              ),
            ),
            'computer' || 'connect' => Stack(
              children: [
                Positioned(
                  left: 4,
                  top: 12,
                  child: _card(
                    _icon(Icons.laptop_rounded, 72),
                    width: 156,
                    height: 116,
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 0,
                  child: _card(
                    _icon(
                      id == 'connect'
                          ? Icons.qr_code_scanner_rounded
                          : Icons.smartphone_rounded,
                    ),
                    width: 88,
                    height: 124,
                  ),
                ),
                Positioned(
                  left: 112,
                  bottom: 17,
                  child: _icon(Icons.link_rounded, 32),
                ),
              ],
            ),
            'install' || 'pc-code' => Stack(
              children: [
                Center(
                  child: _card(
                    _icon(Icons.laptop_rounded, 96),
                    width: 200,
                    height: 140,
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 0,
                  child: _card(
                    _icon(
                      id == 'install'
                          ? Icons.download_rounded
                          : Icons.qr_code_rounded,
                      38,
                    ),
                    width: 72,
                    height: 72,
                  ),
                ),
              ],
            ),
            'chat' => Stack(
              children: [
                Positioned(
                  left: 4,
                  top: 8,
                  child: _card(
                    _icon(Icons.chat_bubble_outline_rounded),
                    width: 156,
                    height: 100,
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 0,
                  child: _card(
                    const AccentLogo(width: 52, height: 52),
                    width: 136,
                    height: 100,
                  ),
                ),
              ],
            ),
            'actions' => Stack(
              children: [
                Positioned(
                  left: 8,
                  top: 12,
                  child: _card(
                    _icon(Icons.task_alt_rounded),
                    width: 136,
                    height: 112,
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 0,
                  child: _card(
                    _icon(Icons.construction_rounded, 42),
                    width: 96,
                    height: 88,
                  ),
                ),
              ],
            ),
            'settings' => Center(
              child: _card(
                _icon(Icons.tune_rounded, 76),
                width: 164,
                height: 144,
              ),
            ),
            'support' => Center(
              child: _card(
                _icon(Icons.favorite_outline_rounded, 76),
                width: 164,
                height: 144,
              ),
            ),
            _ => Center(
              child: _card(
                _icon(Icons.check_circle_outline_rounded, 80),
                width: 164,
                height: 144,
              ),
            ),
          },
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../theme.dart';
import 'guide_model.dart';

class GuideVisualSurface extends StatelessWidget {
  const GuideVisualSurface({
    super.key,
    required this.slide,
    required this.languageCode,
    required this.palette,
    required this.compact,
  });

  final GuideSlide slide;
  final String languageCode;
  final OsiaPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visual = slide.visual;
    if (visual.kind == 'screenshot' && visual.asset != null) {
      return Semantics(
        image: true,
        label: visual.alt.resolve(languageCode),
        child: Container(
          constraints: BoxConstraints(
            minHeight: compact ? 130 : 190,
            maxHeight: compact ? 240 : 360,
          ),
          padding: const EdgeInsets.all(9),
          decoration: _decoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Image.asset(
              visual.asset!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (context, _, _) => Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final labels = languageCode == 'fr'
        ? const <String>['Choisir', 'OSIA', 'Vérifier']
        : const <String>['Choose', 'OSIA', 'Review'];
    return Semantics(
      image: true,
      label: visual.alt.resolve(languageCode),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 112 : 210),
        padding: EdgeInsets.all(compact ? 14 : 20),
        decoration: _decoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 52 : 70,
              height: compact ? 52 : 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.accent.withValues(alpha: 0.12),
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                _iconForVisual(visual.kind),
                color: palette.accent,
                size: compact ? 24 : 32,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  for (var index = 0; index < labels.length; index++) ...[
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: index == 1
                              ? palette.accent.withValues(alpha: 0.10)
                              : palette.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: index == 1 ? palette.accent : palette.border,
                          ),
                        ),
                        child: Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: index == 1
                                ? palette.accent
                                : palette.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (index != labels.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  BoxDecoration _decoration() => BoxDecoration(
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
  );

  static IconData _iconForVisual(String kind) => switch (kind) {
    'diagram' => Icons.account_tree_outlined,
    'callout' => Icons.verified_user_outlined,
    _ => Icons.auto_awesome_outlined,
  };
}

class GuideResponsiveSlide extends StatelessWidget {
  const GuideResponsiveSlide({
    super.key,
    required this.slide,
    required this.languageCode,
    required this.palette,
    required this.reduceMotion,
  });

  final GuideSlide slide;
  final String languageCode;
  final OsiaPalette palette;
  final bool reduceMotion;

  String _text(GuideText value) => value.resolve(languageCode);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final landscape = size.width > size.height && size.width >= 600;
    final titleSize = size.width <= 360 && scale >= 1.5
        ? 19.5
        : (landscape ? 25.0 : 28.0);
    final headline = Text(
      _text(slide.title),
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: titleSize,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    );
    final support = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _text(slide.subtitle),
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final block in slide.bodyBlocks) ...[
          const SizedBox(height: 10),
          Text(
            _text(block),
            style: TextStyle(
              color: palette.textPrimary.withValues(alpha: 0.82),
              fontSize: 14.5,
              height: 1.48,
            ),
          ),
        ],
        for (final callout in slide.callouts) ...[
          const SizedBox(height: 10),
          _CatalogCallout(
            callout: callout,
            languageCode: languageCode,
            palette: palette,
          ),
        ],
      ],
    );
    final visual = GuideVisualSurface(
      slide: slide,
      languageCode: languageCode,
      palette: palette,
      compact: landscape,
    );
    final content = landscape
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [headline, const SizedBox(height: 16), support],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(flex: 6, child: visual),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headline,
              const SizedBox(height: 16),
              visual,
              const SizedBox(height: 18),
              support,
            ],
          );
    return SingleChildScrollView(
      key: Key('guide-slide-scroll-${slide.id}'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: landscape ? 1100 : 760),
          child: TweenAnimationBuilder<double>(
            key: Key('guide-slide-motion-${slide.id}'),
            tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: reduceMotion ? Offset.zero : Offset(0, 8 * (1 - value)),
                child: child,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _CatalogCallout extends StatelessWidget {
  const _CatalogCallout({
    required this.callout,
    required this.languageCode,
    required this.palette,
  });

  final GuideCallout callout;
  final String languageCode;
  final OsiaPalette palette;

  @override
  Widget build(BuildContext context) {
    final accent = callout.kind != 'example';
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
            callout.kind == 'example'
                ? Icons.lightbulb_outline_rounded
                : Icons.bookmark_rounded,
            color: accent ? palette.accent : palette.textMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  callout.title.resolve(languageCode),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  callout.body.resolve(languageCode),
                  style: TextStyle(
                    color: palette.textPrimary.withValues(alpha: 0.84),
                    height: 1.42,
                    fontSize: 13.5,
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

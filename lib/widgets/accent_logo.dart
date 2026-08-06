import 'package:flutter/material.dart';

import '../theme.dart';

/// The in-app OSIA mark, tinted from the canonical active theme accent.
///
/// [BlendMode.srcIn] keeps the source asset's alpha mask, including its
/// anti-aliased edges and transparent cut-outs, without duplicating the asset
/// for each supported palette.
class AccentLogo extends StatelessWidget {
  const AccentLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
  });

  final double? width;
  final double? height;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final accent = OsiaTheme.of(context).accent;
    return Image.asset(
      'assets/osia_logo_mark.png',
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      color: accent,
      colorBlendMode: BlendMode.srcIn,
      semanticLabel: semanticLabel,
    );
  }
}

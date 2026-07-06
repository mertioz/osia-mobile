import 'dart:ui';

import 'package:flutter/material.dart';
import '../l10n.dart';
import '../motion.dart';
import '../theme.dart';

/// Shared motion constants so every implicit animation in the bar moves with
/// the same rhythm — sourced from the global motion tokens so the bar stays
/// in step with the rest of the app.
const Duration _kBarAnimDuration = MotionDurations.medium;
const Curve _kBarAnimCurve = MotionCurves.enter;

/// Floating glassmorphism input bar pinned to the bottom of the chat.
///
/// Two-row layout, like a modern AI chat app:
///   row 1: growing text field ("Message OSIA…")
///   row 2: [+] [model pill]            [mic] [send]
///
/// The model pill shows the currently active model and opens the model
/// selector sheet on tap. Recording state morphs the mic into a stop
/// control. The whole bar is a blurred translucent rounded rectangle so
/// the chat content shows faintly underneath.
class GlassInputBar extends StatelessWidget {
  final TextEditingController textController;

  /// Optional external focus handle for the text field. When provided, the
  /// chat screen owns it so it can conditionally request focus (new empty
  /// chat → open the keyboard) or unfocus (existing conversation → keep it
  /// down). When null the field falls back to its own internal node, so the
  /// manual-tap-to-focus behaviour is unchanged either way. Additive only.
  final FocusNode? focusNode;
  final bool enabled;
  final bool isRecording;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final VoidCallback onAttach;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? pendingFilename;
  final VoidCallback? onRemovePending;

  /// Label of the currently active model, shown in the pill.
  final String modelLabel;

  /// Opens the model selector sheet.
  final VoidCallback onModelTap;

  const GlassInputBar({
    super.key,
    required this.textController,
    this.focusNode,
    this.enabled = true,
    required this.isRecording,
    required this.hasText,
    required this.onSend,
    required this.onMicTap,
    required this.onAttach,
    required this.modelLabel,
    required this.onModelTap,
    this.onChanged,
    this.onSubmitted,
    this.pendingFilename,
    this.onRemovePending,
  });

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final glassFill = palette.surface.withValues(
      alpha: palette.isDark ? 0.55 : 0.70,
    );
    final borderColor = palette.accent.withValues(
      alpha: palette.isDark ? 0.20 : 0.30,
    );
    final radius = BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: glassFill,
            borderRadius: radius,
            border: Border.all(color: borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: palette.isDark ? 0.35 : 0.08,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pending attachment chip — animates in/out of the layout.
              AnimatedSize(
                duration: _kBarAnimDuration,
                curve: _kBarAnimCurve,
                alignment: Alignment.topCenter,
                child: pendingFilename == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _PendingFileChip(
                            filename: pendingFilename!,
                            onRemove: onRemovePending,
                          ),
                        ),
                      ),
              ),
              // Row 1 — text field. AnimatedSize smooths the height change
              // as the text wraps onto new lines (up to 5, then it scrolls
              // internally).
              AnimatedSize(
                duration: _kBarAnimDuration,
                curve: _kBarAnimCurve,
                alignment: Alignment.topCenter,
                child: TextField(
                  controller: textController,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  enabled: enabled,
                  onChanged: onChanged,
                  onSubmitted: enabled ? onSubmitted : null,
                  cursorColor: palette.accent,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    hintText: strings.messageHint,
                    hintStyle: TextStyle(
                      color: palette.textMuted,
                      fontSize: 15,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Row 2 — attach + model pill on the left, mic + send on the
              // right.
              Row(
                children: [
                  _GlassIconButton(
                    icon: Icons.add_rounded,
                    onTap: onAttach,
                    tooltip: strings.attachFile,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _ModelPill(label: modelLabel, onTap: onModelTap),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _GlassMicButton(
                    isRecording: isRecording,
                    enabled: enabled,
                    onTap: onMicTap,
                  ),
                  const SizedBox(width: 6),
                  _GlassSendButton(active: enabled && hasText, onTap: onSend),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill showing the currently active model. Tapping it opens the model
/// selector sheet; the label cross-fades when the selection changes.
class _ModelPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ModelPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return PressableScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: _kBarAnimDuration,
            curve: _kBarAnimCurve,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: palette.accent.withValues(alpha: 0.28),
                width: 0.7,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: palette.accent,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: _kBarAnimDuration,
                    switchInCurve: _kBarAnimCurve,
                    switchOutCurve: MotionCurves.exit,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, ?current],
                    ),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: palette.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: palette.accent.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingFileChip extends StatelessWidget {
  final String filename;
  final VoidCallback? onRemove;
  const _PendingFileChip({required this.filename, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.35),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file_rounded, size: 16, color: palette.accent),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: palette.textPrimary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final btn = InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 20, color: palette.textMuted),
      ),
    );
    return PressableScale(
      child: tooltip == null ? btn : Tooltip(message: tooltip!, child: btn),
    );
  }
}

class _GlassMicButton extends StatefulWidget {
  final bool isRecording;
  final bool enabled;
  final VoidCallback onTap;
  const _GlassMicButton({
    required this.isRecording,
    this.enabled = true,
    required this.onTap,
  });

  @override
  State<_GlassMicButton> createState() => _GlassMicButtonState();
}

class _GlassMicButtonState extends State<_GlassMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: MotionDurations.pulse);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.reduced(context);
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _GlassMicButton old) {
    super.didUpdateWidget(old);
    if (widget.isRecording != old.isRecording) _syncPulse();
  }

  /// Run the recording-glow pulse only while recording and motion is allowed.
  /// Under reduced motion, hold a steady (non-pulsing) glow so the recording
  /// state is still visible without continuous animation.
  void _syncPulse() {
    if (widget.isRecording && !_reduced) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = (widget.isRecording && _reduced) ? 0.5 : 0.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    // Glyph swaps instantly between mic and stop — no cross-fade — so toggling
    // recording paints the new icon/color immediately. Built once and threaded
    // through AnimatedBuilder's `child` so the pulse only repaints the glow.
    final glyph = Icon(
      widget.isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
      size: 20,
      color: widget.isRecording ? palette.accent : palette.textMuted,
    );
    return PressableScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: _pulse,
          child: glyph,
          builder: (context, child) {
            final glow = widget.isRecording ? 0.3 + 0.4 * _pulse.value : 0.0;
            // Plain Container: the fill colour is chosen directly from
            // isRecording, so the grey ↔ accent change paints immediately (no
            // morph). Only the recording glow keeps pulsing.
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isRecording
                    ? palette.accent.withValues(alpha: 0.18)
                    : Colors.transparent,
                boxShadow: widget.isRecording
                    ? [
                        BoxShadow(
                          color: palette.accent.withValues(alpha: glow),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _GlassSendButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _GlassSendButton({required this.active, required this.onTap});

  /// Rounded-square corner radius — a soft square rather than a full circle.
  static final BorderRadius _shape = BorderRadius.circular(14);

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    // Plain Container: the fill colour is chosen directly from `active`, so the
    // button goes accent ↔ grey instantly (no morph) when text is typed or
    // cleared / the message is sent. Rounded-square shape (radius 14) unchanged.
    final btn = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: active ? palette.accent : palette.border.withValues(alpha: 0.4),
        borderRadius: _shape,
        boxShadow: active
            ? [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: _shape,
        onTap: active ? onTap : null,
        child: Center(
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 20,
            color: active
                ? (palette.isDark ? palette.background : Colors.white)
                : palette.textMuted,
          ),
        ),
      ),
    );
    // Always wrap (stable identity) but only respond to presses while active —
    // a disabled send button shouldn't squeeze, and toggling active mustn't
    // tear down the press controller mid-tap.
    return PressableScale(enabled: active, child: btn);
  }
}

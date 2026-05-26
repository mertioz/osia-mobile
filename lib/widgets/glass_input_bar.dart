import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme.dart';

/// Floating glassmorphism input bar pinned to the bottom of the chat.
///
/// Layout: `[+]  text field  [mic]  [send]`. Recording state morphs the
/// mic into a stop control. The whole bar is a blurred translucent
/// rounded rectangle so the chat content shows faintly underneath.
class GlassInputBar extends StatelessWidget {
  final TextEditingController textController;
  final bool isRecording;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final VoidCallback onAttach;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const GlassInputBar({
    super.key,
    required this.textController,
    required this.isRecording,
    required this.hasText,
    required this.onSend,
    required this.onMicTap,
    required this.onAttach,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final glassFill =
        palette.surface.withValues(alpha: palette.isDark ? 0.55 : 0.70);
    final borderColor =
        palette.accent.withValues(alpha: palette.isDark ? 0.20 : 0.30);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: glassFill,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: palette.isDark ? 0.35 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _GlassIconButton(
                icon: Icons.add_rounded,
                onTap: onAttach,
                tooltip: 'Joindre un fichier',
              ),
              const SizedBox(width: 2),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    maxHeight: 140,
                  ),
                  child: TextField(
                    controller: textController,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.send,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    cursorColor: palette.accent,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 15,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 12),
                      hintText: 'Écrivez votre message…',
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
              ),
              const SizedBox(width: 4),
              _GlassMicButton(
                isRecording: isRecording,
                onTap: onMicTap,
              ),
              const SizedBox(width: 6),
              _GlassSendButton(
                active: hasText,
                onTap: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _GlassIconButton(
      {required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final btn = InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          icon,
          size: 20,
          color: palette.textMuted,
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class _GlassMicButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;
  const _GlassMicButton({required this.isRecording, required this.onTap});

  @override
  State<_GlassMicButton> createState() => _GlassMicButtonState();
}

class _GlassMicButtonState extends State<_GlassMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isRecording) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _GlassMicButton old) {
    super.didUpdateWidget(old);
    if (widget.isRecording && !old.isRecording) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isRecording && old.isRecording) {
      _pulse.stop();
      _pulse.value = 0;
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glow = widget.isRecording ? 0.3 + 0.4 * _pulse.value : 0.0;
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
            child: Icon(
              widget.isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
              size: 20,
              color: widget.isRecording ? palette.accent : palette.textMuted,
            ),
          );
        },
      ),
    );
  }
}

class _GlassSendButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _GlassSendButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? palette.accent : palette.border.withValues(alpha: 0.4),
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
        borderRadius: BorderRadius.circular(20),
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
  }
}

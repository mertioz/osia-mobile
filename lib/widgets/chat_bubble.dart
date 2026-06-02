import 'dart:async';

import 'package:flutter/material.dart';
import '../theme.dart';

/// A chat bubble for displaying messages in the conversation.
///
/// User messages are aligned to the right with a subtle accent tint.
/// Assistant messages are aligned to the left and have no fill — they read
/// more like the assistant simply speaking onto the canvas. When
/// [isStreaming] is true, a blinking cursor signals that more content is
/// still arriving.
class ChatBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isTranscript;
  final bool isStreaming;
  final bool isSystem;

  const ChatBubble({
    super.key,
    required this.text,
    this.isUser = false,
    this.isTranscript = false,
    this.isStreaming = false,
    this.isSystem = false,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appearCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    // Same rhythm as the input bar's implicit animations: 250 ms,
    // easeOutCubic, for a consistent feel across the whole chat.
    _appearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _appearCtrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _appearCtrl, curve: Curves.easeOutCubic));
    _appearCtrl.forward();
  }

  @override
  void dispose() {
    _appearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);

    if (widget.isSystem) {
      return FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.border.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: palette.textMuted.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final alignment =
        widget.isUser ? Alignment.centerRight : Alignment.centerLeft;

    final textStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: palette.textPrimary,
      height: 1.45,
    );

    final Widget content = widget.isStreaming
        ? Text.rich(
            TextSpan(
              children: [
                TextSpan(text: widget.text),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _BlinkingCursor(color: palette.accent),
                ),
              ],
            ),
            style: textStyle,
          )
        : Text(widget.text, style: textStyle);

    final bubble = widget.isUser
        ? _userBubble(palette, content)
        : _assistantBubble(palette, content);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Align(
          alignment: alignment,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: bubble,
          ),
        ),
      ),
    );
  }

  Widget _userBubble(OsiaPalette palette, Widget content) {
    // Accent-tinted rounded card: the palette bubble base blended with a
    // soft wash of the accent color so the tint follows the active theme.
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          palette.accent.withValues(alpha: 0.10),
          palette.userBubble,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(6),
        ),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.22),
          width: 0.6,
        ),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: content,
    );
  }

  Widget _assistantBubble(OsiaPalette palette, Widget content) {
    // Assistant message reads as clean text on canvas with a subtle accent
    // bar on the left — no heavy bubble — so streaming output feels like a
    // stream of thought rather than a card animating in.
    return Container(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 10),
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 2, vertical: 4),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small accent-colored vertical bar that toggles visibility every 500 ms.
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      child: Container(
        width: 6,
        height: 15,
        margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}

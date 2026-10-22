import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n.dart';
import '../motion.dart';
import '../theme.dart';
import '../content_report_strings.dart';

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

  /// Called when the user taps the speaker button under an assistant
  /// message — asks the PC to read this message aloud. The button is only
  /// shown when this is non-null (i.e. on completed assistant bubbles).
  final VoidCallback? onSpeak;
  final VoidCallback? onReport;

  /// Optional widget rendered inline at the very end of the streaming text
  /// (after the blinking cursor) — e.g. a mid-stream thinking indicator.
  /// Only used while [isStreaming] is true; ignored otherwise. Non-breaking:
  /// existing call sites that omit it keep their current behaviour.
  final Widget? inlineTrailing;

  const ChatBubble({
    super.key,
    required this.text,
    this.isUser = false,
    this.isTranscript = false,
    this.isStreaming = false,
    this.isSystem = false,
    this.onSpeak,
    this.onReport,
    this.inlineTrailing,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appearCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _appeared = false;

  @override
  void initState() {
    super.initState();
    // Shared app rhythm (MotionDurations.medium) so bubbles land in step with
    // the input bar and the rest of the chat. The fade rides [enter] (opacity
    // must stay in [0,1]); the slide-up rides the light [spring] so the bubble
    // settles with a hair of expressive lift instead of a flat stop.
    _appearCtrl = AnimationController(
      vsync: this,
      duration: MotionDurations.medium,
    );
    _fade = CurvedAnimation(parent: _appearCtrl, curve: MotionCurves.enter);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _appearCtrl, curve: MotionCurves.spring));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appeared) return;
    _appeared = true;
    // Reduced motion: skip the slide/fade and show the bubble immediately.
    if (Motion.reduced(context)) {
      _appearCtrl.value = 1.0;
    } else {
      _appearCtrl.forward();
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.border.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: SelectionArea(
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
        ),
      );
    }

    final alignment = widget.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;

    final textStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: palette.textPrimary,
      height: 1.45,
    );

    final Widget content = widget.isUser
        ? SelectionArea(child: Text(widget.text, style: textStyle))
        : _SafeMarkdownText(
            text: widget.text,
            style: textStyle,
            accent: palette.accent,
            codeBackground: palette.surfaceElevated,
            isStreaming: widget.isStreaming,
            inlineTrailing: widget.inlineTrailing,
          );

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: content,
    );
  }

  Widget _assistantBubble(OsiaPalette palette, Widget content) {
    // Assistant message reads as clean text on canvas with a subtle accent
    // bar on the left — no heavy bubble — so streaming output feels like a
    // stream of thought rather than a card animating in.
    // The speaker button only appears once the message is complete, so it
    // never sends a half-streamed text to the PC for TTS.
    final showSpeak = widget.onSpeak != null && !widget.isStreaming;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: content,
                ),
                if (showSpeak ||
                    (widget.onReport != null && !widget.isStreaming))
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showSpeak) _SpeakButton(onTap: widget.onSpeak!),
                      if (widget.onReport != null && !widget.isStreaming)
                        IconButton(
                          tooltip: OsiaL10n.of(context).reportContent,
                          icon: Icon(
                            Icons.flag_outlined,
                            size: 18,
                            color: palette.textMuted,
                          ),
                          onPressed: widget.onReport,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Conservative Markdown renderer for message text. It recognizes only fully
/// closed code fences, inline code, bold text, and safe HTTP(S) links. Partial
/// streaming delimiters remain literal until their closing delimiter arrives,
/// so no text disappears or jumps into an unsafe widget tree mid-stream.
class _SafeMarkdownText extends StatefulWidget {
  const _SafeMarkdownText({
    required this.text,
    required this.style,
    required this.accent,
    required this.codeBackground,
    required this.isStreaming,
    this.inlineTrailing,
  });

  final String text;
  final TextStyle style;
  final Color accent;
  final Color codeBackground;
  final bool isStreaming;
  final Widget? inlineTrailing;

  @override
  State<_SafeMarkdownText> createState() => _SafeMarkdownTextState();
}

class _SafeMarkdownTextState extends State<_SafeMarkdownText> {
  final List<TapGestureRecognizer> _linkRecognizers = <TapGestureRecognizer>[];

  static final RegExp _fencedCode = RegExp(
    r'```[^\n]*\n(.*?)```',
    dotAll: true,
  );
  static final RegExp _inlineMarkdown = RegExp(
    r'(\*\*[^*\n]+\*\*|`[^`\n]+`|\[[^\]\n]+\]\(https?://[^\s)]+\))',
    caseSensitive: false,
  );
  static final RegExp _safeLink = RegExp(
    r'^\[([^\]\n]+)\]\((https?://[^\s)]+)\)$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _linkRecognizers) {
      recognizer.dispose();
    }
    _linkRecognizers.clear();
  }

  Future<void> _openLink(String raw) async {
    final uri = Uri.tryParse(raw);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    if (uri == null || (scheme != 'http' && scheme != 'https')) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Keep link-launch failures local to the message surface.
    }
  }

  List<InlineSpan> _inlineSpans(String source) {
    if (source.contains('```')) return <InlineSpan>[TextSpan(text: source)];
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inlineMarkdown.allMatches(source)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: source.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('`') && token.endsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: widget.codeBackground,
            ),
          ),
        );
      } else {
        final link = _safeLink.firstMatch(token);
        if (link == null) {
          spans.add(TextSpan(text: token));
        } else {
          final url = link.group(2)!;
          final recognizer = TapGestureRecognizer()
            ..onTap = () => _openLink(url);
          _linkRecognizers.add(recognizer);
          spans.add(
            TextSpan(
              text: link.group(1),
              style: TextStyle(
                color: widget.accent,
                decoration: TextDecoration.underline,
                decorationColor: widget.accent,
              ),
              recognizer: recognizer,
            ),
          );
        }
      }
      cursor = match.end;
    }
    if (cursor < source.length) {
      spans.add(TextSpan(text: source.substring(cursor)));
    }
    return spans;
  }

  List<InlineSpan> _markdownSpans() {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _fencedCode.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.addAll(_inlineSpans(widget.text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: widget.codeBackground,
            height: 1.35,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.addAll(_inlineSpans(widget.text.substring(cursor)));
    }
    if (widget.isStreaming) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _BlinkingCursor(color: widget.accent),
        ),
      );
      if (widget.inlineTrailing != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: widget.inlineTrailing!,
          ),
        );
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    if (!widget.isStreaming) {
      // PC renders completed answers as GitHub Markdown with HTML disabled.
      // Keep the exact stored message; only its native presentation changes.
      final heading = widget.style.copyWith(fontWeight: FontWeight.w600);
      return SelectionArea(
        child: MarkdownBody(
          data: widget.text,
          onTapLink: (_, href, _) {
            if (href != null) _openLink(href);
          },
          imageBuilder: (uri, title, alt) {
            // PC-local paths cannot address phone files. Only public HTTP(S)
            // images can be rendered here; attachments use canonical uploads.
            if (uri.scheme != 'http' && uri.scheme != 'https') {
              return Text(alt ?? '', style: widget.style);
            }
            return Image.network(
              uri.toString(),
              semanticLabel: alt,
              errorBuilder: (_, _, _) => Text(alt ?? '', style: widget.style),
            );
          },
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: widget.style,
            h1: heading.copyWith(fontSize: 23),
            h2: heading.copyWith(fontSize: 21),
            h3: heading.copyWith(fontSize: 19),
            h4: heading.copyWith(fontSize: 17),
            h5: heading.copyWith(fontSize: 16),
            h6: heading,
            listBullet: widget.style,
            blockquote: widget.style,
            tableBody: widget.style,
            tableHead: heading,
            a: widget.style.copyWith(
              color: widget.accent,
              decoration: TextDecoration.underline,
            ),
            code: widget.style.copyWith(
              fontFamily: 'monospace',
              backgroundColor: widget.codeBackground,
            ),
            codeblockDecoration: BoxDecoration(
              color: widget.codeBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: widget.accent, width: 2)),
            ),
            tableBorder: TableBorder.all(
              color: widget.accent.withValues(alpha: 0.2),
            ),
            blockSpacing: 8,
          ),
        ),
      );
    }
    return SelectionArea(
      child: Text.rich(
        TextSpan(children: _markdownSpans()),
        style: widget.style,
      ),
    );
  }
}

/// Small speaker button under an assistant message — asks the PC to read
/// that message aloud over TTS. Deliberately subtle: a bare accent icon,
/// no fill, no border.
class _SpeakButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SpeakButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = OsiaTheme.of(context).accent;
    return Tooltip(
      message: OsiaL10n.of(context).readAloud,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.volume_up_rounded, size: 16, color: accent),
        ),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-sync on dependency changes so a runtime reduced-motion toggle is
    // honored: hold the cursor steady (no flashing) when reduced, else blink.
    if (Motion.reduced(context)) {
      _timer?.cancel();
      _timer = null;
      _visible = true;
    } else {
      _timer ??= Timer.periodic(MotionDurations.cursorBlink, (_) {
        if (mounted) setState(() => _visible = !_visible);
      });
    }
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
      duration: MotionDurations.fast,
      curve: MotionCurves.enter,
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

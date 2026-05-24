import 'package:flutter/material.dart';
import '../theme.dart';

/// A chat bubble for displaying messages in the conversation.
///
/// User messages are aligned to the right with a violet-tinted bubble.
/// OSIA responses are aligned to the left with a darker glassmorphism bubble.
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isTranscript;

  const ChatBubble({
    super.key,
    required this.text,
    this.isUser = false,
    this.isTranscript = false,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? osiaUserBubble : osiaAssistantBubble;
    final borderColor = isUser ? osiaViolet.withValues(alpha: 0.4) : osiaBorder;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: Border.all(
            color: borderColor,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: osiaViolet.withValues(alpha: isUser ? 0.08 : 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Text(
              isTranscript ? 'Vous (transcrit)' : (isUser ? 'Vous' : 'OSIA'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isUser ? osiaAccent.withValues(alpha: 0.8) : osiaTextMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            // Content
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: osiaTextPrimary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

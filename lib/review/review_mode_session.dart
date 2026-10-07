import '../l10n.dart';

enum ReviewMessageRole { user, assistant }

enum ReviewCapability {
  pcControl,
  providerRequest,
  attachment,
  microphone,
  textToSpeech,
  mcp,
  oauth,
  externalAction,
  deleteData,
  purchase,
  fullAccess,
}

enum ReviewCapabilityResult { unavailable }

class ReviewMessage {
  const ReviewMessage({required this.role, required this.text});

  final ReviewMessageRole role;
  final String text;
}

class ReviewConversation {
  const ReviewConversation({
    required this.id,
    required this.title,
    required this.messages,
  });

  final String id;
  final String title;
  final List<ReviewMessage> messages;
}

/// Ephemeral, deterministic reviewer data. This class has no storage,
/// transport, provider, file, or integration dependencies by design.
class ReviewModeSession {
  ReviewModeSession({required OsiaStrings strings})
    : _conversations = <ReviewConversation>[
        ReviewConversation(
          id: 'review-welcome',
          title: strings.reviewModeWelcome,
          messages: <ReviewMessage>[
            ReviewMessage(
              role: ReviewMessageRole.user,
              text: strings.reviewModeSampleQuestion,
            ),
            ReviewMessage(
              role: ReviewMessageRole.assistant,
              text: strings.reviewModeSampleAnswer,
            ),
          ],
        ),
        ReviewConversation(
          id: 'review-walk',
          title: strings.reviewModeSecondConversation,
          messages: <ReviewMessage>[
            ReviewMessage(
              role: ReviewMessageRole.user,
              text: strings.reviewModePlanQuestion,
            ),
            ReviewMessage(
              role: ReviewMessageRole.assistant,
              text: strings.reviewModePlanAnswer,
            ),
          ],
        ),
      ];

  final List<ReviewConversation> _conversations;
  String _activeConversationId = 'review-welcome';
  int _newConversationNumber = 0;
  bool _active = true;

  bool get isActive => _active;

  List<ReviewConversation> get conversations =>
      List<ReviewConversation>.unmodifiable(_conversations);

  ReviewConversation get activeConversation => _conversations.firstWhere(
    (conversation) => conversation.id == _activeConversationId,
  );

  List<ReviewMessage> get activeMessages =>
      List<ReviewMessage>.unmodifiable(activeConversation.messages);

  void selectConversation(String id) {
    if (!_active) return;
    if (_conversations.any((conversation) => conversation.id == id)) {
      _activeConversationId = id;
    }
  }

  void createConversation({required String title}) {
    if (!_active) return;
    _newConversationNumber++;
    final conversation = ReviewConversation(
      id: 'review-new-$_newConversationNumber',
      title: title,
      messages: <ReviewMessage>[],
    );
    _conversations.insert(0, conversation);
    _activeConversationId = conversation.id;
  }

  void sendLocalMessage(String text, {required String response}) {
    if (!_active || text.trim().isEmpty) return;
    final messages = activeConversation.messages;
    messages
      ..add(ReviewMessage(role: ReviewMessageRole.user, text: text.trim()))
      ..add(ReviewMessage(role: ReviewMessageRole.assistant, text: response));
  }

  /// Every capability that could reach a PC, provider, account, integration,
  /// personal file, or external system is unconditionally blocked in review.
  ReviewCapabilityResult tryCapability(ReviewCapability capability) =>
      ReviewCapabilityResult.unavailable;

  void dispose() {
    _active = false;
    _conversations.clear();
  }
}

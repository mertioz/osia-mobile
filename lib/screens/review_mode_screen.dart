import 'package:flutter/material.dart';

import '../l10n.dart';
import '../review/review_mode_session.dart';
import '../theme.dart';
import '../widgets/accent_logo.dart';
import 'legal_screen.dart';

enum _ReviewPage { chat, conversations, models, settings }

class _ReviewModelOption {
  const _ReviewModelOption({
    required this.id,
    required this.name,
    required this.provider,
  });

  final String id;
  final String name;
  final String provider;
}

const List<_ReviewModelOption> _reviewModels = <_ReviewModelOption>[
  _ReviewModelOption(
    id: 'sample-balanced',
    name: 'Sample Balanced',
    provider: 'OSIA demo provider',
  ),
  _ReviewModelOption(
    id: 'sample-fast',
    name: 'Sample Fast',
    provider: 'OSIA demo provider',
  ),
  _ReviewModelOption(
    id: 'sample-local',
    name: 'Sample Local',
    provider: 'On-device preview',
  ),
];

/// Local-only app preview. This screen intentionally has no storage, session,
/// transport, provider, file-picker, audio, OAuth, or MCP dependency.
class ReviewModeScreen extends StatefulWidget {
  const ReviewModeScreen({super.key});

  @override
  State<ReviewModeScreen> createState() => _ReviewModeScreenState();
}

class _ReviewModeScreenState extends State<ReviewModeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _messageController = TextEditingController();
  ReviewModeSession? _session;
  OsiaPalette? _palette;
  String? _languageCode;
  String _selectedModel = _reviewModels.first.id;
  _ReviewPage _page = _ReviewPage.chat;
  bool _autoRead = false;

  ReviewModeSession get _reviewSession => _session!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _palette ??= OsiaTheme.of(context);
    _languageCode ??= OsiaL10n.of(context).languageCode;
    _session ??= ReviewModeSession(strings: osiaStringsForCode(_languageCode));
  }

  @override
  void dispose() {
    _reviewSession.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette ?? osiaPaletteViolet;
    final strings = osiaStringsForCode(_languageCode);
    return Theme(
      data: buildOsiaTheme(palette),
      child: OsiaTheme(
        palette: palette,
        child: OsiaL10n(
          strings: strings,
          child: Builder(
            builder: (context) {
              return Scaffold(
                key: _scaffoldKey,
                backgroundColor: palette.background,
                appBar: AppBar(
                  backgroundColor: palette.background,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    key: const Key('review-navigation-button'),
                    tooltip: strings.reviewModeLabel,
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.menu_rounded),
                  ),
                  titleSpacing: 0,
                  title: Text(
                    'OSIA',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  actions: [
                    IconButton(
                      key: const Key('review-model-shortcut'),
                      tooltip: strings.model,
                      onPressed: () => _setPage(_ReviewPage.models),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                    IconButton(
                      key: const Key('review-exit-button'),
                      tooltip: strings.reviewModeExit,
                      onPressed: _exitReviewMode,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                drawer: _buildDrawer(context, palette, strings),
                body: Column(
                  children: [
                    _buildReviewIndicator(palette, strings),
                    Expanded(child: _buildPage(context, palette, strings)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReviewIndicator(OsiaPalette palette, OsiaStrings strings) {
    return Container(
      key: const Key('review-mode-indicator'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: palette.accent.withValues(alpha: 0.09),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: palette.accent),
          const SizedBox(width: 8),
          Text(
            strings.reviewModeLabel,
            style: TextStyle(
              color: palette.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.reviewModeDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textMuted, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    OsiaPalette palette,
    OsiaStrings strings,
  ) {
    return Drawer(
      backgroundColor: palette.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  const AccentLogo(width: 34, height: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OSIA',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          strings.reviewModeLabel,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(
                    key: const Key('review-nav-chat'),
                    icon: Icons.chat_bubble_outline_rounded,
                    title: strings.newChat,
                    selected: _page == _ReviewPage.chat,
                    palette: palette,
                    onTap: () => _setPage(_ReviewPage.chat),
                  ),
                  _drawerItem(
                    key: const Key('review-nav-conversations'),
                    icon: Icons.forum_outlined,
                    title: strings.conversations,
                    selected: _page == _ReviewPage.conversations,
                    palette: palette,
                    onTap: () => _setPage(_ReviewPage.conversations),
                  ),
                  _drawerItem(
                    key: const Key('review-nav-models'),
                    icon: Icons.tune_rounded,
                    title: strings.model,
                    selected: _page == _ReviewPage.models,
                    palette: palette,
                    onTap: () => _setPage(_ReviewPage.models),
                  ),
                  _drawerItem(
                    key: const Key('review-nav-settings'),
                    icon: Icons.settings_outlined,
                    title: strings.settingsTitle,
                    selected: _page == _ReviewPage.settings,
                    palette: palette,
                    onTap: () => _setPage(_ReviewPage.settings),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('review-drawer-exit'),
              leading: Icon(
                Icons.exit_to_app_rounded,
                color: palette.textMuted,
              ),
              title: Text(strings.reviewModeExit),
              onTap: _exitReviewMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required Key key,
    required IconData icon,
    required String title,
    required bool selected,
    required OsiaPalette palette,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      leading: Icon(icon, color: selected ? palette.accent : palette.textMuted),
      title: Text(title),
      selected: selected,
      selectedTileColor: palette.accent.withValues(alpha: 0.08),
      onTap: onTap,
    );
  }

  Widget _buildPage(
    BuildContext context,
    OsiaPalette palette,
    OsiaStrings strings,
  ) {
    return switch (_page) {
      _ReviewPage.chat => _buildChat(context, palette, strings),
      _ReviewPage.conversations => _buildConversations(palette, strings),
      _ReviewPage.models => _buildModels(palette, strings),
      _ReviewPage.settings => _buildSettings(context, palette, strings),
    };
  }

  Widget _buildChat(
    BuildContext context,
    OsiaPalette palette,
    OsiaStrings strings,
  ) {
    final conversation = _reviewSession.activeConversation;
    final messages = _reviewSession.activeMessages;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      strings.reviewModeDemoData,
                      style: TextStyle(color: palette.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('review-pc-action'),
                tooltip: strings.reviewModeConnectionStatus,
                onPressed: () => _showUnavailable(ReviewCapability.pcControl),
                icon: Icon(Icons.computer_rounded, color: palette.textMuted),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            key: const Key('review-chat-messages'),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            children: [
              for (final message in messages)
                _buildMessage(message, palette, strings),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('review-attachment-button'),
                  tooltip: strings.attachFile,
                  onPressed: () =>
                      _showUnavailable(ReviewCapability.attachment),
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('review-message-field'),
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendLocalMessage(strings),
                    decoration: InputDecoration(
                      hintText: strings.reviewModeInputHint,
                      filled: true,
                      fillColor: palette.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: palette.border),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('review-microphone-button'),
                  tooltip: strings.micUnavailable,
                  onPressed: () =>
                      _showUnavailable(ReviewCapability.microphone),
                  icon: const Icon(Icons.mic_none_rounded),
                ),
                IconButton(
                  key: const Key('review-send-button'),
                  tooltip: strings.reviewModeSendMessage,
                  onPressed: () => _sendLocalMessage(strings),
                  icon: Icon(Icons.arrow_upward_rounded, color: palette.accent),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(
    ReviewMessage message,
    OsiaPalette palette,
    OsiaStrings strings,
  ) {
    final isUser = message.role == ReviewMessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 11, 10, 9),
          decoration: BoxDecoration(
            color: isUser ? palette.userBubble : palette.assistantBubble,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border.withValues(alpha: 0.65)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    strings.reviewModeDemoData,
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(message.text, style: TextStyle(color: palette.textPrimary)),
              if (!isUser)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: strings.readAloud,
                    onPressed: () =>
                        _showUnavailable(ReviewCapability.textToSpeech),
                    icon: Icon(
                      Icons.volume_up_outlined,
                      size: 18,
                      color: palette.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversations(OsiaPalette palette, OsiaStrings strings) {
    final conversations = _reviewSession.conversations;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  strings.conversations,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const Key('review-new-conversation-button'),
                tooltip: strings.newChat,
                onPressed: () {
                  _reviewSession.createConversation(title: strings.newChat);
                  _setPage(_ReviewPage.chat);
                },
                icon: Icon(Icons.add_rounded, color: palette.accent),
              ),
            ],
          ),
        ),
        for (final conversation in conversations)
          Card(
            color: palette.surface,
            child: ListTile(
              key: Key('review-conversation-${conversation.id}'),
              leading: CircleAvatar(
                backgroundColor: palette.accent.withValues(alpha: 0.12),
                child: Icon(Icons.chat_bubble_outline, color: palette.accent),
              ),
              title: Text(conversation.title),
              subtitle: Text(
                conversation.messages.isEmpty
                    ? strings.reviewModeDemoData
                    : conversation.messages.last.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                strings.reviewModeDemoData,
                style: TextStyle(color: palette.textMuted, fontSize: 10),
              ),
              onTap: () {
                _reviewSession.selectConversation(conversation.id);
                _setPage(_ReviewPage.chat);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildModels(OsiaPalette palette, OsiaStrings strings) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Text(strings.model, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          strings.reviewModeDescription,
          style: TextStyle(color: palette.textMuted),
        ),
        const SizedBox(height: 16),
        for (final model in _reviewModels)
          Card(
            color: palette.surface,
            child: ListTile(
              key: Key('review-model-option-${model.id}'),
              leading: Icon(
                model.id == _selectedModel
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: model.id == _selectedModel
                    ? palette.accent
                    : palette.textMuted,
              ),
              title: Text(model.name),
              subtitle: Text(model.provider),
              onTap: () => setState(() => _selectedModel = model.id),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          strings.reviewModeDemoData,
          style: TextStyle(color: palette.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSettings(
    BuildContext context,
    OsiaPalette palette,
    OsiaStrings strings,
  ) {
    return ListView(
      key: const Key('review-settings-screen'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        Text(
          strings.settingsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          strings.reviewModeDescription,
          style: TextStyle(color: palette.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Text(
          strings.appearance,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(strings.colorTheme, style: TextStyle(color: palette.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in osiaPalettes)
              ChoiceChip(
                key: Key('review-theme-${option.key}'),
                avatar: CircleAvatar(backgroundColor: option.swatch),
                label: Text(option.label),
                selected: option.key == palette.key,
                onSelected: (_) => setState(() => _palette = option),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Text(strings.language)),
            DropdownButton<String>(
              key: const Key('review-language-selector'),
              value: _languageCode,
              items: [
                for (final code in osiaSupportedLanguages)
                  DropdownMenuItem<String>(
                    value: code,
                    child: Text(osiaStringsForCode(code).languageName),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _languageCode = value);
              },
            ),
          ],
        ),
        const Divider(height: 28),
        Text(
          strings.voiceSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SwitchListTile(
          key: const Key('review-auto-tts-toggle'),
          contentPadding: EdgeInsets.zero,
          title: Text(strings.autoReadResponses),
          subtitle: Text(strings.reviewModeUnavailable),
          value: _autoRead,
          onChanged: (value) => setState(() => _autoRead = value),
        ),
        const Divider(height: 28),
        Text(
          strings.providersTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.smart_toy_outlined, color: palette.textMuted),
          title: const Text('OSIA demo provider'),
          subtitle: Text(strings.reviewModeDemoData),
        ),
        ListTile(
          key: const Key('review-provider-settings-blocked'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline_rounded, color: palette.textMuted),
          title: Text(strings.liveApi),
          subtitle: Text(strings.reviewModeUnavailable),
          onTap: () => _showUnavailable(ReviewCapability.providerRequest),
        ),
        const Divider(height: 28),
        Text(strings.legal, style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          key: const Key('review-terms-link'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.description_outlined, color: palette.textMuted),
          title: Text(strings.termsOfService),
          onTap: () => _openLegal(LegalDocument.termsOfService),
        ),
        ListTile(
          key: const Key('review-privacy-link'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.privacy_tip_outlined, color: palette.textMuted),
          title: Text(strings.privacyPolicy),
          onTap: () => _openLegal(LegalDocument.privacyPolicy),
        ),
        const Divider(height: 28),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cloud_off_outlined, color: palette.textMuted),
          title: Text(strings.connectionSection),
          subtitle: Text(strings.reviewModeConnectionStatus),
        ),
      ],
    );
  }

  void _setPage(_ReviewPage page) {
    _scaffoldKey.currentState?.closeDrawer();
    if (!mounted) return;
    setState(() => _page = page);
  }

  void _sendLocalMessage(OsiaStrings strings) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _reviewSession.sendLocalMessage(
      text,
      response: strings.reviewModeLocalReply,
    );
    _messageController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  void _showUnavailable(ReviewCapability capability) {
    if (_reviewSession.tryCapability(capability) !=
        ReviewCapabilityResult.unavailable) {
      return;
    }
    final strings = osiaStringsForCode(_languageCode);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(strings.reviewModeUnavailable)));
  }

  void _openLegal(LegalDocument document) {
    final palette = _palette ?? osiaPaletteViolet;
    final strings = osiaStringsForCode(_languageCode);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: buildOsiaTheme(palette),
          child: OsiaTheme(
            palette: palette,
            child: OsiaL10n(
              strings: strings,
              child: Scaffold(
                backgroundColor: palette.background,
                body: Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Container(
                        key: const Key('review-mode-legal-indicator'),
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
                        color: palette.accent.withValues(alpha: 0.09),
                        child: Text(
                          strings.reviewModeLabel,
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: LegalScreen(
                        document: document,
                        allowExternalLinks: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _exitReviewMode() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }
}

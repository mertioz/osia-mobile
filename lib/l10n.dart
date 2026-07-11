import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ── OSIA Localization ─────────────────────────────────────────────────────
//
// Lightweight, dependency-free string localization. Six languages are
// bundled (EN/FR/ZH/JA/DE/ES); the active one is held by
// [LanguageController] and exposed to widgets through [OsiaL10n.of].
//
// The pattern mirrors the theme system (OsiaPalette / ThemeController /
// OsiaTheme) so both "live preferences" behave identically.

/// Codes of all supported languages, in display order.
const List<String> osiaSupportedLanguages = [
  'en',
  'fr',
  'zh',
  'ja',
  'de',
  'es',
];

/// All UI strings for one language.
///
/// Parameterized strings are stored as templates with `{x}` placeholders
/// and exposed through helper methods so the class stays const-constructible.
class OsiaStrings {
  final String languageCode;

  /// Native name of the language, shown in the language selector.
  final String languageName;

  // ── Common ──
  final String cancel;
  final String delete;
  final String retry;
  final String save;
  final String rename;

  // ── Connection screen ──
  final String enterYourToken;
  final String connect;
  final String connectingEllipsis;
  final String tokenRequired;
  final String connectionFailed;
  final String invalidToken;
  final String tokenHint;
  final String pcOffline;

  // ── Chat screen ──
  final String conversations;
  final String newChat;
  final String noConversationsYet;
  final String sayHello;
  final String typeMessageOrMic;
  final String messageHint;
  final String deleteConversationTitle;
  final String deleteConversationBodyTemplate; // {title}
  final String renameConversationTitle;
  final String renameConversationHint;
  final String today;
  final String yesterday;
  final String daysAgoTemplate; // {n}
  final String untitled;
  final String connected;
  final String connectingStatus;
  final String disconnected;
  final String micPermissionDenied;
  final String micUnavailable;
  final String openSettingsAction;
  final String attachFile;
  final String filePickFailedTemplate; // {error}
  final String fileReadFailedTemplate; // {error}
  final String fileEmpty;
  final String analyzeImagePrompt;
  final String hereIsFileTemplate; // {name}
  final String model;
  final String settingsTooltip;
  final String noResponseError;
  final String relayChunkUnsupportedError;
  final String relayFrameTooLargeError;
  final String relayChunkTransferFailedError;
  final String relayE2eDecryptFailedError;
  final String relayUnreachableError;
  final String osiaWorkingBackground;
  final String scheduledTaskCompleted;
  final String scheduledTaskFailed;
  final String reminderNotification;
  final String taskCompleted;

  // ── Model selector ──
  final String availableModels;
  final String noModelsReceived;
  final String modelsLoadFailed;
  final String otherProviders;
  final String reasoning;
  final String reasoningDefault;
  final String reasoningOff;
  final String reasoningNormal;
  final String reasoningMax;
  final String reasoningMinimal;
  final String reasoningLow;
  final String reasoningMedium;
  final String reasoningHigh;
  final String reasoningXhigh;
  final String reasoningNotSupported;
  final String reasoningUseDefault;

  // ── Settings ──
  final String settingsTitle;
  final String appearance;
  final String colorTheme;
  final String language;
  final String legal;
  final String termsOfService;
  final String privacyPolicy;
  final String voiceSection;
  final String autoReadResponses;
  final String autoReadResponsesSubtitle;
  final String readAloud;
  final String connectionSection;
  final String restartServer;
  final String restartServerSubtitle;
  final String reconnecting;
  final String reconnected;
  final String serverRestarted;
  final String serverRestartFailed;
  final String disconnect;
  final String disconnectSubtitle;
  final String disconnectConfirmTitle;
  final String disconnectConfirmBody;
  final String makeDonation;
  final String linkOpenFailed;

  // ── Settings section subtitles (WOR-78) ──
  // Short subtitle (~6 words) shown under each settings section title.
  // Mirrors the PC settings copy. The longer 2-sentence descriptions were
  // moved out of the main settings screen to the provider config screens
  // (WOR-78 point 1).
  final String appearanceSub;
  final String languageSub;
  final String voiceSectionSub;
  final String providersSub;
  final String legalSub;
  final String connectionSectionSub;
  final String memoryTitle;
  final String localMemories;
  final String noMemoriesYet;
  final String refresh;
  final String clearAll;
  final String memorySaved;
  final String memoryDeleted;
  final String memoryCleared;
  final String memoryError;
  final String connectedRequired;
  final String memoryClearConfirm;
  final String memoryEditTitle;
  final String memoryNewTitle;
  final String memoryTitleField;
  final String memoryKeyField;
  final String memoryValueField;
  final String memoryTypeField;
  final String memoryCategoryField;
  final String memoryKindField;
  final String memoryRequiredFields;

  // ── APIs & Providers ──
  final String providersTitle;
  final String configureProviders;
  final String liveApi;
  final String liveApiNotice;
  final String comingSoon;
  final String notificationsSection;
  final String notificationsSectionSub;
  final String osiaNotifications;
  final String osiaNotificationsSubtitle;
  final String notificationPermissionDenied;
  final String backgroundConnection;
  final String backgroundConnectionSubtitle;
  final String backgroundConnectionUnavailable;
  final String catVoiceToVoice;
  final String catVoiceToVoiceSub;
  final String catAiProviders;
  final String catAiProvidersSub;
  final String catTtsProviders;
  final String catTtsProvidersSub;
  final String catSttProviders;
  final String catSttProvidersSub;
  // Config-screen 2-sentence descriptions shown at the top of each provider
  // config screen (WOR-78 point 1).
  final String liveapiDesc;
  final String aiProvidersDesc;
  final String voiceProvidersDesc;
  final String whisperProvidersDesc;
  final String personalityDesc;
  final String heartbeatDesc;
  final String apiKey;
  final String apiKeyHint;
  final String getApiKey;
  final String apiKeySaved;
  final String localProviderNoKey;
  final String localLabel;
  final String showApiKey;
  final String hideApiKey;
  final String apiKeyConfigured;
  final String apiKeyReplaceHint;
  final String removeApiKey;
  final String apiKeyRemoved;

  // ── API fallback keys (WOR-29) ──
  final String fallbackKeys;
  final String addFallbackKey;
  final String editFallbackKey;
  final String deleteFallbackKey;
  final String fallbackKeyIndex; // {n}

  // ── Vision companion model (WOR-25) ──
  final String visionAssociated;
  final String visionProvider;
  final String visionModel;
  final String visionHint;

  // ── TTS / STT selectors (WOR-78.2) ──
  final String ttsProviderLabel;
  final String ttsVoiceLabel;
  final String sttProviderLabel;
  final String ttsVoiceAutomatic;

  // ── Common (config sections) ──
  final String add;
  final String edit;
  final String close;
  final String loading;

  // ── New provider tiles ──
  final String catScheduledTasks;
  final String catScheduledTasksSub;
  final String catAiHierarchy;
  final String catAiHierarchySub;
  final String catPersonalitySkills;
  final String catPersonalitySkillsSub;

  // ── Scheduled tasks (cron) ──
  final String cronTitle;
  final String cronSubtitle;
  final String cronEmpty;
  final String cronAddTask;
  final String cronEditTask;
  final String cronTaskLabel;
  final String cronTaskHint;
  final String cronType;
  final String cronTypeRepeat;
  final String cronTypeOnce;
  final String cronFrequency;
  final String cronUnitMinutes;
  final String cronUnitHours;
  final String cronUnitDays;
  final String cronModeDaily;
  final String cronDate;
  final String cronTime;
  final String cronInvalid;
  final String cronModelDefault;
  final String cronModelInvalid;
  final String cronEveryMinutesTemplate; // {n}
  final String cronEveryHoursTemplate; // {n}
  final String cronEveryDaysTemplate; // {n}
  final String cronDailyAtTemplate; // {t}
  final String cronOnceTemplate; // {d} {t}
  final String cronLinkedConversation;
  final String cronNoConversation;
  final String cronLoadingConversations;

  // ── AI hierarchy ──
  final String hierarchyTitle;
  final String hierarchySubtitle;
  final String hierarchyEnable;
  final String hierarchyActive;
  final String hierarchyHeavy;
  final String hierarchyHeavySub;
  final String hierarchyMedium;
  final String hierarchyMediumSub;
  final String hierarchyAddModel;
  final String hierarchyEmpty;
  final String hierarchyNoProviders;
  final String moveUp;
  final String moveDown;

  // ── Personality & skills ──
  final String personalitySkillsTitle;
  final String tabPersonality;
  final String tabSkills;
  final String personalityHint;
  final String personalitySaved;
  final String skillsEmpty;
  final String skillAdd;
  final String skillNewTitle;
  final String skillNewHint;
  final String skillContentHint;
  final String skillSaved;
  final String skillDeleteTitle;
  final String skillDeleteBodyTemplate; // {name}

  // ── System status (heartbeat) ──
  final String catSystemStatus;
  final String catSystemStatusSub;
  final String heartbeatMonitoring;
  final String heartbeatInterval;
  final String heartbeatIntervalRange;
  final String heartbeatChecksHeader;
  final String heartbeatUsageThresholdHint;
  final String heartbeatDiskThresholdHint;
  final String heartbeatNetworkHint;
  final String heartbeatWaiting;
  final String systemMetricsHeader;
  final String metricCpu;
  final String metricRam;
  final String metricDisk;
  final String metricNetwork;
  final String metricCpuTemp;
  final String metricGpuTemp;

  // ── General / time format ──
  final String sectionGeneral;
  final String timeFormatLabel;

  // ── Autonomous runs (WOR-45) ──
  final String autonomousTitle;
  final String autonomousObjectiveLabel;
  final String autonomousObjectiveHint;
  final String autonomousPickModel;
  final String autonomousNoConfiguredModels;
  final String autonomousStart;
  final String autonomousPlanning;
  final String autonomousRunning;
  final String autonomousInterrupt;
  final String autonomousAbort;
  final String autonomousIdle;
  final String autonomousBusy;
  final String autonomousDone;
  final String autonomousFailed;
  final String autonomousAborted;
  final String autonomousInterrupted;
  final String autonomousResume;
  final String autonomousPhase;
  final String autonomousObjectiveRequired;
  final String autonomousModelRequired;
  final String autonomousTasksTemplate; // {done} {total}

  // ── MCP / Connectors (WOR-44 Phase 4) ──
  final String catConnectors;
  final String catConnectorsSub;
  final String connectorsDesc;
  final String connectorLabel;
  final String mcpConnect;
  final String mcpDisconnect;
  final String mcpSignOut;
  final String mcpSwitchAccount;
  final String mcpCancel;
  final String mcpOpeningBrowser;
  final String mcpStatusConnected;
  final String mcpStatusConnecting;
  final String mcpStatusDisconnected;
  final String mcpStatusFailed;
  final String mcpOauthSoon;
  final String mcpHttpSoon;
  final String mcpOauthConnectOnPc;
  final String mcpOauthConnectOnPcHint;
  final String mcpCopyToken;
  final String mcpTokenCopied;
  final String mcpTokenLabel;
  final String mcpTokenHint;
  final String mcpSlackTeam;
  final String mcpSlackTeamPh;
  final String mcpAddCustom;
  final String mcpRemove;
  final String mcpDescGithub;
  final String mcpDescSlack;
  final String mcpDescNotion;
  final String mcpDescLinear;
  final String mcpDescGdrive;
  final String mcpDescGmail;
  final String gmailRestName;
  final String gmailRestTitle;
  final String gmailRestConfigureOnPc;
  final String gmailRestElevateOnPc;
  final String gmailRestDisconnectOnPc;
  final String gmailRestSetupGuideOnPc;
  final String gmailRestReadOnly;
  final String gmailRestDraftsSend;
  final String gmailRestMailboxActions;
  final String gmailRestConnected;
  final String gmailRestNotConnected;
  final String mcpCustomTitle;
  final String mcpCustomHint;
  final String mcpFieldName;
  final String mcpFieldNamePh;
  final String mcpFieldCommand;
  final String mcpFieldCommandPh;
  final String mcpFieldTokenOptional;
  final String mcpFieldTokenPh;
  final String mcpFieldTokenEnvOptional;
  final String mcpFieldTokenEnvPh;
  final String mcpErrName;
  final String mcpErrCommand;
  final String mcpAdd;

  // ── MCP write-tool confirmation (WOR-44 Phase 5) ──
  final String mcpConfirmTitleTemplate; // {server} {tool}
  final String mcpConfirmWriteWarning;
  final String mcpConfirmArgsLabel;
  final String mcpConfirmApprove;
  final String mcpConfirmDecline;
  final String mcpConfirmWritesLabel;
  final String mcpConfirmWritesSub;
  final String mcpUnattendedWritesLabel;
  final String mcpUnattendedWritesSub;

  // ── Theme names (keyed lookup via themeName) ──
  final String themeViolet;
  final String themeRose;
  final String themeNoir;
  final String themeBlanc;
  final String themeDore;

  const OsiaStrings({
    required this.languageCode,
    required this.languageName,
    required this.cancel,
    required this.delete,
    required this.retry,
    required this.save,
    required this.rename,
    required this.enterYourToken,
    required this.connect,
    required this.connectingEllipsis,
    required this.tokenRequired,
    required this.connectionFailed,
    required this.invalidToken,
    required this.tokenHint,
    required this.pcOffline,
    required this.conversations,
    required this.newChat,
    required this.noConversationsYet,
    required this.sayHello,
    required this.typeMessageOrMic,
    required this.messageHint,
    required this.deleteConversationTitle,
    required this.deleteConversationBodyTemplate,
    required this.renameConversationTitle,
    required this.renameConversationHint,
    required this.today,
    required this.yesterday,
    required this.daysAgoTemplate,
    required this.untitled,
    required this.connected,
    required this.connectingStatus,
    required this.disconnected,
    required this.micPermissionDenied,
    required this.micUnavailable,
    required this.openSettingsAction,
    required this.attachFile,
    required this.filePickFailedTemplate,
    required this.fileReadFailedTemplate,
    required this.fileEmpty,
    required this.analyzeImagePrompt,
    required this.hereIsFileTemplate,
    required this.model,
    required this.settingsTooltip,
    required this.noResponseError,
    required this.relayChunkUnsupportedError,
    required this.relayFrameTooLargeError,
    required this.relayChunkTransferFailedError,
    required this.relayE2eDecryptFailedError,
    required this.relayUnreachableError,
    required this.osiaWorkingBackground,
    required this.scheduledTaskCompleted,
    required this.scheduledTaskFailed,
    required this.reminderNotification,
    required this.taskCompleted,
    required this.availableModels,
    required this.noModelsReceived,
    required this.modelsLoadFailed,
    required this.otherProviders,
    required this.reasoning,
    required this.reasoningDefault,
    required this.reasoningOff,
    required this.reasoningNormal,
    required this.reasoningMax,
    required this.reasoningMinimal,
    required this.reasoningLow,
    required this.reasoningMedium,
    required this.reasoningHigh,
    required this.reasoningXhigh,
    required this.reasoningNotSupported,
    required this.reasoningUseDefault,
    required this.settingsTitle,
    required this.appearance,
    required this.colorTheme,
    required this.language,
    required this.legal,
    required this.termsOfService,
    required this.privacyPolicy,
    required this.voiceSection,
    required this.autoReadResponses,
    required this.autoReadResponsesSubtitle,
    required this.readAloud,
    required this.connectionSection,
    required this.restartServer,
    required this.restartServerSubtitle,
    required this.reconnecting,
    required this.reconnected,
    required this.serverRestarted,
    required this.serverRestartFailed,
    required this.disconnect,
    required this.disconnectSubtitle,
    required this.disconnectConfirmTitle,
    required this.disconnectConfirmBody,
    required this.makeDonation,
    required this.linkOpenFailed,
    required this.appearanceSub,
    required this.languageSub,
    required this.voiceSectionSub,
    required this.providersSub,
    required this.legalSub,
    required this.connectionSectionSub,
    required this.memoryTitle,
    required this.localMemories,
    required this.noMemoriesYet,
    required this.refresh,
    required this.clearAll,
    required this.memorySaved,
    required this.memoryDeleted,
    required this.memoryCleared,
    required this.memoryError,
    required this.connectedRequired,
    required this.memoryClearConfirm,
    required this.memoryEditTitle,
    required this.memoryNewTitle,
    required this.memoryTitleField,
    required this.memoryKeyField,
    required this.memoryValueField,
    required this.memoryTypeField,
    required this.memoryCategoryField,
    required this.memoryKindField,
    required this.memoryRequiredFields,
    required this.providersTitle,
    required this.configureProviders,
    required this.liveApi,
    required this.liveApiNotice,
    required this.comingSoon,
    required this.notificationsSection,
    required this.notificationsSectionSub,
    required this.osiaNotifications,
    required this.osiaNotificationsSubtitle,
    required this.notificationPermissionDenied,
    required this.backgroundConnection,
    required this.backgroundConnectionSubtitle,
    required this.backgroundConnectionUnavailable,
    required this.catVoiceToVoice,
    required this.catVoiceToVoiceSub,
    required this.catAiProviders,
    required this.catAiProvidersSub,
    required this.catTtsProviders,
    required this.catTtsProvidersSub,
    required this.catSttProviders,
    required this.catSttProvidersSub,
    required this.liveapiDesc,
    required this.aiProvidersDesc,
    required this.voiceProvidersDesc,
    required this.whisperProvidersDesc,
    required this.personalityDesc,
    required this.heartbeatDesc,
    required this.apiKey,
    required this.apiKeyHint,
    required this.getApiKey,
    required this.apiKeySaved,
    required this.localProviderNoKey,
    required this.localLabel,
    required this.showApiKey,
    required this.hideApiKey,
    required this.apiKeyConfigured,
    required this.apiKeyReplaceHint,
    required this.removeApiKey,
    required this.apiKeyRemoved,
    required this.fallbackKeys,
    required this.addFallbackKey,
    required this.editFallbackKey,
    required this.deleteFallbackKey,
    required this.fallbackKeyIndex,
    required this.visionAssociated,
    required this.visionProvider,
    required this.visionModel,
    required this.visionHint,
    required this.ttsProviderLabel,
    required this.ttsVoiceLabel,
    required this.sttProviderLabel,
    required this.ttsVoiceAutomatic,
    required this.add,
    required this.edit,
    required this.close,
    required this.loading,
    required this.catScheduledTasks,
    required this.catScheduledTasksSub,
    required this.catAiHierarchy,
    required this.catAiHierarchySub,
    required this.catPersonalitySkills,
    required this.catPersonalitySkillsSub,
    required this.cronTitle,
    required this.cronSubtitle,
    required this.cronEmpty,
    required this.cronAddTask,
    required this.cronEditTask,
    required this.cronTaskLabel,
    required this.cronTaskHint,
    required this.cronType,
    required this.cronTypeRepeat,
    required this.cronTypeOnce,
    required this.cronFrequency,
    required this.cronUnitMinutes,
    required this.cronUnitHours,
    required this.cronUnitDays,
    required this.cronModeDaily,
    required this.cronDate,
    required this.cronTime,
    required this.cronInvalid,
    required this.cronModelDefault,
    required this.cronModelInvalid,
    required this.cronEveryMinutesTemplate,
    required this.cronEveryHoursTemplate,
    required this.cronEveryDaysTemplate,
    required this.cronDailyAtTemplate,
    required this.cronOnceTemplate,
    required this.cronLinkedConversation,
    required this.cronNoConversation,
    required this.cronLoadingConversations,
    required this.hierarchyTitle,
    required this.hierarchySubtitle,
    required this.hierarchyEnable,
    required this.hierarchyActive,
    required this.hierarchyHeavy,
    required this.hierarchyHeavySub,
    required this.hierarchyMedium,
    required this.hierarchyMediumSub,
    required this.hierarchyAddModel,
    required this.hierarchyEmpty,
    required this.hierarchyNoProviders,
    required this.moveUp,
    required this.moveDown,
    required this.personalitySkillsTitle,
    required this.tabPersonality,
    required this.tabSkills,
    required this.personalityHint,
    required this.personalitySaved,
    required this.skillsEmpty,
    required this.skillAdd,
    required this.skillNewTitle,
    required this.skillNewHint,
    required this.skillContentHint,
    required this.skillSaved,
    required this.skillDeleteTitle,
    required this.skillDeleteBodyTemplate,
    required this.catSystemStatus,
    required this.catSystemStatusSub,
    required this.heartbeatMonitoring,
    required this.heartbeatInterval,
    required this.heartbeatIntervalRange,
    required this.heartbeatChecksHeader,
    required this.heartbeatUsageThresholdHint,
    required this.heartbeatDiskThresholdHint,
    required this.heartbeatNetworkHint,
    required this.heartbeatWaiting,
    required this.systemMetricsHeader,
    required this.metricCpu,
    required this.metricRam,
    required this.metricDisk,
    required this.metricNetwork,
    required this.metricCpuTemp,
    required this.metricGpuTemp,
    required this.sectionGeneral,
    required this.timeFormatLabel,
    required this.autonomousTitle,
    required this.autonomousObjectiveLabel,
    required this.autonomousObjectiveHint,
    required this.autonomousPickModel,
    required this.autonomousNoConfiguredModels,
    required this.autonomousStart,
    required this.autonomousPlanning,
    required this.autonomousRunning,
    required this.autonomousInterrupt,
    required this.autonomousAbort,
    required this.autonomousIdle,
    required this.autonomousBusy,
    required this.autonomousDone,
    required this.autonomousFailed,
    required this.autonomousAborted,
    required this.autonomousInterrupted,
    required this.autonomousResume,
    required this.autonomousPhase,
    required this.autonomousObjectiveRequired,
    required this.autonomousModelRequired,
    required this.autonomousTasksTemplate,
    required this.catConnectors,
    required this.catConnectorsSub,
    required this.connectorsDesc,
    required this.connectorLabel,
    required this.mcpConnect,
    required this.mcpDisconnect,
    required this.mcpSignOut,
    required this.mcpSwitchAccount,
    required this.mcpCancel,
    required this.mcpOpeningBrowser,
    required this.mcpStatusConnected,
    required this.mcpStatusConnecting,
    required this.mcpStatusDisconnected,
    required this.mcpStatusFailed,
    required this.mcpOauthSoon,
    required this.mcpHttpSoon,
    required this.mcpOauthConnectOnPc,
    required this.mcpOauthConnectOnPcHint,
    required this.mcpCopyToken,
    required this.mcpTokenCopied,
    required this.mcpTokenLabel,
    required this.mcpTokenHint,
    required this.mcpSlackTeam,
    required this.mcpSlackTeamPh,
    required this.mcpAddCustom,
    required this.mcpRemove,
    required this.mcpDescGithub,
    required this.mcpDescSlack,
    required this.mcpDescNotion,
    required this.mcpDescLinear,
    required this.mcpDescGdrive,
    required this.mcpDescGmail,
    required this.gmailRestName,
    required this.gmailRestTitle,
    required this.gmailRestConfigureOnPc,
    required this.gmailRestElevateOnPc,
    required this.gmailRestDisconnectOnPc,
    required this.gmailRestSetupGuideOnPc,
    required this.gmailRestReadOnly,
    required this.gmailRestDraftsSend,
    required this.gmailRestMailboxActions,
    required this.gmailRestConnected,
    required this.gmailRestNotConnected,
    required this.mcpCustomTitle,
    required this.mcpCustomHint,
    required this.mcpFieldName,
    required this.mcpFieldNamePh,
    required this.mcpFieldCommand,
    required this.mcpFieldCommandPh,
    required this.mcpFieldTokenOptional,
    required this.mcpFieldTokenPh,
    required this.mcpFieldTokenEnvOptional,
    required this.mcpFieldTokenEnvPh,
    required this.mcpErrName,
    required this.mcpErrCommand,
    required this.mcpAdd,
    required this.mcpConfirmTitleTemplate,
    required this.mcpConfirmWriteWarning,
    required this.mcpConfirmArgsLabel,
    required this.mcpConfirmApprove,
    required this.mcpConfirmDecline,
    required this.mcpConfirmWritesLabel,
    required this.mcpConfirmWritesSub,
    required this.mcpUnattendedWritesLabel,
    required this.mcpUnattendedWritesSub,
    required this.themeViolet,
    required this.themeRose,
    required this.themeNoir,
    required this.themeBlanc,
    required this.themeDore,
  });

  // ── Parameterized helpers ──

  String deleteConversationBody(String title) =>
      deleteConversationBodyTemplate.replaceAll('{title}', title);

  String daysAgo(int n) => daysAgoTemplate.replaceAll('{n}', '$n');

  String filePickFailed(String error) =>
      filePickFailedTemplate.replaceAll('{error}', error);

  String fileReadFailed(String error) =>
      fileReadFailedTemplate.replaceAll('{error}', error);

  String hereIsFile(String name) =>
      hereIsFileTemplate.replaceAll('{name}', name);

  String cronEveryMinutes(int n) =>
      cronEveryMinutesTemplate.replaceAll('{n}', '$n');

  String cronEveryHours(int n) =>
      cronEveryHoursTemplate.replaceAll('{n}', '$n');

  String cronEveryDays(int n) => cronEveryDaysTemplate.replaceAll('{n}', '$n');

  String cronDailyAt(String time) =>
      cronDailyAtTemplate.replaceAll('{t}', time);

  String cronOnce(String date, String time) =>
      cronOnceTemplate.replaceAll('{d}', date).replaceAll('{t}', time);

  String skillDeleteBody(String name) =>
      skillDeleteBodyTemplate.replaceAll('{name}', name);

  String autonomousTasks(int done, int total) => autonomousTasksTemplate
      .replaceAll('{done}', '$done')
      .replaceAll('{total}', '$total');

  /// Title for the write-tool confirmation dialog (WOR-44 Phase 5):
  /// "{server} wants to run {tool}".
  String mcpConfirmTitle(String server, String tool) => mcpConfirmTitleTemplate
      .replaceAll('{server}', server)
      .replaceAll('{tool}', tool);

  String modelCount(int count) {
    switch (languageCode) {
      case 'fr':
        return count == 1 ? '1 modèle' : '$count modèles';
      case 'zh':
        return '$count 个模型';
      case 'ja':
        return '$count モデル';
      case 'de':
        return count == 1 ? '1 Modell' : '$count Modelle';
      case 'es':
        return count == 1 ? '1 modelo' : '$count modelos';
      default:
        return count == 1 ? '1 model' : '$count models';
    }
  }

  String get chatGptConnect {
    switch (languageCode) {
      case 'fr':
        return 'Se connecter avec ChatGPT';
      case 'zh':
        return '使用 ChatGPT 登录';
      case 'ja':
        return 'ChatGPT でサインイン';
      case 'de':
        return 'Mit ChatGPT anmelden';
      case 'es':
        return 'Iniciar sesión con ChatGPT';
      default:
        return 'Sign in with ChatGPT';
    }
  }

  String get chatGptDisconnect {
    switch (languageCode) {
      case 'fr':
        return 'Se déconnecter';
      case 'zh':
        return '退出登录';
      case 'ja':
        return 'サインアウト';
      case 'de':
        return 'Abmelden';
      case 'es':
        return 'Cerrar sesión';
      default:
        return 'Sign out';
    }
  }

  String get chatGptOpenLogin {
    switch (languageCode) {
      case 'fr':
        return 'Ouvrir la connexion';
      case 'zh':
        return '打开登录页面';
      case 'ja':
        return 'ログインページを開く';
      case 'de':
        return 'Anmeldung öffnen';
      case 'es':
        return 'Abrir inicio de sesión';
      default:
        return 'Open sign-in page';
    }
  }

  String get chatGptEnterCode {
    switch (languageCode) {
      case 'fr':
        return 'Saisissez ce code :';
      case 'zh':
        return '输入此代码：';
      case 'ja':
        return 'このコードを入力：';
      case 'de':
        return 'Diesen Code eingeben:';
      case 'es':
        return 'Introduce este código:';
      default:
        return 'Enter this code:';
    }
  }

  String get chatGptInfo {
    switch (languageCode) {
      case 'fr':
        return "ChatGPT est un fournisseur cloud. Les requêtes et réponses sont traitées par OpenAI. Aucun fichier local n'est joint automatiquement et les garanties de confidentialité des modèles locaux ne s'appliquent pas. ChatGPT est un fournisseur sélectionnable normal, sans priorité particulière.";
      case 'zh':
        return 'ChatGPT 是云端提供商。提示和回复由 OpenAI 处理。不会自动附加本地文件，本地模型的隐私保证不适用。ChatGPT 是普通的可选提供商，没有特殊优先级。';
      case 'ja':
        return 'ChatGPT はクラウドプロバイダーです。プロンプトと応答は OpenAI が処理します。ローカルファイルは自動添付されず、ローカルモデルのプライバシー保証は適用されません。ChatGPT は特別な優先順位を持たない通常の選択可能プロバイダーです。';
      case 'de':
        return 'ChatGPT ist ein Cloud-Anbieter. Anfragen und Antworten werden von OpenAI verarbeitet. Lokale Dateien werden nicht automatisch angehängt; die Datenschutzgarantien lokaler Modelle gelten nicht. ChatGPT ist ein normal auswählbarer Anbieter ohne besondere Priorität.';
      case 'es':
        return 'ChatGPT es un proveedor en la nube. OpenAI procesa las solicitudes y respuestas. No se adjuntan archivos locales automáticamente y no se aplican las garantías de privacidad de los modelos locales. ChatGPT es un proveedor seleccionable normal, sin prioridad especial.';
      default:
        return 'ChatGPT is a cloud provider. Prompts and responses are processed by OpenAI. No local files are attached automatically, and local-model privacy guarantees do not apply. ChatGPT is a normal selectable provider with no special priority.';
    }
  }

  String chatGptError(String category) {
    switch (languageCode) {
      case 'fr':
        return 'ChatGPT est indisponible. Réessayez ou vérifiez OSIA sur le PC.';
      case 'zh':
        return 'ChatGPT 当前不可用。请重试或检查电脑上的 OSIA。';
      case 'ja':
        return 'ChatGPT を利用できません。再試行するか、PC の OSIA を確認してください。';
      case 'de':
        return 'ChatGPT ist nicht verfügbar. Erneut versuchen oder OSIA auf dem PC prüfen.';
      case 'es':
        return 'ChatGPT no está disponible. Reinténtalo o revisa OSIA en el PC.';
      default:
        return 'ChatGPT is unavailable. Retry or check OSIA on the PC.';
    }
  }

  String chatGptUsage(int percent) {
    switch (languageCode) {
      case 'fr':
        return '$percent % utilisés';
      case 'zh':
        return '已使用 $percent%';
      case 'ja':
        return '$percent% 使用済み';
      case 'de':
        return '$percent % verwendet';
      case 'es':
        return '$percent % usado';
      default:
        return '$percent% used';
    }
  }

  /// Localized display name for a theme palette key.
  String themeName(String paletteKey) {
    switch (paletteKey) {
      case 'violet':
        return themeViolet;
      case 'rose':
        return themeRose;
      case 'noir':
        return themeNoir;
      case 'blanc':
        return themeBlanc;
      case 'dore':
        return themeDore;
    }
    return paletteKey;
  }
}

// ── English (default) ─────────────────────────────────────────────────────

const OsiaStrings osiaStringsEn = OsiaStrings(
  languageCode: 'en',
  languageName: 'English',
  cancel: 'Cancel',
  delete: 'Delete',
  retry: 'Retry',
  save: 'Save',
  enterYourToken: 'Enter your token',
  connect: 'Connect',
  connectingEllipsis: 'Connecting…',
  tokenRequired: 'Please enter your token.',
  connectionFailed: 'Connection failed. Check your token and try again.',
  invalidToken: 'Invalid token. Check it and try again.',
  tokenHint: 'Your token is in the OSIA settings on your PC',
  pcOffline: 'Your PC is offline. Start OSIA on your PC, then try again.',
  conversations: 'Conversations',
  newChat: 'New chat',
  noConversationsYet: 'No conversations yet',
  sayHello: 'Say hello to OSIA',
  typeMessageOrMic: 'Type a message or use the mic.',
  messageHint: 'Message OSIA…',
  deleteConversationTitle: 'Delete conversation?',
  deleteConversationBodyTemplate: '"{title}" will be permanently deleted.',
  rename: 'Rename',
  renameConversationTitle: 'Rename conversation',
  renameConversationHint: 'Conversation name',
  today: 'Today',
  yesterday: 'Yesterday',
  daysAgoTemplate: '{n} days ago',
  untitled: 'Untitled',
  connected: 'Connected',
  connectingStatus: 'Connecting…',
  disconnected: 'Disconnected',
  micPermissionDenied:
      'Microphone permission denied. Open settings to allow it.',
  micUnavailable: 'Cannot access the microphone.',
  openSettingsAction: 'Settings',
  attachFile: 'Attach a file',
  filePickFailedTemplate: 'Could not pick a file: {error}',
  fileReadFailedTemplate: 'Could not read the file: {error}',
  fileEmpty: 'Empty or inaccessible file.',
  analyzeImagePrompt: 'Analyze this image.',
  hereIsFileTemplate: 'Here is the file {name}.',
  model: 'Model',
  settingsTooltip: 'Settings',
  noResponseError: "OSIA didn't respond.",
  relayChunkUnsupportedError:
      'Update OSIA on your PC and phone to send this large message.',
  relayFrameTooLargeError: 'The encrypted relay message is too large.',
  relayChunkTransferFailedError: 'The encrypted relay transfer failed.',
  relayE2eDecryptFailedError: 'Relay encryption verification failed.',
  relayUnreachableError: 'The public relay is unreachable.',
  osiaWorkingBackground: 'OSIA is working in the background',
  scheduledTaskCompleted: 'Scheduled task completed',
  scheduledTaskFailed: 'Scheduled task failed',
  reminderNotification: 'OSIA reminder',
  taskCompleted: 'Task completed',
  availableModels: 'Available models',
  noModelsReceived: 'No models received from the server.',
  modelsLoadFailed: 'Unable to load models',
  otherProviders: 'OTHERS',
  reasoning: 'Reasoning',
  reasoningDefault: 'Default',
  reasoningOff: 'Off',
  reasoningNormal: 'Normal',
  reasoningMax: 'Max',
  reasoningMinimal: 'Minimal',
  reasoningLow: 'Low',
  reasoningMedium: 'Medium',
  reasoningHigh: 'High',
  reasoningXhigh: 'Xhigh',
  reasoningNotSupported: 'Not supported',
  reasoningUseDefault: 'Use default',
  settingsTitle: 'Settings',
  appearance: 'Appearance',
  colorTheme: 'Color theme',
  language: 'Language',
  legal: 'Legal',
  termsOfService: 'Terms of Service',
  privacyPolicy: 'Privacy Policy',
  voiceSection: 'Voice',
  autoReadResponses: 'Read responses aloud automatically',
  autoReadResponsesSubtitle:
      'When off, tap the speaker icon under a message to hear it.',
  readAloud: 'Read aloud',
  connectionSection: 'Connection',
  restartServer: 'Restart server',
  restartServerSubtitle: 'Restart the OSIA server remotely.',
  reconnecting: 'Reconnecting…',
  reconnected: 'Reconnected',
  serverRestarted: 'Server restarted',
  serverRestartFailed: 'Could not restart the server. Try again.',
  disconnect: 'Disconnect',
  disconnectSubtitle: 'Clears your token and returns to the connection screen.',
  disconnectConfirmTitle: 'Disconnect?',
  disconnectConfirmBody:
      'Your token will be erased from this device. Your theme and language are kept.',
  makeDonation: 'Make a donation',
  linkOpenFailed: 'Could not open the link.',
  appearanceSub: 'Theme color for the whole app',
  languageSub: 'Interface language for the app',
  voiceSectionSub: 'How OSIA reads replies aloud',
  providersSub: 'AI, voice and transcription keys',
  legalSub: 'Terms and privacy documents',
  connectionSectionSub: 'Manage the link to your PC',
  memoryTitle: 'Memory',
  localMemories:
      'Local memories OSIA uses to personalize actions and responses.',
  noMemoriesYet: 'No memories yet',
  refresh: 'Refresh',
  clearAll: 'Clear all',
  memorySaved: 'Memory saved',
  memoryDeleted: 'Memory deleted',
  memoryCleared: 'Memory cleared',
  memoryError: 'Memory error',
  connectedRequired: 'Connect to your PC to manage memory.',
  memoryClearConfirm:
      'Clear all local memories from your PC? This cannot be undone.',
  memoryEditTitle: 'Edit memory',
  memoryNewTitle: 'New memory',
  memoryTitleField: 'Title',
  memoryKeyField: 'Key',
  memoryValueField: 'Value',
  memoryTypeField: 'Type',
  memoryCategoryField: 'Category',
  memoryKindField: 'Value kind',
  memoryRequiredFields: 'Title, key and value are required.',
  providersTitle: 'APIs & Providers',
  configureProviders: 'Configure APIs & Providers',
  liveApi: 'Live API',
  liveApiNotice: 'When enabled, STT and TTS are automatically disabled.',
  comingSoon: 'Coming soon',
  notificationsSection: 'Notifications',
  notificationsSectionSub: 'Scheduled tasks and reminders',
  osiaNotifications: 'OSIA notifications',
  osiaNotificationsSubtitle:
      'Get safe alerts when scheduled tasks finish or fail.',
  notificationPermissionDenied:
      'Notifications are blocked. You can enable them in system settings.',
  backgroundConnection: 'Keep OSIA connected in background',
  backgroundConnectionSubtitle:
      'Shows a persistent notification and keeps the mobile link active.',
  backgroundConnectionUnavailable:
      'Background connection could not start. Check notification permission and battery settings.',
  catVoiceToVoice: 'Voice-to-voice (Live API)',
  catVoiceToVoiceSub: 'Real-time spoken conversation with OSIA',
  catAiProviders: 'AI Providers',
  catAiProvidersSub: 'API keys for chat AI models',
  catTtsProviders: 'Voice Providers (TTS)',
  catTtsProvidersSub: 'Voices that read replies aloud',
  catSttProviders: 'Whisper Providers (STT)',
  catSttProvidersSub: 'Turn your speech into text',
  liveapiDesc:
      'Speak naturally and hear OSIA reply in real time, with no separate transcription step. Add the API key for the provider you want to use for live voice.',
  aiProvidersDesc:
      "Connect the AI providers that power OSIA's chat and reasoning. Paste an API key for each provider you want to enable — keys are stored on your device.",
  voiceProvidersDesc:
      "Choose how OSIA speaks its replies aloud. Local voices run on your device for free; cloud voices need the matching provider's API key.",
  whisperProvidersDesc:
      'Choose how OSIA turns your speech into text. faster-whisper runs locally for free, while Groq Whisper needs an API key.',
  personalityDesc:
      'Give OSIA a consistent character and add custom skills it can use. These shape how OSIA talks and what extra abilities it has.',
  heartbeatDesc:
      "Let OSIA watch your device's CPU, memory, disk and temperatures. It can alert you aloud when a metric crosses a threshold you set.",
  apiKey: 'API key',
  apiKeyHint: 'Paste your API key',
  getApiKey: 'Get API key',
  apiKeySaved: 'API key saved',
  localProviderNoKey: 'This provider runs locally — no API key required.',
  localLabel: 'Local',
  showApiKey: 'Show key',
  hideApiKey: 'Hide key',
  apiKeyConfigured: 'Key configured',
  apiKeyReplaceHint: 'Enter a new key to replace it',
  removeApiKey: 'Remove key',
  apiKeyRemoved: 'API key removed',
  fallbackKeys: 'Fallback keys',
  addFallbackKey: 'Add fallback key',
  editFallbackKey: 'Edit fallback key',
  deleteFallbackKey: 'Delete fallback key',
  fallbackKeyIndex: 'Key {n}',
  visionAssociated: 'Paired vision model',
  visionProvider: 'Vision provider',
  visionModel: 'Vision model',
  visionHint:
      'Useful if your main model does not handle images (e.g. DeepSeek, Groq, Llama, Mistral).',
  ttsProviderLabel: 'TTS provider',
  ttsVoiceLabel: 'Voice',
  sttProviderLabel: 'Speech-to-text provider',
  ttsVoiceAutomatic: 'Automatic',
  add: 'Add',
  edit: 'Edit',
  close: 'Close',
  loading: 'Loading…',
  catScheduledTasks: 'Scheduled Tasks',
  catScheduledTasksSub: 'Recurring or one-off automated tasks',
  catAiHierarchy: 'AI Hierarchy',
  catAiHierarchySub: 'Model fallback chains for heavy / medium tasks',
  catPersonalitySkills: 'Personality & Skills',
  catPersonalitySkillsSub: "OSIA's identity and custom skills",
  cronTitle: 'Scheduled Tasks',
  cronSubtitle:
      'Have OSIA run a task on its own at set times — a daily summary, an hourly check. Write it in plain language and pick a repeating interval or a one-time date.',
  cronEmpty: 'No scheduled tasks yet.',
  cronAddTask: 'Add a task',
  cronEditTask: 'Edit task',
  cronTaskLabel: 'Task',
  cronTaskHint: 'What should OSIA do?',
  cronType: 'Type',
  cronTypeRepeat: 'Repeat',
  cronTypeOnce: 'Once',
  cronFrequency: 'Frequency',
  cronUnitMinutes: 'Minutes',
  cronUnitHours: 'Hours',
  cronUnitDays: 'Days',
  cronModeDaily: 'Daily at',
  cronDate: 'Date',
  cronTime: 'Time',
  cronInvalid: 'Enter a task and a valid schedule.',
  cronModelDefault: 'Default/current model',
  cronModelInvalid: 'Choose a valid model.',
  cronEveryMinutesTemplate: 'Every {n} min',
  cronEveryHoursTemplate: 'Every {n} h',
  cronEveryDaysTemplate: 'Every {n} d',
  cronDailyAtTemplate: 'Daily at {t}',
  cronOnceTemplate: 'Once · {d} {t}',
  cronLinkedConversation: 'Linked conversation',
  cronNoConversation: 'None (new conversation)',
  cronLoadingConversations: 'Loading…',
  hierarchyTitle: 'AI Hierarchy',
  hierarchySubtitle:
      'Route work through an ordered list of models instead of one. If a model hits a technical error, OSIA automatically falls back to the next in the chain.',
  hierarchyEnable: 'Enable hierarchy',
  hierarchyActive: 'AI hierarchy active',
  hierarchyHeavy: 'Heavy tasks',
  hierarchyHeavySub: 'Code, debugging, complex reasoning, deep research.',
  hierarchyMedium: 'Medium tasks',
  hierarchyMediumSub: 'Everything else: navigation, summaries, short tasks.',
  hierarchyAddModel: 'Add a model',
  hierarchyEmpty: 'No model in this chain.',
  hierarchyNoProviders: 'Configure an AI provider first.',
  moveUp: 'Move up',
  moveDown: 'Move down',
  personalitySkillsTitle: 'Personality & Skills',
  tabPersonality: 'Personality',
  tabSkills: 'Skills',
  personalityHint: 'Describe how OSIA should behave…',
  personalitySaved: 'Personality saved',
  skillsEmpty: 'No skills yet.',
  skillAdd: 'Add a skill',
  skillNewTitle: 'New skill',
  skillNewHint: 'Skill name',
  skillContentHint: 'Skill instructions (Markdown)…',
  skillSaved: 'Skill saved',
  skillDeleteTitle: 'Delete skill?',
  skillDeleteBodyTemplate: '"{name}" will be permanently deleted.',
  catSystemStatus: 'System status',
  catSystemStatusSub: 'Live CPU, memory, disk and temperatures',
  heartbeatMonitoring: 'Enable monitoring',
  heartbeatInterval: 'Interval (seconds)',
  heartbeatIntervalRange: 'Between 10 and 300 seconds',
  heartbeatChecksHeader: 'Alert checks',
  heartbeatUsageThresholdHint: 'Alert when usage exceeds this %.',
  heartbeatDiskThresholdHint: 'Alert when free space falls below this %.',
  heartbeatNetworkHint: 'Alert when the connectivity check fails.',
  heartbeatWaiting: 'Waiting for data…',
  systemMetricsHeader: 'Live metrics',
  metricCpu: 'CPU',
  metricRam: 'RAM',
  metricDisk: 'Disk',
  metricNetwork: 'Network',
  metricCpuTemp: 'CPU temp.',
  metricGpuTemp: 'GPU temp.',
  sectionGeneral: 'General',
  timeFormatLabel: 'Time format',
  autonomousTitle: 'Autonomous',
  autonomousObjectiveLabel: 'Objective',
  autonomousObjectiveHint: 'Describe what OSIA should accomplish on its own…',
  autonomousPickModel: 'Choose a model',
  autonomousNoConfiguredModels:
      'No configured model — add an API key in Providers first.',
  autonomousStart: 'Start',
  autonomousPlanning: 'Planning…',
  autonomousRunning: 'Running',
  autonomousInterrupt: 'Pause',
  autonomousAbort: 'Abandon',
  autonomousIdle: 'No autonomous task running',
  autonomousBusy: 'An autonomous task is already running.',
  autonomousDone: 'Task completed',
  autonomousFailed: 'Task failed',
  autonomousAborted: 'Task abandoned',
  autonomousInterrupted: 'Paused',
  autonomousResume: 'Resume',
  autonomousPhase: 'Phase',
  autonomousObjectiveRequired: 'Enter an objective first.',
  autonomousModelRequired: 'Choose a model first.',
  autonomousTasksTemplate: '{done} / {total} tasks',
  // ── MCP / Connectors (WOR-44 Phase 4) ──
  catConnectors: 'MCP / Connectors',
  catConnectorsSub: 'Connect external tools and services as extra agent tools.',
  connectorsDesc:
      'MCP (Model Context Protocol) servers expose tools OSIA can use — search the web, read files, manage repos and more. Connect a preconfigured server with one tap (some need an API token), or add your own. Connected tools become available to OSIA with the same safety as built-in tools.',
  connectorLabel: 'Connector',
  mcpConnect: 'Connect',
  mcpDisconnect: 'Disconnect',
  mcpSignOut: 'Sign out',
  mcpSwitchAccount: 'Switch account',
  mcpCancel: 'Cancel',
  mcpOpeningBrowser: 'Opening browser…',
  mcpStatusConnected: 'Connected',
  mcpStatusConnecting: 'Connecting…',
  mcpStatusDisconnected: 'Disconnected',
  mcpStatusFailed: 'Failed',
  mcpOauthSoon: 'OAuth — soon',
  mcpHttpSoon: 'HTTP — soon',
  mcpOauthConnectOnPc: 'Connect on PC',
  mcpOauthConnectOnPcHint:
      'OAuth sign-in happens in the desktop app; the status updates here once connected.',
  mcpCopyToken: 'Copy token',
  mcpTokenCopied: 'Token copied',
  mcpTokenLabel: 'API token / key',
  mcpTokenHint: 'Paste token (stored locally, never synced)…',
  mcpSlackTeam: 'Slack team ID',
  mcpSlackTeamPh: 'e.g. T01234567',
  mcpAddCustom: 'Add custom server',
  mcpRemove: 'Remove',
  mcpDescGithub: 'Repos, issues & pull requests on GitHub.',
  mcpDescSlack: 'Read & post messages in your Slack workspace.',
  mcpDescNotion: 'Pages & databases in your Notion workspace.',
  mcpDescLinear: 'Issues, projects & cycles in Linear.',
  mcpDescGdrive: 'Browse & read files in Google Drive.',
  mcpDescGmail: 'Search & manage email in Gmail.',
  gmailRestName: 'Gmail',
  gmailRestTitle: 'Native Gmail REST / email search and management',
  gmailRestConfigureOnPc: 'Configure on PC',
  gmailRestElevateOnPc: 'Elevate OSIA permissions on PC',
  gmailRestDisconnectOnPc: 'Disconnect on PC',
  gmailRestSetupGuideOnPc: 'Setup guide available on PC',
  gmailRestReadOnly: 'Read-only',
  gmailRestDraftsSend: 'Drafts/send',
  gmailRestMailboxActions: 'Mailbox actions',
  gmailRestConnected: 'Connected',
  gmailRestNotConnected: 'Not connected',
  mcpCustomTitle: 'Add a custom MCP server',
  mcpCustomHint:
      'Add a local stdio command (e.g. npx …). Remote (HTTP) servers are coming in a later update. Adding does not connect — connect it explicitly afterwards.',
  mcpFieldName: 'Name',
  mcpFieldNamePh: 'e.g. My server',
  mcpFieldCommand: 'Command (stdio)',
  mcpFieldCommandPh: 'e.g. npx -y @scope/server …',
  mcpFieldTokenOptional: 'Token (optional)',
  mcpFieldTokenPh: 'Stored locally, never synced…',
  mcpFieldTokenEnvOptional: 'Token env var (stdio, optional)',
  mcpFieldTokenEnvPh: 'e.g. MY_API_KEY',
  mcpErrName: 'Please enter a name.',
  mcpErrCommand: 'Please enter a command.',
  mcpAdd: 'Add',
  mcpConfirmTitleTemplate: '{server} wants to run {tool}',
  mcpConfirmWriteWarning:
      'This tool can create, change or delete data. Only approve actions you started and trust.',
  mcpConfirmArgsLabel: 'Arguments',
  mcpConfirmApprove: 'Approve',
  mcpConfirmDecline: 'Decline',
  mcpConfirmWritesLabel: 'Auto-approve connector write actions',
  mcpConfirmWritesSub:
      'Off asks before connector writes. On lets connector writes run without a local confirmation prompt.',
  mcpUnattendedWritesLabel: 'Allow unattended writes',
  mcpUnattendedWritesSub:
      'Off blocks unattended connector writes when no confirmation device is available. On lets those writes proceed.',
  themeViolet: 'Violet',
  themeRose: 'Rose',
  themeNoir: 'Black',
  themeBlanc: 'White',
  themeDore: 'Gold',
);

// ── French ────────────────────────────────────────────────────────────────

const OsiaStrings osiaStringsFr = OsiaStrings(
  languageCode: 'fr',
  languageName: 'Français',
  cancel: 'Annuler',
  delete: 'Supprimer',
  retry: 'Réessayer',
  save: 'Enregistrer',
  enterYourToken: 'Entrez votre token',
  connect: 'Se connecter',
  connectingEllipsis: 'Connexion…',
  tokenRequired: 'Veuillez entrer votre token.',
  connectionFailed: 'Échec de la connexion. Vérifiez votre token et réessayez.',
  invalidToken: 'Token invalide. Vérifiez-le et réessayez.',
  tokenHint: 'Votre token se trouve dans les paramètres OSIA sur votre PC',
  pcOffline:
      'Votre PC est hors ligne. Lancez OSIA sur votre PC, puis réessayez.',
  conversations: 'Conversations',
  newChat: 'Nouveau chat',
  noConversationsYet: 'Aucune conversation pour le moment',
  sayHello: 'Dites bonjour à OSIA',
  typeMessageOrMic: 'Tapez un message ou utilisez le micro.',
  messageHint: 'Message OSIA…',
  deleteConversationTitle: 'Supprimer la conversation ?',
  deleteConversationBodyTemplate: '« {title} » sera supprimée définitivement.',
  rename: 'Renommer',
  renameConversationTitle: 'Renommer la conversation',
  renameConversationHint: 'Nom de la conversation',
  today: "Aujourd'hui",
  yesterday: 'Hier',
  daysAgoTemplate: 'Il y a {n} j',
  untitled: 'Sans titre',
  connected: 'Connecté',
  connectingStatus: 'Connexion…',
  disconnected: 'Déconnecté',
  micPermissionDenied:
      "Permission micro refusée. Ouvrez les paramètres pour l'autoriser.",
  micUnavailable: "Impossible d'accéder au microphone.",
  openSettingsAction: 'Paramètres',
  attachFile: 'Joindre un fichier',
  filePickFailedTemplate: 'Sélection de fichier impossible : {error}',
  fileReadFailedTemplate: 'Lecture du fichier impossible : {error}',
  fileEmpty: 'Fichier vide ou inaccessible.',
  analyzeImagePrompt: 'Analyse cette image.',
  hereIsFileTemplate: 'Voici le fichier {name}.',
  model: 'Modèle',
  settingsTooltip: 'Paramètres',
  noResponseError: "OSIA n'a pas répondu.",
  relayChunkUnsupportedError:
      'Mettez à jour OSIA sur le PC et le téléphone pour envoyer ce message.',
  relayFrameTooLargeError: 'Le message chiffré du relais est trop volumineux.',
  relayChunkTransferFailedError: 'Le transfert chiffré du relais a échoué.',
  relayE2eDecryptFailedError: 'La vérification du chiffrement a échoué.',
  relayUnreachableError: 'Le relais public est inaccessible.',
  osiaWorkingBackground: 'OSIA travaille en arrière-plan',
  scheduledTaskCompleted: 'Tâche planifiée terminée',
  scheduledTaskFailed: 'Tâche planifiée échouée',
  reminderNotification: 'Rappel OSIA',
  taskCompleted: 'Tâche terminée',
  availableModels: 'Modèles disponibles',
  noModelsReceived: 'Aucun modèle reçu du serveur.',
  modelsLoadFailed: 'Impossible de charger les modèles',
  otherProviders: 'AUTRES',
  reasoning: 'Raisonnement',
  reasoningDefault: 'Défaut',
  reasoningOff: 'Désactivé',
  reasoningNormal: 'Normal',
  reasoningMax: 'Max',
  reasoningMinimal: 'Minimal',
  reasoningLow: 'Faible',
  reasoningMedium: 'Moyen',
  reasoningHigh: 'Élevé',
  reasoningXhigh: 'Très élevé',
  reasoningNotSupported: 'Non pris en charge',
  reasoningUseDefault: 'Utiliser le défaut',
  settingsTitle: 'Paramètres',
  appearance: 'Apparence',
  colorTheme: 'Thème de couleur',
  language: 'Langue',
  legal: 'Légal',
  termsOfService: "Conditions d'utilisation",
  privacyPolicy: 'Politique de confidentialité',
  voiceSection: 'Voix',
  autoReadResponses: 'Lire les réponses à voix haute automatiquement',
  autoReadResponsesSubtitle:
      "Si désactivé, touchez l'icône haut-parleur sous un message pour l'écouter.",
  readAloud: 'Lire à voix haute',
  connectionSection: 'Connexion',
  restartServer: 'Redémarrer le serveur',
  restartServerSubtitle: 'Redémarre le serveur OSIA à distance.',
  reconnecting: 'Reconnexion…',
  reconnected: 'Reconnecté',
  serverRestarted: 'Serveur redémarré',
  serverRestartFailed: 'Échec du redémarrage du serveur. Réessayez.',
  disconnect: 'Se déconnecter',
  disconnectSubtitle: "Efface votre token et retourne à l'écran de connexion.",
  disconnectConfirmTitle: 'Se déconnecter ?',
  disconnectConfirmBody:
      'Votre token sera effacé de cet appareil. Votre thème et votre langue sont conservés.',
  makeDonation: 'Faire un don',
  linkOpenFailed: "Impossible d'ouvrir le lien.",
  appearanceSub: "Couleur du thème de l'application",
  languageSub: "Langue de l'interface",
  voiceSectionSub: 'Comment OSIA lit ses réponses',
  providersSub: 'Clés IA, voix et transcription',
  legalSub: 'Conditions et confidentialité',
  connectionSectionSub: 'Gérer le lien avec votre PC',
  memoryTitle: 'Mémoire',
  localMemories:
      'Mémoires locales utilisées par OSIA pour personnaliser actions et réponses.',
  noMemoriesYet: 'Aucune mémoire pour le moment',
  refresh: 'Actualiser',
  clearAll: 'Tout effacer',
  memorySaved: 'Mémoire enregistrée',
  memoryDeleted: 'Mémoire supprimée',
  memoryCleared: 'Mémoire effacée',
  memoryError: 'Erreur mémoire',
  connectedRequired: 'Connectez-vous au PC pour gérer la mémoire.',
  memoryClearConfirm:
      'Effacer toutes les mémoires locales du PC ? Cette action est irréversible.',
  memoryEditTitle: 'Modifier la mémoire',
  memoryNewTitle: 'Nouvelle mémoire',
  memoryTitleField: 'Titre',
  memoryKeyField: 'Clé',
  memoryValueField: 'Valeur',
  memoryTypeField: 'Type',
  memoryCategoryField: 'Catégorie',
  memoryKindField: 'Type de valeur',
  memoryRequiredFields: 'Titre, clé et valeur sont obligatoires.',
  providersTitle: 'API et fournisseurs',
  configureProviders: 'Configurer les API et fournisseurs',
  liveApi: 'API Live',
  liveApiNotice:
      'Une fois activé, la transcription (STT) et la synthèse vocale (TTS) sont automatiquement désactivées.',
  comingSoon: 'Bientôt disponible',
  notificationsSection: 'Notifications',
  notificationsSectionSub: 'Tâches planifiées et rappels',
  osiaNotifications: 'Notifications OSIA',
  osiaNotificationsSubtitle:
      'Recevez des alertes sûres quand une tâche se termine ou échoue.',
  notificationPermissionDenied:
      'Les notifications sont bloquées. Vous pouvez les autoriser dans les réglages système.',
  backgroundConnection: 'Garder OSIA connecté en arrière-plan',
  backgroundConnectionSubtitle:
      'Affiche une notification persistante et maintient le lien mobile actif.',
  backgroundConnectionUnavailable:
      'La connexion en arrière-plan n’a pas pu démarrer. Vérifiez les notifications et la batterie.',
  catVoiceToVoice: 'Voix à voix (API Live)',
  catVoiceToVoiceSub: 'Conversation vocale en temps réel avec OSIA',
  catAiProviders: 'Fournisseurs IA',
  catAiProvidersSub: 'Clés API pour les modèles de chat IA',
  catTtsProviders: 'Fournisseurs vocaux (TTS)',
  catTtsProvidersSub: 'Des voix qui lisent les réponses à voix haute',
  catSttProviders: 'Fournisseurs Whisper (STT)',
  catSttProvidersSub: 'Transformez votre voix en texte',
  liveapiDesc:
      "Parlez naturellement et entendez OSIA répondre en temps réel, sans étape de transcription séparée. Ajoutez la clé API du fournisseur que vous voulez utiliser pour la voix en direct.",
  aiProvidersDesc:
      "Connectez les fournisseurs d'IA qui alimentent le chat et le raisonnement d'OSIA. Collez une clé API pour chaque fournisseur à activer — les clés sont stockées sur votre appareil.",
  voiceProvidersDesc:
      "Choisissez comment OSIA lit ses réponses à voix haute. Les voix locales s'exécutent gratuitement sur votre appareil ; les voix cloud nécessitent la clé API du fournisseur correspondant.",
  whisperProvidersDesc:
      "Choisissez comment OSIA transforme votre voix en texte. faster-whisper s'exécute localement gratuitement, tandis que Groq Whisper nécessite une clé API.",
  personalityDesc:
      "Donnez à OSIA un caractère cohérent et ajoutez des skills personnalisés qu'il peut utiliser. Ils façonnent la manière dont OSIA parle et ses capacités supplémentaires.",
  heartbeatDesc:
      "Laissez OSIA surveiller le processeur, la mémoire, le disque et les températures de votre appareil. Il peut vous alerter à voix haute quand une mesure dépasse un seuil que vous définissez.",
  apiKey: 'Clé API',
  apiKeyHint: 'Collez votre clé API',
  getApiKey: 'Obtenir une clé API',
  apiKeySaved: 'Clé API enregistrée',
  localProviderNoKey:
      'Ce fournisseur fonctionne en local — aucune clé API requise.',
  localLabel: 'Local',
  showApiKey: 'Afficher la clé',
  hideApiKey: 'Masquer la clé',
  apiKeyConfigured: 'Clé configurée',
  apiKeyReplaceHint: 'Saisissez une nouvelle clé pour la remplacer',
  removeApiKey: 'Supprimer la clé',
  apiKeyRemoved: 'Clé API supprimée',
  fallbackKeys: 'Clés de secours',
  addFallbackKey: 'Ajouter une clé de secours',
  editFallbackKey: 'Modifier la clé de secours',
  deleteFallbackKey: 'Supprimer la clé de secours',
  fallbackKeyIndex: 'Clé {n}',
  visionAssociated: 'Modèle vision associé',
  visionProvider: 'Fournisseur vision',
  visionModel: 'Modèle vision',
  visionHint:
      'Utile si votre modèle principal ne gère pas les images (ex: DeepSeek, Groq, Llama, Mistral).',
  ttsProviderLabel: 'Fournisseur TTS',
  ttsVoiceLabel: 'Voix',
  sttProviderLabel: 'Fournisseur de reconnaissance vocale',
  ttsVoiceAutomatic: 'Automatique',
  add: 'Ajouter',
  edit: 'Modifier',
  close: 'Fermer',
  loading: 'Chargement…',
  catScheduledTasks: 'Tâches planifiées',
  catScheduledTasksSub: 'Tâches automatisées récurrentes ou ponctuelles',
  catAiHierarchy: 'Hiérarchie IA',
  catAiHierarchySub: 'Chaînes de modèles pour tâches lourdes / moyennes',
  catPersonalitySkills: 'Personnalité et Skills',
  catPersonalitySkillsSub: "L'identité d'OSIA et ses skills personnalisés",
  cronTitle: 'Tâches planifiées',
  cronSubtitle:
      'Laissez OSIA exécuter une tâche toute seule à des moments définis — un résumé quotidien, une vérification horaire. Décrivez-la en langage clair et choisissez un intervalle récurrent ou une date unique.',
  cronEmpty: 'Aucune tâche planifiée pour le moment.',
  cronAddTask: 'Ajouter une tâche',
  cronEditTask: 'Modifier la tâche',
  cronTaskLabel: 'Tâche',
  cronTaskHint: 'Que doit faire OSIA ?',
  cronType: 'Type',
  cronTypeRepeat: 'Récurrent',
  cronTypeOnce: 'Une fois',
  cronFrequency: 'Fréquence',
  cronUnitMinutes: 'Minutes',
  cronUnitHours: 'Heures',
  cronUnitDays: 'Jours',
  cronModeDaily: 'Chaque jour à',
  cronDate: 'Date',
  cronTime: 'Heure',
  cronInvalid: 'Saisissez une tâche et un horaire valide.',
  cronModelDefault: 'Modèle par défaut/actuel',
  cronModelInvalid: 'Choisissez un modèle valide.',
  cronEveryMinutesTemplate: 'Toutes les {n} min',
  cronEveryHoursTemplate: 'Toutes les {n} h',
  cronEveryDaysTemplate: 'Tous les {n} j',
  cronDailyAtTemplate: 'Chaque jour à {t}',
  cronOnceTemplate: 'Une fois · {d} {t}',
  cronLinkedConversation: 'Conversation liée',
  cronNoConversation: 'Aucune (nouvelle conversation)',
  cronLoadingConversations: 'Chargement…',
  hierarchyTitle: 'Hiérarchie IA',
  hierarchySubtitle:
      "Faites passer le travail par une liste ordonnée de modèles plutôt qu'un seul. Si un modèle rencontre une erreur technique, OSIA bascule automatiquement vers le suivant dans la chaîne.",
  hierarchyEnable: 'Activer la hiérarchie',
  hierarchyActive: 'Hiérarchie IA active',
  hierarchyHeavy: 'Tâches lourdes',
  hierarchyHeavySub:
      'Code, débogage, raisonnement complexe, recherche approfondie.',
  hierarchyMedium: 'Tâches moyennes',
  hierarchyMediumSub: 'Tout le reste : navigation, résumés, tâches courtes.',
  hierarchyAddModel: 'Ajouter un modèle',
  hierarchyEmpty: 'Aucun modèle dans cette chaîne.',
  hierarchyNoProviders: "Configurez d'abord un fournisseur IA.",
  moveUp: 'Monter',
  moveDown: 'Descendre',
  personalitySkillsTitle: 'Personnalité et Skills',
  tabPersonality: 'Personnalité',
  tabSkills: 'Skills',
  personalityHint: "Décrivez le comportement d'OSIA…",
  personalitySaved: 'Personnalité enregistrée',
  skillsEmpty: 'Aucun skill pour le moment.',
  skillAdd: 'Ajouter un skill',
  skillNewTitle: 'Nouveau skill',
  skillNewHint: 'Nom du skill',
  skillContentHint: 'Instructions du skill (Markdown)…',
  skillSaved: 'Skill enregistré',
  skillDeleteTitle: 'Supprimer le skill ?',
  skillDeleteBodyTemplate: '« {name} » sera supprimé définitivement.',
  catSystemStatus: 'État système',
  catSystemStatusSub: 'CPU, mémoire, disque et températures en direct',
  heartbeatMonitoring: 'Activer la surveillance',
  heartbeatInterval: 'Intervalle (secondes)',
  heartbeatIntervalRange: 'Entre 10 et 300 secondes',
  heartbeatChecksHeader: 'Contrôles d’alerte',
  heartbeatUsageThresholdHint: 'Alerte lorsque l’utilisation dépasse ce %.',
  heartbeatDiskThresholdHint: 'Alerte lorsque l’espace libre passe sous ce %.',
  heartbeatNetworkHint: 'Alerte lorsque le test de connexion échoue.',
  heartbeatWaiting: 'En attente de données…',
  systemMetricsHeader: 'Métriques en direct',
  metricCpu: 'CPU',
  metricRam: 'RAM',
  metricDisk: 'Disque',
  metricNetwork: 'Réseau',
  metricCpuTemp: 'Temp. CPU',
  metricGpuTemp: 'Temp. GPU',
  sectionGeneral: 'Général',
  timeFormatLabel: 'Format horaire',
  autonomousTitle: 'Autonome',
  autonomousObjectiveLabel: 'Objectif',
  autonomousObjectiveHint: "Décrivez ce qu'OSIA doit accomplir seul…",
  autonomousPickModel: 'Choisir un modèle',
  autonomousNoConfiguredModels:
      "Aucun modèle configuré — ajoutez d'abord une clé API dans Fournisseurs.",
  autonomousStart: 'Démarrer',
  autonomousPlanning: 'Planification…',
  autonomousRunning: 'En cours',
  autonomousInterrupt: 'Pause',
  autonomousAbort: 'Abandonner',
  autonomousIdle: 'Aucune tâche autonome en cours',
  autonomousBusy: 'Une tâche autonome est déjà en cours.',
  autonomousDone: 'Tâche terminée',
  autonomousFailed: 'Tâche échouée',
  autonomousAborted: 'Tâche abandonnée',
  autonomousInterrupted: 'En pause',
  autonomousResume: 'Reprendre',
  autonomousPhase: 'Phase',
  autonomousObjectiveRequired: "Saisissez d'abord un objectif.",
  autonomousModelRequired: "Choisissez d'abord un modèle.",
  autonomousTasksTemplate: '{done} / {total} tâches',
  // ── MCP / Connectors (WOR-44 Phase 4) ──
  catConnectors: 'MCP / Connecteurs',
  catConnectorsSub:
      "Connectez des outils et services externes comme outils supplémentaires de l'agent.",
  connectorsDesc:
      "Les serveurs MCP (Model Context Protocol) exposent des outils qu'OSIA peut utiliser — chercher sur le web, lire des fichiers, gérer des dépôts, etc. Connectez un serveur préconfiguré en un clic (certains exigent un jeton d'API), ou ajoutez le vôtre. Les outils connectés deviennent disponibles pour OSIA avec la même sécurité que les outils intégrés.",
  connectorLabel: 'Connecteur',
  mcpConnect: 'Connecter',
  mcpDisconnect: 'Déconnecter',
  mcpSignOut: 'Se déconnecter',
  mcpSwitchAccount: 'Changer de compte',
  mcpCancel: 'Annuler',
  mcpOpeningBrowser: 'Ouverture du navigateur…',
  mcpStatusConnected: 'Connecté',
  mcpStatusConnecting: 'Connexion…',
  mcpStatusDisconnected: 'Déconnecté',
  mcpStatusFailed: 'Échec',
  mcpOauthSoon: 'OAuth — bientôt',
  mcpHttpSoon: 'HTTP — bientôt',
  mcpOauthConnectOnPc: 'Connecter sur PC',
  mcpOauthConnectOnPcHint:
      "La connexion OAuth se fait dans l'application de bureau ; le statut se met à jour ici une fois connecté.",
  mcpCopyToken: 'Copier le jeton',
  mcpTokenCopied: 'Jeton copié',
  mcpTokenLabel: "Jeton / clé d'API",
  mcpTokenHint: 'Collez le jeton (stocké en local, jamais synchronisé)…',
  mcpSlackTeam: "ID d'équipe Slack",
  mcpSlackTeamPh: 'ex. T01234567',
  mcpAddCustom: 'Ajouter un serveur',
  mcpRemove: 'Supprimer',
  mcpDescGithub: 'Dépôts, issues et pull requests sur GitHub.',
  mcpDescSlack: 'Lire et publier des messages dans votre espace Slack.',
  mcpDescNotion: 'Pages et bases de données de votre espace Notion.',
  mcpDescLinear: 'Issues, projets et cycles dans Linear.',
  mcpDescGdrive: 'Parcourir et lire des fichiers dans Google Drive.',
  mcpDescGmail: 'Rechercher et gérer les e-mails dans Gmail.',
  gmailRestName: 'Gmail',
  gmailRestTitle: 'Gmail REST natif / recherche et gestion des e-mails',
  gmailRestConfigureOnPc: 'Configurer sur PC',
  gmailRestDisconnectOnPc: 'Déconnecter sur PC',
  gmailRestElevateOnPc: 'Élever les autorisations OSIA sur PC',
  gmailRestSetupGuideOnPc: 'Guide de configuration disponible sur PC',
  gmailRestReadOnly: 'Lecture seule',
  gmailRestDraftsSend: 'Brouillons/envoi',
  gmailRestMailboxActions: 'Actions de boîte mail',
  gmailRestConnected: 'Connecté',
  gmailRestNotConnected: 'Non connecté',
  mcpCustomTitle: 'Ajouter un serveur MCP personnalisé',
  mcpCustomHint:
      "Ajoutez une commande stdio locale (ex. npx …). Les serveurs distants (HTTP) arriveront plus tard. L'ajout ne connecte pas — connectez-le ensuite explicitement.",
  mcpFieldName: 'Nom',
  mcpFieldNamePh: 'ex. Mon serveur',
  mcpFieldCommand: 'Commande (stdio)',
  mcpFieldCommandPh: 'ex. npx -y @scope/server …',
  mcpFieldTokenOptional: 'Jeton (facultatif)',
  mcpFieldTokenPh: 'Stocké en local, jamais synchronisé…',
  mcpFieldTokenEnvOptional: "Variable d'env. du jeton (stdio, facultatif)",
  mcpFieldTokenEnvPh: 'ex. MY_API_KEY',
  mcpErrName: 'Veuillez saisir un nom.',
  mcpErrCommand: 'Veuillez saisir une commande.',
  mcpAdd: 'Ajouter',
  mcpConfirmTitleTemplate: '{server} veut exécuter {tool}',
  mcpConfirmWriteWarning:
      "Cet outil peut créer, modifier ou supprimer des données. N'approuvez que les actions que vous avez lancées et en qui vous avez confiance.",
  mcpConfirmArgsLabel: 'Arguments',
  mcpConfirmApprove: 'Approuver',
  mcpConfirmDecline: 'Refuser',
  mcpConfirmWritesLabel:
      'Approuver automatiquement les ecritures des connecteurs',
  mcpConfirmWritesSub:
      'Desactive, OSIA demande avant les ecritures. Active, les connecteurs ecrivent sans confirmation locale.',
  mcpUnattendedWritesLabel: 'Autoriser les écritures sans surveillance',
  mcpUnattendedWritesSub:
      'Desactive, bloque les ecritures sans appareil de confirmation. Active, les laisse continuer.',
  themeViolet: 'Violet',
  themeRose: 'Rose',
  themeNoir: 'Noir',
  themeBlanc: 'Blanc',
  themeDore: 'Doré',
);

// ── Chinese (Simplified) ──────────────────────────────────────────────────

const OsiaStrings osiaStringsZh = OsiaStrings(
  languageCode: 'zh',
  languageName: '中文',
  cancel: '取消',
  delete: '删除',
  retry: '重试',
  save: '保存',
  enterYourToken: '输入您的令牌',
  connect: '连接',
  connectingEllipsis: '连接中…',
  tokenRequired: '请输入您的令牌。',
  connectionFailed: '连接失败。请检查您的令牌后重试。',
  invalidToken: '令牌无效。请检查后重试。',
  tokenHint: '您的令牌位于您电脑上的 OSIA 设置中',
  pcOffline: '您的电脑已离线。请在电脑上启动 OSIA，然后重试。',
  conversations: '对话',
  newChat: '新对话',
  noConversationsYet: '暂无对话',
  sayHello: '向 OSIA 打个招呼',
  typeMessageOrMic: '输入消息或使用麦克风。',
  messageHint: '发送给 OSIA…',
  deleteConversationTitle: '删除对话？',
  deleteConversationBodyTemplate: '"{title}" 将被永久删除。',
  rename: '重命名',
  renameConversationTitle: '重命名对话',
  renameConversationHint: '对话名称',
  today: '今天',
  yesterday: '昨天',
  daysAgoTemplate: '{n} 天前',
  untitled: '无标题',
  connected: '已连接',
  connectingStatus: '连接中…',
  disconnected: '已断开',
  micPermissionDenied: '麦克风权限被拒绝。请打开设置以允许。',
  micUnavailable: '无法访问麦克风。',
  openSettingsAction: '设置',
  attachFile: '附加文件',
  filePickFailedTemplate: '无法选择文件：{error}',
  fileReadFailedTemplate: '无法读取文件：{error}',
  fileEmpty: '文件为空或无法访问。',
  analyzeImagePrompt: '分析这张图片。',
  hereIsFileTemplate: '这是文件 {name}。',
  model: '模型',
  settingsTooltip: '设置',
  noResponseError: 'OSIA 没有回应。',
  relayChunkUnsupportedError: '请更新电脑和手机上的 OSIA 以发送此大消息。',
  relayFrameTooLargeError: '加密中继消息过大。',
  relayChunkTransferFailedError: '加密中继传输失败。',
  relayE2eDecryptFailedError: '中继加密验证失败。',
  relayUnreachableError: '无法连接公共中继。',
  osiaWorkingBackground: 'OSIA 正在后台工作',
  scheduledTaskCompleted: '定时任务已完成',
  scheduledTaskFailed: '定时任务失败',
  reminderNotification: 'OSIA 提醒',
  taskCompleted: '任务完成',
  availableModels: '可用模型',
  noModelsReceived: '未从服务器收到任何模型。',
  modelsLoadFailed: '无法加载模型',
  otherProviders: '其他',
  reasoning: '推理',
  reasoningDefault: '默认',
  reasoningOff: '关闭',
  reasoningNormal: '正常',
  reasoningMax: '最大',
  reasoningMinimal: '最小',
  reasoningLow: '低',
  reasoningMedium: '中',
  reasoningHigh: '高',
  reasoningXhigh: '超高',
  reasoningNotSupported: '不支持',
  reasoningUseDefault: '使用默认值',
  settingsTitle: '设置',
  appearance: '外观',
  colorTheme: '颜色主题',
  language: '语言',
  legal: '法律',
  termsOfService: '服务条款',
  privacyPolicy: '隐私政策',
  voiceSection: '语音',
  autoReadResponses: '自动朗读回复',
  autoReadResponsesSubtitle: '关闭后，点按消息下方的扬声器图标即可收听。',
  readAloud: '朗读',
  connectionSection: '连接',
  restartServer: '重启服务器',
  restartServerSubtitle: '远程重启 OSIA 服务器。',
  reconnecting: '重新连接中…',
  reconnected: '已重新连接',
  serverRestarted: '服务器已重启',
  serverRestartFailed: '服务器重启失败。请重试。',
  disconnect: '断开连接',
  disconnectSubtitle: '清除您的令牌并返回连接页面。',
  disconnectConfirmTitle: '断开连接？',
  disconnectConfirmBody: '您的令牌将从此设备中删除。您的主题和语言将被保留。',
  makeDonation: '捐赠支持',
  linkOpenFailed: '无法打开链接。',
  appearanceSub: '整个应用的主题颜色',
  languageSub: '应用界面语言',
  voiceSectionSub: 'OSIA 如何朗读回复',
  providersSub: 'AI、语音和转录密钥',
  legalSub: '条款与隐私文件',
  connectionSectionSub: '管理与电脑的连接',
  memoryTitle: '记忆',
  localMemories: 'OSIA 用于个性化操作和回答的本地记忆。',
  noMemoriesYet: '暂无记忆',
  refresh: '刷新',
  clearAll: '全部清除',
  memorySaved: '记忆已保存',
  memoryDeleted: '记忆已删除',
  memoryCleared: '记忆已清除',
  memoryError: '记忆错误',
  connectedRequired: '连接到电脑后才能管理记忆。',
  memoryClearConfirm: '清除电脑上的所有本地记忆？此操作无法撤销。',
  memoryEditTitle: '编辑记忆',
  memoryNewTitle: '新建记忆',
  memoryTitleField: '标题',
  memoryKeyField: '键',
  memoryValueField: '值',
  memoryTypeField: '类型',
  memoryCategoryField: '类别',
  memoryKindField: '值类型',
  memoryRequiredFields: '标题、键和值为必填项。',
  providersTitle: 'API 与提供商',
  configureProviders: '配置 API 与提供商',
  liveApi: '实时 API',
  liveApiNotice: '启用后，语音转文字 (STT) 和文字转语音 (TTS) 将自动停用。',
  comingSoon: '即将推出',
  notificationsSection: '通知',
  notificationsSectionSub: '定时任务和提醒',
  osiaNotifications: 'OSIA 通知',
  osiaNotificationsSubtitle: '计划任务完成或失败时接收安全提醒。',
  notificationPermissionDenied: '通知已被阻止。你可以在系统设置中启用。',
  backgroundConnection: '在后台保持 OSIA 连接',
  backgroundConnectionSubtitle: '显示常驻通知，并保持移动连接处于活动状态。',
  backgroundConnectionUnavailable: '后台连接无法启动。请检查通知权限和电池设置。',
  catVoiceToVoice: '语音对话（实时 API）',
  catVoiceToVoiceSub: '与 OSIA 进行实时语音对话',
  catAiProviders: 'AI 提供商',
  catAiProvidersSub: '聊天 AI 模型的 API 密钥',
  catTtsProviders: '语音提供商 (TTS)',
  catTtsProvidersSub: '朗读回复的语音',
  catSttProviders: 'Whisper 提供商 (STT)',
  catSttProvidersSub: '将您的语音转换为文字',
  liveapiDesc: '自然地说话，实时听到 OSIA 的回复，无需单独的转录步骤。添加您想用于实时语音的提供商的 API 密钥。',
  aiProvidersDesc:
      '连接为 OSIA 的聊天和推理提供支持的 AI 提供商。为每个要启用的提供商粘贴 API 密钥——密钥保存在您的设备上。',
  voiceProvidersDesc: '选择 OSIA 如何朗读其回复。本地语音在您的设备上免费运行；云端语音需要相应提供商的 API 密钥。',
  whisperProvidersDesc:
      '选择 OSIA 如何将您的语音转换为文字。faster-whisper 在本地免费运行，而 Groq Whisper 需要 API 密钥。',
  personalityDesc: '赋予 OSIA 一致的性格，并添加它可以使用的自定义技能。它们决定了 OSIA 的说话方式及其额外能力。',
  heartbeatDesc: '让 OSIA 监测您设备的 CPU、内存、磁盘和温度。当某项指标超过您设定的阈值时，它可以语音提醒您。',
  apiKey: 'API 密钥',
  apiKeyHint: '粘贴您的 API 密钥',
  getApiKey: '获取 API 密钥',
  apiKeySaved: 'API 密钥已保存',
  localProviderNoKey: '该提供商在本地运行 — 无需 API 密钥。',
  localLabel: '本地',
  showApiKey: '显示密钥',
  hideApiKey: '隐藏密钥',
  apiKeyConfigured: '密钥已配置',
  apiKeyReplaceHint: '输入新密钥以替换',
  removeApiKey: '移除密钥',
  apiKeyRemoved: 'API 密钥已移除',
  fallbackKeys: '备用密钥',
  addFallbackKey: '添加备用密钥',
  editFallbackKey: '编辑备用密钥',
  deleteFallbackKey: '删除备用密钥',
  fallbackKeyIndex: '密钥 {n}',
  visionAssociated: '配套视觉模型',
  visionProvider: '视觉提供商',
  visionModel: '视觉模型',
  visionHint: '如果您的主模型不支持图像（例如 DeepSeek、Groq、Llama、Mistral），此功能很有用。',
  ttsProviderLabel: 'TTS 提供商',
  ttsVoiceLabel: '语音',
  sttProviderLabel: '语音转文字提供商',
  ttsVoiceAutomatic: '自动',
  add: '添加',
  edit: '编辑',
  close: '关闭',
  loading: '加载中…',
  catScheduledTasks: '定时任务',
  catScheduledTasksSub: '周期性或一次性的自动任务',
  catAiHierarchy: 'AI 层级',
  catAiHierarchySub: '重型 / 中型任务的模型回退链',
  catPersonalitySkills: '个性与技能',
  catPersonalitySkillsSub: 'OSIA 的身份与自定义技能',
  cronTitle: '定时任务',
  cronSubtitle: '让 OSIA 在设定的时间自动运行任务——例如每日摘要或每小时检查。用自然语言描述它，并选择重复间隔或一次性日期。',
  cronEmpty: '暂无定时任务。',
  cronAddTask: '添加任务',
  cronEditTask: '编辑任务',
  cronTaskLabel: '任务',
  cronTaskHint: 'OSIA 应该做什么？',
  cronType: '类型',
  cronTypeRepeat: '重复',
  cronTypeOnce: '一次',
  cronFrequency: '频率',
  cronUnitMinutes: '分钟',
  cronUnitHours: '小时',
  cronUnitDays: '天',
  cronModeDaily: '每天于',
  cronDate: '日期',
  cronTime: '时间',
  cronInvalid: '请输入任务和有效的计划。',
  cronModelDefault: '默认/当前模型',
  cronModelInvalid: '请选择有效模型。',
  cronEveryMinutesTemplate: '每 {n} 分钟',
  cronEveryHoursTemplate: '每 {n} 小时',
  cronEveryDaysTemplate: '每 {n} 天',
  cronDailyAtTemplate: '每天 {t}',
  cronOnceTemplate: '一次 · {d} {t}',
  cronLinkedConversation: '关联对话',
  cronNoConversation: '无（新对话）',
  cronLoadingConversations: '加载中…',
  hierarchyTitle: 'AI 层级',
  hierarchySubtitle: '让工作通过一个有序的模型列表处理，而不是单个模型。如果某个模型遇到技术错误，OSIA 会自动回退到链中的下一个。',
  hierarchyEnable: '启用层级',
  hierarchyActive: 'AI层级已启用',
  hierarchyHeavy: '重型任务',
  hierarchyHeavySub: '代码、调试、复杂推理、深度研究。',
  hierarchyMedium: '中型任务',
  hierarchyMediumSub: '其他一切：导航、摘要、简短任务。',
  hierarchyAddModel: '添加模型',
  hierarchyEmpty: '此链中暂无模型。',
  hierarchyNoProviders: '请先配置一个 AI 提供商。',
  moveUp: '上移',
  moveDown: '下移',
  personalitySkillsTitle: '个性与技能',
  tabPersonality: '个性',
  tabSkills: '技能',
  personalityHint: '描述 OSIA 应有的行为方式…',
  personalitySaved: '个性已保存',
  skillsEmpty: '暂无技能。',
  skillAdd: '添加技能',
  skillNewTitle: '新建技能',
  skillNewHint: '技能名称',
  skillContentHint: '技能说明（Markdown）…',
  skillSaved: '技能已保存',
  skillDeleteTitle: '删除技能？',
  skillDeleteBodyTemplate: '"{name}" 将被永久删除。',
  catSystemStatus: '系统状态',
  catSystemStatusSub: '实时 CPU、内存、磁盘和温度',
  heartbeatMonitoring: '启用监控',
  heartbeatInterval: '间隔（秒）',
  heartbeatIntervalRange: '介于 10 到 300 秒之间',
  heartbeatChecksHeader: '警报检查',
  heartbeatUsageThresholdHint: '使用率超过此百分比时提醒。',
  heartbeatDiskThresholdHint: '可用空间低于此百分比时提醒。',
  heartbeatNetworkHint: '连接检查失败时提醒。',
  heartbeatWaiting: '正在等待数据…',
  systemMetricsHeader: '实时指标',
  metricCpu: 'CPU',
  metricRam: '内存',
  metricDisk: '磁盘',
  metricNetwork: '网络',
  metricCpuTemp: 'CPU 温度',
  metricGpuTemp: 'GPU 温度',
  sectionGeneral: '通用',
  timeFormatLabel: '时间格式',
  autonomousTitle: '自主',
  autonomousObjectiveLabel: '目标',
  autonomousObjectiveHint: '描述 OSIA 需要自主完成的任务…',
  autonomousPickModel: '选择模型',
  autonomousNoConfiguredModels: '没有已配置的模型 — 请先在「提供商」中添加 API 密钥。',
  autonomousStart: '开始',
  autonomousPlanning: '规划中…',
  autonomousRunning: '运行中',
  autonomousInterrupt: '暂停',
  autonomousAbort: '放弃',
  autonomousIdle: '没有正在运行的自主任务',
  autonomousBusy: '已有一个自主任务正在运行。',
  autonomousDone: '任务完成',
  autonomousFailed: '任务失败',
  autonomousAborted: '任务已放弃',
  autonomousInterrupted: '已暂停',
  autonomousResume: '继续',
  autonomousPhase: '阶段',
  autonomousObjectiveRequired: '请先输入目标。',
  autonomousModelRequired: '请先选择模型。',
  autonomousTasksTemplate: '{done} / {total} 个任务',
  // ── MCP / Connectors (WOR-44 Phase 4) ──
  catConnectors: 'MCP / 连接器',
  catConnectorsSub: '将外部工具和服务作为额外的代理工具进行连接。',
  connectorsDesc:
      'MCP（模型上下文协议）服务器提供 OSIA 可使用的工具 — 网络搜索、读取文件、管理仓库等。一键连接预配置的服务器（部分需要 API 令牌），或添加你自己的。已连接的工具将以与内置工具相同的安全性提供给 OSIA。',
  connectorLabel: '连接器',
  mcpConnect: '连接',
  mcpDisconnect: '断开',
  mcpSignOut: '退出登录',
  mcpSwitchAccount: '切换账户',
  mcpCancel: '取消',
  mcpOpeningBrowser: '正在打开浏览器…',
  mcpStatusConnected: '已连接',
  mcpStatusConnecting: '连接中…',
  mcpStatusDisconnected: '未连接',
  mcpStatusFailed: '失败',
  mcpOauthSoon: 'OAuth — 即将推出',
  mcpHttpSoon: 'HTTP — 即将推出',
  mcpOauthConnectOnPc: '在电脑上连接',
  mcpOauthConnectOnPcHint: 'OAuth 登录在桌面应用中完成；连接后此处的状态会自动更新。',
  mcpCopyToken: '复制令牌',
  mcpTokenCopied: '已复制令牌',
  mcpTokenLabel: 'API 令牌 / 密钥',
  mcpTokenHint: '粘贴令牌（本地存储，不会同步）…',
  mcpSlackTeam: 'Slack 团队 ID',
  mcpSlackTeamPh: '例如：T01234567',
  mcpAddCustom: '添加自定义服务器',
  mcpRemove: '移除',
  mcpDescGithub: 'GitHub 上的仓库、议题与拉取请求。',
  mcpDescSlack: '在你的 Slack 工作区读取与发布消息。',
  mcpDescNotion: '你的 Notion 工作区中的页面与数据库。',
  mcpDescLinear: 'Linear 中的议题、项目与周期。',
  mcpDescGdrive: '浏览并读取 Google Drive 中的文件。',
  mcpDescGmail: '在 Gmail 中搜索与管理电子邮件。',
  gmailRestName: 'Gmail',
  gmailRestTitle: '原生 Gmail REST / 邮件搜索与管理',
  gmailRestConfigureOnPc: '在电脑上配置',
  gmailRestDisconnectOnPc: '在电脑上断开连接',
  gmailRestElevateOnPc: '在电脑上提升 OSIA 权限',
  gmailRestSetupGuideOnPc: '设置指南可在电脑上查看',
  gmailRestReadOnly: '只读',
  gmailRestDraftsSend: '草稿/发送',
  gmailRestMailboxActions: '邮箱操作',
  gmailRestConnected: '已连接',
  gmailRestNotConnected: '未连接',
  mcpCustomTitle: '添加自定义 MCP 服务器',
  mcpCustomHint:
      '添加本地 stdio 命令（例如 npx …）。远程 (HTTP) 服务器将在后续更新中推出。添加不会自动连接 — 之后请手动连接。',
  mcpFieldName: '名称',
  mcpFieldNamePh: '例如：我的服务器',
  mcpFieldCommand: '命令 (stdio)',
  mcpFieldCommandPh: '例如：npx -y @scope/server …',
  mcpFieldTokenOptional: '令牌（可选）',
  mcpFieldTokenPh: '本地存储，不会同步…',
  mcpFieldTokenEnvOptional: '令牌环境变量 (stdio，可选)',
  mcpFieldTokenEnvPh: '例如：MY_API_KEY',
  mcpErrName: '请输入名称。',
  mcpErrCommand: '请输入命令。',
  mcpAdd: '添加',
  mcpConfirmTitleTemplate: '{server} 想要运行 {tool}',
  mcpConfirmWriteWarning: '此工具可以创建、修改或删除数据。请仅批准你自己发起且信任的操作。',
  mcpConfirmArgsLabel: '参数',
  mcpConfirmApprove: '批准',
  mcpConfirmDecline: '拒绝',
  mcpConfirmWritesLabel: '自动批准连接器写入操作',
  mcpConfirmWritesSub: '关闭时，OSIA 会在连接器写入前询问。开启时，连接器无需本地确认即可写入。',
  mcpUnattendedWritesLabel: '允许无人值守写入',
  mcpUnattendedWritesSub: '没有确认设备可用时，关闭会阻止无人值守的连接器写入。开启则允许这些写入继续。',
  themeViolet: '紫色',
  themeRose: '玫瑰',
  themeNoir: '黑色',
  themeBlanc: '白色',
  themeDore: '金色',
);

// ── Japanese ──────────────────────────────────────────────────────────────

const OsiaStrings osiaStringsJa = OsiaStrings(
  languageCode: 'ja',
  languageName: '日本語',
  cancel: 'キャンセル',
  delete: '削除',
  retry: '再試行',
  save: '保存',
  enterYourToken: 'トークンを入力してください',
  connect: '接続',
  connectingEllipsis: '接続中…',
  tokenRequired: 'トークンを入力してください。',
  connectionFailed: '接続に失敗しました。トークンを確認してもう一度お試しください。',
  invalidToken: 'トークンが無効です。確認してもう一度お試しください。',
  tokenHint: 'トークンは PC の OSIA 設定にあります',
  pcOffline: 'お使いの PC がオフラインです。PC で OSIA を起動してから、もう一度お試しください。',
  conversations: '会話',
  newChat: '新しいチャット',
  noConversationsYet: 'まだ会話がありません',
  sayHello: 'OSIA に挨拶しましょう',
  typeMessageOrMic: 'メッセージを入力するか、マイクを使用してください。',
  messageHint: 'OSIA にメッセージ…',
  deleteConversationTitle: '会話を削除しますか？',
  deleteConversationBodyTemplate: '「{title}」は完全に削除されます。',
  rename: '名前を変更',
  renameConversationTitle: '会話の名前を変更',
  renameConversationHint: '会話名',
  today: '今日',
  yesterday: '昨日',
  daysAgoTemplate: '{n} 日前',
  untitled: '無題',
  connected: '接続済み',
  connectingStatus: '接続中…',
  disconnected: '切断されました',
  micPermissionDenied: 'マイクの権限が拒否されました。設定を開いて許可してください。',
  micUnavailable: 'マイクにアクセスできません。',
  openSettingsAction: '設定',
  attachFile: 'ファイルを添付',
  filePickFailedTemplate: 'ファイルを選択できませんでした：{error}',
  fileReadFailedTemplate: 'ファイルを読み込めませんでした：{error}',
  fileEmpty: 'ファイルが空かアクセスできません。',
  analyzeImagePrompt: 'この画像を分析してください。',
  hereIsFileTemplate: 'ファイル {name} です。',
  model: 'モデル',
  settingsTooltip: '設定',
  noResponseError: 'OSIA から応答がありませんでした。',
  relayChunkUnsupportedError: 'この大きなメッセージを送るには、PC とスマートフォンの OSIA を更新してください。',
  relayFrameTooLargeError: '暗号化されたリレーメッセージが大きすぎます。',
  relayChunkTransferFailedError: '暗号化されたリレー転送に失敗しました。',
  relayE2eDecryptFailedError: 'リレー暗号化の検証に失敗しました。',
  relayUnreachableError: '公開リレーに接続できません。',
  osiaWorkingBackground: 'OSIA はバックグラウンドで作業中',
  scheduledTaskCompleted: 'スケジュールタスク完了',
  scheduledTaskFailed: 'スケジュールタスク失敗',
  reminderNotification: 'OSIA リマインダー',
  taskCompleted: 'タスク完了',
  availableModels: '利用可能なモデル',
  noModelsReceived: 'サーバーからモデルを受信していません。',
  modelsLoadFailed: 'モデルを読み込めません',
  otherProviders: 'その他',
  reasoning: '推論',
  reasoningDefault: 'デフォルト',
  reasoningOff: 'オフ',
  reasoningNormal: '標準',
  reasoningMax: '最大',
  reasoningMinimal: '最小',
  reasoningLow: '低',
  reasoningMedium: '中',
  reasoningHigh: '高',
  reasoningXhigh: '最高',
  reasoningNotSupported: '未対応',
  reasoningUseDefault: 'デフォルトを使用',
  settingsTitle: '設定',
  appearance: '外観',
  colorTheme: 'カラーテーマ',
  language: '言語',
  legal: '法的情報',
  termsOfService: '利用規約',
  privacyPolicy: 'プライバシーポリシー',
  voiceSection: '音声',
  autoReadResponses: '応答を自動的に読み上げる',
  autoReadResponsesSubtitle: 'オフの場合、メッセージの下のスピーカーアイコンをタップすると読み上げられます。',
  readAloud: '読み上げる',
  connectionSection: '接続',
  restartServer: 'サーバーを再起動',
  restartServerSubtitle: 'OSIA サーバーをリモートで再起動します。',
  reconnecting: '再接続中…',
  reconnected: '再接続しました',
  serverRestarted: 'サーバーを再起動しました',
  serverRestartFailed: 'サーバーの再起動に失敗しました。もう一度お試しください。',
  disconnect: '切断',
  disconnectSubtitle: 'トークンを消去し、接続画面に戻ります。',
  disconnectConfirmTitle: '切断しますか？',
  disconnectConfirmBody: 'トークンはこのデバイスから消去されます。テーマと言語は保持されます。',
  makeDonation: '寄付をする',
  linkOpenFailed: 'リンクを開けませんでした。',
  appearanceSub: 'アプリ全体のテーマカラー',
  languageSub: 'アプリの表示言語',
  voiceSectionSub: 'OSIA が応答を読み上げる方法',
  providersSub: 'AI・音声・文字起こしのキー',
  legalSub: '規約とプライバシー文書',
  connectionSectionSub: 'PC との接続を管理',
  memoryTitle: 'メモリー',
  localMemories: 'OSIA が操作と応答をパーソナライズするためのローカルメモリー。',
  noMemoriesYet: 'まだメモリーはありません',
  refresh: '更新',
  clearAll: 'すべて消去',
  memorySaved: 'メモリーを保存しました',
  memoryDeleted: 'メモリーを削除しました',
  memoryCleared: 'メモリーを消去しました',
  memoryError: 'メモリーエラー',
  connectedRequired: 'メモリーを管理するには PC に接続してください。',
  memoryClearConfirm: 'PC のすべてのローカルメモリーを消去しますか？元に戻せません。',
  memoryEditTitle: 'メモリーを編集',
  memoryNewTitle: '新しいメモリー',
  memoryTitleField: 'タイトル',
  memoryKeyField: 'キー',
  memoryValueField: '値',
  memoryTypeField: 'タイプ',
  memoryCategoryField: 'カテゴリ',
  memoryKindField: '値の種類',
  memoryRequiredFields: 'タイトル、キー、値は必須です。',
  providersTitle: 'API とプロバイダー',
  configureProviders: 'API とプロバイダーを設定',
  liveApi: 'ライブ API',
  liveApiNotice: '有効にすると、音声認識 (STT) と音声合成 (TTS) は自動的に無効になります。',
  comingSoon: '近日公開',
  notificationsSection: '通知',
  notificationsSectionSub: 'スケジュールタスクとリマインダー',
  osiaNotifications: 'OSIA 通知',
  osiaNotificationsSubtitle: 'スケジュールタスクの完了や失敗を安全に通知します。',
  notificationPermissionDenied: '通知がブロックされています。システム設定で有効にできます。',
  backgroundConnection: 'バックグラウンドで OSIA の接続を維持',
  backgroundConnectionSubtitle: '常設通知を表示し、モバイル接続を維持します。',
  backgroundConnectionUnavailable:
      'バックグラウンド接続を開始できませんでした。通知権限とバッテリー設定を確認してください。',
  catVoiceToVoice: '音声対音声（ライブ API）',
  catVoiceToVoiceSub: 'OSIA とのリアルタイム音声会話',
  catAiProviders: 'AI プロバイダー',
  catAiProvidersSub: 'チャット AI モデル用の API キー',
  catTtsProviders: '音声プロバイダー (TTS)',
  catTtsProvidersSub: '応答を読み上げる音声',
  catSttProviders: 'Whisper プロバイダー (STT)',
  catSttProvidersSub: 'あなたの音声を文字に変換',
  liveapiDesc:
      '自然に話しかけ、OSIA の応答をリアルタイムで聞けます。個別の文字起こしは不要です。ライブ音声に使いたいプロバイダーの API キーを追加してください。',
  aiProvidersDesc:
      'OSIA のチャットと推論を支える AI プロバイダーを接続します。有効にしたいプロバイダーごとに API キーを貼り付けてください。キーはこのデバイスに保存されます。',
  voiceProvidersDesc:
      'OSIA が応答を読み上げる方法を選びます。ローカル音声はデバイス上で無料で動作し、クラウド音声には対応するプロバイダーの API キーが必要です。',
  whisperProvidersDesc:
      'OSIA があなたの音声を文字に変換する方法を選びます。faster-whisper はローカルで無料で動作し、Groq Whisper には API キーが必要です。',
  personalityDesc:
      'OSIA に一貫した性格を与え、使用できるカスタムスキルを追加します。これらは OSIA の話し方と追加の能力を形づくります。',
  heartbeatDesc:
      'OSIA がデバイスの CPU・メモリ・ディスク・温度を監視できます。指標が設定したしきい値を超えたとき、音声で知らせます。',
  apiKey: 'API キー',
  apiKeyHint: 'API キーを貼り付け',
  getApiKey: 'API キーを取得',
  apiKeySaved: 'API キーを保存しました',
  localProviderNoKey: 'このプロバイダーはローカルで動作します — API キーは不要です。',
  localLabel: 'ローカル',
  showApiKey: 'キーを表示',
  hideApiKey: 'キーを非表示',
  apiKeyConfigured: 'キー設定済み',
  apiKeyReplaceHint: '置き換えるには新しいキーを入力してください',
  removeApiKey: 'キーを削除',
  apiKeyRemoved: 'API キーを削除しました',
  fallbackKeys: 'フォールバックキー',
  addFallbackKey: 'フォールバックキーを追加',
  editFallbackKey: 'フォールバックキーを編集',
  deleteFallbackKey: 'フォールバックキーを削除',
  fallbackKeyIndex: 'キー {n}',
  visionAssociated: '連携ビジョンモデル',
  visionProvider: 'ビジョンプロバイダー',
  visionModel: 'ビジョンモデル',
  visionHint: 'メインモデルが画像を扱えない場合に便利です（例：DeepSeek、Groq、Llama、Mistral）。',
  ttsProviderLabel: 'TTS プロバイダー',
  ttsVoiceLabel: '音声',
  sttProviderLabel: '音声認識プロバイダー',
  ttsVoiceAutomatic: '自動',
  add: '追加',
  edit: '編集',
  close: '閉じる',
  loading: '読み込み中…',
  catScheduledTasks: 'スケジュールタスク',
  catScheduledTasksSub: '繰り返しまたは一度きりの自動タスク',
  catAiHierarchy: 'AI 階層',
  catAiHierarchySub: '重い / 中程度のタスク向けモデルのフォールバック連鎖',
  catPersonalitySkills: '個性とスキル',
  catPersonalitySkillsSub: 'OSIA のアイデンティティとカスタムスキル',
  cronTitle: 'スケジュールタスク',
  cronSubtitle:
      '設定した時刻に OSIA がタスクを自動で実行します（毎日の要約や毎時のチェックなど）。タスクは平易な言葉で書き、繰り返す間隔または一度きりの日付を選びます。',
  cronEmpty: 'スケジュールタスクはまだありません。',
  cronAddTask: 'タスクを追加',
  cronEditTask: 'タスクを編集',
  cronTaskLabel: 'タスク',
  cronTaskHint: 'OSIA は何をすべきですか？',
  cronType: 'タイプ',
  cronTypeRepeat: '繰り返し',
  cronTypeOnce: '一度',
  cronFrequency: '頻度',
  cronUnitMinutes: '分',
  cronUnitHours: '時間',
  cronUnitDays: '日',
  cronModeDaily: '毎日',
  cronDate: '日付',
  cronTime: '時刻',
  cronInvalid: 'タスクと有効なスケジュールを入力してください。',
  cronModelDefault: 'デフォルト/現在のモデル',
  cronModelInvalid: '有効なモデルを選択してください。',
  cronEveryMinutesTemplate: '{n} 分ごと',
  cronEveryHoursTemplate: '{n} 時間ごと',
  cronEveryDaysTemplate: '{n} 日ごと',
  cronDailyAtTemplate: '毎日 {t}',
  cronOnceTemplate: '一度 · {d} {t}',
  cronLinkedConversation: '関連する会話',
  cronNoConversation: 'なし（新しい会話）',
  cronLoadingConversations: '読み込み中…',
  hierarchyTitle: 'AI 階層',
  hierarchySubtitle:
      '1 つのモデルではなく、順序付けられたモデルのリストで処理を行います。あるモデルが技術的なエラーになった場合、OSIA は自動的にチェーン内の次のモデルへ切り替えます。',
  hierarchyEnable: '階層を有効化',
  hierarchyActive: 'AIヒエラルキー有効',
  hierarchyHeavy: '重いタスク',
  hierarchyHeavySub: 'コード、デバッグ、複雑な推論、深いリサーチ。',
  hierarchyMedium: '中程度のタスク',
  hierarchyMediumSub: 'その他すべて：ナビゲーション、要約、短いタスク。',
  hierarchyAddModel: 'モデルを追加',
  hierarchyEmpty: 'この連鎖にはモデルがありません。',
  hierarchyNoProviders: 'まず AI プロバイダーを設定してください。',
  moveUp: '上へ',
  moveDown: '下へ',
  personalitySkillsTitle: '個性とスキル',
  tabPersonality: '個性',
  tabSkills: 'スキル',
  personalityHint: 'OSIA の振る舞いを記述してください…',
  personalitySaved: '個性を保存しました',
  skillsEmpty: 'スキルはまだありません。',
  skillAdd: 'スキルを追加',
  skillNewTitle: '新しいスキル',
  skillNewHint: 'スキル名',
  skillContentHint: 'スキルの指示（Markdown）…',
  skillSaved: 'スキルを保存しました',
  skillDeleteTitle: 'スキルを削除しますか？',
  skillDeleteBodyTemplate: '「{name}」は完全に削除されます。',
  catSystemStatus: 'システム状態',
  catSystemStatusSub: 'CPU・メモリ・ディスク・温度をリアルタイム表示',
  heartbeatMonitoring: '監視を有効化',
  heartbeatInterval: '間隔（秒）',
  heartbeatIntervalRange: '10〜300 秒の範囲',
  heartbeatChecksHeader: 'アラート項目',
  heartbeatUsageThresholdHint: '使用率がこの%を超えたら通知します。',
  heartbeatDiskThresholdHint: '空き容量がこの%を下回ったら通知します。',
  heartbeatNetworkHint: '接続チェックに失敗したら通知します。',
  heartbeatWaiting: 'データを待機中…',
  systemMetricsHeader: 'リアルタイム指標',
  metricCpu: 'CPU',
  metricRam: 'メモリ',
  metricDisk: 'ディスク',
  metricNetwork: 'ネットワーク',
  metricCpuTemp: 'CPU 温度',
  metricGpuTemp: 'GPU 温度',
  sectionGeneral: '一般',
  timeFormatLabel: '時刻表示形式',
  autonomousTitle: '自律',
  autonomousObjectiveLabel: '目標',
  autonomousObjectiveHint: 'OSIA が自律的に達成すべき内容を入力…',
  autonomousPickModel: 'モデルを選択',
  autonomousNoConfiguredModels: '設定済みのモデルがありません — まず「プロバイダー」で API キーを追加してください。',
  autonomousStart: '開始',
  autonomousPlanning: '計画中…',
  autonomousRunning: '実行中',
  autonomousInterrupt: '一時停止',
  autonomousAbort: '中止',
  autonomousIdle: '実行中の自律タスクはありません',
  autonomousBusy: '自律タスクはすでに実行中です。',
  autonomousDone: 'タスク完了',
  autonomousFailed: 'タスク失敗',
  autonomousAborted: 'タスクを中止しました',
  autonomousInterrupted: '一時停止中',
  autonomousResume: '再開',
  autonomousPhase: 'フェーズ',
  autonomousObjectiveRequired: 'まず目標を入力してください。',
  autonomousModelRequired: 'まずモデルを選択してください。',
  autonomousTasksTemplate: '{done} / {total} タスク',
  // ── MCP / Connectors (WOR-44 Phase 4) ──
  catConnectors: 'MCP / コネクタ',
  catConnectorsSub: '外部のツールやサービスをエージェントの追加ツールとして接続します。',
  connectorsDesc:
      'MCP（Model Context Protocol）サーバーは、OSIA が使えるツール（ウェブ検索、ファイル読み取り、リポジトリ管理など）を提供します。事前設定済みのサーバーをワンタップで接続（一部は API トークンが必要）するか、独自に追加できます。接続されたツールは組み込みツールと同じ安全性で OSIA から利用可能になります。',
  connectorLabel: 'コネクタ',
  mcpConnect: '接続',
  mcpDisconnect: '切断',
  mcpSignOut: 'サインアウト',
  mcpSwitchAccount: 'アカウントを切り替え',
  mcpCancel: 'キャンセル',
  mcpOpeningBrowser: 'ブラウザを開いています…',
  mcpStatusConnected: '接続済み',
  mcpStatusConnecting: '接続中…',
  mcpStatusDisconnected: '未接続',
  mcpStatusFailed: '失敗',
  mcpOauthSoon: 'OAuth — 近日対応',
  mcpHttpSoon: 'HTTP — 近日対応',
  mcpOauthConnectOnPc: 'PCで接続',
  mcpOauthConnectOnPcHint:
      'OAuth サインインはデスクトップアプリで行います。接続が完了すると、ここのステータスが更新されます。',
  mcpCopyToken: 'トークンをコピー',
  mcpTokenCopied: 'トークンをコピーしました',
  mcpTokenLabel: 'API トークン / キー',
  mcpTokenHint: 'トークンを貼り付け（ローカル保存、同期されません）…',
  mcpSlackTeam: 'Slack チーム ID',
  mcpSlackTeamPh: '例：T01234567',
  mcpAddCustom: 'カスタムサーバーを追加',
  mcpRemove: '削除',
  mcpDescGithub: 'GitHub のリポジトリ・Issue・プルリクエスト。',
  mcpDescSlack: 'Slack ワークスペースでメッセージを読み書きします。',
  mcpDescNotion: 'Notion ワークスペースのページとデータベース。',
  mcpDescLinear: 'Linear の Issue・プロジェクト・サイクル。',
  mcpDescGdrive: 'Google Drive のファイルを閲覧・読み取りします。',
  mcpDescGmail: 'Gmail のメールを検索・管理します。',
  gmailRestName: 'Gmail',
  gmailRestTitle: 'ネイティブ Gmail REST / メール検索と管理',
  gmailRestConfigureOnPc: 'PCで設定',
  gmailRestDisconnectOnPc: 'PCで切断',
  gmailRestElevateOnPc: 'PCで OSIA の権限を引き上げ',
  gmailRestSetupGuideOnPc: 'セットアップガイドはPCで利用可能',
  gmailRestReadOnly: '読み取り専用',
  gmailRestDraftsSend: '下書き/送信',
  gmailRestMailboxActions: 'メールボックス操作',
  gmailRestConnected: '接続済み',
  gmailRestNotConnected: '未接続',
  mcpCustomTitle: 'カスタム MCP サーバーを追加',
  mcpCustomHint:
      'ローカルの stdio コマンド（例：npx …）を追加します。リモート (HTTP) サーバーは今後のアップデートで対応予定です。追加しても接続はされません — 後で明示的に接続してください。',
  mcpFieldName: '名前',
  mcpFieldNamePh: '例：マイサーバー',
  mcpFieldCommand: 'コマンド (stdio)',
  mcpFieldCommandPh: '例：npx -y @scope/server …',
  mcpFieldTokenOptional: 'トークン（任意）',
  mcpFieldTokenPh: 'ローカル保存、同期されません…',
  mcpFieldTokenEnvOptional: 'トークンの環境変数 (stdio、任意)',
  mcpFieldTokenEnvPh: '例：MY_API_KEY',
  mcpErrName: '名前を入力してください。',
  mcpErrCommand: 'コマンドを入力してください。',
  mcpAdd: '追加',
  mcpConfirmTitleTemplate: '{server} が {tool} を実行しようとしています',
  mcpConfirmWriteWarning: 'このツールはデータの作成・変更・削除を行えます。自分が開始した信頼できる操作のみ承認してください。',
  mcpConfirmArgsLabel: '引数',
  mcpConfirmApprove: '承認',
  mcpConfirmDecline: '拒否',
  mcpConfirmWritesLabel: 'コネクターの書き込み操作を自動承認',
  mcpConfirmWritesSub: 'オフではコネクターの書き込み前に確認します。オンではローカル確認なしで書き込みを実行します。',
  mcpUnattendedWritesLabel: '無人での書き込みを許可',
  mcpUnattendedWritesSub:
      '確認端末が利用できない場合、オフでは無人のコネクター書き込みをブロックします。オンでは続行を許可します。',
  themeViolet: 'バイオレット',
  themeRose: 'ローズ',
  themeNoir: 'ブラック',
  themeBlanc: 'ホワイト',
  themeDore: 'ゴールド',
);

// ── German ────────────────────────────────────────────────────────────────

const OsiaStrings osiaStringsDe = OsiaStrings(
  languageCode: 'de',
  languageName: 'Deutsch',
  cancel: 'Abbrechen',
  delete: 'Löschen',
  retry: 'Erneut versuchen',
  save: 'Speichern',
  enterYourToken: 'Token eingeben',
  connect: 'Verbinden',
  connectingEllipsis: 'Verbinden…',
  tokenRequired: 'Bitte geben Sie Ihr Token ein.',
  connectionFailed:
      'Verbindung fehlgeschlagen. Überprüfen Sie Ihr Token und versuchen Sie es erneut.',
  invalidToken:
      'Ungültiges Token. Überprüfen Sie es und versuchen Sie es erneut.',
  tokenHint: 'Ihr Token finden Sie in den OSIA-Einstellungen auf Ihrem PC',
  pcOffline:
      'Ihr PC ist offline. Starten Sie OSIA auf Ihrem PC und versuchen Sie es erneut.',
  conversations: 'Unterhaltungen',
  newChat: 'Neuer Chat',
  noConversationsYet: 'Noch keine Unterhaltungen',
  sayHello: 'Sag Hallo zu OSIA',
  typeMessageOrMic:
      'Geben Sie eine Nachricht ein oder nutzen Sie das Mikrofon.',
  messageHint: 'Nachricht an OSIA…',
  deleteConversationTitle: 'Unterhaltung löschen?',
  deleteConversationBodyTemplate: '„{title}" wird dauerhaft gelöscht.',
  rename: 'Umbenennen',
  renameConversationTitle: 'Unterhaltung umbenennen',
  renameConversationHint: 'Name der Unterhaltung',
  today: 'Heute',
  yesterday: 'Gestern',
  daysAgoTemplate: 'Vor {n} Tagen',
  untitled: 'Ohne Titel',
  connected: 'Verbunden',
  connectingStatus: 'Verbinden…',
  disconnected: 'Getrennt',
  micPermissionDenied:
      'Mikrofonberechtigung verweigert. Öffnen Sie die Einstellungen, um sie zu erlauben.',
  micUnavailable: 'Kein Zugriff auf das Mikrofon möglich.',
  openSettingsAction: 'Einstellungen',
  attachFile: 'Datei anhängen',
  filePickFailedTemplate: 'Datei konnte nicht ausgewählt werden: {error}',
  fileReadFailedTemplate: 'Datei konnte nicht gelesen werden: {error}',
  fileEmpty: 'Datei ist leer oder nicht zugänglich.',
  analyzeImagePrompt: 'Analysiere dieses Bild.',
  hereIsFileTemplate: 'Hier ist die Datei {name}.',
  model: 'Modell',
  settingsTooltip: 'Einstellungen',
  noResponseError: 'OSIA hat nicht geantwortet.',
  relayChunkUnsupportedError:
      'Aktualisiere OSIA auf PC und Smartphone für diese große Nachricht.',
  relayFrameTooLargeError: 'Die verschlüsselte Relay-Nachricht ist zu groß.',
  relayChunkTransferFailedError:
      'Die verschlüsselte Relay-Übertragung ist fehlgeschlagen.',
  relayE2eDecryptFailedError:
      'Die Relay-Verschlüsselungsprüfung ist fehlgeschlagen.',
  relayUnreachableError: 'Das öffentliche Relay ist nicht erreichbar.',
  osiaWorkingBackground: 'OSIA arbeitet im Hintergrund',
  scheduledTaskCompleted: 'Geplante Aufgabe abgeschlossen',
  scheduledTaskFailed: 'Geplante Aufgabe fehlgeschlagen',
  reminderNotification: 'OSIA-Erinnerung',
  taskCompleted: 'Aufgabe abgeschlossen',
  availableModels: 'Verfügbare Modelle',
  noModelsReceived: 'Keine Modelle vom Server erhalten.',
  modelsLoadFailed: 'Modelle können nicht geladen werden',
  otherProviders: 'ANDERE',
  reasoning: 'Schlussfolgern',
  reasoningDefault: 'Standard',
  reasoningOff: 'Aus',
  reasoningNormal: 'Normal',
  reasoningMax: 'Max',
  reasoningMinimal: 'Minimal',
  reasoningLow: 'Niedrig',
  reasoningMedium: 'Mittel',
  reasoningHigh: 'Hoch',
  reasoningXhigh: 'Extra hoch',
  reasoningNotSupported: 'Nicht unterstützt',
  reasoningUseDefault: 'Standard verwenden',
  settingsTitle: 'Einstellungen',
  appearance: 'Erscheinungsbild',
  colorTheme: 'Farbthema',
  language: 'Sprache',
  legal: 'Rechtliches',
  termsOfService: 'Nutzungsbedingungen',
  privacyPolicy: 'Datenschutzerklärung',
  voiceSection: 'Sprachausgabe',
  autoReadResponses: 'Antworten automatisch vorlesen',
  autoReadResponsesSubtitle:
      'Wenn deaktiviert, tippen Sie auf das Lautsprechersymbol unter einer Nachricht, um sie anzuhören.',
  readAloud: 'Vorlesen',
  connectionSection: 'Verbindung',
  restartServer: 'Server neu starten',
  restartServerSubtitle: 'Startet den OSIA-Server aus der Ferne neu.',
  reconnecting: 'Wiederverbinden…',
  reconnected: 'Wieder verbunden',
  serverRestarted: 'Server neu gestartet',
  serverRestartFailed:
      'Neustart des Servers fehlgeschlagen. Bitte versuchen Sie es erneut.',
  disconnect: 'Trennen',
  disconnectSubtitle:
      'Löscht Ihr Token und kehrt zum Verbindungsbildschirm zurück.',
  disconnectConfirmTitle: 'Verbindung trennen?',
  disconnectConfirmBody:
      'Ihr Token wird von diesem Gerät gelöscht. Ihr Thema und Ihre Sprache bleiben erhalten.',
  makeDonation: 'Spenden',
  linkOpenFailed: 'Der Link konnte nicht geöffnet werden.',
  appearanceSub: 'Themenfarbe der gesamten App',
  languageSub: 'Sprache der Benutzeroberfläche',
  voiceSectionSub: 'Wie OSIA Antworten vorliest',
  providersSub: 'Schlüssel für KI, Stimme, Transkription',
  legalSub: 'Nutzungsbedingungen und Datenschutz',
  connectionSectionSub: 'Verbindung zum PC verwalten',
  memoryTitle: 'Speicher',
  localMemories:
      'Lokale Erinnerungen, mit denen OSIA Aktionen und Antworten personalisiert.',
  noMemoriesYet: 'Noch keine Erinnerungen',
  refresh: 'Aktualisieren',
  clearAll: 'Alle löschen',
  memorySaved: 'Erinnerung gespeichert',
  memoryDeleted: 'Erinnerung gelöscht',
  memoryCleared: 'Speicher gelöscht',
  memoryError: 'Speicherfehler',
  connectedRequired:
      'Verbinden Sie sich mit dem PC, um den Speicher zu verwalten.',
  memoryClearConfirm:
      'Alle lokalen Erinnerungen vom PC löschen? Dies kann nicht rückgängig gemacht werden.',
  memoryEditTitle: 'Erinnerung bearbeiten',
  memoryNewTitle: 'Neue Erinnerung',
  memoryTitleField: 'Titel',
  memoryKeyField: 'Schlüssel',
  memoryValueField: 'Wert',
  memoryTypeField: 'Typ',
  memoryCategoryField: 'Kategorie',
  memoryKindField: 'Werttyp',
  memoryRequiredFields: 'Titel, Schlüssel und Wert sind erforderlich.',
  providersTitle: 'APIs & Anbieter',
  configureProviders: 'APIs & Anbieter konfigurieren',
  liveApi: 'Live-API',
  liveApiNotice: 'Wenn aktiviert, werden STT und TTS automatisch deaktiviert.',
  comingSoon: 'Bald verfügbar',
  notificationsSection: 'Benachrichtigungen',
  notificationsSectionSub: 'Geplante Aufgaben und Erinnerungen',
  osiaNotifications: 'OSIA-Benachrichtigungen',
  osiaNotificationsSubtitle:
      'Erhalte sichere Hinweise, wenn geplante Aufgaben enden oder fehlschlagen.',
  notificationPermissionDenied:
      'Benachrichtigungen sind blockiert. Du kannst sie in den Systemeinstellungen aktivieren.',
  backgroundConnection: 'OSIA im Hintergrund verbunden halten',
  backgroundConnectionSubtitle:
      'Zeigt eine dauerhafte Benachrichtigung und hält die mobile Verbindung aktiv.',
  backgroundConnectionUnavailable:
      'Die Hintergrundverbindung konnte nicht gestartet werden. Prüfe Benachrichtigungen und Akku-Einstellungen.',
  catVoiceToVoice: 'Sprache-zu-Sprache (Live-API)',
  catVoiceToVoiceSub: 'Gesprochener Echtzeit-Dialog mit OSIA',
  catAiProviders: 'KI-Anbieter',
  catAiProvidersSub: 'API-Schlüssel für Chat-KI-Modelle',
  catTtsProviders: 'Sprachanbieter (TTS)',
  catTtsProvidersSub: 'Stimmen, die Antworten vorlesen',
  catSttProviders: 'Whisper-Anbieter (STT)',
  catSttProvidersSub: 'Wandelt Ihre Sprache in Text um',
  liveapiDesc:
      'Sprechen Sie natürlich und hören Sie OSIA in Echtzeit antworten, ohne separaten Transkriptionsschritt. Fügen Sie den API-Schlüssel des Anbieters hinzu, den Sie für Live-Stimme verwenden möchten.',
  aiProvidersDesc:
      'Verbinden Sie die KI-Anbieter, die OSIAs Chat und Schlussfolgern antreiben. Fügen Sie für jeden Anbieter, den Sie aktivieren möchten, einen API-Schlüssel ein — die Schlüssel werden auf Ihrem Gerät gespeichert.',
  voiceProvidersDesc:
      'Wählen Sie, wie OSIA seine Antworten vorliest. Lokale Stimmen laufen kostenlos auf Ihrem Gerät; Cloud-Stimmen benötigen den API-Schlüssel des jeweiligen Anbieters.',
  whisperProvidersDesc:
      'Wählen Sie, wie OSIA Ihre Sprache in Text umwandelt. faster-whisper läuft lokal und kostenlos, während Groq Whisper einen API-Schlüssel benötigt.',
  personalityDesc:
      'Geben Sie OSIA einen beständigen Charakter und fügen Sie eigene Skills hinzu, die es nutzen kann. Sie prägen, wie OSIA spricht und welche zusätzlichen Fähigkeiten es hat.',
  heartbeatDesc:
      'Lassen Sie OSIA CPU, Arbeitsspeicher, Festplatte und Temperaturen Ihres Geräts überwachen. Es kann Sie laut warnen, wenn ein Messwert einen von Ihnen festgelegten Schwellenwert überschreitet.',
  apiKey: 'API-Schlüssel',
  apiKeyHint: 'API-Schlüssel einfügen',
  getApiKey: 'API-Schlüssel erhalten',
  apiKeySaved: 'API-Schlüssel gespeichert',
  localProviderNoKey:
      'Dieser Anbieter läuft lokal — kein API-Schlüssel erforderlich.',
  localLabel: 'Lokal',
  showApiKey: 'Schlüssel anzeigen',
  hideApiKey: 'Schlüssel ausblenden',
  apiKeyConfigured: 'Schlüssel konfiguriert',
  apiKeyReplaceHint: 'Neuen Schlüssel eingeben, um ihn zu ersetzen',
  removeApiKey: 'Schlüssel entfernen',
  apiKeyRemoved: 'API-Schlüssel entfernt',
  fallbackKeys: 'Ersatzschlüssel',
  addFallbackKey: 'Ersatzschlüssel hinzufügen',
  editFallbackKey: 'Ersatzschlüssel bearbeiten',
  deleteFallbackKey: 'Ersatzschlüssel löschen',
  fallbackKeyIndex: 'Schlüssel {n}',
  visionAssociated: 'Verknüpftes Vision-Modell',
  visionProvider: 'Vision-Anbieter',
  visionModel: 'Vision-Modell',
  visionHint:
      'Nützlich, wenn Ihr Hauptmodell keine Bilder verarbeiten kann (z. B. DeepSeek, Groq, Llama, Mistral).',
  ttsProviderLabel: 'TTS-Anbieter',
  ttsVoiceLabel: 'Stimme',
  sttProviderLabel: 'Spracherkennungs-Anbieter',
  ttsVoiceAutomatic: 'Automatisch',
  add: 'Hinzufügen',
  edit: 'Bearbeiten',
  close: 'Schließen',
  loading: 'Wird geladen…',
  catScheduledTasks: 'Geplante Aufgaben',
  catScheduledTasksSub: 'Wiederkehrende oder einmalige automatische Aufgaben',
  catAiHierarchy: 'KI-Hierarchie',
  catAiHierarchySub: 'Modell-Fallback-Ketten für schwere / mittlere Aufgaben',
  catPersonalitySkills: 'Persönlichkeit & Skills',
  catPersonalitySkillsSub: 'OSIAs Identität und eigene Skills',
  cronTitle: 'Geplante Aufgaben',
  cronSubtitle:
      'Lassen Sie OSIA eine Aufgabe zu festgelegten Zeiten von selbst ausführen — eine tägliche Zusammenfassung, eine stündliche Prüfung. Beschreiben Sie sie in einfacher Sprache und wählen Sie ein wiederkehrendes Intervall oder ein einmaliges Datum.',
  cronEmpty: 'Noch keine geplanten Aufgaben.',
  cronAddTask: 'Aufgabe hinzufügen',
  cronEditTask: 'Aufgabe bearbeiten',
  cronTaskLabel: 'Aufgabe',
  cronTaskHint: 'Was soll OSIA tun?',
  cronType: 'Typ',
  cronTypeRepeat: 'Wiederholen',
  cronTypeOnce: 'Einmal',
  cronFrequency: 'Häufigkeit',
  cronUnitMinutes: 'Minuten',
  cronUnitHours: 'Stunden',
  cronUnitDays: 'Tage',
  cronModeDaily: 'Täglich um',
  cronDate: 'Datum',
  cronTime: 'Uhrzeit',
  cronInvalid: 'Geben Sie eine Aufgabe und einen gültigen Zeitplan ein.',
  cronModelDefault: 'Standard-/aktuelles Modell',
  cronModelInvalid: 'Wählen Sie ein gültiges Modell.',
  cronEveryMinutesTemplate: 'Alle {n} Min',
  cronEveryHoursTemplate: 'Alle {n} Std',
  cronEveryDaysTemplate: 'Alle {n} Tage',
  cronDailyAtTemplate: 'Täglich um {t}',
  cronOnceTemplate: 'Einmal · {d} {t}',
  cronLinkedConversation: 'Verknüpfte Unterhaltung',
  cronNoConversation: 'Keine (neue Unterhaltung)',
  cronLoadingConversations: 'Wird geladen…',
  hierarchyTitle: 'KI-Hierarchie',
  hierarchySubtitle:
      'Leiten Sie die Arbeit durch eine geordnete Liste von Modellen statt durch ein einzelnes. Stößt ein Modell auf einen technischen Fehler, wechselt OSIA automatisch zum nächsten in der Kette.',
  hierarchyEnable: 'Hierarchie aktivieren',
  hierarchyActive: 'KI-Hierarchie aktiv',
  hierarchyHeavy: 'Schwere Aufgaben',
  hierarchyHeavySub: 'Code, Debugging, komplexes Denken, tiefe Recherche.',
  hierarchyMedium: 'Mittlere Aufgaben',
  hierarchyMediumSub:
      'Alles andere: Navigation, Zusammenfassungen, kurze Aufgaben.',
  hierarchyAddModel: 'Modell hinzufügen',
  hierarchyEmpty: 'Kein Modell in dieser Kette.',
  hierarchyNoProviders: 'Konfigurieren Sie zuerst einen KI-Anbieter.',
  moveUp: 'Nach oben',
  moveDown: 'Nach unten',
  personalitySkillsTitle: 'Persönlichkeit & Skills',
  tabPersonality: 'Persönlichkeit',
  tabSkills: 'Skills',
  personalityHint: 'Beschreiben Sie, wie sich OSIA verhalten soll…',
  personalitySaved: 'Persönlichkeit gespeichert',
  skillsEmpty: 'Noch keine Skills.',
  skillAdd: 'Skill hinzufügen',
  skillNewTitle: 'Neuer Skill',
  skillNewHint: 'Skill-Name',
  skillContentHint: 'Skill-Anweisungen (Markdown)…',
  skillSaved: 'Skill gespeichert',
  skillDeleteTitle: 'Skill löschen?',
  skillDeleteBodyTemplate: '„{name}" wird dauerhaft gelöscht.',
  catSystemStatus: 'Systemstatus',
  catSystemStatusSub: 'CPU, Arbeitsspeicher, Festplatte und Temperaturen live',
  heartbeatMonitoring: 'Überwachung aktivieren',
  heartbeatInterval: 'Intervall (Sekunden)',
  heartbeatIntervalRange: 'Zwischen 10 und 300 Sekunden',
  heartbeatChecksHeader: 'Warnchecks',
  heartbeatUsageThresholdHint:
      'Warnen, wenn die Auslastung diesen % überschreitet.',
  heartbeatDiskThresholdHint:
      'Warnen, wenn der freie Speicher unter diesen % fällt.',
  heartbeatNetworkHint: 'Warnen, wenn die Verbindungsprüfung fehlschlägt.',
  heartbeatWaiting: 'Warte auf Daten…',
  systemMetricsHeader: 'Live-Metriken',
  metricCpu: 'CPU',
  metricRam: 'RAM',
  metricDisk: 'Festplatte',
  metricNetwork: 'Netzwerk',
  metricCpuTemp: 'CPU-Temp.',
  metricGpuTemp: 'GPU-Temp.',
  sectionGeneral: 'Allgemein',
  timeFormatLabel: 'Zeitformat',
  autonomousTitle: 'Autonom',
  autonomousObjectiveLabel: 'Ziel',
  autonomousObjectiveHint: 'Beschreibe, was OSIA eigenständig erledigen soll…',
  autonomousPickModel: 'Modell wählen',
  autonomousNoConfiguredModels:
      'Kein konfiguriertes Modell — füge zuerst unter Anbieter einen API-Schlüssel hinzu.',
  autonomousStart: 'Starten',
  autonomousPlanning: 'Planung…',
  autonomousRunning: 'Läuft',
  autonomousInterrupt: 'Pause',
  autonomousAbort: 'Abbrechen',
  autonomousIdle: 'Keine autonome Aufgabe aktiv',
  autonomousBusy: 'Eine autonome Aufgabe läuft bereits.',
  autonomousDone: 'Aufgabe abgeschlossen',
  autonomousFailed: 'Aufgabe fehlgeschlagen',
  autonomousAborted: 'Aufgabe abgebrochen',
  autonomousInterrupted: 'Pausiert',
  autonomousResume: 'Fortsetzen',
  autonomousPhase: 'Phase',
  autonomousObjectiveRequired: 'Gib zuerst ein Ziel ein.',
  autonomousModelRequired: 'Wähle zuerst ein Modell.',
  autonomousTasksTemplate: '{done} / {total} Aufgaben',
  // ── MCP / Connectors (WOR-44 Phase 4) ──
  catConnectors: 'MCP / Konnektoren',
  catConnectorsSub:
      'Externe Tools und Dienste als zusätzliche Agent-Werkzeuge verbinden.',
  connectorsDesc:
      'MCP-Server (Model Context Protocol) stellen Werkzeuge bereit, die OSIA nutzen kann — im Web suchen, Dateien lesen, Repos verwalten und mehr. Verbinden Sie einen vorkonfigurierten Server mit einem Tippen (einige benötigen ein API-Token) oder fügen Sie einen eigenen hinzu. Verbundene Werkzeuge stehen OSIA mit derselben Sicherheit wie integrierte Werkzeuge zur Verfügung.',
  connectorLabel: 'Konnektor',
  mcpConnect: 'Verbinden',
  mcpDisconnect: 'Trennen',
  mcpSignOut: 'Abmelden',
  mcpSwitchAccount: 'Konto wechseln',
  mcpCancel: 'Abbrechen',
  mcpOpeningBrowser: 'Browser wird geöffnet…',
  mcpStatusConnected: 'Verbunden',
  mcpStatusConnecting: 'Verbinde…',
  mcpStatusDisconnected: 'Getrennt',
  mcpStatusFailed: 'Fehlgeschlagen',
  mcpOauthSoon: 'OAuth — bald',
  mcpHttpSoon: 'HTTP — bald',
  mcpOauthConnectOnPc: 'Am PC verbinden',
  mcpOauthConnectOnPcHint:
      'Die OAuth-Anmeldung erfolgt in der Desktop-App; der Status wird hier nach dem Verbinden aktualisiert.',
  mcpCopyToken: 'Token kopieren',
  mcpTokenCopied: 'Token kopiert',
  mcpTokenLabel: 'API-Token / -Schlüssel',
  mcpTokenHint: 'Token einfügen (lokal gespeichert, nie synchronisiert)…',
  mcpSlackTeam: 'Slack-Team-ID',
  mcpSlackTeamPh: 'z. B. T01234567',
  mcpAddCustom: 'Eigenen Server hinzufügen',
  mcpRemove: 'Entfernen',
  mcpDescGithub: 'Repos, Issues und Pull Requests auf GitHub.',
  mcpDescSlack: 'Nachrichten in Ihrem Slack-Workspace lesen und posten.',
  mcpDescNotion: 'Seiten und Datenbanken in Ihrem Notion-Workspace.',
  mcpDescLinear: 'Issues, Projekte und Zyklen in Linear.',
  mcpDescGdrive: 'Dateien in Google Drive durchsuchen und lesen.',
  mcpDescGmail: 'E-Mails in Gmail durchsuchen und verwalten.',
  gmailRestName: 'Gmail',
  gmailRestTitle: 'Native Gmail REST / E-Mail-Suche und -Verwaltung',
  gmailRestConfigureOnPc: 'Am PC konfigurieren',
  gmailRestDisconnectOnPc: 'Am PC trennen',
  gmailRestElevateOnPc: 'OSIA-Berechtigungen am PC erweitern',
  gmailRestSetupGuideOnPc: 'Setup-Anleitung am PC verfügbar',
  gmailRestReadOnly: 'Schreibgeschützt',
  gmailRestDraftsSend: 'Entwürfe/Senden',
  gmailRestMailboxActions: 'Postfachaktionen',
  gmailRestConnected: 'Verbunden',
  gmailRestNotConnected: 'Nicht verbunden',
  mcpCustomTitle: 'Eigenen MCP-Server hinzufügen',
  mcpCustomHint:
      'Fügen Sie einen lokalen stdio-Befehl hinzu (z. B. npx …). Remote-Server (HTTP) folgen in einem späteren Update. Das Hinzufügen verbindet nicht — verbinden Sie ihn danach ausdrücklich.',
  mcpFieldName: 'Name',
  mcpFieldNamePh: 'z. B. Mein Server',
  mcpFieldCommand: 'Befehl (stdio)',
  mcpFieldCommandPh: 'z. B. npx -y @scope/server …',
  mcpFieldTokenOptional: 'Token (optional)',
  mcpFieldTokenPh: 'Lokal gespeichert, nie synchronisiert…',
  mcpFieldTokenEnvOptional: 'Token-Umgebungsvariable (stdio, optional)',
  mcpFieldTokenEnvPh: 'z. B. MY_API_KEY',
  mcpErrName: 'Bitte einen Namen eingeben.',
  mcpErrCommand: 'Bitte einen Befehl eingeben.',
  mcpAdd: 'Hinzufügen',
  mcpConfirmTitleTemplate: '{server} möchte {tool} ausführen',
  mcpConfirmWriteWarning:
      'Dieses Tool kann Daten erstellen, ändern oder löschen. Bestätige nur Aktionen, die du selbst gestartet hast und denen du vertraust.',
  mcpConfirmArgsLabel: 'Argumente',
  mcpConfirmApprove: 'Zulassen',
  mcpConfirmDecline: 'Ablehnen',
  mcpConfirmWritesLabel: 'Connector-Schreibaktionen automatisch erlauben',
  mcpConfirmWritesSub:
      'Aus fragt vor Connector-Schreibaktionen. Ein fuehrt sie ohne lokale Bestaetigung aus.',
  mcpUnattendedWritesLabel: 'Unbeaufsichtigte Schreibvorgänge erlauben',
  mcpUnattendedWritesSub:
      'Aus blockiert unbeaufsichtigte Connector-Schreibaktionen ohne Bestaetigungsgeraet. Ein erlaubt sie.',
  themeViolet: 'Violett',
  themeRose: 'Rosé',
  themeNoir: 'Schwarz',
  themeBlanc: 'Weiß',
  themeDore: 'Gold',
);

// ── Spanish ───────────────────────────────────────────────────────────────

const OsiaStrings osiaStringsEs = OsiaStrings(
  languageCode: 'es',
  languageName: 'Español',
  cancel: 'Cancelar',
  delete: 'Eliminar',
  retry: 'Reintentar',
  save: 'Guardar',
  enterYourToken: 'Introduce tu token',
  connect: 'Conectar',
  connectingEllipsis: 'Conectando…',
  tokenRequired: 'Por favor, introduce tu token.',
  connectionFailed:
      'Error de conexión. Comprueba tu token e inténtalo de nuevo.',
  invalidToken: 'Token no válido. Compruébalo e inténtalo de nuevo.',
  tokenHint: 'Tu token está en los ajustes de OSIA en tu PC',
  pcOffline:
      'Tu PC está desconectado. Inicia OSIA en tu PC y vuelve a intentarlo.',
  conversations: 'Conversaciones',
  newChat: 'Nuevo chat',
  noConversationsYet: 'Aún no hay conversaciones',
  sayHello: 'Saluda a OSIA',
  typeMessageOrMic: 'Escribe un mensaje o usa el micrófono.',
  messageHint: 'Mensaje a OSIA…',
  deleteConversationTitle: '¿Eliminar conversación?',
  deleteConversationBodyTemplate: '«{title}» se eliminará permanentemente.',
  rename: 'Cambiar nombre',
  renameConversationTitle: 'Cambiar nombre de la conversación',
  renameConversationHint: 'Nombre de la conversación',
  today: 'Hoy',
  yesterday: 'Ayer',
  daysAgoTemplate: 'Hace {n} días',
  untitled: 'Sin título',
  connected: 'Conectado',
  connectingStatus: 'Conectando…',
  disconnected: 'Desconectado',
  micPermissionDenied:
      'Permiso de micrófono denegado. Abre los ajustes para permitirlo.',
  micUnavailable: 'No se puede acceder al micrófono.',
  openSettingsAction: 'Ajustes',
  attachFile: 'Adjuntar un archivo',
  filePickFailedTemplate: 'No se pudo seleccionar el archivo: {error}',
  fileReadFailedTemplate: 'No se pudo leer el archivo: {error}',
  fileEmpty: 'Archivo vacío o inaccesible.',
  analyzeImagePrompt: 'Analiza esta imagen.',
  hereIsFileTemplate: 'Aquí está el archivo {name}.',
  model: 'Modelo',
  settingsTooltip: 'Ajustes',
  noResponseError: 'OSIA no respondió.',
  relayChunkUnsupportedError:
      'Actualiza OSIA en el PC y el teléfono para enviar este mensaje grande.',
  relayFrameTooLargeError: 'El mensaje cifrado del relay es demasiado grande.',
  relayChunkTransferFailedError: 'Falló la transferencia cifrada del relay.',
  relayE2eDecryptFailedError: 'Falló la verificación del cifrado del relay.',
  relayUnreachableError: 'No se puede acceder al relay público.',
  osiaWorkingBackground: 'OSIA está trabajando en segundo plano',
  scheduledTaskCompleted: 'Tarea programada completada',
  scheduledTaskFailed: 'Tarea programada fallida',
  reminderNotification: 'Recordatorio OSIA',
  taskCompleted: 'Tarea completada',
  availableModels: 'Modelos disponibles',
  noModelsReceived: 'No se recibieron modelos del servidor.',
  modelsLoadFailed: 'No se pueden cargar los modelos',
  otherProviders: 'OTROS',
  reasoning: 'Razonamiento',
  reasoningDefault: 'Predeterminado',
  reasoningOff: 'Desactivado',
  reasoningNormal: 'Normal',
  reasoningMax: 'Máximo',
  reasoningMinimal: 'Mínimo',
  reasoningLow: 'Bajo',
  reasoningMedium: 'Medio',
  reasoningHigh: 'Alto',
  reasoningXhigh: 'Muy alto',
  reasoningNotSupported: 'No compatible',
  reasoningUseDefault: 'Usar predeterminado',
  settingsTitle: 'Ajustes',
  appearance: 'Apariencia',
  colorTheme: 'Tema de color',
  language: 'Idioma',
  legal: 'Legal',
  termsOfService: 'Términos de servicio',
  privacyPolicy: 'Política de privacidad',
  voiceSection: 'Voz',
  autoReadResponses: 'Leer las respuestas en voz alta automáticamente',
  autoReadResponsesSubtitle:
      'Si está desactivado, toca el icono del altavoz bajo un mensaje para escucharlo.',
  readAloud: 'Leer en voz alta',
  connectionSection: 'Conexión',
  restartServer: 'Reiniciar servidor',
  restartServerSubtitle: 'Reinicia el servidor OSIA de forma remota.',
  reconnecting: 'Reconectando…',
  reconnected: 'Reconectado',
  serverRestarted: 'Servidor reiniciado',
  serverRestartFailed: 'No se pudo reiniciar el servidor. Inténtalo de nuevo.',
  disconnect: 'Desconectar',
  disconnectSubtitle: 'Borra tu token y vuelve a la pantalla de conexión.',
  disconnectConfirmTitle: '¿Desconectar?',
  disconnectConfirmBody:
      'Tu token se borrará de este dispositivo. Tu tema e idioma se conservan.',
  makeDonation: 'Hacer una donación',
  linkOpenFailed: 'No se pudo abrir el enlace.',
  appearanceSub: 'Color del tema de la app',
  languageSub: 'Idioma de la interfaz',
  voiceSectionSub: 'Cómo OSIA lee las respuestas',
  providersSub: 'Claves de IA, voz y transcripción',
  legalSub: 'Términos y privacidad',
  connectionSectionSub: 'Gestiona el enlace con tu PC',
  memoryTitle: 'Memoria',
  localMemories:
      'Memorias locales que OSIA usa para personalizar acciones y respuestas.',
  noMemoriesYet: 'Aún no hay memorias',
  refresh: 'Actualizar',
  clearAll: 'Borrar todo',
  memorySaved: 'Memoria guardada',
  memoryDeleted: 'Memoria eliminada',
  memoryCleared: 'Memoria borrada',
  memoryError: 'Error de memoria',
  connectedRequired: 'Conéctate al PC para gestionar la memoria.',
  memoryClearConfirm:
      '¿Borrar todas las memorias locales del PC? Esta acción no se puede deshacer.',
  memoryEditTitle: 'Editar memoria',
  memoryNewTitle: 'Nueva memoria',
  memoryTitleField: 'Título',
  memoryKeyField: 'Clave',
  memoryValueField: 'Valor',
  memoryTypeField: 'Tipo',
  memoryCategoryField: 'Categoría',
  memoryKindField: 'Tipo de valor',
  memoryRequiredFields: 'Título, clave y valor son obligatorios.',
  providersTitle: 'API y proveedores',
  configureProviders: 'Configurar API y proveedores',
  liveApi: 'API Live',
  liveApiNotice:
      'Cuando está activado, STT y TTS se desactivan automáticamente.',
  comingSoon: 'Próximamente',
  notificationsSection: 'Notificaciones',
  notificationsSectionSub: 'Tareas programadas y recordatorios',
  osiaNotifications: 'Notificaciones de OSIA',
  osiaNotificationsSubtitle:
      'Recibe avisos seguros cuando una tarea programada termine o falle.',
  notificationPermissionDenied:
      'Las notificaciones están bloqueadas. Puedes activarlas en los ajustes del sistema.',
  backgroundConnection: 'Mantener OSIA conectado en segundo plano',
  backgroundConnectionSubtitle:
      'Muestra una notificación permanente y mantiene activo el enlace móvil.',
  backgroundConnectionUnavailable:
      'No se pudo iniciar la conexión en segundo plano. Revisa los permisos de notificación y batería.',
  catVoiceToVoice: 'Voz a voz (API Live)',
  catVoiceToVoiceSub: 'Conversación hablada en tiempo real con OSIA',
  catAiProviders: 'Proveedores de IA',
  catAiProvidersSub: 'Claves API para modelos de chat de IA',
  catTtsProviders: 'Proveedores de voz (TTS)',
  catTtsProvidersSub: 'Voces que leen las respuestas en voz alta',
  catSttProviders: 'Proveedores Whisper (STT)',
  catSttProvidersSub: 'Convierte tu voz en texto',
  liveapiDesc:
      'Habla con naturalidad y escucha a OSIA responder en tiempo real, sin un paso de transcripción aparte. Añade la clave API del proveedor que quieras usar para la voz en directo.',
  aiProvidersDesc:
      'Conecta los proveedores de IA que impulsan el chat y el razonamiento de OSIA. Pega una clave API para cada proveedor que quieras activar — las claves se guardan en tu dispositivo.',
  voiceProvidersDesc:
      'Elige cómo OSIA lee sus respuestas en voz alta. Las voces locales funcionan gratis en tu dispositivo; las voces en la nube necesitan la clave API del proveedor correspondiente.',
  whisperProvidersDesc:
      'Elige cómo OSIA convierte tu voz en texto. faster-whisper funciona localmente y gratis, mientras que Groq Whisper necesita una clave API.',
  personalityDesc:
      'Da a OSIA un carácter coherente y añade skills personalizados que pueda usar. Estos definen cómo habla OSIA y qué capacidades adicionales tiene.',
  heartbeatDesc:
      'Deja que OSIA vigile la CPU, la memoria, el disco y las temperaturas de tu dispositivo. Puede avisarte en voz alta cuando una métrica supere un umbral que tú definas.',
  apiKey: 'Clave API',
  apiKeyHint: 'Pega tu clave API',
  getApiKey: 'Obtener clave API',
  apiKeySaved: 'Clave API guardada',
  localProviderNoKey:
      'Este proveedor funciona localmente — no requiere clave API.',
  localLabel: 'Local',
  showApiKey: 'Mostrar clave',
  hideApiKey: 'Ocultar clave',
  apiKeyConfigured: 'Clave configurada',
  apiKeyReplaceHint: 'Introduce una nueva clave para reemplazarla',
  removeApiKey: 'Eliminar clave',
  apiKeyRemoved: 'Clave API eliminada',
  fallbackKeys: 'Claves de respaldo',
  addFallbackKey: 'Añadir clave de respaldo',
  editFallbackKey: 'Editar clave de respaldo',
  deleteFallbackKey: 'Eliminar clave de respaldo',
  fallbackKeyIndex: 'Clave {n}',
  visionAssociated: 'Modelo de visión asociado',
  visionProvider: 'Proveedor de visión',
  visionModel: 'Modelo de visión',
  visionHint:
      'Útil si tu modelo principal no admite imágenes (p. ej. DeepSeek, Groq, Llama, Mistral).',
  ttsProviderLabel: 'Proveedor de TTS',
  ttsVoiceLabel: 'Voz',
  sttProviderLabel: 'Proveedor de voz a texto',
  ttsVoiceAutomatic: 'Automático',
  add: 'Añadir',
  edit: 'Editar',
  close: 'Cerrar',
  loading: 'Cargando…',
  catScheduledTasks: 'Tareas programadas',
  catScheduledTasksSub: 'Tareas automáticas recurrentes o únicas',
  catAiHierarchy: 'Jerarquía de IA',
  catAiHierarchySub: 'Cadenas de modelos para tareas pesadas / medianas',
  catPersonalitySkills: 'Personalidad y Skills',
  catPersonalitySkillsSub: 'La identidad de OSIA y sus skills personalizados',
  cronTitle: 'Tareas programadas',
  cronSubtitle:
      'Deja que OSIA ejecute una tarea por su cuenta a horas fijas — un resumen diario, una comprobación cada hora. Descríbela en lenguaje natural y elige un intervalo recurrente o una fecha única.',
  cronEmpty: 'Aún no hay tareas programadas.',
  cronAddTask: 'Añadir una tarea',
  cronEditTask: 'Editar tarea',
  cronTaskLabel: 'Tarea',
  cronTaskHint: '¿Qué debe hacer OSIA?',
  cronType: 'Tipo',
  cronTypeRepeat: 'Repetir',
  cronTypeOnce: 'Una vez',
  cronFrequency: 'Frecuencia',
  cronUnitMinutes: 'Minutos',
  cronUnitHours: 'Horas',
  cronUnitDays: 'Días',
  cronModeDaily: 'Cada día a las',
  cronDate: 'Fecha',
  cronTime: 'Hora',
  cronInvalid: 'Introduce una tarea y un horario válido.',
  cronModelDefault: 'Modelo predeterminado/actual',
  cronModelInvalid: 'Elige un modelo válido.',
  cronEveryMinutesTemplate: 'Cada {n} min',
  cronEveryHoursTemplate: 'Cada {n} h',
  cronEveryDaysTemplate: 'Cada {n} d',
  cronDailyAtTemplate: 'Cada día a las {t}',
  cronOnceTemplate: 'Una vez · {d} {t}',
  cronLinkedConversation: 'Conversación vinculada',
  cronNoConversation: 'Ninguna (nueva conversación)',
  cronLoadingConversations: 'Cargando…',
  hierarchyTitle: 'Jerarquía de IA',
  hierarchySubtitle:
      'Dirige el trabajo a través de una lista ordenada de modelos en lugar de uno solo. Si un modelo sufre un error técnico, OSIA recurre automáticamente al siguiente de la cadena.',
  hierarchyEnable: 'Activar jerarquía',
  hierarchyActive: 'Jerarquía IA activa',
  hierarchyHeavy: 'Tareas pesadas',
  hierarchyHeavySub:
      'Código, depuración, razonamiento complejo, investigación profunda.',
  hierarchyMedium: 'Tareas medianas',
  hierarchyMediumSub: 'Todo lo demás: navegación, resúmenes, tareas cortas.',
  hierarchyAddModel: 'Añadir un modelo',
  hierarchyEmpty: 'No hay modelos en esta cadena.',
  hierarchyNoProviders: 'Configura primero un proveedor de IA.',
  moveUp: 'Subir',
  moveDown: 'Bajar',
  personalitySkillsTitle: 'Personalidad y Skills',
  tabPersonality: 'Personalidad',
  tabSkills: 'Skills',
  personalityHint: 'Describe cómo debe comportarse OSIA…',
  personalitySaved: 'Personalidad guardada',
  skillsEmpty: 'Aún no hay skills.',
  skillAdd: 'Añadir un skill',
  skillNewTitle: 'Nuevo skill',
  skillNewHint: 'Nombre del skill',
  skillContentHint: 'Instrucciones del skill (Markdown)…',
  skillSaved: 'Skill guardado',
  skillDeleteTitle: '¿Eliminar skill?',
  skillDeleteBodyTemplate: '«{name}» se eliminará permanentemente.',
  catSystemStatus: 'Estado del sistema',
  catSystemStatusSub: 'CPU, memoria, disco y temperaturas en directo',
  heartbeatMonitoring: 'Activar la supervisión',
  heartbeatInterval: 'Intervalo (segundos)',
  heartbeatIntervalRange: 'Entre 10 y 300 segundos',
  heartbeatChecksHeader: 'Comprobaciones de alerta',
  heartbeatUsageThresholdHint: 'Alertar cuando el uso supere este %.',
  heartbeatDiskThresholdHint: 'Alertar cuando el espacio libre baje de este %.',
  heartbeatNetworkHint: 'Alertar cuando falle la comprobación de conexión.',
  heartbeatWaiting: 'Esperando datos…',
  systemMetricsHeader: 'Métricas en directo',
  metricCpu: 'CPU',
  metricRam: 'RAM',
  metricDisk: 'Disco',
  metricNetwork: 'Red',
  metricCpuTemp: 'Temp. CPU',
  metricGpuTemp: 'Temp. GPU',
  sectionGeneral: 'General',
  timeFormatLabel: 'Formato de hora',
  autonomousTitle: 'Autónomo',
  autonomousObjectiveLabel: 'Objetivo',
  autonomousObjectiveHint: 'Describe lo que OSIA debe lograr por su cuenta…',
  autonomousPickModel: 'Elegir un modelo',
  autonomousNoConfiguredModels:
      'Ningún modelo configurado — añade primero una clave API en Proveedores.',
  autonomousStart: 'Iniciar',
  autonomousPlanning: 'Planificando…',
  autonomousRunning: 'En curso',
  autonomousInterrupt: 'Pausar',
  autonomousAbort: 'Abandonar',
  autonomousIdle: 'No hay ninguna tarea autónoma en curso',
  autonomousBusy: 'Ya hay una tarea autónoma en curso.',
  autonomousDone: 'Tarea completada',
  autonomousFailed: 'Tarea fallida',
  autonomousAborted: 'Tarea abandonada',
  autonomousInterrupted: 'En pausa',
  autonomousResume: 'Reanudar',
  autonomousPhase: 'Fase',
  autonomousObjectiveRequired: 'Introduce primero un objetivo.',
  autonomousModelRequired: 'Elige primero un modelo.',
  autonomousTasksTemplate: '{done} / {total} tareas',
  // ── MCP / Connectors (WOR-44 Phase 4) ──
  catConnectors: 'MCP / Conectores',
  catConnectorsSub:
      'Conecta herramientas y servicios externos como herramientas adicionales del agente.',
  connectorsDesc:
      'Los servidores MCP (Model Context Protocol) exponen herramientas que OSIA puede usar: buscar en la web, leer archivos, gestionar repos y más. Conecta un servidor preconfigurado con un toque (algunos requieren un token de API), o añade el tuyo. Las herramientas conectadas quedan disponibles para OSIA con la misma seguridad que las integradas.',
  connectorLabel: 'Conector',
  mcpConnect: 'Conectar',
  mcpDisconnect: 'Desconectar',
  mcpSignOut: 'Cerrar sesión',
  mcpSwitchAccount: 'Cambiar de cuenta',
  mcpCancel: 'Cancelar',
  mcpOpeningBrowser: 'Abriendo el navegador…',
  mcpStatusConnected: 'Conectado',
  mcpStatusConnecting: 'Conectando…',
  mcpStatusDisconnected: 'Desconectado',
  mcpStatusFailed: 'Error',
  mcpOauthSoon: 'OAuth — pronto',
  mcpHttpSoon: 'HTTP — pronto',
  mcpOauthConnectOnPc: 'Conectar en el PC',
  mcpOauthConnectOnPcHint:
      'El inicio de sesión con OAuth se realiza en la aplicación de escritorio; el estado se actualiza aquí una vez conectado.',
  mcpCopyToken: 'Copiar token',
  mcpTokenCopied: 'Token copiado',
  mcpTokenLabel: 'Token / clave de API',
  mcpTokenHint: 'Pega el token (se guarda localmente, nunca se sincroniza)…',
  mcpSlackTeam: 'ID de equipo de Slack',
  mcpSlackTeamPh: 'p. ej. T01234567',
  mcpAddCustom: 'Añadir servidor personalizado',
  mcpRemove: 'Quitar',
  mcpDescGithub: 'Repos, incidencias y pull requests en GitHub.',
  mcpDescSlack: 'Leer y publicar mensajes en tu espacio de Slack.',
  mcpDescNotion: 'Páginas y bases de datos de tu espacio de Notion.',
  mcpDescLinear: 'Incidencias, proyectos y ciclos en Linear.',
  mcpDescGdrive: 'Explorar y leer archivos en Google Drive.',
  mcpDescGmail: 'Buscar y gestionar el correo en Gmail.',
  gmailRestName: 'Gmail',
  gmailRestTitle: 'Gmail REST nativo / búsqueda y gestión de correo',
  gmailRestConfigureOnPc: 'Configurar en el PC',
  gmailRestDisconnectOnPc: 'Desconectar en el PC',
  gmailRestElevateOnPc: 'Elevar permisos de OSIA en el PC',
  gmailRestSetupGuideOnPc: 'Guía de configuración disponible en el PC',
  gmailRestReadOnly: 'Solo lectura',
  gmailRestDraftsSend: 'Borradores/envío',
  gmailRestMailboxActions: 'Acciones del buzón',
  gmailRestConnected: 'Conectado',
  gmailRestNotConnected: 'No conectado',
  mcpCustomTitle: 'Añadir un servidor MCP personalizado',
  mcpCustomHint:
      'Añade un comando stdio local (p. ej. npx …). Los servidores remotos (HTTP) llegarán en una actualización posterior. Añadir no conecta — conéctalo explícitamente después.',
  mcpFieldName: 'Nombre',
  mcpFieldNamePh: 'p. ej. Mi servidor',
  mcpFieldCommand: 'Comando (stdio)',
  mcpFieldCommandPh: 'p. ej. npx -y @scope/server …',
  mcpFieldTokenOptional: 'Token (opcional)',
  mcpFieldTokenPh: 'Se guarda localmente, nunca se sincroniza…',
  mcpFieldTokenEnvOptional: 'Variable de entorno del token (stdio, opcional)',
  mcpFieldTokenEnvPh: 'p. ej. MY_API_KEY',
  mcpErrName: 'Introduce un nombre.',
  mcpErrCommand: 'Introduce un comando.',
  mcpAdd: 'Añadir',
  mcpConfirmTitleTemplate: '{server} quiere ejecutar {tool}',
  mcpConfirmWriteWarning:
      'Esta herramienta puede crear, modificar o eliminar datos. Aprueba solo las acciones que iniciaste y en las que confías.',
  mcpConfirmArgsLabel: 'Argumentos',
  mcpConfirmApprove: 'Aprobar',
  mcpConfirmDecline: 'Rechazar',
  mcpConfirmWritesLabel: 'Autoaprobar escrituras de conectores',
  mcpConfirmWritesSub:
      'Desactivado pregunta antes de escribir. Activado ejecuta sin confirmacion local.',
  mcpUnattendedWritesLabel: 'Permitir escrituras desatendidas',
  mcpUnattendedWritesSub:
      'Desactivado bloquea escrituras sin dispositivo de confirmacion. Activado las permite.',
  themeViolet: 'Violeta',
  themeRose: 'Rosa',
  themeNoir: 'Negro',
  themeBlanc: 'Blanco',
  themeDore: 'Dorado',
);

// ── Lookup ────────────────────────────────────────────────────────────────

const List<OsiaStrings> osiaAllStrings = <OsiaStrings>[
  osiaStringsEn,
  osiaStringsFr,
  osiaStringsZh,
  osiaStringsJa,
  osiaStringsDe,
  osiaStringsEs,
];

/// Resolve a strings bundle by its language code. Falls back to English
/// for any unknown or null code.
OsiaStrings osiaStringsForCode(String? code) {
  for (final s in osiaAllStrings) {
    if (s.languageCode == code) return s;
  }
  return osiaStringsEn;
}

// ── Language controller ───────────────────────────────────────────────────

/// A [ChangeNotifier] that owns the currently active [OsiaStrings].
///
/// Mirrors [ThemeController]: the app builds one at startup, restores the
/// saved language (or detects it from the device locale on first launch),
/// and rebuilds when the user picks a new language in settings.
class LanguageController extends ChangeNotifier {
  OsiaStrings _strings;
  LanguageController({OsiaStrings initial = osiaStringsEn})
    : _strings = initial;

  OsiaStrings get strings => _strings;
  String get code => _strings.languageCode;

  void setLanguageByCode(String code) {
    final next = osiaStringsForCode(code);
    if (next.languageCode == _strings.languageCode) return;
    _strings = next;
    notifyListeners();
  }

  /// Best-match supported language for the current device locale.
  /// Defaults to English when the device language isn't supported.
  static String detectDeviceLanguage() {
    final locale = ui.PlatformDispatcher.instance.locale;
    final lang = locale.languageCode.toLowerCase();
    return osiaSupportedLanguages.contains(lang) ? lang : 'en';
  }
}

// ── Inherited strings accessor ────────────────────────────────────────────

/// Provides the active [OsiaStrings] to widgets through `OsiaL10n.of(ctx)`.
class OsiaL10n extends InheritedWidget {
  final OsiaStrings strings;

  const OsiaL10n({super.key, required this.strings, required super.child});

  static OsiaStrings of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<OsiaL10n>();
    return widget?.strings ?? osiaStringsEn;
  }

  @override
  bool updateShouldNotify(OsiaL10n old) => old.strings != strings;
}

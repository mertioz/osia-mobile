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
  final String scanQrCode;
  final String scanPairingQrTitle;
  final String scanPairingQrHint;
  final String invalidPairingQr;
  final String cameraPermissionDeniedForPairing;
  final String cameraUnavailableForPairing;

  // ── Isolated reviewer mode ──
  final String reviewModeLabel;
  final String reviewModeEntryHint;
  final String reviewModeDescription;
  final String reviewModeDemoData;
  final String reviewModeLocalReply;
  final String reviewModeUnavailable;
  final String reviewModeInputHint;
  final String reviewModeConnectionStatus;
  final String reviewModeExit;
  final String reviewModeSendMessage;
  final String reviewModeWelcome;
  final String reviewModeSecondConversation;
  final String reviewModeSampleQuestion;
  final String reviewModeSampleAnswer;
  final String reviewModePlanQuestion;
  final String reviewModePlanAnswer;

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

  // ── TTS / STT selectors (WOR-78.2) ──
  final String ttsProviderLabel;
  final String ttsVoiceLabel;
  final String sttProviderLabel;
  final String sttFallbackProviderLabel;
  final String sttNoFallback;
  final String sttNoLocalModels;
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
  final String skillActivationRejected;
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
  final String autonomousModelFallback;
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
  final String gmailRestReconnect;
  final String gmailRestPcHostedAuth;
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
  final String themeRed;
  final String themeGreen;

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
    required this.scanQrCode,
    required this.scanPairingQrTitle,
    required this.scanPairingQrHint,
    required this.invalidPairingQr,
    required this.cameraPermissionDeniedForPairing,
    required this.cameraUnavailableForPairing,
    required this.reviewModeLabel,
    required this.reviewModeEntryHint,
    required this.reviewModeDescription,
    required this.reviewModeDemoData,
    required this.reviewModeLocalReply,
    required this.reviewModeUnavailable,
    required this.reviewModeInputHint,
    required this.reviewModeConnectionStatus,
    required this.reviewModeExit,
    required this.reviewModeSendMessage,
    required this.reviewModeWelcome,
    required this.reviewModeSecondConversation,
    required this.reviewModeSampleQuestion,
    required this.reviewModeSampleAnswer,
    required this.reviewModePlanQuestion,
    required this.reviewModePlanAnswer,
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
    required this.ttsProviderLabel,
    required this.ttsVoiceLabel,
    required this.sttProviderLabel,
    required this.sttFallbackProviderLabel,
    required this.sttNoFallback,
    required this.sttNoLocalModels,
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
    required this.skillActivationRejected,
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
    required this.autonomousModelFallback,
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
    required this.gmailRestReconnect,
    required this.gmailRestPcHostedAuth,
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
    required this.themeRed,
    required this.themeGreen,
  });

  // ── Guide shell (EN/FR canonical, English fallback elsewhere) ──
  String get guideTitle =>
      languageCode == 'fr' ? 'Guide OSIA Mobile' : 'OSIA Mobile guide';
  String get guideClose =>
      languageCode == 'fr' ? 'Fermer le guide' : 'Close guide';
  String get guideChooseJourney => languageCode == 'fr'
      ? 'Choisissez votre parcours'
      : 'Choose your journey';
  String get guideHomeIntro => languageCode == 'fr'
      ? 'Commencez simplement ou approfondissez un sujet à votre rythme.'
      : 'Start simply or explore one subject in depth at your own pace.';
  String get guideContents =>
      languageCode == 'fr' ? 'Table des matières' : 'Table of contents';
  String get guideHome =>
      languageCode == 'fr' ? 'Accueil du guide' : 'Guide home';
  String get guideSwipeHint => languageCode == 'fr'
      ? 'Faites glisser horizontalement pour continuer.'
      : 'Swipe horizontally to continue.';
  String get guideResume => languageCode == 'fr' ? 'Reprendre' : 'Resume';
  String get guideViewJourney =>
      languageCode == 'fr' ? 'Voir le parcours' : 'View journey';
  String get guideSlides =>
      languageCode == 'fr' ? 'Écrans du guide' : 'Guide slides';
  String get guideCategories =>
      languageCode == 'fr' ? 'Catégories du guide' : 'Guide categories';

  String guideSlideProgress(int current, int total) => languageCode == 'fr'
      ? 'Écran $current sur $total'
      : 'Slide $current of $total';

  String guideProgressLabel(int current, int total) => languageCode == 'fr'
      ? 'Progression : écran $current sur $total'
      : 'Progress: slide $current of $total';

  String guideSlideAnnouncement(int current, int total, String title) =>
      languageCode == 'fr'
      ? 'Écran $current sur $total : $title'
      : 'Slide $current of $total: $title';

  String guideCompletedProgress(int completed, int total) =>
      languageCode == 'fr'
      ? '$completed sur $total écrans terminés'
      : '$completed of $total slides completed';

  String guideCompactProgress(int completed, int total) => languageCode == 'fr'
      ? '$completed / $total écrans'
      : '$completed / $total slides';

  String get supportOsia => switch (languageCode) {
    'fr' => 'Soutenir OSIA (facultatif)',
    'zh' => '支持 OSIA（可选）',
    'ja' => 'OSIA を支援（任意）',
    'de' => 'OSIA unterstützen (optional)',
    'es' => 'Apoyar OSIA (opcional)',
    _ => 'Support OSIA (optional)',
  };

  String get pcSettingsUnavailable => switch (languageCode) {
    'fr' => 'Les réglages du PC sont indisponibles. Réessayez.',
    'zh' => '电脑设置暂不可用，请重试。',
    'ja' => 'PC の設定を取得できません。再試行してください。',
    'de' => 'PC-Einstellungen nicht verfügbar. Bitte erneut versuchen.',
    'es' => 'Ajustes del PC no disponibles. Inténtalo de nuevo.',
    _ => 'PC settings are unavailable. Please retry.',
  };

  // ── Parameterized helpers ──

  String get createFolder => switch (languageCode) {
    'fr' => 'Créer un projet',
    'zh' => '创建项目',
    'ja' => 'プロジェクトを作成',
    'de' => 'Projekt erstellen',
    'es' => 'Crear proyecto',
    _ => 'Create project',
  };

  String get folderName => switch (languageCode) {
    'fr' => 'Nom du projet',
    'zh' => '项目名称',
    'ja' => 'プロジェクト名',
    'de' => 'Projektname',
    'es' => 'Nombre del proyecto',
    _ => 'Project name',
  };

  String get renameFolder => switch (languageCode) {
    'fr' => 'Renommer le projet',
    'zh' => '重命名项目',
    'ja' => 'プロジェクト名を変更',
    'de' => 'Projekt umbenennen',
    'es' => 'Renombrar proyecto',
    _ => 'Rename project',
  };

  String get folderSettings => switch (languageCode) {
    'fr' => 'Paramètres du projet',
    'zh' => '项目设置',
    'ja' => 'プロジェクト設定',
    'de' => 'Projekteinstellungen',
    'es' => 'Ajustes del proyecto',
    _ => 'Project settings',
  };

  String get deleteProject => switch (languageCode) {
    'fr' => 'Supprimer le projet',
    'zh' => '删除项目',
    'ja' => 'プロジェクトを削除',
    'de' => 'Projekt löschen',
    'es' => 'Eliminar proyecto',
    _ => 'Delete project',
  };

  String deleteProjectConfirmation(
    String name,
    int count,
  ) => switch (languageCode) {
    'fr' when count == 1 =>
      'Supprimer le projet « $name » et sa conversation ? Cette action est définitive.',
    'fr' =>
      'Supprimer le projet « $name » et ses $count conversations ? Cette action est définitive.',
    'zh' => '删除项目“$name”及其中的 $count 个对话？此操作无法撤销。',
    'ja' => 'プロジェクト「$name」とその $count 件の会話を削除しますか？この操作は取り消せません。',
    'de' when count == 1 =>
      'Projekt „$name“ und seine 1 Unterhaltung löschen? Diese Aktion ist endgültig.',
    'de' =>
      'Projekt „$name“ und seine $count Unterhaltungen löschen? Diese Aktion ist endgültig.',
    'es' when count == 1 =>
      '¿Eliminar el proyecto «$name» y su conversación? Esta acción es permanente.',
    'es' =>
      '¿Eliminar el proyecto «$name» y sus $count conversaciones? Esta acción es permanente.',
    _ when count == 1 =>
      'Delete project “$name” and its 1 conversation? This action is permanent.',
    _ =>
      'Delete project “$name” and its $count conversations? This action is permanent.',
  };

  String get allowFolderContext => switch (languageCode) {
    'fr' =>
      'Autoriser OSIA à utiliser les autres conversations de ce projet comme contexte',
    'zh' => '允许 OSIA 使用此项目中的其他对话作为上下文',
    'ja' => 'OSIA がこのプロジェクト内の他の会話をコンテキストとして使用することを許可',
    'de' =>
      'OSIA erlauben, andere Unterhaltungen in diesem Projekt als Kontext zu verwenden',
    'es' =>
      'Permitir que OSIA use otras conversaciones de este proyecto como contexto',
    _ => 'Allow OSIA to use other conversations in this project as context',
  };

  String get folderContextNextTurn => switch (languageCode) {
    'fr' => 'Ce réglage s’applique dès le prochain tour.',
    'zh' => '此设置将在下一轮对话生效。',
    'ja' => 'この設定は次のターンから適用されます。',
    'de' => 'Diese Einstellung gilt ab der nächsten Anfrage.',
    'es' => 'Este ajuste se aplica desde el siguiente turno.',
    _ => 'This setting takes effect on the next turn.',
  };

  String get moveToFolder => switch (languageCode) {
    'fr' => 'Déplacer vers un projet',
    'zh' => '移动到项目',
    'ja' => 'プロジェクトへ移動',
    'de' => 'In Projekt verschieben',
    'es' => 'Mover a proyecto',
    _ => 'Move to project',
  };

  String get removeFromProject => switch (languageCode) {
    'fr' => 'Retirer du projet',
    'zh' => '从项目中移除',
    'ja' => 'プロジェクトから外す',
    'de' => 'Aus Projekt entfernen',
    'es' => 'Quitar del proyecto',
    _ => 'Remove from project',
  };

  String get projectsSection => switch (languageCode) {
    'fr' => 'Projets',
    'zh' => '项目',
    'ja' => 'プロジェクト',
    'de' => 'Projekte',
    'es' => 'Proyectos',
    _ => 'Projects',
  };

  String get outsideFolders => switch (languageCode) {
    'fr' => 'Conversations non classées',
    'zh' => '未归入项目的对话',
    'ja' => 'プロジェクト外の会話',
    'de' => 'Nicht zugeordnete Unterhaltungen',
    'es' => 'Conversaciones sin proyecto',
    _ => 'Ungrouped conversations',
  };

  String get moveFolderUp => switch (languageCode) {
    'fr' => 'Monter le projet',
    'zh' => '上移项目',
    'ja' => 'プロジェクトを上へ',
    'de' => 'Projekt nach oben',
    'es' => 'Subir proyecto',
    _ => 'Move project up',
  };

  String get moveFolderDown => switch (languageCode) {
    'fr' => 'Descendre le projet',
    'zh' => '下移项目',
    'ja' => 'プロジェクトを下へ',
    'de' => 'Projekt nach unten',
    'es' => 'Bajar proyecto',
    _ => 'Move project down',
  };

  String get deleteAllConversations => switch (languageCode) {
    'fr' => 'Supprimer les conversations hors projets',
    'zh' => '删除项目外的对话',
    'ja' => 'プロジェクト外の会話を削除',
    'de' => 'Unterhaltungen außerhalb von Projekten löschen',
    'es' => 'Eliminar conversaciones fuera de proyectos',
    _ => 'Delete conversations outside projects',
  };

  String get conversationDeleteFailed => switch (languageCode) {
    'fr' => 'La conversation n’a pas pu être supprimée. Réessayez.',
    'zh' => '无法删除此对话，请重试。',
    'ja' => '会話を削除できませんでした。もう一度お試しください。',
    'de' =>
      'Die Unterhaltung konnte nicht gelöscht werden. Bitte erneut versuchen.',
    'es' => 'No se pudo eliminar la conversación. Inténtalo de nuevo.',
    _ => 'The conversation could not be deleted. Please try again.',
  };

  String get conversationDeleteInProgress => switch (languageCode) {
    'fr' => 'Une suppression de conversation est déjà en cours.',
    'zh' => '对话删除正在进行中。',
    'ja' => '会話の削除を処理中です。',
    'de' => 'Eine Unterhaltungs-Löschung läuft bereits.',
    'es' => 'Ya hay una eliminación de conversación en curso.',
    _ => 'A conversation deletion is already in progress.',
  };

  String get noUngroupedConversations => switch (languageCode) {
    'fr' => 'Aucune conversation hors projets à supprimer.',
    'zh' => '没有可删除的项目外对话。',
    'ja' => '削除できるプロジェクト外の会話はありません。',
    'de' => 'Es gibt keine Unterhaltungen außerhalb von Projekten zu löschen.',
    'es' => 'No hay conversaciones fuera de proyectos para eliminar.',
    _ => 'There are no conversations outside projects to delete.',
  };

  String bulkDeleteWarning(int count) => switch (languageCode) {
    'fr' =>
      '$count conversations hors projets seront supprimées définitivement. Les conversations dans les projets et tous les projets seront conservés.',
    'zh' => '将永久删除项目外的 $count 个对话。项目内的对话和所有项目都会保留。',
    'ja' => 'プロジェクト外の会話 $count 件を完全に削除します。プロジェクト内の会話とすべてのプロジェクトは保持されます。',
    'de' =>
      '$count Unterhaltungen außerhalb von Projekten werden dauerhaft gelöscht. Unterhaltungen in Projekten und alle Projekte bleiben erhalten.',
    'es' =>
      'Se eliminarán permanentemente $count conversaciones fuera de proyectos. Se conservarán las conversaciones dentro de proyectos y todos los proyectos.',
    _ =>
      '$count conversations outside projects will be permanently deleted. Conversations inside projects and all projects are preserved.',
  };

  String typeToConfirm(String phrase) => switch (languageCode) {
    'fr' => 'Saisissez $phrase pour confirmer :',
    'zh' => '输入 $phrase 以确认：',
    'ja' => '確認するには $phrase と入力してください：',
    'de' => 'Geben Sie zur Bestätigung $phrase ein:',
    'es' => 'Escribe $phrase para confirmar:',
    _ => 'Type $phrase to confirm:',
  };

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

  String _autonomousAuthorizationText(Map<String, String> values) =>
      values[languageCode] ?? values['en']!;

  String get autonomousAuthorizeAndStart => _autonomousAuthorizationText(const {
    'en': 'Authorize and Start',
    'fr': 'Autoriser et démarrer',
    'zh': '授权并开始',
    'ja': '承認して開始',
    'de': 'Autorisieren und starten',
    'es': 'Autorizar e iniciar',
  });
  String get autonomousReviewPlan => _autonomousAuthorizationText(const {
    'en': 'Review plan before execution',
    'fr': 'Examiner le plan avant exécution',
    'zh': '执行前审核计划',
    'ja': '実行前に計画を確認',
    'de': 'Plan vor Ausführung prüfen',
    'es': 'Revisar el plan antes de ejecutar',
  });
  String get autonomousRequestedCapabilities =>
      _autonomousAuthorizationText(const {
        'en': 'Requested capabilities',
        'fr': 'Capacités demandées',
        'zh': '请求的能力',
        'ja': '要求された機能',
        'de': 'Angeforderte Fähigkeiten',
        'es': 'Capacidades solicitadas',
      });
  String get autonomousAdditionalPermission =>
      _autonomousAuthorizationText(const {
        'en': 'Additional permission required',
        'fr': 'Autorisation supplémentaire requise',
        'zh': '需要额外权限',
        'ja': '追加の権限が必要です',
        'de': 'Zusätzliche Berechtigung erforderlich',
        'es': 'Se requiere permiso adicional',
      });
  String get autonomousApproveExact => _autonomousAuthorizationText(const {
    'en': 'Approve exact scope',
    'fr': 'Approuver la portée exacte',
    'zh': '批准精确范围',
    'ja': '正確な範囲を承認',
    'de': 'Exakten Umfang genehmigen',
    'es': 'Aprobar alcance exacto',
  });
  String get autonomousDeny => _autonomousAuthorizationText(const {
    'en': 'Deny',
    'fr': 'Refuser',
    'zh': '拒绝',
    'ja': '拒否',
    'de': 'Ablehnen',
    'es': 'Denegar',
  });
  String get autonomousPcOnly => _autonomousAuthorizationText(const {
    'en': 'Local PC review required; mobile approval is unavailable.',
    'fr': 'Examen local sur le PC requis ; approbation mobile indisponible.',
    'zh': '需要在本地电脑上审核；无法通过手机批准。',
    'ja': 'ローカル PC での確認が必要です。モバイルでは承認できません。',
    'de': 'Lokale PC-Prüfung erforderlich; mobile Freigabe ist nicht möglich.',
    'es':
        'Se requiere revisión local en el PC; no se puede aprobar en el móvil.',
  });
  String get autonomousRevoke => _autonomousAuthorizationText(const {
    'en': 'Revoke',
    'fr': 'Révoquer',
    'zh': '撤销',
    'ja': '取り消す',
    'de': 'Widerrufen',
    'es': 'Revocar',
  });
  String get autonomousAuthorizationRevoked =>
      _autonomousAuthorizationText(const {
        'en': 'Authorization revoked; automatic continuation blocked',
        'fr': 'Autorisation révoquée ; poursuite automatique bloquée',
        'zh': '授权已撤销；自动继续已被阻止',
        'ja': '承認が取り消され、自動続行はブロックされました',
        'de': 'Autorisierung widerrufen; automatische Fortsetzung blockiert',
        'es': 'Autorización revocada; continuación automática bloqueada',
      });
  String get autonomousOutcomeUnknown => _autonomousAuthorizationText(const {
    'en': 'Prior action outcome unknown; automatic continuation blocked',
    'fr': 'Résultat antérieur inconnu ; poursuite automatique bloquée',
    'zh': '先前操作结果未知；自动继续已被阻止',
    'ja': '以前の操作結果が不明なため、自動続行はブロックされました',
    'de': 'Früheres Aktionsergebnis unbekannt; Fortsetzung blockiert',
    'es': 'Resultado anterior desconocido; continuación automática bloqueada',
  });

  String get autonomousDocuments => _autonomousAuthorizationText(const {
    'en': 'Documents',
    'fr': 'Documents',
    'zh': '文档',
    'ja': '文書',
    'de': 'Dokumente',
    'es': 'Documentos',
  });

  String get autonomousAddDocuments => _autonomousAuthorizationText(const {
    'en': 'Add',
    'fr': 'Ajouter',
    'zh': '添加',
    'ja': '追加',
    'de': 'Hinzufügen',
    'es': 'Añadir',
  });

  String get autonomousRemoveDocument => _autonomousAuthorizationText(const {
    'en': 'Remove document',
    'fr': 'Retirer le document',
    'zh': '移除文档',
    'ja': '文書を削除',
    'de': 'Dokument entfernen',
    'es': 'Quitar documento',
  });

  String get documentTransferPreparing => _autonomousAuthorizationText(const {
    'en': 'Preparing…',
    'fr': 'Préparation…',
    'zh': '正在准备…',
    'ja': '準備中…',
    'de': 'Wird vorbereitet…',
    'es': 'Preparando…',
  });

  String get documentTransferUploading => _autonomousAuthorizationText(const {
    'en': 'Uploading…',
    'fr': 'Envoi…',
    'zh': '正在上传…',
    'ja': 'アップロード中…',
    'de': 'Wird hochgeladen…',
    'es': 'Subiendo…',
  });

  String get documentTransferVerifying => _autonomousAuthorizationText(const {
    'en': 'Verifying…',
    'fr': 'Vérification…',
    'zh': '正在验证…',
    'ja': '検証中…',
    'de': 'Wird geprüft…',
    'es': 'Verificando…',
  });

  String get documentTransferReady => _autonomousAuthorizationText(const {
    'en': 'Ready',
    'fr': 'Prêt',
    'zh': '已就绪',
    'ja': '準備完了',
    'de': 'Bereit',
    'es': 'Listo',
  });

  String get documentTransferFailed => _autonomousAuthorizationText(const {
    'en': 'Upload failed. Remove the document and try again.',
    'fr': "L'envoi a échoué. Retirez le document et réessayez.",
    'zh': '上传失败。请移除文档后重试。',
    'ja': 'アップロードに失敗しました。文書を削除して再試行してください。',
    'de': 'Upload fehlgeschlagen. Dokument entfernen und erneut versuchen.',
    'es': 'La carga falló. Quita el documento e inténtalo de nuevo.',
  });

  String get documentProcessingFailed => _autonomousAuthorizationText(const {
    'en': 'Document processing failed',
    'fr': 'Le traitement du document a échoué',
    'zh': '文档处理失败',
    'ja': '文書の処理に失敗しました',
    'de': 'Dokumentverarbeitung fehlgeschlagen',
    'es': 'Error al procesar el documento',
  });

  String documentPhase(String phase) {
    const labels = <String, Map<String, String>>{
      'identifying': {
        'en': 'Identifying',
        'fr': 'Identification',
        'zh': '识别',
        'ja': '識別',
        'de': 'Erkennen',
        'es': 'Identificando',
      },
      'inspecting': {
        'en': 'Inspecting',
        'fr': 'Inspection',
        'zh': '检查',
        'ja': '検査',
        'de': 'Prüfen',
        'es': 'Inspeccionando',
      },
      'extracting': {
        'en': 'Extracting',
        'fr': 'Extraction',
        'zh': '提取',
        'ja': '抽出',
        'de': 'Extrahieren',
        'es': 'Extrayendo',
      },
      'indexing': {
        'en': 'Indexing',
        'fr': 'Indexation',
        'zh': '索引',
        'ja': '索引作成',
        'de': 'Indizieren',
        'es': 'Indexando',
      },
      'ready': {
        'en': 'Ready',
        'fr': 'Prêt',
        'zh': '已就绪',
        'ja': '準備完了',
        'de': 'Bereit',
        'es': 'Listo',
      },
      'failed': {
        'en': 'Failed',
        'fr': 'Échec',
        'zh': '失败',
        'ja': '失敗',
        'de': 'Fehlgeschlagen',
        'es': 'Error',
      },
    };
    final localized = labels[phase];
    return localized?[languageCode] ?? localized?['en'] ?? phase;
  }

  String get scheduledAuthorizationTitle => _autonomousAuthorizationText(const {
    'en': 'Scheduled task authorization',
    'fr': 'Autorisation de la tÃ¢che planifiÃ©e',
    'zh': 'å®šæ—¶ä»»åŠ¡æŽˆæƒ',
    'ja': 'ã‚¹ã‚±ã‚¸ãƒ¥ãƒ¼ãƒ«ã‚¿ã‚¹ã‚¯ã®æ‰¿èª',
    'de': 'Autorisierung der geplanten Aufgabe',
    'es': 'AutorizaciÃ³n de tarea programada',
  });
  String get scheduledAuthorize => _autonomousAuthorizationText(const {
    'en': 'Authorize',
    'fr': 'Autoriser',
    'zh': 'æŽˆæƒ',
    'ja': 'æ‰¿èª',
    'de': 'Autorisieren',
    'es': 'Autorizar',
  });
  String get scheduledReauthorize => _autonomousAuthorizationText(const {
    'en': 'Reauthorize',
    'fr': 'RÃ©autoriser',
    'zh': 'é‡æ–°æŽˆæƒ',
    'ja': 'å†æ‰¿èª',
    'de': 'Erneut autorisieren',
    'es': 'Volver a autorizar',
  });
  String get scheduledDisable => _autonomousAuthorizationText(const {
    'en': 'Disable',
    'fr': 'DÃ©sactiver',
    'zh': 'åœç”¨',
    'ja': 'ç„¡åŠ¹åŒ–',
    'de': 'Deaktivieren',
    'es': 'Desactivar',
  });
  String get scheduledInstructionPrivate => _autonomousAuthorizationText(const {
    'en': 'The task instruction stays private on the PC.',
    'fr': "L'instruction de la tÃ¢che reste privÃ©e sur le PC.",
    'zh': 'ä»»åŠ¡æŒ‡ä»¤ä»…ä¿ç•™åœ¨ PC ä¸Šã€‚',
    'ja': 'ã‚¿ã‚¹ã‚¯æŒ‡ç¤ºã¯ PC ä¸Šã§éžå…¬é–‹ã®ã¾ã¾ã§ã™ã€‚',
    'de': 'Die Aufgabenanweisung bleibt auf dem PC privat.',
    'es': 'La instrucciÃ³n de la tarea permanece privada en el PC.',
  });
  String get scheduledPcReviewRequired => _autonomousAuthorizationText(const {
    'en': 'This task requires local review on the PC.',
    'fr': 'Cette tÃ¢che exige un examen local sur le PC.',
    'zh': 'æ­¤ä»»åŠ¡éœ€è¦åœ¨ PC ä¸Šæœ¬åœ°å®¡æ ¸ã€‚',
    'ja': 'ã“ã®ã‚¿ã‚¹ã‚¯ã¯ PC ä¸Šã§ã®ãƒ­ãƒ¼ã‚«ãƒ«ç¢ºèªãŒå¿…è¦ã§ã™ã€‚',
    'de': 'Diese Aufgabe muss lokal auf dem PC geprÃ¼ft werden.',
    'es': 'Esta tarea requiere revisiÃ³n local en el PC.',
  });
  String get scheduledExactCapabilities => _autonomousAuthorizationText(const {
    'en': 'Exact capabilities',
    'fr': 'CapacitÃ©s exactes',
    'zh': 'ç²¾ç¡®æƒé™',
    'ja': 'æ­£ç¢ºãªæ©Ÿèƒ½',
    'de': 'Exakte FÃ¤higkeiten',
    'es': 'Capacidades exactas',
  });

  String scheduledRevision(int value) => _autonomousAuthorizationText({
    'en': 'Revision $value',
    'fr': 'R\u00e9vision $value',
    'zh': '\u4fee\u8ba2 $value',
    'ja': '\u30ea\u30d3\u30b8\u30e7\u30f3 $value',
    'de': 'Revision $value',
    'es': 'Revisi\u00f3n $value',
  });

  String scheduledMaxExecutions(int value) => _autonomousAuthorizationText({
    'en': 'Maximum executions: $value',
    'fr': "Nombre maximal d'executions : $value",
    'zh': '\u6700\u5927\u6267\u884c\u6b21\u6570\uff1a$value',
    'ja': '\u6700\u5927\u5b9f\u884c\u56de\u6570: $value',
    'de': 'Maximale Ausf\u00fchrungen: $value',
    'es': 'Ejecuciones m\u00e1ximas: $value',
  });

  String scheduledExpires(String value) => _autonomousAuthorizationText({
    'en': 'Expires: $value',
    'fr': 'Expire : $value',
    'zh': '\u5230\u671f\u65f6\u95f4\uff1a$value',
    'ja': '\u6709\u52b9\u671f\u9650: $value',
    'de': 'L\u00e4uft ab: $value',
    'es': 'Caduca: $value',
  });

  String scheduledAuthorizationStatus(String status) {
    final values = <String, Map<String, String>>{
      'authorized': {
        'en': 'Authorized',
        'fr': 'AutorisÃ©e',
        'zh': 'å·²æŽˆæƒ',
        'ja': 'æ‰¿èªæ¸ˆã¿',
        'de': 'Autorisiert',
        'es': 'Autorizada',
      },
      'authorization_expired': {
        'en': 'Expired',
        'fr': 'ExpirÃ©e',
        'zh': 'å·²è¿‡æœŸ',
        'ja': 'æœŸé™åˆ‡ã‚Œ',
        'de': 'Abgelaufen',
        'es': 'Caducada',
      },
      'authorization_revoked': {
        'en': 'Revoked',
        'fr': 'RÃ©voquÃ©e',
        'zh': 'å·²æ’¤é”€',
        'ja': 'å–ã‚Šæ¶ˆã—æ¸ˆã¿',
        'de': 'Widerrufen',
        'es': 'Revocada',
      },
      'authorization_invalidated_by_edit': {
        'en': 'Edited â€” authorization required',
        'fr': 'ModifiÃ©e â€” autorisation requise',
        'zh': 'å·²ä¿®æ”¹ â€” éœ€è¦æŽˆæƒ',
        'ja': 'ç·¨é›†æ¸ˆã¿ â€” å†æ‰¿èªãŒå¿…è¦',
        'de': 'GeÃ¤ndert â€“ Autorisierung erforderlich',
        'es': 'Editada â€” requiere autorizaciÃ³n',
      },
      'disabled': {
        'en': 'Disabled',
        'fr': 'DÃ©sactivÃ©e',
        'zh': 'å·²åœç”¨',
        'ja': 'ç„¡åŠ¹',
        'de': 'Deaktiviert',
        'es': 'Desactivada',
      },
      'running': {
        'en': 'Running',
        'fr': 'En cours',
        'zh': 'æ­£åœ¨è¿è¡Œ',
        'ja': 'å®Ÿè¡Œä¸­',
        'de': 'Wird ausgefÃ¼hrt',
        'es': 'En ejecuciÃ³n',
      },
      'blocked_outcome_unknown': {
        'en': 'Blocked â€” prior outcome unknown',
        'fr': 'BloquÃ©e â€” rÃ©sultat antÃ©rieur inconnu',
        'zh': 'å·²é˜»æ­¢ â€” ä¸Šæ¬¡ç»“æžœæœªçŸ¥',
        'ja': 'ãƒ–ãƒ­ãƒƒã‚¯ä¸­ â€” ä»¥å‰ã®çµæžœãŒä¸æ˜Ž',
        'de': 'Blockiert â€“ vorheriges Ergebnis unbekannt',
        'es': 'Bloqueada â€” resultado anterior desconocido',
      },
    };
    return _autonomousAuthorizationText(
      values[status] ??
          const {
            'en': 'Authorization required',
            'fr': 'Autorisation requise',
            'zh': 'éœ€è¦æŽˆæƒ',
            'ja': 'æ‰¿èªãŒå¿…è¦',
            'de': 'Autorisierung erforderlich',
            'es': 'AutorizaciÃ³n requerida',
          },
    );
  }

  String autonomousFailureDiagnostic(String? category) {
    final messages =
        _autonomousFailureMessages[languageCode] ??
        _autonomousFailureMessages['en']!;
    return messages[category] ?? messages['unknown_failure']!;
  }

  String autonomousDiagnosticMetadata({
    int? attempt,
    int? maxAttempts,
    int? replanCount,
    int? maxReplans,
  }) {
    final parts = <String>[];
    if (attempt != null && attempt > 0 && maxAttempts != null) {
      switch (languageCode) {
        case 'fr':
          parts.add('Tentative $attempt/$maxAttempts.');
          break;
        case 'zh':
          parts.add('尝试 $attempt/$maxAttempts。');
          break;
        case 'ja':
          parts.add('試行 $attempt/$maxAttempts。');
          break;
        case 'de':
          parts.add('Versuch $attempt/$maxAttempts.');
          break;
        case 'es':
          parts.add('Intento $attempt/$maxAttempts.');
          break;
        default:
          parts.add('Attempt $attempt/$maxAttempts.');
          break;
      }
    }
    if (replanCount != null && maxReplans != null) {
      switch (languageCode) {
        case 'fr':
          parts.add('Plans de reprise $replanCount/$maxReplans.');
          break;
        case 'zh':
          parts.add('恢复计划 $replanCount/$maxReplans。');
          break;
        case 'ja':
          parts.add('復旧計画 $replanCount/$maxReplans。');
          break;
        case 'de':
          parts.add('Wiederherstellungspläne $replanCount/$maxReplans.');
          break;
        case 'es':
          parts.add('Planes de recuperación $replanCount/$maxReplans.');
          break;
        default:
          parts.add('Recovery plans $replanCount/$maxReplans.');
          break;
      }
    }
    return parts.join(' ');
  }

  /// Title for the write-tool confirmation dialog (WOR-44 Phase 5):
  /// "{server} wants to run {tool}".
  String mcpConfirmTitle(String server, String tool) => mcpConfirmTitleTemplate
      .replaceAll('{server}', server)
      .replaceAll('{tool}', tool);

  String get colossalDeletionPcReviewTitle {
    switch (languageCode) {
      case 'fr':
        return 'Verification locale requise';
      case 'de':
        return 'Lokale Prufung erforderlich';
      case 'es':
        return 'Se requiere revision local';
      default:
        return 'Local PC review required';
    }
  }

  String get colossalDeletionPcReviewBody {
    switch (languageCode) {
      case 'fr':
        return 'Cette suppression colossale ne peut pas etre autorisee depuis le mobile. Consultez l inventaire complet et confirmez-la localement sur le PC.';
      case 'de':
        return 'Diese sehr grosse Loschung kann nicht mobil genehmigt werden. Prufen Sie das vollstandige Inventar lokal am PC.';
      case 'es':
        return 'Esta eliminacion masiva no se puede aprobar desde el movil. Revise el inventario completo localmente en el PC.';
      default:
        return 'This colossal deletion cannot be approved on mobile. Review the complete inventory and confirm it locally on the PC.';
    }
  }

  String colossalDeletionSafeCounts(
    int files,
    int folders,
    int bytes,
    int roots,
  ) {
    final size = bytes >= 1024 * 1024 * 1024
        ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB'
        : bytes >= 1024 * 1024
        ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB'
        : bytes >= 1024
        ? '${(bytes / 1024).toStringAsFixed(1)} KiB'
        : '$bytes B';
    switch (languageCode) {
      case 'fr':
        return '$files fichiers, $folders dossiers, $size, $roots racines';
      case 'de':
        return '$files Dateien, $folders Ordner, $size, $roots Wurzeln';
      case 'es':
        return '$files archivos, $folders carpetas, $size, $roots raices';
      default:
        return '$files files, $folders folders, $size, $roots roots';
    }
  }

  String get colossalDeletionClose {
    switch (languageCode) {
      case 'fr':
        return 'Fermer';
      case 'de':
        return 'Schliessen';
      case 'es':
        return 'Cerrar';
      default:
        return 'Close';
    }
  }

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

  String chatGptQuotaRemaining(String label, int percent) {
    final weekly = switch (languageCode) {
      'fr' => 'Hebdomadaire',
      'zh' => '每周',
      'ja' => '週間',
      'de' => 'Wöchentlich',
      'es' => 'Semanal',
      _ => 'Weekly',
    };
    if (label.endsWith('Weekly')) {
      label = '${label.substring(0, label.length - 6)}$weekly';
    }
    return switch (languageCode) {
      'fr' => '$label : $percent % restants',
      'zh' => '$label：剩余 $percent%',
      'ja' => '$label: 残り $percent%',
      'de' => '$label: $percent % verbleibend',
      'es' => '$label: $percent % restante',
      _ => '$label: $percent% remaining',
    };
  }

  String get claudeWorkspace => switch (languageCode) {
    'fr' => 'Workspace Claude API (facultatif)',
    'zh' => 'Claude API 工作区（可选）',
    'ja' => 'Claude API ワークスペース（任意）',
    'de' => 'Claude API Workspace (optional)',
    'es' => 'Workspace de Claude API (opcional)',
    _ => 'Claude API workspace (optional)',
  };

  String get grokApiInfo => switch (languageCode) {
    'fr' =>
      'Connexion par clé API xAI. La facturation API est distincte des abonnements Grok. La connexion au compte Grok dans OSIA reste indisponible, dans l’attente d’une méthode officielle et d’une autorisation.',
    'zh' => '使用xAI API密钥连接。API与Grok订阅分开计费。OSIA中的Grok账户登录在获得官方方法和授权前不可用。',
    'ja' =>
      'xAI APIキーで接続します。API料金はGrokのサブスクリプションとは別です。OSIAでのGrokアカウント接続は公式の方法と許可が得られるまで利用できません。',
    'de' =>
      'Mit xAI-API-Schlüssel verbinden. Die API wird getrennt vom Grok-Abo abgerechnet. Die Grok-Kontoanmeldung in OSIA ist bis zu einer offiziellen Methode und Genehmigung nicht verfügbar.',
    'es' =>
      'Conecta con una clave API de xAI. La API se factura por separado de Grok. El inicio de sesión de Grok en OSIA no está disponible hasta contar con un método oficial y autorización.',
    _ =>
      'Connect with an xAI API key. API billing is separate from Grok subscriptions. Grok account login in OSIA is unavailable pending an official method and authorization.',
  };

  String get claudeApiInfo => switch (languageCode) {
    'fr' =>
      'Utilise une clé API Claude Console et ses crédits API. Le workspace est nécessaire pour les clés multi-workspaces.',
    'zh' => '使用 Claude Console API 密钥和 API 额度。多工作区密钥需要工作区 ID。',
    'ja' => 'Claude Console の API キーと API クレジットを使用します。複数ワークスペースのキーには ID が必要です。',
    'de' =>
      'Verwendet einen Claude Console API-Schlüssel und API-Guthaben. Schlüssel für mehrere Workspaces benötigen die Workspace-ID.',
    'es' =>
      'Usa una clave API de Claude Console y créditos API. Las claves de varios workspaces necesitan el ID del workspace.',
    _ =>
      'Uses a Claude Console API key and API credits. Multi-workspace keys require a workspace ID.',
  };

  String get claudeWorkspaceSaved => switch (languageCode) {
    'fr' => 'Workspace enregistré',
    'zh' => '工作区已保存',
    'ja' => 'ワークスペースを保存しました',
    'de' => 'Workspace gespeichert',
    'es' => 'Workspace guardado',
    _ => 'Workspace saved',
  };

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

  String _wor254(String key) =>
      _wor254Messages[languageCode]?[key] ??
      _wor254Messages['en']![key] ??
      _wor254Messages['en']!['thinking']!;

  String get activeTransportTitle => _wor254('transport.title');
  String get executionTraceTitle => _wor254('trace.title');
  String get thinkingLabel => _wor254('thinking');
  String get legacyRunTitle => _wor254('legacy_run.title');
  String get legacyRunActive => _wor254('legacy_run.active');
  String get legacyRunResume => _wor254('legacy_run.resume');
  String get legacyRunStop => _wor254('legacy_run.stop');

  String transportStateText(String state) => _wor254('transport.$state');

  /// Localized display name for a theme palette key.
  String themeName(String paletteKey) {
    switch (paletteKey) {
      case 'osia':
        return 'OSIA';
      case 'azure':
        return 'Azure';
      case 'emerald':
        return 'Emerald';
      case 'rose':
        return themeRose;
      case 'amber':
        return 'Amber';
      case 'neutral':
        return 'Neutral';
    }
    return paletteKey;
  }
}

const Map<String, Map<String, String>> _wor254Messages = {
  'en': {
    'transport.title': 'Active transport',
    'transport.switching': 'Switching / reconnecting',
    'transport.lanDirect': 'LAN direct',
    'transport.webRtcP2p': 'WebRTC P2P',
    'transport.relayOsia': 'Relay OSIA',
    'trace.title': 'Thinking',
    'thinking': 'Thinking…',
    'legacy_run.title': 'Previous durable run',
    'legacy_run.active': 'Work from an earlier version is still available.',
    'legacy_run.resume': 'Resume',
    'legacy_run.stop': 'Stop',
  },
  'fr': {
    'transport.title': 'Transport actif',
    'transport.switching': 'Bascule / reconnexion',
    'transport.lanDirect': 'LAN direct',
    'transport.webRtcP2p': 'WebRTC P2P',
    'transport.relayOsia': 'Relais OSIA',
    'trace.title': 'Réflexion',
    'thinking': 'Réflexion…',
    'legacy_run.title': 'Exécution durable précédente',
    'legacy_run.active':
        'Un travail créé avec une version antérieure reste disponible.',
    'legacy_run.resume': 'Reprendre',
    'legacy_run.stop': 'Arrêter',
  },
  'zh': {
    'transport.title': '当前传输方式',
    'transport.switching': '正在切换或重新连接',
    'transport.lanDirect': '局域网直连',
    'transport.webRtcP2p': 'WebRTC 点对点',
    'transport.relayOsia': 'OSIA 中继',
    'trace.title': '思考过程',
    'thinking': '正在思考…',
    'legacy_run.title': '先前的持久运行',
    'legacy_run.active': '早期版本创建的工作仍可继续。',
    'legacy_run.resume': '继续',
    'legacy_run.stop': '停止',
  },
  'ja': {
    'transport.title': '使用中の通信経路',
    'transport.switching': '切り替え／再接続中',
    'transport.lanDirect': 'LAN 直接接続',
    'transport.webRtcP2p': 'WebRTC P2P',
    'transport.relayOsia': 'OSIA リレー',
    'trace.title': '処理状況',
    'thinking': '考えています…',
    'legacy_run.title': '以前の永続実行',
    'legacy_run.active': '以前のバージョンで作成した作業を続行できます。',
    'legacy_run.resume': '再開',
    'legacy_run.stop': '停止',
  },
  'de': {
    'transport.title': 'Aktiver Transport',
    'transport.switching': 'Wechsel / erneute Verbindung',
    'transport.lanDirect': 'LAN direkt',
    'transport.webRtcP2p': 'WebRTC P2P',
    'transport.relayOsia': 'OSIA-Relay',
    'trace.title': 'Verarbeitung',
    'thinking': 'Denke nach…',
    'legacy_run.title': 'Früherer dauerhafter Lauf',
    'legacy_run.active':
        'Arbeit aus einer früheren Version ist noch verfügbar.',
    'legacy_run.resume': 'Fortsetzen',
    'legacy_run.stop': 'Stoppen',
  },
  'es': {
    'transport.title': 'Transporte activo',
    'transport.switching': 'Cambio / reconexión',
    'transport.lanDirect': 'LAN directo',
    'transport.webRtcP2p': 'WebRTC P2P',
    'transport.relayOsia': 'Relé OSIA',
    'trace.title': 'Proceso',
    'thinking': 'Pensando…',
    'legacy_run.title': 'Ejecución duradera anterior',
    'legacy_run.active': 'El trabajo de una versión anterior sigue disponible.',
    'legacy_run.resume': 'Reanudar',
    'legacy_run.stop': 'Detener',
  },
};

const Map<String, Map<String, String>> _autonomousFailureMessages = {
  'en': {
    'planning_provider_failure':
        'Planning could not reach the selected provider.',
    'planning_authentication_failure':
        'Planning stopped because provider authentication failed.',
    'planning_rate_limit': 'Planning was rate-limited. Try again later.',
    'planning_timeout': 'Planning timed out before a plan was ready.',
    'invalid_planning_output': 'The provider returned an invalid plan.',
    'task_execution_failure': 'A step could not be executed.',
    'task_timeout': 'A step timed out before completion.',
    'verification_error': 'OSIA could not verify the step safely.',
    'verification_not_completed':
        "The step's completion criterion was not met.",
    'task_attempts_exhausted': 'The step used all permitted attempts.',
    'replan_failure': 'OSIA could not build a recovery plan.',
    'replans_exhausted': 'The run used all permitted recovery plans.',
    'invalid_resume_state': 'The saved run cannot be resumed safely.',
    'interrupted': 'The run is paused and can be resumed.',
    'aborted': 'The run was abandoned by the user.',
    'orchestrator_failure':
        'Autonomous execution stopped because of an internal error.',
    'checkpoint_failure': 'OSIA could not save the autonomous checkpoint.',
    'unknown_failure':
        'The autonomous run failed. Try again or review diagnostics.',
  },
  'fr': {
    'planning_provider_failure':
        "La planification n'a pas pu joindre le fournisseur sélectionné.",
    'planning_authentication_failure':
        "La planification s'est arrêtée car l'authentification a échoué.",
    'planning_rate_limit':
        'La planification a été limitée. Réessayez plus tard.',
    'planning_timeout':
        'La planification a expiré avant que le plan soit prêt.',
    'invalid_planning_output': 'Le fournisseur a renvoyé un plan invalide.',
    'task_execution_failure': "Une étape n'a pas pu être exécutée.",
    'task_timeout': 'Une étape a expiré avant sa fin.',
    'verification_error': "OSIA n'a pas pu vérifier l'étape de façon sûre.",
    'verification_not_completed':
        "Le critère de réussite de l'étape n'est pas satisfait.",
    'task_attempts_exhausted':
        "L'étape a utilisé toutes les tentatives autorisées.",
    'replan_failure': "OSIA n'a pas pu créer un plan de reprise.",
    'replans_exhausted':
        "L'exécution a utilisé tous les plans de reprise autorisés.",
    'invalid_resume_state':
        "L'exécution enregistrée ne peut pas être reprise en toute sécurité.",
    'interrupted': "L'exécution est en pause et peut être reprise.",
    'aborted': "L'exécution a été abandonnée par l'utilisateur.",
    'orchestrator_failure':
        "L'exécution autonome s'est arrêtée à cause d'une erreur interne.",
    'checkpoint_failure':
        "OSIA n'a pas pu enregistrer le point de reprise autonome.",
    'unknown_failure':
        "L'exécution autonome a échoué. Réessayez ou consultez le diagnostic.",
  },
  'zh': {
    'planning_provider_failure': '规划无法连接所选提供商。',
    'planning_authentication_failure': '规划因提供商身份验证失败而停止。',
    'planning_rate_limit': '规划受到速率限制，请稍后重试。',
    'planning_timeout': '规划在计划就绪前超时。',
    'invalid_planning_output': '提供商返回了无效计划。',
    'task_execution_failure': '某个步骤无法执行。',
    'task_timeout': '某个步骤在完成前超时。',
    'verification_error': 'OSIA 无法安全验证该步骤。',
    'verification_not_completed': '该步骤的完成条件未满足。',
    'task_attempts_exhausted': '该步骤已用完所有允许的尝试次数。',
    'replan_failure': 'OSIA 无法创建恢复计划。',
    'replans_exhausted': '此次运行已用完所有允许的恢复计划。',
    'invalid_resume_state': '无法安全恢复已保存的运行。',
    'interrupted': '运行已暂停，可以恢复。',
    'aborted': '运行已由用户放弃。',
    'orchestrator_failure': '自主执行因内部错误而停止。',
    'checkpoint_failure': 'OSIA 无法保存自主运行检查点。',
    'unknown_failure': '自主运行失败，请重试或查看诊断。',
  },
  'ja': {
    'planning_provider_failure': '計画時に選択したプロバイダーへ接続できませんでした。',
    'planning_authentication_failure': 'プロバイダー認証に失敗したため計画を停止しました。',
    'planning_rate_limit': '計画がレート制限されました。後でもう一度お試しください。',
    'planning_timeout': '計画の準備前にタイムアウトしました。',
    'invalid_planning_output': 'プロバイダーから無効な計画が返されました。',
    'task_execution_failure': 'ステップを実行できませんでした。',
    'task_timeout': 'ステップが完了前にタイムアウトしました。',
    'verification_error': 'OSIA はステップを安全に検証できませんでした。',
    'verification_not_completed': 'ステップの完了条件を満たしていません。',
    'task_attempts_exhausted': 'ステップは許可された試行回数を使い切りました。',
    'replan_failure': 'OSIA は復旧計画を作成できませんでした。',
    'replans_exhausted': '実行は許可された復旧計画を使い切りました。',
    'invalid_resume_state': '保存された実行を安全に再開できません。',
    'interrupted': '実行は一時停止され、再開できます。',
    'aborted': '実行はユーザーによって破棄されました。',
    'orchestrator_failure': '内部エラーのため自律実行を停止しました。',
    'checkpoint_failure': 'OSIA は自律実行のチェックポイントを保存できませんでした。',
    'unknown_failure': '自律実行に失敗しました。再試行するか診断を確認してください。',
  },
  'de': {
    'planning_provider_failure':
        'Die Planung konnte den ausgewählten Anbieter nicht erreichen.',
    'planning_authentication_failure':
        'Die Planung wurde wegen fehlgeschlagener Anbieter-Anmeldung beendet.',
    'planning_rate_limit':
        'Die Planung wurde begrenzt. Bitte später erneut versuchen.',
    'planning_timeout': 'Die Planung überschritt das Zeitlimit.',
    'invalid_planning_output':
        'Der Anbieter hat einen ungültigen Plan geliefert.',
    'task_execution_failure': 'Ein Schritt konnte nicht ausgeführt werden.',
    'task_timeout': 'Ein Schritt überschritt vor Abschluss das Zeitlimit.',
    'verification_error': 'OSIA konnte den Schritt nicht sicher prüfen.',
    'verification_not_completed':
        'Das Abschlusskriterium des Schritts wurde nicht erfüllt.',
    'task_attempts_exhausted':
        'Der Schritt hat alle erlaubten Versuche verbraucht.',
    'replan_failure': 'OSIA konnte keinen Wiederherstellungsplan erstellen.',
    'replans_exhausted':
        'Der Lauf hat alle erlaubten Wiederherstellungspläne verbraucht.',
    'invalid_resume_state':
        'Der gespeicherte Lauf kann nicht sicher fortgesetzt werden.',
    'interrupted': 'Der Lauf ist pausiert und kann fortgesetzt werden.',
    'aborted': 'Der Lauf wurde vom Benutzer verworfen.',
    'orchestrator_failure':
        'Die autonome Ausführung wurde wegen eines internen Fehlers beendet.',
    'checkpoint_failure':
        'OSIA konnte den autonomen Prüfpunkt nicht speichern.',
    'unknown_failure':
        'Der autonome Lauf ist fehlgeschlagen. Erneut versuchen oder Diagnose prüfen.',
  },
  'es': {
    'planning_provider_failure':
        'La planificación no pudo contactar al proveedor seleccionado.',
    'planning_authentication_failure':
        'La planificación se detuvo porque falló la autenticación.',
    'planning_rate_limit':
        'La planificación fue limitada. Inténtalo más tarde.',
    'planning_timeout':
        'La planificación agotó el tiempo antes de estar lista.',
    'invalid_planning_output': 'El proveedor devolvió un plan no válido.',
    'task_execution_failure': 'No se pudo ejecutar un paso.',
    'task_timeout': 'Un paso agotó el tiempo antes de completarse.',
    'verification_error': 'OSIA no pudo verificar el paso de forma segura.',
    'verification_not_completed':
        'No se cumplió el criterio de finalización del paso.',
    'task_attempts_exhausted': 'El paso agotó todos los intentos permitidos.',
    'replan_failure': 'OSIA no pudo crear un plan de recuperación.',
    'replans_exhausted':
        'La ejecución agotó todos los planes de recuperación permitidos.',
    'invalid_resume_state':
        'La ejecución guardada no se puede reanudar de forma segura.',
    'interrupted': 'La ejecución está en pausa y puede reanudarse.',
    'aborted': 'La ejecución fue abandonada por el usuario.',
    'orchestrator_failure':
        'La ejecución autónoma se detuvo por un error interno.',
    'checkpoint_failure': 'OSIA no pudo guardar el punto de control autónomo.',
    'unknown_failure':
        'La ejecución autónoma falló. Reinténtalo o revisa el diagnóstico.',
  },
};

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
  scanQrCode: 'Scan QR code',
  scanPairingQrTitle: 'Scan pairing QR code',
  scanPairingQrHint:
      'Point the camera at the QR code shown by OSIA on your PC.',
  invalidPairingQr:
      'This is not a valid OSIA pairing QR code. Try another code.',
  cameraPermissionDeniedForPairing:
      'Camera access was denied. You can cancel and enter the token manually.',
  cameraUnavailableForPairing:
      'The camera is unavailable. Try again or enter the token manually.',
  reviewModeLabel: 'Review mode',
  reviewModeEntryHint: 'Open the isolated local review mode.',
  reviewModeDescription:
      'Explore OSIA with synthetic data. No PC or online service is contacted.',
  reviewModeDemoData: 'Synthetic demo data',
  reviewModeLocalReply:
      'This local demo reply was generated on this device. No provider or PC was contacted, and no external action was performed.',
  reviewModeUnavailable: 'Unavailable in review mode.',
  reviewModeInputHint: 'Try a message (it stays on this device)',
  reviewModeConnectionStatus: 'No PC connection',
  reviewModeExit: 'Exit review mode',
  reviewModeSendMessage: 'Send message',
  reviewModeWelcome: 'Getting started',
  reviewModeSecondConversation: 'Planning a weekend walk',
  reviewModeSampleQuestion: 'What can I explore in OSIA Mobile?',
  reviewModeSampleAnswer:
      'This synthetic conversation previews the Chat interface. Its messages are sample data.',
  reviewModePlanQuestion: 'Can you help me plan a short walk?',
  reviewModePlanAnswer:
      'This is a sample response. No location, route service, or external action was used.',
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
      'Shows a persistent notification while OSIA is ready for messages from your PC. Android may stop it; opening OSIA reconnects normally.',
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
      "Personality shapes OSIA's tone. Skills are reusable instructions; they do not add tools, permissions, or capabilities.",
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
  ttsProviderLabel: 'TTS provider',
  ttsVoiceLabel: 'Voice',
  sttProviderLabel: 'Speech-to-text provider',
  sttFallbackProviderLabel: 'Fallback provider',
  sttNoFallback: 'None',
  sttNoLocalModels: 'No local Whisper model is downloaded on the PC',
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
  skillActivationRejected:
      'The PC kept this skill off because it is invalid, unavailable, or missing a declared tool.',
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
  autonomousNoConfiguredModels: 'No configured model is currently available.',
  autonomousModelFallback:
      'The selected autonomous model became unavailable. Another configured model was selected.',
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
  gmailRestReconnect: 'Reconnect Gmail',
  gmailRestPcHostedAuth:
      'Authentication and Gmail credentials stay on your PC-hosted OSIA.',
  gmailRestConfigureOnPc: 'Configure Google OAuth on PC',
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
  themeRed: 'Red',
  themeGreen: 'Green',
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
  scanQrCode: 'Scanner le code QR',
  scanPairingQrTitle: 'Scanner le code QR d’appairage',
  scanPairingQrHint:
      'Pointez la caméra vers le code QR affiché par OSIA sur votre PC.',
  invalidPairingQr:
      'Ce code QR n’est pas un code d’appairage OSIA valide. Essayez-en un autre.',
  cameraPermissionDeniedForPairing:
      'L’accès à la caméra a été refusé. Vous pouvez annuler et saisir le jeton manuellement.',
  cameraUnavailableForPairing:
      'La caméra est indisponible. Réessayez ou saisissez le jeton manuellement.',
  reviewModeLabel: 'Mode d’évaluation',
  reviewModeEntryHint: 'Ouvrir le mode d’évaluation local et isolé.',
  reviewModeDescription:
      'Explorez OSIA avec des données synthétiques. Aucun PC ni service en ligne ne sera contacté.',
  reviewModeDemoData: 'Données de démonstration synthétiques',
  reviewModeLocalReply:
      'Cette réponse de démonstration a été générée localement sur cet appareil. Aucun fournisseur ni PC n’a été contacté et aucune action externe n’a été effectuée.',
  reviewModeUnavailable: 'Indisponible en mode d’évaluation.',
  reviewModeInputHint: 'Essayez un message (il reste sur cet appareil)',
  reviewModeConnectionStatus: 'Aucune connexion à un PC',
  reviewModeExit: 'Quitter le mode d’évaluation',
  reviewModeSendMessage: 'Envoyer le message',
  reviewModeWelcome: 'Bien démarrer',
  reviewModeSecondConversation: 'Préparer une promenade',
  reviewModeSampleQuestion: 'Que puis-je découvrir dans OSIA Mobile ?',
  reviewModeSampleAnswer:
      'Cette conversation synthétique présente l’interface de chat. Ses messages sont des données d’exemple.',
  reviewModePlanQuestion: 'Peux-tu m’aider à prévoir une courte promenade ?',
  reviewModePlanAnswer:
      'Ceci est une réponse d’exemple. Aucune position, aucun service d’itinéraire ni aucune action externe n’a été utilisé.',
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
      'Affiche une notification persistante pendant qu’OSIA attend les messages du PC. Android peut l’arrêter ; ouvrir OSIA rétablit la connexion.',
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
      "La personnalité façonne le ton d'OSIA. Les skills sont des instructions réutilisables ; ils n'ajoutent ni outils, ni autorisations, ni capacités.",
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
  ttsProviderLabel: 'Fournisseur TTS',
  ttsVoiceLabel: 'Voix',
  sttProviderLabel: 'Fournisseur de reconnaissance vocale',
  sttFallbackProviderLabel: 'Fournisseur de secours',
  sttNoFallback: 'Aucun',
  sttNoLocalModels: 'Aucun modèle Whisper local n’est téléchargé sur le PC',
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
  skillActivationRejected:
      'Le PC a laissé ce skill désactivé car il est invalide, indisponible ou dépend d’un outil absent.',
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
      "Aucun modèle configuré n'est disponible actuellement.",
  autonomousModelFallback:
      'Le modèle autonome sélectionné est devenu indisponible. Un autre modèle configuré a été sélectionné.',
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
  gmailRestReconnect: 'Reconnecter Gmail',
  gmailRestPcHostedAuth:
      'L’authentification et les identifiants Gmail restent sur OSIA hébergé par votre PC.',
  gmailRestConfigureOnPc: 'Configurer Google OAuth sur PC',
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
  themeRed: 'Rouge',
  themeGreen: 'Vert',
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
  scanQrCode: '扫描二维码',
  scanPairingQrTitle: '扫描配对二维码',
  scanPairingQrHint: '将摄像头对准电脑上 OSIA 显示的二维码。',
  invalidPairingQr: '这不是有效的 OSIA 配对二维码。请扫描其他代码。',
  cameraPermissionDeniedForPairing: '摄像头权限已被拒绝。您可以取消并手动输入令牌。',
  cameraUnavailableForPairing: '摄像头不可用。请重试或手动输入令牌。',
  reviewModeLabel: '审核模式',
  reviewModeEntryHint: '打开隔离的本地审核模式。',
  reviewModeDescription: '使用合成数据探索 OSIA。不会连接电脑或在线服务。',
  reviewModeDemoData: '合成演示数据',
  reviewModeLocalReply: '此演示回复在本机生成。未联系任何模型服务或电脑，也未执行任何外部操作。',
  reviewModeUnavailable: '审核模式下不可用。',
  reviewModeInputHint: '试着发送消息（仅保留在本机）',
  reviewModeConnectionStatus: '未连接电脑',
  reviewModeExit: '退出审核模式',
  reviewModeSendMessage: '发送消息',
  reviewModeWelcome: '开始使用',
  reviewModeSecondConversation: '计划周末散步',
  reviewModeSampleQuestion: '我可以在 OSIA Mobile 中查看哪些内容？',
  reviewModeSampleAnswer: '此合成对话展示聊天界面。消息均为示例数据。',
  reviewModePlanQuestion: '可以帮我规划一段短途散步吗？',
  reviewModePlanAnswer: '这是示例回复。未使用位置、路线服务或任何外部操作。',
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
  backgroundConnectionSubtitle:
      '显示常驻通知，以便 OSIA 接收来自电脑的消息。Android 可能会停止此服务；打开 OSIA 会正常重新连接。',
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
  personalityDesc: '个性设定影响 OSIA 的语气。技能是可复用的指令；它们不会添加工具、权限或功能。',
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
  ttsProviderLabel: 'TTS 提供商',
  ttsVoiceLabel: '语音',
  sttProviderLabel: '语音转文字提供商',
  sttFallbackProviderLabel: '备用提供商',
  sttNoFallback: '无',
  sttNoLocalModels: 'PC 上未下载本地 Whisper 模型',
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
  skillActivationRejected: 'PC 保持此技能关闭，因为它无效、不可用或缺少声明的工具。',
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
  autonomousNoConfiguredModels: '当前没有可用的已配置模型。',
  autonomousModelFallback: '所选自主模型已不可用，已改选另一个已配置的模型。',
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
  gmailRestReconnect: '重新连接 Gmail',
  gmailRestPcHostedAuth: '身份验证和 Gmail 凭据仅保留在电脑托管的 OSIA 上。',
  gmailRestConfigureOnPc: '在电脑上配置 Google OAuth',
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
  themeRed: '红色',
  themeGreen: '绿色',
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
  scanQrCode: 'QR コードをスキャン',
  scanPairingQrTitle: 'ペアリング QR コードをスキャン',
  scanPairingQrHint: 'PC の OSIA に表示された QR コードにカメラを向けてください。',
  invalidPairingQr: '有効な OSIA ペアリング QR コードではありません。別のコードをお試しください。',
  cameraPermissionDeniedForPairing: 'カメラへのアクセスが拒否されました。キャンセルしてトークンを手動入力できます。',
  cameraUnavailableForPairing: 'カメラを使用できません。再試行するか、トークンを手動入力してください。',
  reviewModeLabel: 'レビューモード',
  reviewModeEntryHint: '隔離されたローカルレビューモードを開きます。',
  reviewModeDescription: '合成データで OSIA を確認できます。PC やオンラインサービスには接続しません。',
  reviewModeDemoData: '合成デモデータ',
  reviewModeLocalReply:
      'このデモ返信はこの端末でローカル生成されました。プロバイダーや PC には接続せず、外部操作も行っていません。',
  reviewModeUnavailable: 'レビューモードでは利用できません。',
  reviewModeInputHint: 'メッセージを試してください（この端末内に留まります）',
  reviewModeConnectionStatus: 'PC 未接続',
  reviewModeExit: 'レビューモードを終了',
  reviewModeSendMessage: 'メッセージを送信',
  reviewModeWelcome: 'はじめに',
  reviewModeSecondConversation: '週末の散歩を計画',
  reviewModeSampleQuestion: 'OSIA Mobile では何を確認できますか？',
  reviewModeSampleAnswer: 'この合成会話はチャット画面のプレビューです。すべてサンプルデータです。',
  reviewModePlanQuestion: '短い散歩の計画を手伝ってくれますか？',
  reviewModePlanAnswer: 'これはサンプル返信です。位置情報やルートサービス、外部操作は使用していません。',
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
  backgroundConnectionSubtitle:
      'PC からのメッセージを受信できる間は常設通知を表示します。Android が停止した場合、OSIA を開くと再接続します。',
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
      '性格設定は OSIA の話し方を調整します。スキルは再利用可能な指示であり、ツール・権限・機能を追加するものではありません。',
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
  ttsProviderLabel: 'TTS プロバイダー',
  ttsVoiceLabel: '音声',
  sttProviderLabel: '音声認識プロバイダー',
  sttFallbackProviderLabel: '予備プロバイダー',
  sttNoFallback: 'なし',
  sttNoLocalModels: 'PC にローカル Whisper モデルがダウンロードされていません',
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
  skillActivationRejected: 'このスキルは無効、利用不可、または宣言されたツールが不足しているため、PC 側でオフのままです。',
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
  autonomousNoConfiguredModels: '現在利用できる設定済みモデルはありません。',
  autonomousModelFallback: '選択した自律モデルを利用できないため、別の設定済みモデルを選択しました。',
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
  gmailRestReconnect: 'Gmail を再接続',
  gmailRestPcHostedAuth: '認証と Gmail の資格情報は PC 上の OSIA にのみ保持されます。',
  gmailRestConfigureOnPc: 'PC で Google OAuth を設定',
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
  themeRed: 'レッド',
  themeGreen: 'グリーン',
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
  scanQrCode: 'QR-Code scannen',
  scanPairingQrTitle: 'Kopplungs-QR-Code scannen',
  scanPairingQrHint:
      'Richten Sie die Kamera auf den QR-Code, den OSIA auf Ihrem PC anzeigt.',
  invalidPairingQr:
      'Dies ist kein gültiger OSIA-Kopplungs-QR-Code. Versuchen Sie einen anderen Code.',
  cameraPermissionDeniedForPairing:
      'Der Kamerazugriff wurde verweigert. Sie können abbrechen und das Token manuell eingeben.',
  cameraUnavailableForPairing:
      'Die Kamera ist nicht verfügbar. Versuchen Sie es erneut oder geben Sie das Token manuell ein.',
  reviewModeLabel: 'Prüfmodus',
  reviewModeEntryHint: 'Den isolierten lokalen Prüfmodus öffnen.',
  reviewModeDescription:
      'OSIA mit synthetischen Daten erkunden. Es wird kein PC und kein Online-Dienst kontaktiert.',
  reviewModeDemoData: 'Synthetische Demodaten',
  reviewModeLocalReply:
      'Diese lokale Demoantwort wurde auf diesem Gerät erstellt. Es wurde kein Anbieter oder PC kontaktiert und keine externe Aktion ausgeführt.',
  reviewModeUnavailable: 'Im Prüfmodus nicht verfügbar.',
  reviewModeInputHint: 'Nachricht testen (bleibt auf diesem Gerät)',
  reviewModeConnectionStatus: 'Keine PC-Verbindung',
  reviewModeExit: 'Prüfmodus verlassen',
  reviewModeSendMessage: 'Nachricht senden',
  reviewModeWelcome: 'Erste Schritte',
  reviewModeSecondConversation: 'Einen Wochenendspaziergang planen',
  reviewModeSampleQuestion: 'Was kann ich in OSIA Mobile ansehen?',
  reviewModeSampleAnswer:
      'Diese synthetische Unterhaltung zeigt die Chat-Oberfläche. Die Nachrichten sind Beispieldaten.',
  reviewModePlanQuestion: 'Kannst du mir bei einem kurzen Spaziergang helfen?',
  reviewModePlanAnswer:
      'Dies ist eine Beispielantwort. Es wurden weder Standort- noch Routendienste oder externe Aktionen verwendet.',
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
      'Zeigt eine dauerhafte Benachrichtigung, während OSIA für Nachrichten vom PC bereit ist. Android kann den Dienst beenden; beim Öffnen verbindet sich OSIA neu.',
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
      'Die Persönlichkeit prägt OSIAs Ton. Skills sind wiederverwendbare Anweisungen; sie fügen keine Tools, Berechtigungen oder Fähigkeiten hinzu.',
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
  ttsProviderLabel: 'TTS-Anbieter',
  ttsVoiceLabel: 'Stimme',
  sttProviderLabel: 'Spracherkennungs-Anbieter',
  sttFallbackProviderLabel: 'Ersatzanbieter',
  sttNoFallback: 'Keiner',
  sttNoLocalModels:
      'Auf dem PC ist kein lokales Whisper-Modell heruntergeladen',
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
  skillActivationRejected:
      'Der PC ließ diesen Skill deaktiviert, weil er ungültig oder nicht verfügbar ist oder ein deklariertes Tool fehlt.',
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
      'Derzeit ist kein konfiguriertes Modell verfügbar.',
  autonomousModelFallback:
      'Das ausgewählte autonome Modell ist nicht mehr verfügbar. Ein anderes konfiguriertes Modell wurde ausgewählt.',
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
  gmailRestReconnect: 'Gmail erneut verbinden',
  gmailRestPcHostedAuth:
      'Authentifizierung und Gmail-Zugangsdaten bleiben auf dem PC mit OSIA.',
  gmailRestConfigureOnPc: 'Google OAuth am PC konfigurieren',
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
  themeRed: 'Rot',
  themeGreen: 'Grün',
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
  scanQrCode: 'Escanear código QR',
  scanPairingQrTitle: 'Escanear QR de emparejamiento',
  scanPairingQrHint: 'Apunta la cámara al código QR que muestra OSIA en tu PC.',
  invalidPairingQr:
      'Este no es un código QR de emparejamiento de OSIA válido. Prueba con otro.',
  cameraPermissionDeniedForPairing:
      'Se denegó el acceso a la cámara. Puedes cancelar e introducir el token manualmente.',
  cameraUnavailableForPairing:
      'La cámara no está disponible. Inténtalo de nuevo o introduce el token manualmente.',
  reviewModeLabel: 'Modo de revisión',
  reviewModeEntryHint: 'Abrir el modo de revisión local y aislado.',
  reviewModeDescription:
      'Explora OSIA con datos sintéticos. No se contactará con ningún PC ni servicio en línea.',
  reviewModeDemoData: 'Datos sintéticos de demostración',
  reviewModeLocalReply:
      'Esta respuesta de demostración se generó localmente en este dispositivo. No se contactó con ningún proveedor ni PC y no se realizó ninguna acción externa.',
  reviewModeUnavailable: 'No disponible en el modo de revisión.',
  reviewModeInputHint: 'Prueba un mensaje (permanece en este dispositivo)',
  reviewModeConnectionStatus: 'Sin conexión a un PC',
  reviewModeExit: 'Salir del modo de revisión',
  reviewModeSendMessage: 'Enviar mensaje',
  reviewModeWelcome: 'Primeros pasos',
  reviewModeSecondConversation: 'Planear un paseo de fin de semana',
  reviewModeSampleQuestion: '¿Qué puedo explorar en OSIA Mobile?',
  reviewModeSampleAnswer:
      'Esta conversación sintética muestra la interfaz de chat. Sus mensajes son datos de ejemplo.',
  reviewModePlanQuestion: '¿Puedes ayudarme a planear un paseo corto?',
  reviewModePlanAnswer:
      'Esta es una respuesta de ejemplo. No se usaron ubicación, servicios de rutas ni acciones externas.',
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
      'Muestra una notificación permanente mientras OSIA espera mensajes del PC. Android puede detenerlo; al abrir OSIA se reconecta normalmente.',
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
      'La personalidad define el tono de OSIA. Los skills son instrucciones reutilizables; no añaden herramientas, permisos ni capacidades.',
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
  ttsProviderLabel: 'Proveedor de TTS',
  ttsVoiceLabel: 'Voz',
  sttProviderLabel: 'Proveedor de voz a texto',
  sttFallbackProviderLabel: 'Proveedor alternativo',
  sttNoFallback: 'Ninguno',
  sttNoLocalModels: 'No hay ningún modelo Whisper local descargado en el PC',
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
  skillActivationRejected:
      'El PC mantuvo este skill desactivado porque no es válido, no está disponible o le falta una herramienta declarada.',
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
      'No hay ningún modelo configurado disponible actualmente.',
  autonomousModelFallback:
      'El modelo autónomo seleccionado dejó de estar disponible. Se seleccionó otro modelo configurado.',
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
  gmailRestReconnect: 'Volver a conectar Gmail',
  gmailRestPcHostedAuth:
      'La autenticación y las credenciales de Gmail permanecen en OSIA alojado en tu PC.',
  gmailRestConfigureOnPc: 'Configurar Google OAuth en el PC',
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
  themeRed: 'Rojo',
  themeGreen: 'Verde',
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

extension PermissionOsiaStrings on OsiaStrings {
  String get pairingQrDataNotice => _permissionText(
    'Android QR scanning uses Google ML Kit, which sends diagnostic and usage metrics to Google. Manual token pairing avoids this SDK.',
    'Le scan QR Android utilise Google ML Kit, qui transmet des diagnostics et métriques d’usage à Google. L’association manuelle par jeton évite ce SDK.',
    'Android 二维码扫描使用 Google ML Kit，并向 Google 发送诊断和使用指标。手动输入配对令牌可避免使用此 SDK。',
    'Android の QR スキャンは Google ML Kit を使用し、診断・利用状況の指標を Google に送信します。トークンを手入力すれば、この SDK を使わずに接続できます。',
    'Der Android-QR-Scanner verwendet Google ML Kit und sendet Diagnose- und Nutzungsmetriken an Google. Manuelle Token-Kopplung verwendet dieses SDK nicht.',
    'El escaneo QR de Android usa Google ML Kit y envía métricas de diagnóstico y uso a Google. La vinculación manual con token evita este SDK.',
  );

  String _permissionText(
    String en,
    String fr,
    String zh,
    String ja,
    String de,
    String es,
  ) => switch (languageCode) {
    'fr' => fr,
    'zh' => zh,
    'ja' => ja,
    'de' => de,
    'es' => es,
    _ => en,
  };

  String get permissionsTitle => _permissionText(
    'Permissions',
    'Autorisations',
    '权限',
    '権限',
    'Berechtigungen',
    'Permisos',
  );
  String get permissionsSubtitle => _permissionText(
    'PC-controlled access',
    'Accès contrôlé par le PC',
    '由电脑控制的访问权限',
    'PC が管理するアクセス',
    'Vom PC gesteuerter Zugriff',
    'Acceso controlado por el PC',
  );
  String get permissionLive =>
      _permissionText('Live', 'En direct', '实时', 'ライブ', 'Live', 'En directo');
  String get permissionLastKnown => _permissionText(
    'Last known state',
    'Dernier état connu',
    '上次已知状态',
    '最後に確認した状態',
    'Letzter bekannter Stand',
    'Último estado conocido',
  );
  String get permissionSyncing => _permissionText(
    'Syncing with your PC…',
    'Synchronisation avec votre PC…',
    '正在与电脑同步…',
    'PC と同期中…',
    'Synchronisierung mit dem PC…',
    'Sincronizando con el PC…',
  );
  String get permissionNoSnapshot => _permissionText(
    'Connect to your PC to load permissions.',
    'Connectez-vous à votre PC pour charger les autorisations.',
    '连接电脑以加载权限。',
    'PC に接続して権限を読み込んでください。',
    'Mit dem PC verbinden, um Berechtigungen zu laden.',
    'Conecta el PC para cargar los permisos.',
  );
  String get permissionDefaultAccess => _permissionText(
    'Default Access',
    'Accès par défaut',
    '默认访问',
    'デフォルトアクセス',
    'Standardzugriff',
    'Acceso predeterminado',
  );
  String get permissionFullAccess => _permissionText(
    'Full Access',
    'Accès complet',
    '完全访问',
    'フルアクセス',
    'Vollzugriff',
    'Acceso total',
  );
  String get permissionMixedAccess => permissionCustomAccess;
  String get permissionCustomAccess => _permissionText(
    'Custom Access',
    'Accès personnalisé',
    '自定义访问',
    'カスタムアクセス',
    'Benutzerdefinierter Zugriff',
    'Acceso personalizado',
  );
  String get permissionAskEachTime => _permissionText(
    'Ask every time',
    'Demander à chaque fois',
    '每次询问',
    '毎回確認',
    'Jedes Mal fragen',
    'Preguntar cada vez',
  );
  String get permissionPcOffline => _permissionText(
    'PC offline',
    'PC hors ligne',
    '电脑离线',
    'PC はオフラインです',
    'PC offline',
    'PC sin conexión',
  );
  String get permissionPcConfirmationRequired => _permissionText(
    'Confirmation required on the PC',
    'Confirmation requise sur le PC',
    '需要在电脑上确认',
    'PC での確認が必要です',
    'Bestätigung am PC erforderlich',
    'Se requiere confirmación en el PC',
  );
  String get permissionSyncError => _permissionText(
    'Permission sync unavailable',
    'Synchronisation des autorisations indisponible',
    '权限同步不可用',
    '権限を同期できません',
    'Berechtigungssynchronisierung nicht verfügbar',
    'Sincronización de permisos no disponible',
  );
  String get permissionCurrentMode => _permissionText(
    'Current mode',
    'Mode actuel',
    '当前模式',
    '現在のモード',
    'Aktueller Modus',
    'Modo actual',
  );
  String get permissionModes =>
      _permissionText('Mode', 'Mode', '模式', 'モード', 'Modus', 'Modo');
  String get permissionCategories => _permissionText(
    'Categories',
    'Catégories',
    '类别',
    'カテゴリー',
    'Kategorien',
    'Categorías',
  );
  String get permissionDefaultDescription => _permissionText(
    'OSIA asks before sensitive actions.',
    'OSIA demande avant les actions sensibles.',
    'OSIA 会在敏感操作前询问。',
    'OSIA は重要な操作の前に確認します。',
    'OSIA fragt vor sensiblen Aktionen nach.',
    'OSIA pregunta antes de acciones sensibles.',
  );
  String get permissionCustomDescription => _permissionText(
    'Choose which ordinary actions can run automatically.',
    'Choisissez les actions ordinaires exécutables automatiquement.',
    '选择可自动执行的常规操作。',
    '自動実行できる通常操作を選択します。',
    'Wählen Sie automatisch erlaubte normale Aktionen.',
    'Elige qué acciones ordinarias pueden ejecutarse automáticamente.',
  );
  String get permissionFullDescription => _permissionText(
    'Confirm in OSIA, then wait for the confirmed PC state.',
    'Confirmez dans OSIA, puis attendez l’état confirmé du PC.',
    '在 OSIA 中确认，然后等待电脑确认状态。',
    'OSIA で確認し、PC の確認済み状態を待ちます。',
    'In OSIA bestätigen und den bestätigten PC-Stand abwarten.',
    'Confirma en OSIA y espera el estado confirmado del PC.',
  );
  String get permissionFullWarning => _permissionText(
    'Full Access lets OSIA perform ordinary actions without asking. Critical destruction protections remain active.',
    'L’Accès complet permet à OSIA d’effectuer les actions ordinaires sans demander. Les protections critiques restent actives.',
    '完全访问允许 OSIA 无需询问即可执行常规操作。关键破坏保护仍然有效。',
    'フルアクセスでは OSIA が通常操作を確認なしで実行できます。重要な破壊保護は継続します。',
    'Vollzugriff erlaubt OSIA normale Aktionen ohne Nachfrage. Kritische Schutzmechanismen bleiben aktiv.',
    'El Acceso total permite acciones ordinarias sin preguntar. Las protecciones críticas siguen activas.',
  );
  String get permissionFullActivationPending => _permissionText(
    'Activation… Waiting for the confirmed PC state.',
    'Activation… En attente de l’état confirmé du PC.',
    '正在启用… 正在等待电脑确认状态。',
    '有効化中… PC の確認済み状態を待っています。',
    'Aktivierung… Warten auf den bestätigten PC-Stand.',
    'Activando… Esperando el estado confirmado del PC.',
  );
  String get permissionChooseCategories => _permissionText(
    'Adjust a category below to create Custom Access.',
    'Modifiez une catégorie ci-dessous pour créer un Accès personnalisé.',
    '在下方调整类别以创建自定义访问。',
    '下のカテゴリーを変更してカスタムアクセスを作成します。',
    'Passen Sie unten eine Kategorie für benutzerdefinierten Zugriff an.',
    'Ajusta una categoría para crear Acceso personalizado.',
  );
  String get permissionContractIncompatible => _permissionText(
    'Update OSIA on your PC to manage permissions here.',
    'Mettez OSIA à jour sur votre PC pour gérer les autorisations ici.',
    '请更新电脑上的 OSIA 以在此管理权限。',
    'ここで権限を管理するには PC の OSIA を更新してください。',
    'Aktualisieren Sie OSIA auf dem PC, um Berechtigungen hier zu verwalten.',
    'Actualiza OSIA en el PC para gestionar aquí los permisos.',
  );
  String get permissionRequestTimedOut => _permissionText(
    'The confirmed PC state was restored.',
    'Le dernier état confirmé du PC a été restauré.',
    '已恢复电脑上最后确认的状态。',
    'PC で最後に確認された状態に戻しました。',
    'Der zuletzt bestätigte PC-Stand wurde wiederhergestellt.',
    'Se restauró el último estado confirmado del PC.',
  );
  String get permissionConfirmAction => _permissionText(
    'Confirm',
    'Confirmer',
    '确认',
    '確認',
    'Bestätigen',
    'Confirmar',
  );
  String get permissionRevokeAllTemporary => _permissionText(
    'Revoke all temporary permissions',
    'Révoquer toutes les autorisations temporaires',
    '撤销所有临时权限',
    '一時的な権限をすべて取り消す',
    'Alle temporären Berechtigungen widerrufen',
    'Revocar todos los permisos temporales',
  );
  String get permissionRevokeConfirmation => _permissionText(
    'This removes the selected temporary permission immediately.',
    'Cette action révoque immédiatement l’autorisation temporaire sélectionnée.',
    '这会立即撤销所选临时权限。',
    '選択した一時権限を直ちに取り消します。',
    'Dies widerruft die ausgewählte temporäre Berechtigung sofort.',
    'Esto revoca inmediatamente el permiso temporal seleccionado.',
  );
  String get permissionRevokeAllConfirmation => _permissionText(
    'This removes every active temporary permission.',
    'Cette action révoque toutes les autorisations temporaires actives.',
    '这会撤销所有有效的临时权限。',
    '有効な一時権限をすべて取り消します。',
    'Dies widerruft alle aktiven temporären Berechtigungen.',
    'Esto revoca todos los permisos temporales activos.',
  );
  String get permissionDisableFullConfirmation => _permissionText(
    'Full Access will be disabled immediately.',
    'L’Accès complet sera désactivé immédiatement.',
    '完全访问将立即停用。',
    'フルアクセスは直ちに無効になります。',
    'Vollzugriff wird sofort deaktiviert.',
    'El Acceso total se desactivará inmediatamente.',
  );
  String get permissionPcEnableOnly => _permissionText(
    'Full Access can only be enabled on your PC.',
    'L’Accès complet peut uniquement être activé sur votre PC.',
    '完全访问只能在电脑上启用。',
    'フルアクセスは PC でのみ有効にできます。',
    'Vollzugriff kann nur am PC aktiviert werden.',
    'El Acceso total solo se puede activar en el PC.',
  );
  String get permissionOn =>
      _permissionText('On', 'Activé', '开启', 'オン', 'An', 'Activado');
  String get permissionOff =>
      _permissionText('Off', 'Désactivé', '关闭', 'オフ', 'Aus', 'Desactivado');
  String get permissionTemporary => _permissionText(
    'Temporary permissions',
    'Autorisations temporaires',
    '临时权限',
    '一時的な権限',
    'Temporäre Berechtigungen',
    'Permisos temporales',
  );
  String get permissionNoTemporary => _permissionText(
    'No temporary permissions are active.',
    'Aucune autorisation temporaire active.',
    '没有有效的临时权限。',
    '有効な一時権限はありません。',
    'Keine temporären Berechtigungen aktiv.',
    'No hay permisos temporales activos.',
  );
  String get permissionRevoke => _permissionText(
    'Revoke',
    'Révoquer',
    '撤销',
    '取り消す',
    'Widerrufen',
    'Revocar',
  );
  String get permissionRevokeRun => _permissionText(
    'Revoke all for this run',
    'Tout révoquer pour cette exécution',
    '撤销此运行的全部权限',
    'この実行の権限をすべて取り消す',
    'Alles für diesen Lauf widerrufen',
    'Revocar todo para esta ejecución',
  );
  String get permissionRevokeTask => _permissionText(
    'Revoke all for this task',
    'Tout révoquer pour cette tâche',
    '撤销此任务的全部权限',
    'このタスクの権限をすべて取り消す',
    'Alles für diese Aufgabe widerrufen',
    'Revocar todo para esta tarea',
  );
  String get permissionRevokeAll => _permissionText(
    'Revoke all delegated access',
    'Révoquer tous les accès délégués',
    '撤销所有委托访问',
    '委任アクセスをすべて取り消す',
    'Alle delegierten Zugriffe widerrufen',
    'Revocar todo el acceso delegado',
  );
  String get permissionDisableFullAccess => _permissionText(
    'Disable Full Access',
    'Désactiver l’Accès complet',
    '停用完全访问',
    'フルアクセスを無効にする',
    'Vollzugriff deaktivieren',
    'Desactivar Acceso total',
  );
  String get permissionPending => _permissionText(
    'Waiting for PC confirmation…',
    'En attente de confirmation du PC…',
    '等待电脑确认…',
    'PC の確認待ち…',
    'Warten auf PC-Bestätigung…',
    'Esperando confirmación del PC…',
  );
  String get permissionRefresh => _permissionText(
    'Refresh',
    'Actualiser',
    '刷新',
    '更新',
    'Aktualisieren',
    'Actualizar',
  );
  String get permissionChangesUnavailable => _permissionText(
    'Changes are unavailable on this PC.',
    'Les modifications sont indisponibles sur ce PC.',
    '此电脑暂时无法进行更改。',
    'この PC では変更できません。',
    'Änderungen sind auf diesem PC nicht verfügbar.',
    'Los cambios no están disponibles en este PC.',
  );
  String get permissionHistory => _permissionText(
    'Recent activity',
    'Activité récente',
    '最近活动',
    '最近の履歴',
    'Letzte Aktivität',
    'Actividad reciente',
  );
  String get permissionNoHistory => _permissionText(
    'No permission activity yet.',
    'Aucune activité pour le moment.',
    '暂无权限活动。',
    '権限の履歴はまだありません。',
    'Noch keine Berechtigungsaktivität.',
    'Aún no hay actividad de permisos.',
  );
  String get permissionApplied => _permissionText(
    'Confirmed by your PC.',
    'Confirmé par votre PC.',
    '电脑已确认。',
    'PC で確認されました。',
    'Vom PC bestätigt.',
    'Confirmado por el PC.',
  );
  String get permissionRejected => _permissionText(
    'The PC did not apply that change.',
    'Le PC n’a pas appliqué cette modification.',
    '电脑未应用此更改。',
    'PC はこの変更を適用しませんでした。',
    'Der PC hat die Änderung nicht angewendet.',
    'El PC no aplicó el cambio.',
  );

  String permissionCategoryLabel(String key) => switch (key) {
    'files_modify' => _permissionText(
      'Modify files',
      'Modifier des fichiers',
      '修改文件',
      'ファイルの変更',
      'Dateien ändern',
      'Modificar archivos',
    ),
    'files_delete' => _permissionText(
      'Delete files',
      'Supprimer des fichiers',
      '删除文件',
      'ファイルの削除',
      'Dateien löschen',
      'Eliminar archivos',
    ),
    'commands' => _permissionText(
      'Run commands',
      'Exécuter des commandes',
      '运行命令',
      'コマンドの実行',
      'Befehle ausführen',
      'Ejecutar comandos',
    ),
    'browser_account' => _permissionText(
      'Browser account actions',
      'Actions de compte web',
      '浏览器账户操作',
      'ブラウザーのアカウント操作',
      'Browser-Kontoaktionen',
      'Acciones de cuenta web',
    ),
    'connectors' => _permissionText(
      'Connected services',
      'Services connectés',
      '已连接服务',
      '接続済みサービス',
      'Verbundene Dienste',
      'Servicios conectados',
    ),
    'send_publish_submit' => _permissionText(
      'Send or publish',
      'Envoyer ou publier',
      '发送或发布',
      '送信または公開',
      'Senden oder veröffentlichen',
      'Enviar o publicar',
    ),
    'purchases_payments' => _permissionText(
      'Purchases and payments',
      'Achats et paiements',
      '购买与付款',
      '購入と支払い',
      'Käufe und Zahlungen',
      'Compras y pagos',
    ),
    'autonomous_actions' => _permissionText(
      'Autonomous actions',
      'Actions autonomes',
      '自主操作',
      '自律操作',
      'Autonome Aktionen',
      'Acciones autónomas',
    ),
    'scheduled_actions' => _permissionText(
      'Scheduled actions',
      'Actions planifiées',
      '计划操作',
      'スケジュール済み操作',
      'Geplante Aktionen',
      'Acciones programadas',
    ),
    _ => _permissionText(
      'Sensitive actions',
      'Actions sensibles',
      '敏感操作',
      '重要な操作',
      'Sensible Aktionen',
      'Acciones sensibles',
    ),
  };

  String permissionContractText(String key) => switch (key) {
    'permissions.category.files_modify' => permissionCategoryLabel(
      'files_modify',
    ),
    'permissions.category.files_delete' => permissionCategoryLabel(
      'files_delete',
    ),
    'permissions.category.commands' => permissionCategoryLabel('commands'),
    'permissions.category.browser_account' => permissionCategoryLabel(
      'browser_account',
    ),
    'permissions.category.connectors' => permissionCategoryLabel('connectors'),
    'permissions.category.send_publish_submit' => permissionCategoryLabel(
      'send_publish_submit',
    ),
    'permissions.category.purchases_payments' => permissionCategoryLabel(
      'purchases_payments',
    ),
    'permissions.category.autonomous_actions' => permissionCategoryLabel(
      'autonomous_actions',
    ),
    'permissions.category.scheduled_actions' => permissionCategoryLabel(
      'scheduled_actions',
    ),
    'permissions.switch.files_modify' => _permissionText(
      'Create or edit files without asking each time.',
      'Créer ou modifier des fichiers sans demander à chaque fois.',
      '无需每次询问即可创建或编辑文件。',
      '毎回確認せずにファイルを作成・編集します。',
      'Dateien ohne jedes Mal zu fragen erstellen oder ändern.',
      'Crear o editar archivos sin preguntar cada vez.',
    ),
    'permissions.switch.files_delete' => _permissionText(
      'Delete ordinary files without asking each time.',
      'Supprimer des fichiers ordinaires sans demander à chaque fois.',
      '无需每次询问即可删除普通文件。',
      '毎回確認せずに通常のファイルを削除します。',
      'Normale Dateien ohne jedes Mal zu fragen löschen.',
      'Eliminar archivos ordinarios sin preguntar cada vez.',
    ),
    'permissions.switch.commands' => _permissionText(
      'Run classified commands and scripts automatically.',
      'Exécuter automatiquement les commandes et scripts classifiés.',
      '自动运行已分类的命令和脚本。',
      '分類済みのコマンドとスクリプトを自動実行します。',
      'Klassifizierte Befehle und Skripte automatisch ausführen.',
      'Ejecutar automáticamente comandos y scripts clasificados.',
    ),
    'permissions.switch.browser_account' => _permissionText(
      'Allow ordinary browser and account actions.',
      'Autoriser les actions ordinaires de navigateur et de compte.',
      '允许常规浏览器和账户操作。',
      '通常のブラウザーとアカウント操作を許可します。',
      'Normale Browser- und Kontoaktionen erlauben.',
      'Permitir acciones ordinarias del navegador y la cuenta.',
    ),
    'permissions.switch.connectors' => _permissionText(
      'Use Gmail, MCP and connected services automatically.',
      'Utiliser automatiquement Gmail, MCP et les services connectés.',
      '自动使用 Gmail、MCP 和已连接服务。',
      'Gmail、MCP、接続済みサービスを自動使用します。',
      'Gmail, MCP und verbundene Dienste automatisch nutzen.',
      'Usar automáticamente Gmail, MCP y servicios conectados.',
    ),
    'permissions.switch.send_publish_submit' => _permissionText(
      'Allow ordinary sends, publications and submissions.',
      'Autoriser les envois, publications et soumissions ordinaires.',
      '允许常规发送、发布和提交。',
      '通常の送信、公開、提出を許可します。',
      'Normale Sendungen, Veröffentlichungen und Übermittlungen erlauben.',
      'Permitir envíos, publicaciones y entregas ordinarias.',
    ),
    'permissions.switch.purchases_payments' => _permissionText(
      'Apply the payment limits confirmed on the PC.',
      'Appliquer les limites de paiement confirmées sur le PC.',
      '应用在电脑上确认的付款限制。',
      'PC で確認された支払い制限を適用します。',
      'Die am PC bestätigten Zahlungslimits anwenden.',
      'Aplicar los límites de pago confirmados en el PC.',
    ),
    'permissions.switch.autonomous_actions' => _permissionText(
      'Allow ordinary actions in Autonomous runs.',
      'Autoriser les actions ordinaires dans les exécutions autonomes.',
      '允许自主运行中的常规操作。',
      '自律実行での通常操作を許可します。',
      'Normale Aktionen in autonomen Läufen erlauben.',
      'Permitir acciones ordinarias en ejecuciones autónomas.',
    ),
    'permissions.switch.scheduled_actions' => _permissionText(
      'Allow ordinary scheduled and background actions.',
      'Autoriser les actions planifiées et en arrière-plan ordinaires.',
      '允许常规计划任务和后台操作。',
      '通常のスケジュール済み・バックグラウンド操作を許可します。',
      'Normale geplante und Hintergrundaktionen erlauben.',
      'Permitir acciones ordinarias programadas y en segundo plano.',
    ),
    _ => '',
  };

  String permissionActionLabel(String key) => switch (key) {
    'files_and_folders' => _permissionText(
      'Files and folders',
      'Fichiers et dossiers',
      '文件和文件夹',
      'ファイルとフォルダー',
      'Dateien und Ordner',
      'Archivos y carpetas',
    ),
    'commands' => permissionCategoryLabel('commands'),
    'device_settings' => _permissionText(
      'Device settings',
      'Réglages de l’appareil',
      '设备设置',
      'デバイス設定',
      'Geräteeinstellungen',
      'Ajustes del dispositivo',
    ),
    'connected_services' => permissionCategoryLabel('connectors'),
    'web_actions' => _permissionText(
      'Web actions',
      'Actions web',
      '网页操作',
      'Web 操作',
      'Web-Aktionen',
      'Acciones web',
    ),
    'payments' => permissionCategoryLabel('purchases_payments'),
    _ => permissionCategoryLabel(''),
  };

  String permissionContextLabel(String context) => switch (context) {
    'autonomous' => _permissionText(
      'Autonomous',
      'Autonome',
      '自主',
      '自律',
      'Autonom',
      'Autónomo',
    ),
    'scheduled' => _permissionText(
      'Scheduled Task',
      'Tâche planifiée',
      '计划任务',
      'スケジュール済みタスク',
      'Geplante Aufgabe',
      'Tarea programada',
    ),
    _ => _permissionText('Chat', 'Chat', '聊天', 'チャット', 'Chat', 'Chat'),
  };

  String permissionRemainingUses(int count) => _permissionText(
    '$count use${count == 1 ? '' : 's'} left',
    '$count utilisation${count == 1 ? '' : 's'} restante${count == 1 ? '' : 's'}',
    '剩余 $count 次',
    '残り $count 回',
    '$count Verwendung${count == 1 ? '' : 'en'} übrig',
    '$count uso${count == 1 ? '' : 's'} restante${count == 1 ? '' : 's'}',
  );

  String permissionExpiresIn(int minutes) => _permissionText(
    'Expires in $minutes min',
    'Expire dans $minutes min',
    '$minutes 分钟后到期',
    '$minutes 分後に期限切れ',
    'Läuft in $minutes Min. ab',
    'Caduca en $minutes min',
  );

  String permissionHistoryLabel(String event) => switch (event) {
    'full_access_enabled' => permissionFullAccess,
    'full_access_disabled' => permissionDisableFullAccess,
    'grant_created' => _permissionText(
      'Temporary access added',
      'Accès temporaire ajouté',
      '已添加临时访问',
      '一時アクセスを追加',
      'Temporärer Zugriff hinzugefügt',
      'Acceso temporal añadido',
    ),
    'grant_revoked' => _permissionText(
      'Temporary access revoked',
      'Accès temporaire révoqué',
      '已撤销临时访问',
      '一時アクセスを取り消し',
      'Temporärer Zugriff widerrufen',
      'Acceso temporal revocado',
    ),
    'delegated_authority_revoked' => permissionRevokeAll,
    'automatic_permission_changed' => _permissionText(
      'Access settings changed',
      'Réglages d’accès modifiés',
      '访问设置已更改',
      'アクセス設定を変更',
      'Zugriffseinstellungen geändert',
      'Ajustes de acceso modificados',
    ),
    _ => _permissionText(
      'Permission activity',
      'Activité d’autorisation',
      '权限活动',
      '権限の履歴',
      'Berechtigungsaktivität',
      'Actividad de permisos',
    ),
  };
}

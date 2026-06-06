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

  // ── Connection screen ──
  final String enterYourToken;
  final String connect;
  final String connectingEllipsis;
  final String tokenRequired;
  final String connectionFailed;
  final String invalidToken;

  // ── Chat screen ──
  final String conversations;
  final String newChat;
  final String noConversationsYet;
  final String sayHello;
  final String typeMessageOrMic;
  final String messageHint;
  final String deleteConversationTitle;
  final String deleteConversationBodyTemplate; // {title}
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

  // ── Model selector ──
  final String availableModels;
  final String noModelsReceived;
  final String modelsLoadFailed;
  final String otherProviders;

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
  final String disconnect;
  final String disconnectSubtitle;
  final String disconnectConfirmTitle;
  final String disconnectConfirmBody;
  final String makeDonation;
  final String linkOpenFailed;

  // ── APIs & Providers ──
  final String providersTitle;
  final String configureProviders;
  final String liveApi;
  final String liveApiNotice;
  final String catVoiceToVoice;
  final String catAiProviders;
  final String catTtsProviders;
  final String catSttProviders;
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
  final String cronEveryMinutesTemplate; // {n}
  final String cronEveryHoursTemplate; // {n}
  final String cronEveryDaysTemplate; // {n}
  final String cronDailyAtTemplate; // {t}
  final String cronOnceTemplate; // {d} {t}

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
  final String heartbeatWaiting;
  final String systemMetricsHeader;
  final String metricCpu;
  final String metricRam;
  final String metricDisk;
  final String metricCpuTemp;
  final String metricGpuTemp;

  // ── General / time format ──
  final String sectionGeneral;
  final String timeFormatLabel;

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
    required this.enterYourToken,
    required this.connect,
    required this.connectingEllipsis,
    required this.tokenRequired,
    required this.connectionFailed,
    required this.invalidToken,
    required this.conversations,
    required this.newChat,
    required this.noConversationsYet,
    required this.sayHello,
    required this.typeMessageOrMic,
    required this.messageHint,
    required this.deleteConversationTitle,
    required this.deleteConversationBodyTemplate,
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
    required this.availableModels,
    required this.noModelsReceived,
    required this.modelsLoadFailed,
    required this.otherProviders,
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
    required this.disconnect,
    required this.disconnectSubtitle,
    required this.disconnectConfirmTitle,
    required this.disconnectConfirmBody,
    required this.makeDonation,
    required this.linkOpenFailed,
    required this.providersTitle,
    required this.configureProviders,
    required this.liveApi,
    required this.liveApiNotice,
    required this.catVoiceToVoice,
    required this.catAiProviders,
    required this.catTtsProviders,
    required this.catSttProviders,
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
    required this.cronEveryMinutesTemplate,
    required this.cronEveryHoursTemplate,
    required this.cronEveryDaysTemplate,
    required this.cronDailyAtTemplate,
    required this.cronOnceTemplate,
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
    required this.heartbeatWaiting,
    required this.systemMetricsHeader,
    required this.metricCpu,
    required this.metricRam,
    required this.metricDisk,
    required this.metricCpuTemp,
    required this.metricGpuTemp,
    required this.sectionGeneral,
    required this.timeFormatLabel,
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

  String cronEveryDays(int n) =>
      cronEveryDaysTemplate.replaceAll('{n}', '$n');

  String cronDailyAt(String time) =>
      cronDailyAtTemplate.replaceAll('{t}', time);

  String cronOnce(String date, String time) =>
      cronOnceTemplate.replaceAll('{d}', date).replaceAll('{t}', time);

  String skillDeleteBody(String name) =>
      skillDeleteBodyTemplate.replaceAll('{name}', name);

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
  conversations: 'Conversations',
  newChat: 'New chat',
  noConversationsYet: 'No conversations yet',
  sayHello: 'Say hello to OSIA',
  typeMessageOrMic: 'Type a message or use the mic.',
  messageHint: 'Message OSIA…',
  deleteConversationTitle: 'Delete conversation?',
  deleteConversationBodyTemplate: '"{title}" will be permanently deleted.',
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
  availableModels: 'Available models',
  noModelsReceived: 'No models received from the server.',
  modelsLoadFailed: 'Unable to load models',
  otherProviders: 'OTHERS',
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
  disconnect: 'Disconnect',
  disconnectSubtitle: 'Clears your token and returns to the connection screen.',
  disconnectConfirmTitle: 'Disconnect?',
  disconnectConfirmBody:
      'Your token will be erased from this device. Your theme and language are kept.',
  makeDonation: 'Make a donation',
  linkOpenFailed: 'Could not open the link.',
  providersTitle: 'APIs & Providers',
  configureProviders: 'Configure APIs & Providers',
  liveApi: 'Live API',
  liveApiNotice: 'When enabled, STT and TTS are automatically disabled.',
  catVoiceToVoice: 'Voice-to-voice (Live API)',
  catAiProviders: 'AI Providers',
  catTtsProviders: 'Voice Providers (TTS)',
  catSttProviders: 'Whisper Providers (STT)',
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
      'OSIA runs each task on its schedule, just like a spoken command.',
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
  cronEveryMinutesTemplate: 'Every {n} min',
  cronEveryHoursTemplate: 'Every {n} h',
  cronEveryDaysTemplate: 'Every {n} d',
  cronDailyAtTemplate: 'Daily at {t}',
  cronOnceTemplate: 'Once · {d} {t}',
  hierarchyTitle: 'AI Hierarchy',
  hierarchySubtitle:
      'Order the models OSIA tries for each task type. The first reachable one is used. When off, your selected model is always used.',
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
  heartbeatWaiting: 'Waiting for data…',
  systemMetricsHeader: 'Live metrics',
  metricCpu: 'CPU',
  metricRam: 'RAM',
  metricDisk: 'Disk',
  metricCpuTemp: 'CPU temp.',
  metricGpuTemp: 'GPU temp.',
  sectionGeneral: 'General',
  timeFormatLabel: 'Time format',
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
  conversations: 'Conversations',
  newChat: 'Nouveau chat',
  noConversationsYet: 'Aucune conversation pour le moment',
  sayHello: 'Dites bonjour à OSIA',
  typeMessageOrMic: 'Tapez un message ou utilisez le micro.',
  messageHint: 'Message OSIA…',
  deleteConversationTitle: 'Supprimer la conversation ?',
  deleteConversationBodyTemplate: '« {title} » sera supprimée définitivement.',
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
  availableModels: 'Modèles disponibles',
  noModelsReceived: 'Aucun modèle reçu du serveur.',
  modelsLoadFailed: 'Impossible de charger les modèles',
  otherProviders: 'AUTRES',
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
  disconnect: 'Se déconnecter',
  disconnectSubtitle: "Efface votre token et retourne à l'écran de connexion.",
  disconnectConfirmTitle: 'Se déconnecter ?',
  disconnectConfirmBody:
      'Votre token sera effacé de cet appareil. Votre thème et votre langue sont conservés.',
  makeDonation: 'Faire un don',
  linkOpenFailed: "Impossible d'ouvrir le lien.",
  providersTitle: 'API et fournisseurs',
  configureProviders: 'Configurer les API et fournisseurs',
  liveApi: 'API Live',
  liveApiNotice:
      'Une fois activé, la transcription (STT) et la synthèse vocale (TTS) sont automatiquement désactivées.',
  catVoiceToVoice: 'Voix à voix (API Live)',
  catAiProviders: 'Fournisseurs IA',
  catTtsProviders: 'Fournisseurs vocaux (TTS)',
  catSttProviders: 'Fournisseurs Whisper (STT)',
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
      'OSIA exécute chaque tâche à son horaire, comme une commande vocale.',
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
  cronEveryMinutesTemplate: 'Toutes les {n} min',
  cronEveryHoursTemplate: 'Toutes les {n} h',
  cronEveryDaysTemplate: 'Tous les {n} j',
  cronDailyAtTemplate: 'Chaque jour à {t}',
  cronOnceTemplate: 'Une fois · {d} {t}',
  hierarchyTitle: 'Hiérarchie IA',
  hierarchySubtitle:
      "Ordonnez les modèles qu'OSIA essaie pour chaque type de tâche. Le premier disponible est utilisé. Si désactivé, votre modèle sélectionné est toujours utilisé.",
  hierarchyEnable: 'Activer la hiérarchie',
  hierarchyActive: 'Hiérarchie IA active',
  hierarchyHeavy: 'Tâches lourdes',
  hierarchyHeavySub: 'Code, débogage, raisonnement complexe, recherche approfondie.',
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
  heartbeatWaiting: 'En attente de données…',
  systemMetricsHeader: 'Métriques en direct',
  metricCpu: 'CPU',
  metricRam: 'RAM',
  metricDisk: 'Disque',
  metricCpuTemp: 'Temp. CPU',
  metricGpuTemp: 'Temp. GPU',
  sectionGeneral: 'Général',
  timeFormatLabel: 'Format horaire',
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
  conversations: '对话',
  newChat: '新对话',
  noConversationsYet: '暂无对话',
  sayHello: '向 OSIA 打个招呼',
  typeMessageOrMic: '输入消息或使用麦克风。',
  messageHint: '发送给 OSIA…',
  deleteConversationTitle: '删除对话？',
  deleteConversationBodyTemplate: '"{title}" 将被永久删除。',
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
  availableModels: '可用模型',
  noModelsReceived: '未从服务器收到任何模型。',
  modelsLoadFailed: '无法加载模型',
  otherProviders: '其他',
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
  disconnect: '断开连接',
  disconnectSubtitle: '清除您的令牌并返回连接页面。',
  disconnectConfirmTitle: '断开连接？',
  disconnectConfirmBody: '您的令牌将从此设备中删除。您的主题和语言将被保留。',
  makeDonation: '捐赠支持',
  linkOpenFailed: '无法打开链接。',
  providersTitle: 'API 与提供商',
  configureProviders: '配置 API 与提供商',
  liveApi: '实时 API',
  liveApiNotice: '启用后，语音转文字 (STT) 和文字转语音 (TTS) 将自动停用。',
  catVoiceToVoice: '语音对话（实时 API）',
  catAiProviders: 'AI 提供商',
  catTtsProviders: '语音提供商 (TTS)',
  catSttProviders: 'Whisper 提供商 (STT)',
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
  cronSubtitle: 'OSIA 会按计划执行每个任务，就像语音命令一样。',
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
  cronEveryMinutesTemplate: '每 {n} 分钟',
  cronEveryHoursTemplate: '每 {n} 小时',
  cronEveryDaysTemplate: '每 {n} 天',
  cronDailyAtTemplate: '每天 {t}',
  cronOnceTemplate: '一次 · {d} {t}',
  hierarchyTitle: 'AI 层级',
  hierarchySubtitle:
      '为每种任务类型排列 OSIA 尝试的模型顺序。使用第一个可用的模型。关闭时，始终使用您选择的模型。',
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
  heartbeatWaiting: '正在等待数据…',
  systemMetricsHeader: '实时指标',
  metricCpu: 'CPU',
  metricRam: '内存',
  metricDisk: '磁盘',
  metricCpuTemp: 'CPU 温度',
  metricGpuTemp: 'GPU 温度',
  sectionGeneral: '通用',
  timeFormatLabel: '时间格式',
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
  conversations: '会話',
  newChat: '新しいチャット',
  noConversationsYet: 'まだ会話がありません',
  sayHello: 'OSIA に挨拶しましょう',
  typeMessageOrMic: 'メッセージを入力するか、マイクを使用してください。',
  messageHint: 'OSIA にメッセージ…',
  deleteConversationTitle: '会話を削除しますか？',
  deleteConversationBodyTemplate: '「{title}」は完全に削除されます。',
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
  availableModels: '利用可能なモデル',
  noModelsReceived: 'サーバーからモデルを受信していません。',
  modelsLoadFailed: 'モデルを読み込めません',
  otherProviders: 'その他',
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
  disconnect: '切断',
  disconnectSubtitle: 'トークンを消去し、接続画面に戻ります。',
  disconnectConfirmTitle: '切断しますか？',
  disconnectConfirmBody: 'トークンはこのデバイスから消去されます。テーマと言語は保持されます。',
  makeDonation: '寄付をする',
  linkOpenFailed: 'リンクを開けませんでした。',
  providersTitle: 'API とプロバイダー',
  configureProviders: 'API とプロバイダーを設定',
  liveApi: 'ライブ API',
  liveApiNotice: '有効にすると、音声認識 (STT) と音声合成 (TTS) は自動的に無効になります。',
  catVoiceToVoice: '音声対音声（ライブ API）',
  catAiProviders: 'AI プロバイダー',
  catTtsProviders: '音声プロバイダー (TTS)',
  catSttProviders: 'Whisper プロバイダー (STT)',
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
  cronSubtitle: 'OSIA は各タスクを音声コマンドと同じようにスケジュールどおり実行します。',
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
  cronEveryMinutesTemplate: '{n} 分ごと',
  cronEveryHoursTemplate: '{n} 時間ごと',
  cronEveryDaysTemplate: '{n} 日ごと',
  cronDailyAtTemplate: '毎日 {t}',
  cronOnceTemplate: '一度 · {d} {t}',
  hierarchyTitle: 'AI 階層',
  hierarchySubtitle:
      'タスクの種類ごとに OSIA が試すモデルの順序を決めます。最初に利用可能なものが使われます。オフのときは選択中のモデルが常に使われます。',
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
  heartbeatWaiting: 'データを待機中…',
  systemMetricsHeader: 'リアルタイム指標',
  metricCpu: 'CPU',
  metricRam: 'メモリ',
  metricDisk: 'ディスク',
  metricCpuTemp: 'CPU 温度',
  metricGpuTemp: 'GPU 温度',
  sectionGeneral: '一般',
  timeFormatLabel: '時刻表示形式',
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
  conversations: 'Unterhaltungen',
  newChat: 'Neuer Chat',
  noConversationsYet: 'Noch keine Unterhaltungen',
  sayHello: 'Sag Hallo zu OSIA',
  typeMessageOrMic:
      'Geben Sie eine Nachricht ein oder nutzen Sie das Mikrofon.',
  messageHint: 'Nachricht an OSIA…',
  deleteConversationTitle: 'Unterhaltung löschen?',
  deleteConversationBodyTemplate: '„{title}" wird dauerhaft gelöscht.',
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
  availableModels: 'Verfügbare Modelle',
  noModelsReceived: 'Keine Modelle vom Server erhalten.',
  modelsLoadFailed: 'Modelle können nicht geladen werden',
  otherProviders: 'ANDERE',
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
  disconnect: 'Trennen',
  disconnectSubtitle:
      'Löscht Ihr Token und kehrt zum Verbindungsbildschirm zurück.',
  disconnectConfirmTitle: 'Verbindung trennen?',
  disconnectConfirmBody:
      'Ihr Token wird von diesem Gerät gelöscht. Ihr Thema und Ihre Sprache bleiben erhalten.',
  makeDonation: 'Spenden',
  linkOpenFailed: 'Der Link konnte nicht geöffnet werden.',
  providersTitle: 'APIs & Anbieter',
  configureProviders: 'APIs & Anbieter konfigurieren',
  liveApi: 'Live-API',
  liveApiNotice: 'Wenn aktiviert, werden STT und TTS automatisch deaktiviert.',
  catVoiceToVoice: 'Sprache-zu-Sprache (Live-API)',
  catAiProviders: 'KI-Anbieter',
  catTtsProviders: 'Sprachanbieter (TTS)',
  catSttProviders: 'Whisper-Anbieter (STT)',
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
      'OSIA führt jede Aufgabe nach Zeitplan aus, wie einen Sprachbefehl.',
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
  cronEveryMinutesTemplate: 'Alle {n} Min',
  cronEveryHoursTemplate: 'Alle {n} Std',
  cronEveryDaysTemplate: 'Alle {n} Tage',
  cronDailyAtTemplate: 'Täglich um {t}',
  cronOnceTemplate: 'Einmal · {d} {t}',
  hierarchyTitle: 'KI-Hierarchie',
  hierarchySubtitle:
      'Ordnen Sie die Modelle, die OSIA je Aufgabentyp versucht. Das erste erreichbare wird verwendet. Wenn aus, wird immer Ihr gewähltes Modell genutzt.',
  hierarchyEnable: 'Hierarchie aktivieren',
  hierarchyActive: 'KI-Hierarchie aktiv',
  hierarchyHeavy: 'Schwere Aufgaben',
  hierarchyHeavySub: 'Code, Debugging, komplexes Denken, tiefe Recherche.',
  hierarchyMedium: 'Mittlere Aufgaben',
  hierarchyMediumSub: 'Alles andere: Navigation, Zusammenfassungen, kurze Aufgaben.',
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
  heartbeatWaiting: 'Warte auf Daten…',
  systemMetricsHeader: 'Live-Metriken',
  metricCpu: 'CPU',
  metricRam: 'RAM',
  metricDisk: 'Festplatte',
  metricCpuTemp: 'CPU-Temp.',
  metricGpuTemp: 'GPU-Temp.',
  sectionGeneral: 'Allgemein',
  timeFormatLabel: 'Zeitformat',
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
  conversations: 'Conversaciones',
  newChat: 'Nuevo chat',
  noConversationsYet: 'Aún no hay conversaciones',
  sayHello: 'Saluda a OSIA',
  typeMessageOrMic: 'Escribe un mensaje o usa el micrófono.',
  messageHint: 'Mensaje a OSIA…',
  deleteConversationTitle: '¿Eliminar conversación?',
  deleteConversationBodyTemplate: '«{title}» se eliminará permanentemente.',
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
  availableModels: 'Modelos disponibles',
  noModelsReceived: 'No se recibieron modelos del servidor.',
  modelsLoadFailed: 'No se pueden cargar los modelos',
  otherProviders: 'OTROS',
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
  disconnect: 'Desconectar',
  disconnectSubtitle: 'Borra tu token y vuelve a la pantalla de conexión.',
  disconnectConfirmTitle: '¿Desconectar?',
  disconnectConfirmBody:
      'Tu token se borrará de este dispositivo. Tu tema e idioma se conservan.',
  makeDonation: 'Hacer una donación',
  linkOpenFailed: 'No se pudo abrir el enlace.',
  providersTitle: 'API y proveedores',
  configureProviders: 'Configurar API y proveedores',
  liveApi: 'API Live',
  liveApiNotice: 'Cuando está activado, STT y TTS se desactivan automáticamente.',
  catVoiceToVoice: 'Voz a voz (API Live)',
  catAiProviders: 'Proveedores de IA',
  catTtsProviders: 'Proveedores de voz (TTS)',
  catSttProviders: 'Proveedores Whisper (STT)',
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
      'OSIA ejecuta cada tarea según su horario, como un comando de voz.',
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
  cronEveryMinutesTemplate: 'Cada {n} min',
  cronEveryHoursTemplate: 'Cada {n} h',
  cronEveryDaysTemplate: 'Cada {n} d',
  cronDailyAtTemplate: 'Cada día a las {t}',
  cronOnceTemplate: 'Una vez · {d} {t}',
  hierarchyTitle: 'Jerarquía de IA',
  hierarchySubtitle:
      'Ordena los modelos que OSIA prueba para cada tipo de tarea. Se usa el primero disponible. Si está desactivada, siempre se usa tu modelo seleccionado.',
  hierarchyEnable: 'Activar jerarquía',
  hierarchyActive: 'Jerarquía IA activa',
  hierarchyHeavy: 'Tareas pesadas',
  hierarchyHeavySub: 'Código, depuración, razonamiento complejo, investigación profunda.',
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
  heartbeatWaiting: 'Esperando datos…',
  systemMetricsHeader: 'Métricas en directo',
  metricCpu: 'CPU',
  metricRam: 'RAM',
  metricDisk: 'Disco',
  metricCpuTemp: 'Temp. CPU',
  metricGpuTemp: 'Temp. GPU',
  sectionGeneral: 'General',
  timeFormatLabel: 'Formato de hora',
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

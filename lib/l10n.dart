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

  // ── Connection screen ──
  final String enterYourToken;
  final String connect;
  final String connectingEllipsis;
  final String tokenRequired;
  final String connectionFailed;

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
    required this.enterYourToken,
    required this.connect,
    required this.connectingEllipsis,
    required this.tokenRequired,
    required this.connectionFailed,
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
  enterYourToken: 'Enter your token',
  connect: 'Connect',
  connectingEllipsis: 'Connecting…',
  tokenRequired: 'Please enter your token.',
  connectionFailed: 'Connection failed. Check your token and try again.',
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
  enterYourToken: 'Entrez votre token',
  connect: 'Se connecter',
  connectingEllipsis: 'Connexion…',
  tokenRequired: 'Veuillez entrer votre token.',
  connectionFailed: 'Échec de la connexion. Vérifiez votre token et réessayez.',
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
  enterYourToken: '输入您的令牌',
  connect: '连接',
  connectingEllipsis: '连接中…',
  tokenRequired: '请输入您的令牌。',
  connectionFailed: '连接失败。请检查您的令牌后重试。',
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
  enterYourToken: 'トークンを入力してください',
  connect: '接続',
  connectingEllipsis: '接続中…',
  tokenRequired: 'トークンを入力してください。',
  connectionFailed: '接続に失敗しました。トークンを確認してもう一度お試しください。',
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
  enterYourToken: 'Token eingeben',
  connect: 'Verbinden',
  connectingEllipsis: 'Verbinden…',
  tokenRequired: 'Bitte geben Sie Ihr Token ein.',
  connectionFailed:
      'Verbindung fehlgeschlagen. Überprüfen Sie Ihr Token und versuchen Sie es erneut.',
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
  enterYourToken: 'Introduce tu token',
  connect: 'Conectar',
  connectingEllipsis: 'Conectando…',
  tokenRequired: 'Por favor, introduce tu token.',
  connectionFailed:
      'Error de conexión. Comprueba tu token e inténtalo de nuevo.',
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

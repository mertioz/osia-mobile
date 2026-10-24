/// Short Mobile-only copy; the shared PC manual is unchanged.
/// Each supported language is required, without a bilingual manual fallback.
class OnboardingText {
  const OnboardingText({
    required this.en,
    required this.fr,
    required this.zh,
    required this.ja,
    required this.de,
    required this.es,
  });

  final String en;
  final String fr;
  final String zh;
  final String ja;
  final String de;
  final String es;

  Map<String, String> get translations => {
    'en': en,
    'fr': fr,
    'zh': zh,
    'ja': ja,
    'de': de,
    'es': es,
  };

  String resolve(String languageCode) =>
      translations[languageCode] ??
      (throw ArgumentError.value(languageCode, 'languageCode'));
}

class OnboardingSlide {
  const OnboardingSlide(this.id, this.title, this.body);
  final String id;
  final OnboardingText title;
  final OnboardingText body;
}

const onboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    'welcome',
    OnboardingText(
      en: 'Welcome to OSIA',
      fr: 'Bienvenue sur OSIA',
      zh: '欢迎使用 OSIA',
      ja: 'OSIA へようこそ',
      de: 'Willkommen bei OSIA',
      es: 'Te damos la bienvenida a OSIA',
    ),
    OnboardingText(
      en: 'Your AI assistant,\non your phone and computer.',
      fr: 'Votre assistant IA,\nsur téléphone et ordinateur.',
      zh: '你的 AI 助手，\n手机和电脑都能用。',
      ja: 'スマホでもパソコンでも使える\nあなたの AI アシスタントです。',
      de: 'Dein KI-Assistent,\nauf Smartphone und Computer.',
      es: 'Tu asistente de IA,\nen el móvil y el ordenador.',
    ),
  ),
  OnboardingSlide(
    'computer',
    OnboardingText(
      en: 'One assistant, two screens',
      fr: 'Un assistant, deux écrans',
      zh: '一个助手，两个屏幕',
      ja: 'スマホも PC も、同じ OSIA',
      de: 'Ein Assistent, zwei Geräte',
      es: 'Un asistente, dos pantallas',
    ),
    OnboardingText(
      en: 'Keep OSIA open on your PC\nto use it from your phone.',
      fr: 'Gardez OSIA ouvert sur le PC\npour l’utiliser sur votre téléphone.',
      zh: '让电脑上的 OSIA 保持运行，\n就能通过手机使用它。',
      ja: 'スマホから使うときは、\nPC の OSIA は開いたままに。',
      de: 'Lass OSIA auf dem PC geöffnet,\num es am Smartphone zu nutzen.',
      es: 'Mantén OSIA abierto en tu PC\npara usarlo desde el móvil.',
    ),
  ),
  OnboardingSlide(
    'install',
    OnboardingText(
      en: 'Start on your computer',
      fr: 'D’abord, sur votre PC',
      zh: '先在电脑上安装',
      ja: 'まずはパソコンで',
      de: 'Zuerst auf dem Computer',
      es: 'Empieza en el ordenador',
    ),
    OnboardingText(
      en: 'Install OSIA from osia.space,\nthen open it on your computer.',
      fr: 'Installez OSIA depuis osia.space,\npuis ouvrez-le sur votre PC.',
      zh: '从 osia.space 下载安装 OSIA，\n然后在电脑上打开它。',
      ja: 'osia.space から OSIA を入れて、\nパソコンで開きましょう。',
      de: 'Installiere OSIA von osia.space\nund öffne es auf deinem PC.',
      es: 'Instala OSIA desde osia.space\ny ábrelo en tu ordenador.',
    ),
  ),
  OnboardingSlide(
    'pc-code',
    OnboardingText(
      en: 'Find your connection code',
      fr: 'Trouvez le code de connexion',
      zh: '找到连接码',
      ja: '接続コードを確認',
      de: 'Finde den Verbindungscode',
      es: 'Busca el código de conexión',
    ),
    OnboardingText(
      en: 'On PC: open Settings, then\nConnection / Mobile.',
      fr: 'Sur PC : Réglages, puis\nConnexion / Mobile.',
      zh: '在电脑上打开「设置」，\n再进入「连接 / 移动」。',
      ja: 'パソコンの「設定」から\n「接続 / モバイル」を開きます。',
      de: 'Am PC: Einstellungen öffnen,\ndann Verbindung / Mobil.',
      es: 'En el PC: abre Ajustes y luego\nConexión / Móvil.',
    ),
  ),
  OnboardingSlide(
    'connect',
    OnboardingText(
      en: 'Connect your phone',
      fr: 'Connectez votre téléphone',
      zh: '连接手机',
      ja: 'スマホを接続',
      de: 'Verbinde dein Smartphone',
      es: 'Conecta tu móvil',
    ),
    OnboardingText(
      en: 'In the app, scan the QR code\nor paste the PC token.',
      fr: 'Dans l’app, scannez le QR code\nou collez le code de votre PC.',
      zh: '在手机应用中扫描二维码，\n或粘贴电脑上的连接码。',
      ja: 'QR コードを読み取るか、\nPC のコードを貼り付けます。',
      de: 'Scanne in der App den QR-Code\noder füge den PC-Token ein.',
      es: 'En la app, escanea el QR o pega\nel código de tu PC.',
    ),
  ),
  OnboardingSlide(
    'chat',
    OnboardingText(
      en: 'Chat naturally',
      fr: 'Parlez simplement',
      zh: '像聊天一样自然',
      ja: '気軽に話しかけよう',
      de: 'Schreib einfach los',
      es: 'Habla con naturalidad',
    ),
    OnboardingText(
      en: 'Ask a question or describe\nwhat you need help with.',
      fr: 'Posez une question ou dites\nce dont vous avez besoin.',
      zh: '直接提问，\n或说说你需要什么帮助。',
      ja: '質問や、手伝ってほしいことを\n気軽に伝えてみましょう。',
      de: 'Stelle eine Frage oder sag,\nwobei du Hilfe brauchst.',
      es: 'Haz una pregunta o cuenta\nen qué necesitas ayuda.',
    ),
  ),
  OnboardingSlide(
    'actions',
    OnboardingText(
      en: 'More than chat',
      fr: 'Plus qu’une conversation',
      zh: '不只是聊天',
      ja: '会話だけではありません',
      de: 'Mehr als ein Chat',
      es: 'Mucho más que conversar',
    ),
    OnboardingText(
      en: 'OSIA can also take action\nwith the tools you set up.',
      fr: 'OSIA peut aussi agir grâce\naux outils que vous configurez.',
      zh: '配置好工具后，\nOSIA 还能帮你完成操作。',
      ja: '設定したツールを使って、\n作業を手伝うこともできます。',
      de: 'Mit eingerichteten Tools kann\nOSIA auch Aufgaben ausführen.',
      es: 'OSIA también puede actuar con\nlas herramientas que configures.',
    ),
  ),
  OnboardingSlide(
    'settings',
    OnboardingText(
      en: 'Make OSIA yours',
      fr: 'Réglez OSIA à votre goût',
      zh: '按你的习惯设置',
      ja: '自分に合った設定に',
      de: 'Deine Einstellungen',
      es: 'OSIA a tu gusto',
    ),
    OnboardingText(
      en: 'Open Settings for language,\nvoice and AI services.',
      fr: 'Dans Paramètres : langue,\nvoix et services d’IA.',
      zh: '在「设置」中调整语言、\n语音和 AI 服务。',
      ja: '「設定」で言語や音声、\nAI サービスを変更できます。',
      de: 'In Einstellungen findest du\nSprache, Stimme und KI-Dienste.',
      es: 'En Ajustes puedes elegir idioma,\nvoz y servicios de IA.',
    ),
  ),
  OnboardingSlide(
    'support',
    OnboardingText(
      en: 'Support OSIA if you want',
      fr: 'Soutenez OSIA si vous voulez',
      zh: '自愿支持 OSIA',
      ja: 'よければ OSIA を応援',
      de: 'OSIA freiwillig unterstützen',
      es: 'Apoya a OSIA si quieres',
    ),
    OnboardingText(
      en: 'Donations are optional.\nThey help OSIA grow.',
      fr: 'Les dons sont facultatifs.\nIls aident OSIA à grandir.',
      zh: '捐助完全自愿，\n你的支持让 OSIA 不断成长。',
      ja: '寄付は任意です。\nOSIA の開発を支える力になります。',
      de: 'Spenden sind freiwillig.\nSie helfen OSIA zu wachsen.',
      es: 'Las donaciones son opcionales.\nAyudan a OSIA a crecer.',
    ),
  ),
  OnboardingSlide(
    'ready',
    OnboardingText(
      en: 'You’re ready',
      fr: 'Tout est prêt pour commencer',
      zh: '可以开始了',
      ja: 'さあ、始めましょう',
      de: 'Du kannst loslegen',
      es: 'Todo listo para empezar',
    ),
    OnboardingText(
      en: 'Connect to your PC,\nthen send your first message.',
      fr: 'Connectez-vous à votre PC,\npuis envoyez un premier message.',
      zh: '连接电脑，\n发出你的第一条消息吧。',
      ja: 'パソコンに接続したら、\nメッセージを送りましょう。',
      de: 'Verbinde dich mit deinem PC\nund sende die erste Nachricht.',
      es: 'Conecta con tu PC y envía\ntu primer mensaje.',
    ),
  ),
];

/// Visible and screen-reader navigation follows the same app language.
abstract final class OnboardingLabels {
  static const close = OnboardingText(
    en: 'Close introduction',
    fr: 'Fermer l’introduction',
    zh: '关闭介绍',
    ja: '紹介を閉じる',
    de: 'Einführung schließen',
    es: 'Cerrar introducción',
  );
  static const next = OnboardingText(
    en: 'Next step',
    fr: 'Étape suivante',
    zh: '下一步',
    ja: '次へ',
    de: 'Weiter',
    es: 'Siguiente paso',
  );
  static const start = OnboardingText(
    en: 'Start using OSIA',
    fr: 'Commencer avec OSIA',
    zh: '开始使用 OSIA',
    ja: 'OSIA を使い始める',
    de: 'OSIA starten',
    es: 'Empezar a usar OSIA',
  );
  static const swipe = OnboardingText(
    en: 'Swipe left to continue',
    fr: 'Glissez vers la gauche',
    zh: '向左滑动继续',
    ja: '左にスワイプして次へ',
    de: 'Zum Fortfahren nach links wischen',
    es: 'Desliza a la izquierda',
  );
  static const step = OnboardingText(
    en: 'Step {current} of {total}',
    fr: 'Étape {current} sur {total}',
    zh: '第 {current} 步，共 {total} 步',
    ja: '{total} ステップ中 {current} ステップ目',
    de: 'Schritt {current} von {total}',
    es: 'Paso {current} de {total}',
  );
  static String progress(String languageCode, int current, int total) => step
      .resolve(languageCode)
      .replaceAll('{current}', '$current')
      .replaceAll('{total}', '$total');
}

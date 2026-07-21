import 'package:flutter/foundation.dart';

const int guideContentSchemaVersion = 1;
const String guideEssentialCategoryId = 'getting-started';
const String guideAdvancedCategoryId = 'master-osia-mobile';

@immutable
class GuideText {
  const GuideText({required this.en, required this.fr});

  final String en;
  final String fr;

  String resolve(String languageCode) => languageCode == 'fr' ? fr : en;
}

@immutable
class GuideCategory {
  const GuideCategory({
    required this.id,
    required this.order,
    required this.title,
    required this.summary,
  });

  final String id;
  final int order;
  final GuideText title;
  final GuideText summary;
}

@immutable
class GuideLesson {
  const GuideLesson({
    required this.id,
    required this.categoryId,
    required this.order,
    required this.title,
    required this.introduction,
    required this.paragraphs,
    required this.exampleTitle,
    required this.example,
    this.remember,
    this.asset,
    this.caption,
    this.altText,
  });

  final String id;
  final String categoryId;
  final int order;
  final GuideText title;
  final GuideText introduction;
  final List<GuideText> paragraphs;
  final GuideText exampleTitle;
  final GuideText example;
  final GuideText? remember;
  final String? asset;
  final GuideText? caption;
  final GuideText? altText;
}

const List<GuideCategory> guideCategories = <GuideCategory>[
  GuideCategory(
    id: guideEssentialCategoryId,
    order: 1,
    title: GuideText(en: 'Getting started', fr: 'Démarrage essentiel'),
    summary: GuideText(
      en: 'Everything needed to pair the phone and have a confident first conversation.',
      fr: 'Tout ce qu’il faut pour associer le téléphone et réussir une première conversation.',
    ),
  ),
  GuideCategory(
    id: guideAdvancedCategoryId,
    order: 2,
    title: GuideText(en: 'Master OSIA Mobile', fr: 'Maîtriser OSIA Mobile'),
    summary: GuideText(
      en: 'A deeper guide to connections, voice, models, notifications, synchronization and safety.',
      fr: 'Un guide approfondi sur les connexions, la voix, les modèles, les notifications, la synchronisation et la sécurité.',
    ),
  ),
];

const List<GuideLesson> guideLessons = <GuideLesson>[
  GuideLesson(
    id: 'essential.what-is-mobile',
    categoryId: guideEssentialCategoryId,
    order: 1,
    title: GuideText(
      en: 'What OSIA Mobile is',
      fr: 'Qu’est-ce qu’OSIA Mobile ?',
    ),
    introduction: GuideText(
      en: 'OSIA Mobile is the phone interface for OSIA running on your computer.',
      fr: 'OSIA Mobile est l’interface téléphonique d’OSIA, qui fonctionne sur votre ordinateur.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The main intelligence, tools and services stay on the PC. The phone lets you continue conversations and send requests from another room or while away from the desktop.',
        fr: 'L’intelligence principale, les outils et les services restent sur le PC. Le téléphone permet de poursuivre une conversation et d’envoyer une demande depuis une autre pièce ou loin du bureau.',
      ),
      GuideText(
        en: 'The PC generally needs to be running and connected. Voice can also be used when microphone access and the PC voice configuration are available.',
        fr: 'Le PC doit généralement être allumé et connecté. La voix peut aussi être utilisée si l’accès au microphone et la configuration vocale du PC sont disponibles.',
      ),
    ],
    exampleTitle: GuideText(en: 'Useful examples', fr: 'Exemples utiles'),
    example: GuideText(
      en: 'Ask a question from another room; continue a PC conversation on the phone; send a request away from the desk; dictate a message when voice is available.',
      fr: 'Posez une question depuis une autre pièce ; poursuivez sur le téléphone une conversation commencée sur PC ; envoyez une demande loin du bureau ; dictez un message lorsque la voix est disponible.',
    ),
    remember: GuideText(
      en: 'The phone is a companion to your OSIA PC, not a completely independent AI system.',
      fr: 'Le téléphone accompagne votre PC OSIA ; ce n’est pas un système d’IA totalement indépendant.',
    ),
  ),
  GuideLesson(
    id: 'essential.before-pairing',
    categoryId: guideEssentialCategoryId,
    order: 2,
    title: GuideText(en: 'Before pairing', fr: 'Avant l’association'),
    introduction: GuideText(
      en: 'Pairing establishes trust between this phone and your OSIA PC.',
      fr: 'L’association établit une relation de confiance entre ce téléphone et votre PC OSIA.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Install and run OSIA on the PC, then install OSIA Mobile on the phone. The PC displays the pairing token that the phone needs.',
        fr: 'Installez et lancez OSIA sur le PC, puis installez OSIA Mobile sur le téléphone. Le PC affiche le jeton d’association nécessaire au téléphone.',
      ),
      GuideText(
        en: 'The token is temporary and private. Do not share it or include it in a screenshot. You do not need to understand ports, certificates, WebSockets, STUN, ICE or TURN to pair safely.',
        fr: 'Le jeton est temporaire et privé. Ne le partagez pas et ne l’incluez pas dans une capture. Il n’est pas nécessaire de comprendre les ports, certificats, WebSockets, STUN, ICE ou TURN pour associer les appareils en sécurité.',
      ),
    ],
    exampleTitle: GuideText(en: 'Safe preparation', fr: 'Préparation sûre'),
    example: GuideText(
      en: 'Keep both devices connected, leave OSIA running on the PC, and reveal the token only when you are ready to enter it.',
      fr: 'Gardez les deux appareils connectés, laissez OSIA fonctionner sur le PC et n’affichez le jeton qu’au moment de le saisir.',
    ),
    remember: GuideText(
      en: 'Treat the pairing token like a short-lived password.',
      fr: 'Traitez le jeton d’association comme un mot de passe de courte durée.',
    ),
  ),
  GuideLesson(
    id: 'essential.pair-token',
    categoryId: guideEssentialCategoryId,
    order: 3,
    title: GuideText(en: 'Pair with the token', fr: 'Associer avec le jeton'),
    introduction: GuideText(
      en: 'Enter the token shown by OSIA on the PC into the first OSIA Mobile screen.',
      fr: 'Saisissez dans le premier écran d’OSIA Mobile le jeton affiché par OSIA sur le PC.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: '1. On the PC, open OSIA Settings.\n2. Open the Connection / Mobile pairing section.\n3. Display or copy the token.\n4. Open OSIA Mobile.\n5. Enter or paste the token.\n6. Validate it.\n7. Wait for the Connected state.',
        fr: '1. Sur le PC, ouvrez les réglages OSIA.\n2. Ouvrez la section Connexion / Mobile.\n3. Affichez ou copiez le jeton.\n4. Ouvrez OSIA Mobile.\n5. Saisissez ou collez le jeton.\n6. Validez-le.\n7. Attendez l’état Connecté.',
      ),
      GuideText(
        en: 'Success opens the Chat screen and shows a Connected badge. If it fails, the token may be expired or mistyped, the PC may be off, or the phone may have no usable network.',
        fr: 'En cas de réussite, l’écran Discussion s’ouvre avec un badge Connecté. En cas d’échec, le jeton peut être expiré ou mal saisi, le PC peut être éteint ou le téléphone peut ne pas disposer d’un réseau utilisable.',
      ),
    ],
    exampleTitle: GuideText(en: 'Synthetic example', fr: 'Exemple fictif'),
    example: GuideText(
      en: 'A guide or support screenshot should show only a value such as DEMO-CODE or a fully masked token—never the real token.',
      fr: 'Une capture destinée à un guide ou au support doit afficher uniquement une valeur comme DEMO-CODE ou un jeton entièrement masqué — jamais le vrai jeton.',
    ),
    remember: GuideText(
      en: 'Connected confirms that the phone has authenticated the PC.',
      fr: 'L’état Connecté confirme que le téléphone a authentifié le PC.',
    ),
    asset: 'assets/guide/pc-pairing.png',
    caption: GuideText(
      en: 'Sanitized OSIA PC Connection / Mobile page with the pairing token fully masked.',
      fr: 'Page Connexion / Mobile d’OSIA PC assainie, avec le jeton entièrement masqué.',
    ),
    altText: GuideText(
      en: 'OSIA PC mobile-pairing settings with a completely masked demonstration token and no device or network identity.',
      fr: 'Réglages d’association mobile d’OSIA PC avec un jeton de démonstration entièrement masqué, sans identité d’appareil ni de réseau.',
    ),
  ),
  GuideLesson(
    id: 'essential.mobile-pages',
    categoryId: guideEssentialCategoryId,
    order: 4,
    title: GuideText(
      en: 'Tour the mobile pages',
      fr: 'Découvrir les pages mobiles',
    ),
    introduction: GuideText(
      en: 'OSIA Mobile keeps the conversation at the center and places deeper controls one level away.',
      fr: 'OSIA Mobile place la conversation au centre et garde les réglages approfondis à un niveau de distance.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Connection validates the pairing token. Chat shows the active conversation, composer, connection badge and model. Conversations is the side drawer for creating, opening, renaming and deleting chats. Autonomous runs and monitors longer PC tasks.',
        fr: 'Connexion valide le jeton d’association. Discussion affiche la conversation active, la zone de saisie, le badge de connexion et le modèle. Conversations est le volet latéral permettant de créer, ouvrir, renommer et supprimer des discussions. Autonome lance et suit des tâches PC plus longues.',
      ),
      GuideText(
        en: 'Settings contains language, notifications, Android background mode, automatic read-aloud, system options, Memory, Providers, appearance, legal information, restart and disconnect. Provider subpages cover AI/TTS/STT, scheduled tasks, hierarchy, personality and skills, system status and connectors.',
        fr: 'Réglages contient la langue, les notifications, le mode arrière-plan Android, la lecture automatique, les options système, la mémoire, les fournisseurs, l’apparence, les informations légales, le redémarrage et la déconnexion. Les sous-pages Fournisseurs couvrent IA/TTS/STT, tâches planifiées, hiérarchie, personnalité et compétences, état du système et connecteurs.',
      ),
    ],
    exampleTitle: GuideText(en: 'Navigation', fr: 'Navigation'),
    example: GuideText(
      en: 'Use the top-left menu for conversations. Use the rocket for Autonomous and the gear for Settings. The model pill is in the composer.',
      fr: 'Utilisez le menu en haut à gauche pour les conversations, la fusée pour Autonome et la roue dentée pour Réglages. Le modèle se trouve dans la zone de saisie.',
    ),
    remember: GuideText(
      en: 'Most everyday use happens in Chat and the Conversations drawer.',
      fr: 'L’usage quotidien se déroule surtout dans Discussion et le volet Conversations.',
    ),
    asset: 'assets/guide/mobile-navigation.png',
    caption: GuideText(
      en: 'Sanitized OSIA Mobile conversation drawer and Chat navigation.',
      fr: 'Volet Conversations et navigation Discussion d’OSIA Mobile, assainis.',
    ),
    altText: GuideText(
      en: 'OSIA Mobile Chat with the Conversations drawer open, showing only synthetic conversation titles.',
      fr: 'Discussion OSIA Mobile avec le volet Conversations ouvert et uniquement des titres fictifs.',
    ),
  ),
  GuideLesson(
    id: 'essential.first-message',
    categoryId: guideEssentialCategoryId,
    order: 5,
    title: GuideText(
      en: 'Send the first message',
      fr: 'Envoyer le premier message',
    ),
    introduction: GuideText(
      en: 'A clear request helps OSIA produce a useful result.',
      fr: 'Une demande claire aide OSIA à produire un résultat utile.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Open an existing conversation or create a new one, type the request, and tap Send. Wait while OSIA works, then continue in the same conversation so the earlier context remains available on the PC.',
        fr: 'Ouvrez une conversation ou créez-en une, saisissez la demande et touchez Envoyer. Attendez qu’OSIA travaille, puis continuez dans la même conversation afin que le contexte précédent reste disponible sur le PC.',
      ),
      GuideText(
        en: 'State the goal, add the relevant context, and describe the desired result. For example: “Summarize the main points of this text,” “Help me plan tomorrow,” “Explain this error simply,” or “Continue the task I started on the PC.”',
        fr: 'Indiquez l’objectif, ajoutez le contexte utile et décrivez le résultat souhaité. Par exemple : « Résume les points principaux de ce texte », « Aide-moi à organiser demain », « Explique simplement cette erreur » ou « Continue la tâche commencée sur le PC ».',
      ),
    ],
    exampleTitle: GuideText(en: 'Simple formula', fr: 'Formule simple'),
    example: GuideText(
      en: 'Goal + relevant context + expected result: “Plan tomorrow from these appointments and return a short checklist.”',
      fr: 'Objectif + contexte utile + résultat attendu : « Organise ma journée de demain à partir de ces rendez-vous et donne-moi une courte liste. »',
    ),
    remember: GuideText(
      en: 'Clear goals and useful context usually matter more than a long prompt.',
      fr: 'Un objectif clair et un contexte utile comptent généralement plus qu’une longue demande.',
    ),
    asset: 'assets/guide/mobile-chat.png',
    caption: GuideText(
      en: 'Sanitized OSIA Mobile Chat with a synthetic planning conversation.',
      fr: 'Discussion OSIA Mobile assainie avec une conversation fictive de planification.',
    ),
    altText: GuideText(
      en: 'OSIA Mobile Chat showing one synthetic user request and a short synthetic response, with no personal data.',
      fr: 'Discussion OSIA Mobile montrant une demande et une courte réponse fictives, sans donnée personnelle.',
    ),
  ),
  GuideLesson(
    id: 'essential.voice',
    categoryId: guideEssentialCategoryId,
    order: 6,
    title: GuideText(en: 'Use voice', fr: 'Utiliser la voix'),
    introduction: GuideText(
      en: 'The microphone turns a recording into a message through the PC’s configured speech-to-text service.',
      fr: 'Le microphone transforme un enregistrement en message grâce au service de reconnaissance vocale configuré sur le PC.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Tap the microphone to start recording, speak, then tap it again to stop and send. The phone may request microphone permission. If permission is permanently denied, change it in the phone’s system settings.',
        fr: 'Touchez le microphone pour enregistrer, parlez, puis touchez-le de nouveau pour arrêter et envoyer. Le téléphone peut demander l’autorisation du microphone. Si elle est refusée définitivement, modifiez-la dans les réglages système du téléphone.',
      ),
      GuideText(
        en: 'A speaker button can request that the PC synthesize a response, and automatic read-aloud can be enabled in Settings. Availability depends on the platform, network and PC STT/TTS configuration. There is no mobile wake word.',
        fr: 'Un bouton haut-parleur peut demander au PC de synthétiser une réponse, et la lecture automatique peut être activée dans Réglages. La disponibilité dépend de la plateforme, du réseau et de la configuration STT/TTS du PC. Il n’existe pas de mot de réveil mobile.',
      ),
    ],
    exampleTitle: GuideText(en: 'Short procedure', fr: 'Procédure courte'),
    example: GuideText(
      en: 'Tap mic; speak clearly; tap mic again; wait for the transcript and response.',
      fr: 'Touchez le micro ; parlez clairement ; touchez-le de nouveau ; attendez la transcription et la réponse.',
    ),
    remember: GuideText(
      en: 'STT turns speech into text; TTS reads text aloud. Both are handled through the paired PC configuration.',
      fr: 'STT transforme la parole en texte ; TTS lit le texte à voix haute. Les deux dépendent de la configuration du PC associé.',
    ),
  ),
  GuideLesson(
    id: 'essential.reconnection',
    categoryId: guideEssentialCategoryId,
    order: 7,
    title: GuideText(
      en: 'Connection and reconnection',
      fr: 'Connexion et reconnexion',
    ),
    introduction: GuideText(
      en: 'The app tries to reach the paired PC and shows its current state in Chat.',
      fr: 'L’application tente de joindre le PC associé et affiche son état dans Discussion.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'When both devices share a network, a private local connection is generally preferred. When available, direct internet or encrypted relay paths can keep the phone connected away from home.',
        fr: 'Lorsque les deux appareils partagent un réseau, une connexion locale privée est généralement privilégiée. Lorsqu’ils sont disponibles, des chemins Internet directs ou un relais chiffré peuvent maintenir la connexion à distance.',
      ),
      GuideText(
        en: 'Locking the phone, changing network, or losing coverage can interrupt the connection. Reopening or resuming the app triggers reconnection. Normal use cannot continue while the PC is off.',
        fr: 'Verrouiller le téléphone, changer de réseau ou perdre la couverture peut interrompre la connexion. Rouvrir ou reprendre l’application déclenche la reconnexion. L’utilisation normale est impossible lorsque le PC est éteint.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'If it disconnects',
      fr: 'En cas de déconnexion',
    ),
    example: GuideText(
      en: 'Check that the PC is running, restore phone connectivity, reopen OSIA Mobile, and allow a short reconnection period.',
      fr: 'Vérifiez que le PC fonctionne, rétablissez le réseau du téléphone, rouvrez OSIA Mobile et laissez-lui un court délai de reconnexion.',
    ),
    remember: GuideText(
      en: 'A temporary Disconnected or Connecting state after sleep or a network change can be normal.',
      fr: 'Un état temporaire Déconnecté ou Connexion après une veille ou un changement de réseau peut être normal.',
    ),
  ),
  GuideLesson(
    id: 'essential.notifications-background',
    categoryId: guideEssentialCategoryId,
    order: 8,
    title: GuideText(
      en: 'Notifications and background',
      fr: 'Notifications et arrière-plan',
    ),
    introduction: GuideText(
      en: 'OSIA Mobile can show local notifications for scheduled-task and reminder events received from the PC.',
      fr: 'OSIA Mobile peut afficher des notifications locales pour les tâches planifiées et rappels reçus du PC.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Notifications are opt-in and require phone permission. An in-app message appears when the socket event arrives; the optional system notification is generated locally and duplicate events are suppressed.',
        fr: 'Les notifications sont facultatives et nécessitent l’autorisation du téléphone. Un message apparaît dans l’application à la réception de l’événement ; la notification système facultative est créée localement et les doublons sont supprimés.',
      ),
      GuideText(
        en: 'On Android, the optional background connection uses a visible ongoing service notification. On iOS, permanent background connectivity is not guaranteed. There is currently no APNs push service, so a fully suspended app may receive nothing until it reconnects.',
        fr: 'Sur Android, la connexion facultative en arrière-plan utilise une notification de service permanente et visible. Sur iOS, une connexion permanente en arrière-plan n’est pas garantie. Il n’existe actuellement aucun service push APNs ; une application totalement suspendue peut ne rien recevoir avant sa reconnexion.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'What a notification means',
      fr: 'Signification d’une notification',
    ),
    example: GuideText(
      en: 'A local OSIA notification means the phone received a scheduled-task or reminder event over its current connection; it is not proof of a separate cloud push channel.',
      fr: 'Une notification locale OSIA signifie que le téléphone a reçu un événement de tâche ou de rappel par sa connexion actuelle ; elle ne prouve pas l’existence d’un canal push séparé.',
    ),
    remember: GuideText(
      en: 'Notifications depend on permission and a live-enough connection to the PC.',
      fr: 'Les notifications dépendent de l’autorisation et d’une connexion suffisamment active avec le PC.',
    ),
    asset: 'assets/guide/mobile-settings.png',
    caption: GuideText(
      en: 'Sanitized OSIA Mobile Settings showing notification and Android background controls.',
      fr: 'Réglages OSIA Mobile assainis montrant les notifications et les commandes d’arrière-plan Android.',
    ),
    altText: GuideText(
      en: 'OSIA Mobile Settings with notifications, Android background connection and automatic read-aloud all disabled in a demo profile.',
      fr: 'Réglages OSIA Mobile avec notifications, connexion Android en arrière-plan et lecture automatique désactivées dans un profil de démonstration.',
    ),
  ),
  GuideLesson(
    id: 'essential.ready',
    categoryId: guideEssentialCategoryId,
    order: 9,
    title: GuideText(en: 'Ready', fr: 'Prêt'),
    introduction: GuideText(
      en: 'You now know the complete path from pairing to a first useful conversation.',
      fr: 'Vous connaissez maintenant tout le parcours, de l’association à une première conversation utile.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Keep the PC running, keep the phone paired, check the connection badge, and send messages from Chat. Voice is optional, and preferences can be changed later in Settings.',
        fr: 'Laissez le PC fonctionner, gardez le téléphone associé, vérifiez le badge de connexion et envoyez des messages depuis Discussion. La voix est facultative et les préférences restent modifiables dans Réglages.',
      ),
      GuideText(
        en: 'The advanced category explains connection modes, Android and iOS background limits, voice, conversations, models, notifications, troubleshooting, security and privacy.',
        fr: 'La catégorie avancée explique les modes de connexion, les limites d’arrière-plan Android et iOS, la voix, les conversations, les modèles, les notifications, le dépannage, la sécurité et la confidentialité.',
      ),
    ],
    exampleTitle: GuideText(en: 'Quick check', fr: 'Vérification rapide'),
    example: GuideText(
      en: 'PC running ✓  Phone paired ✓  Connected visible ✓  Message sent ✓  Voice optional ✓',
      fr: 'PC allumé ✓  Téléphone associé ✓  État Connecté visible ✓  Message envoyé ✓  Voix facultative ✓',
    ),
    remember: GuideText(
      en: 'Finish closes the essential guide; the advanced category remains available from Settings.',
      fr: 'Terminer ferme le guide essentiel ; la catégorie avancée reste disponible depuis Réglages.',
    ),
  ),
  GuideLesson(
    id: 'advanced.pairing-trust',
    categoryId: guideAdvancedCategoryId,
    order: 1,
    title: GuideText(en: 'Pairing and trust', fr: 'Association et confiance'),
    introduction: GuideText(
      en: 'Pairing prevents an unknown phone from using your OSIA PC.',
      fr: 'L’association empêche un téléphone inconnu d’utiliser votre PC OSIA.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The token lets both devices derive the information needed for authenticated, encrypted handshakes. The public relay receives derived routing and proof data, not the raw token.',
        fr: 'Le jeton permet aux deux appareils de dériver les informations nécessaires à des échanges authentifiés et chiffrés. Le relais public reçoit des données de routage et de preuve dérivées, pas le jeton brut.',
      ),
      GuideText(
        en: 'The phone stores the token and authenticated LAN identity in platform secure storage. Disconnecting removes connection credentials. Reinstalling or clearing secure data may require pairing again; a regenerated PC token invalidates the previous trust path.',
        fr: 'Le téléphone stocke le jeton et l’identité LAN authentifiée dans le stockage sécurisé de la plateforme. La déconnexion supprime les identifiants de connexion. Une réinstallation ou l’effacement des données sécurisées peut imposer une nouvelle association ; régénérer le jeton PC invalide l’ancien chemin de confiance.',
      ),
    ],
    exampleTitle: GuideText(en: 'When to pair again', fr: 'Quand réassocier'),
    example: GuideText(
      en: 'Pair again after deliberately disconnecting, clearing app data, changing the PC token, or when stored secure data can no longer be read.',
      fr: 'Réassociez après une déconnexion volontaire, l’effacement des données de l’application, un changement de jeton PC ou lorsque les données sécurisées ne sont plus lisibles.',
    ),
    remember: GuideText(
      en: 'Keep the token private even after pairing.',
      fr: 'Gardez le jeton privé même après l’association.',
    ),
  ),
  GuideLesson(
    id: 'advanced.connection-hierarchy',
    categoryId: guideAdvancedCategoryId,
    order: 2,
    title: GuideText(en: 'Connection hierarchy', fr: 'Hiérarchie de connexion'),
    introduction: GuideText(
      en: 'OSIA Mobile selects one authenticated application transport at a time and prefers direct paths.',
      fr: 'OSIA Mobile sélectionne un seul transport applicatif authentifié à la fois et privilégie les chemins directs.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'First it tries a previously provisioned private-LAN WSS endpoint discovered through the paired Bonjour/mDNS identity. If none is ready, it opens an end-to-end encrypted relay standby to obtain authenticated LAN provisioning and WebRTC capability data, then retries LAN.',
        fr: 'Il essaie d’abord un point WSS de réseau privé déjà provisionné, découvert grâce à l’identité Bonjour/mDNS associée. Si aucun n’est prêt, il ouvre un relais chiffré de bout en bout en attente afin d’obtenir les données authentifiées de provisionnement LAN et de capacité WebRTC, puis réessaie le LAN.',
      ),
      GuideText(
        en: 'Next it tries WebRTC/P2P with authenticated ICE configuration. If direct connection fails, it explicitly commits the encrypted relay. LAN works only on the same suitable network; WebRTC and relay require internet. Production does not silently downgrade to the old rendezvous socket path.',
        fr: 'Ensuite, il essaie WebRTC/P2P avec une configuration ICE authentifiée. Si la connexion directe échoue, il valide explicitement le relais chiffré. Le LAN fonctionne uniquement sur un réseau local adapté ; WebRTC et le relais exigent Internet. La version de production ne rétrograde pas silencieusement vers l’ancien chemin de rendez-vous.',
      ),
      GuideText(
        en: 'LAN usually offers the lowest latency and keeps the network path local. WebRTC may be direct across networks. Relay adds an intermediary transport but keeps application payloads end-to-end encrypted. No transport switch occurs during an active request.',
        fr: 'Le LAN offre généralement la latence la plus faible et conserve le chemin réseau local. WebRTC peut être direct entre réseaux. Le relais ajoute un intermédiaire mais garde les données applicatives chiffrées de bout en bout. Aucun changement de transport n’a lieu pendant une demande active.',
      ),
    ],
    exampleTitle: GuideText(en: 'Plain-language order', fr: 'Ordre simplifié'),
    example: GuideText(
      en: 'Known local path; encrypted standby for discovery/signaling; local retry; WebRTC/P2P; encrypted relay.',
      fr: 'Chemin local connu ; relais chiffré en attente pour découverte/signalisation ; nouvel essai local ; WebRTC/P2P ; relais chiffré.',
    ),
    remember: GuideText(
      en: 'If the PC is offline, none of these paths can provide normal OSIA use.',
      fr: 'Si le PC est hors ligne, aucun de ces chemins ne permet l’usage normal d’OSIA.',
    ),
  ),
  GuideLesson(
    id: 'advanced.android-background',
    categoryId: guideAdvancedCategoryId,
    order: 3,
    title: GuideText(
      en: 'Android background connection',
      fr: 'Connexion Android en arrière-plan',
    ),
    introduction: GuideText(
      en: 'Android offers an optional foreground service to keep the existing OSIA connection active longer in the background.',
      fr: 'Android propose un service de premier plan facultatif pour maintenir plus longtemps la connexion OSIA existante en arrière-plan.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Enabling it requires notification permission and a currently reachable PC. Android then displays a low-importance, private, ongoing “OSIA background connection active” notification. Disabling the setting stops the service.',
        fr: 'Son activation exige l’autorisation des notifications et un PC actuellement joignable. Android affiche alors une notification privée, permanente et peu intrusive « Connexion OSIA en arrière-plan active ». Désactiver le réglage arrête le service.',
      ),
      GuideText(
        en: 'The service is bounded, uses remote-messaging foreground-service rules, and is not sticky. Android can still impose timeouts, battery restrictions, process death or manufacturer-specific limits; after a recorded timeout the app disables the preference rather than pretending it is active.',
        fr: 'Le service est limité, suit les règles de service de premier plan pour la messagerie distante et n’est pas relancé automatiquement. Android peut encore imposer des délais, restrictions de batterie, arrêts de processus ou limites propres au fabricant ; après un délai détecté, l’application désactive la préférence au lieu de prétendre qu’elle reste active.',
      ),
    ],
    exampleTitle: GuideText(en: 'Practical check', fr: 'Vérification pratique'),
    example: GuideText(
      en: 'If the ongoing notification disappears and background delivery stops, reopen the app, verify the PC connection, review battery restrictions, then re-enable the option if appropriate.',
      fr: 'Si la notification permanente disparaît et que la réception en arrière-plan cesse, rouvrez l’application, vérifiez la connexion au PC, contrôlez les restrictions de batterie, puis réactivez l’option si nécessaire.',
    ),
    remember: GuideText(
      en: 'A foreground service improves persistence but cannot override every Android system limit.',
      fr: 'Un service de premier plan améliore la persistance sans pouvoir contourner toutes les limites d’Android.',
    ),
    asset: 'assets/guide/mobile-settings.png',
    caption: GuideText(
      en: 'Android Settings controls for notifications and the optional background connection.',
      fr: 'Commandes Android des notifications et de la connexion facultative en arrière-plan.',
    ),
    altText: GuideText(
      en: 'OSIA Mobile Settings on Android showing the notification and background connection switches.',
      fr: 'Réglages OSIA Mobile sur Android montrant les interrupteurs de notifications et de connexion en arrière-plan.',
    ),
  ),
  GuideLesson(
    id: 'advanced.ios-background',
    categoryId: guideAdvancedCategoryId,
    order: 4,
    title: GuideText(
      en: 'iOS background and resume',
      fr: 'Arrière-plan et reprise sur iOS',
    ),
    introduction: GuideText(
      en: 'iOS may suspend OSIA Mobile after it leaves the foreground.',
      fr: 'iOS peut suspendre OSIA Mobile lorsqu’il quitte le premier plan.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'A persistent socket is not guaranteed while suspended. When the app resumes, the shared lifecycle service asks the current connection to reconnect and refreshes the open conversation, models and configuration.',
        fr: 'Une socket permanente n’est pas garantie pendant la suspension. À la reprise, le service de cycle de vie demande à la connexion courante de se rétablir et actualise la conversation ouverte, les modèles et la configuration.',
      ),
      GuideText(
        en: 'Current notifications are local and depend on socket-delivered events; they are not APNs remote pushes. Local discovery declares Bonjour and local-network access, and the multicast entitlement is present, but intended discovery still depends on Apple multicast approval.',
        fr: 'Les notifications actuelles sont locales et dépendent d’événements reçus par la socket ; ce ne sont pas des notifications distantes APNs. La découverte locale déclare Bonjour et l’accès au réseau local, et l’autorisation multicast est présente, mais la découverte prévue dépend encore de l’approbation multicast d’Apple.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'After a long suspension',
      fr: 'Après une longue suspension',
    ),
    example: GuideText(
      en: 'Return to OSIA Mobile, wait for Connected, and allow the active conversation to synchronize before sending another request.',
      fr: 'Revenez dans OSIA Mobile, attendez l’état Connecté et laissez la conversation active se synchroniser avant d’envoyer une autre demande.',
    ),
    remember: GuideText(
      en: 'The iOS project is prepared for testing, but this guide does not claim public TestFlight or App Store availability.',
      fr: 'Le projet iOS est préparé pour les tests, mais ce guide ne prétend pas qu’une version TestFlight ou App Store est publique.',
    ),
  ),
  GuideLesson(
    id: 'advanced.voice-tts-stt',
    categoryId: guideAdvancedCategoryId,
    order: 5,
    title: GuideText(en: 'Voice, TTS and STT', fr: 'Voix, TTS et STT'),
    introduction: GuideText(
      en: 'Mobile voice captures and plays audio, while the paired PC remains responsible for configured speech services.',
      fr: 'Le mobile capture et lit l’audio, tandis que le PC associé reste responsable des services vocaux configurés.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'STT converts the phone’s WAV recording into text on the PC. TTS converts assistant text into audio on the PC and streams it back. The explicit speaker control plays one response even when automatic read-aloud is off.',
        fr: 'STT convertit sur le PC l’enregistrement WAV du téléphone en texte. TTS convertit sur le PC le texte de l’assistant en audio puis le renvoie. Le bouton haut-parleur lit une réponse même lorsque la lecture automatique est désactivée.',
      ),
      GuideText(
        en: 'Provider, language and voice choices come from the PC configuration and can involve local engines or external services. Audio or transcripts may cross the network accordingly. Mobile microphone permission is separate from PC microphone and voice settings.',
        fr: 'Les choix de fournisseur, langue et voix proviennent de la configuration PC et peuvent utiliser des moteurs locaux ou des services externes. L’audio ou les transcriptions peuvent donc traverser le réseau. L’autorisation du microphone mobile est distincte des réglages vocaux et du microphone PC.',
      ),
    ],
    exampleTitle: GuideText(en: 'Troubleshoot voice', fr: 'Dépanner la voix'),
    example: GuideText(
      en: 'No transcript: check mobile microphone permission, connection and PC STT configuration. No sound: check media volume, stop stale playback, and verify PC TTS configuration.',
      fr: 'Pas de transcription : vérifiez l’autorisation du microphone mobile, la connexion et le STT du PC. Pas de son : vérifiez le volume multimédia, arrêtez une lecture bloquée et contrôlez le TTS du PC.',
    ),
    remember: GuideText(
      en: 'The disabled Live API option is not presented as an available voice-to-voice feature.',
      fr: 'L’option Live API désactivée n’est pas présentée comme une fonction voix-à-voix disponible.',
    ),
  ),
  GuideLesson(
    id: 'advanced.conversations-sync',
    categoryId: guideAdvancedCategoryId,
    order: 6,
    title: GuideText(
      en: 'Conversations and synchronization',
      fr: 'Conversations et synchronisation',
    ),
    introduction: GuideText(
      en: 'The PC is authoritative for the conversation list and saved messages.',
      fr: 'Le PC est la source d’autorité pour la liste des conversations et les messages enregistrés.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Mobile requests the list, active conversation and history over the current transport. Creating, loading, renaming and deleting a conversation sends the corresponding request to the PC. Deletion removes the PC conversation after confirmation.',
        fr: 'Le mobile demande au PC la liste, la conversation active et l’historique par le transport courant. Créer, charger, renommer ou supprimer une conversation envoie la demande correspondante au PC. La suppression retire la conversation du PC après confirmation.',
      ),
      GuideText(
        en: 'The phone keeps only bounded secure preferences plus temporary in-memory optimistic and streaming state. After reconnect it re-requests the open conversation; other conversations synchronize when selected. While disconnected, authoritative history and new replies may be unavailable.',
        fr: 'Le téléphone conserve seulement des préférences sécurisées limitées, ainsi qu’un état temporaire en mémoire pour l’affichage optimiste et le streaming. Après reconnexion, il redemande la conversation ouverte ; les autres se synchronisent à leur sélection. Hors connexion, l’historique de référence et les nouvelles réponses peuvent être indisponibles.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'After changing networks',
      fr: 'Après un changement de réseau',
    ),
    example: GuideText(
      en: 'Wait for Connected, reopen the desired conversation, and let its PC history load before assuming a message is missing.',
      fr: 'Attendez l’état Connecté, rouvrez la conversation voulue et laissez son historique PC se charger avant de conclure qu’un message manque.',
    ),
    remember: GuideText(
      en: 'The phone displays and temporarily buffers conversations; the PC persists them.',
      fr: 'Le téléphone affiche et met temporairement en mémoire les conversations ; le PC les conserve.',
    ),
  ),
  GuideLesson(
    id: 'advanced.models',
    categoryId: guideAdvancedCategoryId,
    order: 7,
    title: GuideText(
      en: 'Models and AI selection',
      fr: 'Modèles et sélection IA',
    ),
    introduction: GuideText(
      en: 'A provider operates an AI service; a model is a particular AI available through that provider.',
      fr: 'Un fournisseur exploite un service d’IA ; un modèle est une IA particulière proposée par ce fournisseur.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The model pill requests the live PC catalogue, grouped by provider. Selecting an entry sends provider and model to the PC. Per-model reasoning can also be selected where supported. The PC confirms the authoritative selection in the next models list.',
        fr: 'Le sélecteur de modèle demande au PC son catalogue actuel, regroupé par fournisseur. La sélection envoie le fournisseur et le modèle au PC. Le niveau de raisonnement peut aussi être choisi lorsque le modèle le permet. Le PC confirme la sélection de référence dans la liste suivante.',
      ),
      GuideText(
        en: 'Models differ in speed, capability, usage limits and provider cost. If the PC AI hierarchy is enabled, its configured chains may override the simple chat selection. An unavailable model produces the server/provider outcome; OSIA Mobile does not invent an undocumented fallback.',
        fr: 'Les modèles diffèrent en vitesse, capacité, limites d’usage et coût fournisseur. Si la hiérarchie IA du PC est active, ses chaînes configurées peuvent remplacer la sélection simple de Discussion. Un modèle indisponible produit le résultat du serveur ou du fournisseur ; OSIA Mobile n’invente aucun repli non documenté.',
      ),
    ],
    exampleTitle: GuideText(en: 'Choosing well', fr: 'Bien choisir'),
    example: GuideText(
      en: 'Use a faster model for routine requests and a more capable model for difficult work, while checking the provider’s limits and price.',
      fr: 'Utilisez un modèle rapide pour les demandes courantes et un modèle plus puissant pour les travaux difficiles, tout en vérifiant les limites et tarifs du fournisseur.',
    ),
    remember: GuideText(
      en: 'The PC controls availability and is authoritative for the active provider/model.',
      fr: 'Le PC contrôle la disponibilité et fait autorité pour le fournisseur et le modèle actifs.',
    ),
  ),
  GuideLesson(
    id: 'advanced.notifications',
    categoryId: guideAdvancedCategoryId,
    order: 8,
    title: GuideText(
      en: 'Notification details',
      fr: 'Détails des notifications',
    ),
    introduction: GuideText(
      en: 'Current OSIA Mobile notifications are permission-gated local notifications triggered by socket events.',
      fr: 'Les notifications actuelles d’OSIA Mobile sont des notifications locales soumises à autorisation et déclenchées par des événements socket.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Scheduled completion, failure and reminder frames show an in-app snackbar. When the local toggle and OS permission are enabled, the app also posts a private system notification and records a bounded event ID list to avoid duplicates.',
        fr: 'Les événements de fin, d’échec et de rappel planifiés affichent un message dans l’application. Lorsque l’option locale et l’autorisation système sont actives, l’application publie aussi une notification système privée et conserve une liste limitée d’identifiants pour éviter les doublons.',
      ),
      GuideText(
        en: 'Android can keep receiving longer with its opt-in foreground service. iOS may suspend the socket. A denied permission, disabled toggle, offline PC, interrupted socket, suspended app, sanitized sensitive title or duplicate event can explain why no notification appears. APNs push is not currently supported.',
        fr: 'Android peut recevoir plus longtemps avec son service de premier plan facultatif. iOS peut suspendre la socket. Une autorisation refusée, une option désactivée, un PC hors ligne, une socket interrompue, une application suspendue, un titre sensible masqué ou un doublon peuvent expliquer l’absence de notification. Le push APNs n’est pas pris en charge actuellement.',
      ),
    ],
    exampleTitle: GuideText(en: 'Check in order', fr: 'Vérifier dans l’ordre'),
    example: GuideText(
      en: 'Check permission, the OSIA notification toggle, the live connection, the PC task event, then Android background mode or iOS suspension state.',
      fr: 'Vérifiez l’autorisation, l’option de notifications OSIA, la connexion active, l’événement de tâche PC, puis le mode arrière-plan Android ou l’état de suspension iOS.',
    ),
    remember: GuideText(
      en: 'Local/socket notifications are not equivalent to a cloud push service.',
      fr: 'Les notifications locales par socket ne sont pas équivalentes à un service push cloud.',
    ),
  ),
  GuideLesson(
    id: 'advanced.troubleshooting',
    categoryId: guideAdvancedCategoryId,
    order: 9,
    title: GuideText(en: 'Troubleshooting', fr: 'Dépannage'),
    introduction: GuideText(
      en: 'Start with the simplest check and move deeper only when needed.',
      fr: 'Commencez par la vérification la plus simple et approfondissez uniquement si nécessaire.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Invalid or expired token: obtain a fresh token and enter it exactly. PC unavailable: start OSIA on the PC and verify its network. No local discovery: allow local-network access, use the same suitable LAN, and remember that iOS multicast approval affects discovery. Remote unavailable: verify internet on both devices.',
        fr: 'Jeton invalide ou expiré : obtenez un nouveau jeton et saisissez-le exactement. PC indisponible : lancez OSIA sur le PC et vérifiez son réseau. Pas de découverte locale : autorisez le réseau local, utilisez un LAN commun adapté et rappelez-vous que l’approbation multicast iOS affecte la découverte. Connexion distante indisponible : vérifiez Internet sur les deux appareils.',
      ),
      GuideText(
        en: 'Stuck reconnecting: foreground the app and wait, then verify the PC. Message not sent: wait for Connected and ensure the current conversation is not already busy. No microphone: grant permission and check PC STT. No TTS: check media volume, read-aloud setting and PC TTS. No notification: check permission, toggle and background limits.',
        fr: 'Reconnexion bloquée : remettez l’application au premier plan et attendez, puis vérifiez le PC. Message non envoyé : attendez Connecté et assurez-vous que la conversation n’est pas déjà occupée. Pas de microphone : accordez l’autorisation et vérifiez le STT du PC. Pas de TTS : vérifiez le volume, la lecture automatique et le TTS du PC. Pas de notification : vérifiez l’autorisation, l’option et les limites d’arrière-plan.',
      ),
      GuideText(
        en: 'For duplicated or stale connection symptoms, avoid opening multiple app instances, return to Chat, and allow the single connection coordinator to settle. Disconnect/re-pair only after the safer checks because it removes stored connection credentials.',
        fr: 'En cas de connexion dupliquée ou obsolète, évitez plusieurs instances de l’application, revenez dans Discussion et laissez le coordinateur de connexion unique se stabiliser. Ne déconnectez et réassociez qu’après les vérifications sans risque, car cela supprime les identifiants enregistrés.',
      ),
    ],
    exampleTitle: GuideText(en: 'Fast diagnostic', fr: 'Diagnostic rapide'),
    example: GuideText(
      en: 'PC running? Phone online? Connected badge? Correct conversation? Required permission or provider configured?',
      fr: 'PC allumé ? Téléphone en ligne ? Badge Connecté ? Bonne conversation ? Autorisation ou fournisseur requis configuré ?',
    ),
    remember: GuideText(
      en: 'Do not share a real token, diagnostic log or private screenshot while asking for help.',
      fr: 'Ne partagez pas de vrai jeton, journal de diagnostic ou capture privée pour demander de l’aide.',
    ),
  ),
  GuideLesson(
    id: 'advanced.security-privacy',
    categoryId: guideAdvancedCategoryId,
    order: 10,
    title: GuideText(
      en: 'Security and privacy',
      fr: 'Sécurité et confidentialité',
    ),
    introduction: GuideText(
      en: 'The phone and PC exchange your requests and results, so protect both ends and the information between them.',
      fr: 'Le téléphone et le PC échangent vos demandes et résultats ; protégez donc les deux appareils et les informations qui circulent.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Keep pairing tokens private and never share screenshots containing tokens, device identities, IP addresses, certificates, account data, real conversations or diagnostics. Public Wi-Fi adds network exposure; prefer trusted networks and rely on authenticated encrypted transports.',
        fr: 'Gardez les jetons privés et ne partagez jamais de captures contenant jetons, identités d’appareil, adresses IP, certificats, données de compte, conversations réelles ou diagnostics. Le Wi-Fi public augmente l’exposition réseau ; préférez les réseaux de confiance et les transports authentifiés et chiffrés.',
      ),
      GuideText(
        en: 'Requests may be processed by external AI, STT, TTS or connector providers selected in the PC configuration. Their policies, costs and retention can differ. Local and relay encryption protects transport, but it does not prevent a deliberately configured provider from receiving the content it must process.',
        fr: 'Les demandes peuvent être traitées par des fournisseurs externes d’IA, STT, TTS ou de connecteurs choisis sur le PC. Leurs politiques, coûts et durées de conservation diffèrent. Le chiffrement local et du relais protège le transport, mais n’empêche pas un fournisseur volontairement configuré de recevoir le contenu nécessaire à son traitement.',
      ),
      GuideText(
        en: 'Before reporting a bug, reproduce it with synthetic data, crop unrelated screen areas, mask identifiers, remove metadata and describe the visible state without attaching secrets or real logs.',
        fr: 'Avant de signaler un bug, reproduisez-le avec des données fictives, recadrez les zones inutiles, masquez les identifiants, retirez les métadonnées et décrivez l’état visible sans joindre de secrets ni de vrais journaux.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'Safe support package',
      fr: 'Dossier de support sûr',
    ),
    example: GuideText(
      en: 'Synthetic conversation + cropped screenshot + masked token/network fields + OS/app version + plain description of the steps.',
      fr: 'Conversation fictive + capture recadrée + jeton et réseau masqués + version du système et de l’application + description simple des étapes.',
    ),
    remember: GuideText(
      en: 'Share the minimum evidence needed, and sanitize it before it leaves your devices.',
      fr: 'Partagez uniquement les éléments nécessaires et assainissez-les avant qu’ils ne quittent vos appareils.',
    ),
  ),
];

List<GuideLesson> guideLessonsForCategory(String categoryId) {
  final lessons = guideLessons
      .where((lesson) => lesson.categoryId == categoryId)
      .toList(growable: false);
  lessons.sort((a, b) => a.order.compareTo(b.order));
  return lessons;
}

GuideLesson? guideLessonById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final lesson in guideLessons) {
    if (lesson.id == id) return lesson;
  }
  return null;
}

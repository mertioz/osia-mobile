import 'package:flutter/foundation.dart';

part 'guide_curriculum.g.dart';

const int guideContentSchemaVersion = 3;
const String guideEssentialCategoryId = 'getting-started';
const String guideMasteryCategoryId = 'master-osia';
const String guideAdvancedCategoryId = 'osia-advanced';
const String guideLegacyAdvancedCategoryId = 'master-osia-mobile';

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
    required this.semanticId,
    required this.order,
    required this.title,
    required this.summary,
  });

  final String id;
  final String semanticId;
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
    this.paragraphs = const <GuideText>[],
    this.bullets = const <GuideText>[],
    required this.exampleTitle,
    required this.example,
    this.remember,
    this.asset,
    this.caption,
    this.altText,
    this.subjectId,
    this.glossaryIds = const <String>[],
  });

  final String id;
  final String categoryId;
  final int order;
  final GuideText title;
  final GuideText introduction;
  final List<GuideText> paragraphs;
  final List<GuideText> bullets;
  final GuideText exampleTitle;
  final GuideText example;
  final GuideText? remember;
  final String? asset;
  final GuideText? caption;
  final GuideText? altText;
  final String? subjectId;
  final List<String> glossaryIds;
}

const List<GuideCategory> guideCategories = <GuideCategory>[
  GuideCategory(
    id: guideEssentialCategoryId,
    semanticId: 'essential',
    order: 1,
    title: GuideText(en: 'Getting started', fr: 'Démarrage essentiel'),
    summary: GuideText(
      en: 'Pair your phone and begin a first conversation in a few short slides.',
      fr: 'Associez votre téléphone et commencez une première conversation en quelques écrans courts.',
    ),
  ),
  GuideCategory(
    id: guideMasteryCategoryId,
    semanticId: 'mastery',
    order: 2,
    title: GuideText(en: 'Master OSIA', fr: 'Maîtriser OSIA'),
    summary: GuideText(
      en: 'Every OSIA feature, explained clearly with practical examples.',
      fr: 'Toutes les fonctions d’OSIA, expliquées clairement avec des exemples.',
    ),
  ),
  GuideCategory(
    id: guideAdvancedCategoryId,
    semanticId: 'advanced',
    order: 3,
    title: GuideText(en: 'OSIA: Advanced Guide', fr: 'OSIA : Guide avancé'),
    summary: GuideText(
      en: 'Architecture, protocols, development, security, and project continuation.',
      fr: 'Architecture, protocoles, développement, sécurité et reprise du projet.',
    ),
  ),
];

const List<GuideLesson> _legacyGuideLessons = <GuideLesson>[
  GuideLesson(
    id: 'essential.what-is-mobile',
    categoryId: guideEssentialCategoryId,
    order: 1,
    title: GuideText(
      en: 'OSIA, from your phone',
      fr: 'OSIA, depuis votre téléphone',
    ),
    introduction: GuideText(
      en: 'OSIA Mobile is the phone interface for OSIA running on your computer.',
      fr: 'OSIA Mobile est l’interface téléphonique d’OSIA exécuté sur votre ordinateur.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The PC provides the main intelligence and services. The phone lets you ask a question from another room, continue a conversation, send a remote request or use voice while the PC is running and connected.',
        fr: 'Le PC fournit l’intelligence et les services principaux. Le téléphone permet de poser une question depuis une autre pièce, poursuivre une conversation, envoyer une demande à distance ou utiliser la voix lorsque le PC fonctionne et reste connecté.',
      ),
    ],
    exampleTitle: GuideText(en: 'Simple example', fr: 'Exemple simple'),
    example: GuideText(
      en: 'Continue on the phone the planning task you started on the PC.',
      fr: 'Poursuivez sur le téléphone la planification commencée sur le PC.',
    ),
    remember: GuideText(
      en: 'The phone is a secure interface to your OSIA PC, not a separate AI system.',
      fr: 'Le téléphone est une interface sécurisée vers votre PC OSIA, pas un système d’IA séparé.',
    ),
  ),
  GuideLesson(
    id: 'essential.before-pairing',
    categoryId: guideEssentialCategoryId,
    order: 2,
    title: GuideText(en: 'Before you connect', fr: 'Avant la connexion'),
    introduction: GuideText(
      en: 'Have OSIA running on the PC and OSIA Mobile installed on the phone.',
      fr: 'OSIA doit fonctionner sur le PC et OSIA Mobile doit être installé sur le téléphone.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The PC displays a temporary, private pairing token that creates trust with this phone. Keep it secret. You do not need to understand ports, certificates, WebSockets, STUN, ICE or TURN.',
        fr: 'Le PC affiche un jeton d’association temporaire et privé qui établit la confiance avec ce téléphone. Gardez-le secret. Vous n’avez pas besoin de comprendre les ports, certificats, WebSockets, STUN, ICE ou TURN.',
      ),
    ],
    exampleTitle: GuideText(en: 'Quick preparation', fr: 'Préparation rapide'),
    example: GuideText(
      en: 'Keep the PC awake and confirm that the phone has a working network connection.',
      fr: 'Laissez le PC actif et vérifiez que le téléphone dispose d’une connexion réseau.',
    ),
    remember: GuideText(
      en: 'Treat the pairing token like a temporary password.',
      fr: 'Traitez le jeton d’association comme un mot de passe temporaire.',
    ),
  ),
  GuideLesson(
    id: 'essential.pair-token',
    categoryId: guideEssentialCategoryId,
    order: 3,
    title: GuideText(
      en: 'Find the token on the PC',
      fr: 'Trouver le jeton sur le PC',
    ),
    introduction: GuideText(
      en: 'The pairing token is available in OSIA Settings on the computer.',
      fr: 'Le jeton d’association se trouve dans les réglages OSIA sur l’ordinateur.',
    ),
    bullets: <GuideText>[
      GuideText(en: 'Open OSIA Settings.', fr: 'Ouvrez les réglages OSIA.'),
      GuideText(
        en: 'Open Connection / Mobile pairing.',
        fr: 'Ouvrez Connexion / Association mobile.',
      ),
      GuideText(
        en: 'Display or copy the temporary token.',
        fr: 'Affichez ou copiez le jeton temporaire.',
      ),
    ],
    exampleTitle: GuideText(en: 'Safe example', fr: 'Exemple sûr'),
    example: GuideText(
      en: 'Tutorials and support images should show DEMO-CODE or a fully masked value, never a real token.',
      fr: 'Les guides et captures d’assistance doivent afficher DEMO-CODE ou une valeur entièrement masquée, jamais un vrai jeton.',
    ),
    remember: GuideText(
      en: 'Do not share the token or a screenshot that reveals it.',
      fr: 'Ne partagez ni le jeton ni une capture qui le révèle.',
    ),
    asset: 'assets/guide/pc-pairing.png',
    caption: GuideText(
      en: 'Sanitized OSIA PC pairing page with the token fully masked.',
      fr: 'Page d’association OSIA PC assainie, avec le jeton entièrement masqué.',
    ),
    altText: GuideText(
      en: 'OSIA PC mobile-pairing settings with a completely masked pairing token.',
      fr: 'Réglages d’association mobile OSIA PC avec un jeton entièrement masqué.',
    ),
  ),
  GuideLesson(
    id: 'essential.enter-token',
    categoryId: guideEssentialCategoryId,
    order: 4,
    title: GuideText(en: 'Connect the phone', fr: 'Connecter le téléphone'),
    introduction: GuideText(
      en: 'Enter or paste the PC token on the OSIA Mobile Connection page.',
      fr: 'Saisissez ou collez le jeton du PC sur la page Connexion d’OSIA Mobile.',
    ),
    bullets: <GuideText>[
      GuideText(en: 'Validate the token.', fr: 'Validez le jeton.'),
      GuideText(
        en: 'Wait while the phone establishes trust.',
        fr: 'Patientez pendant que le téléphone établit la confiance.',
      ),
      GuideText(
        en: 'Look for the Connected state and Chat.',
        fr: 'Repérez l’état Connecté et la page Discussion.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'If it does not connect',
      fr: 'Si la connexion échoue',
    ),
    example: GuideText(
      en: 'Check for an expired or mistyped token, an offline PC, or a phone without network access.',
      fr: 'Vérifiez si le jeton a expiré ou est mal saisi, si le PC est hors ligne ou si le téléphone n’a pas de réseau.',
    ),
    remember: GuideText(
      en: 'Connected means the phone is paired and ready to exchange messages with the PC.',
      fr: 'Connecté signifie que le téléphone est associé et prêt à échanger avec le PC.',
    ),
    asset: 'assets/guide/mobile-chat.png',
    caption: GuideText(
      en: 'Sanitized Chat screen showing a connected demo session.',
      fr: 'Écran Discussion assaini montrant une session de démonstration connectée.',
    ),
    altText: GuideText(
      en: 'OSIA Mobile Chat with synthetic messages and a connected status.',
      fr: 'Discussion OSIA Mobile avec des messages fictifs et un état connecté.',
    ),
  ),
  GuideLesson(
    id: 'essential.mobile-pages',
    categoryId: guideEssentialCategoryId,
    order: 5,
    title: GuideText(
      en: 'Know the main pages',
      fr: 'Connaître les pages principales',
    ),
    introduction: GuideText(
      en: 'After connection, Chat is the main place for active conversations and messages.',
      fr: 'Après la connexion, Discussion est la page principale pour les conversations et les messages.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Conversations manages chats; Autonomous follows longer PC tasks; Settings contains notifications and preferences; Memory shows local memories; Providers and system pages configure the PC. Connection handles pairing and recovery.',
        fr: 'Conversations gère les discussions ; Autonome suit les tâches PC plus longues ; Réglages contient les notifications et préférences ; Mémoire affiche les souvenirs locaux ; Fournisseurs et les pages système configurent le PC. Connexion gère l’association et la récupération.',
      ),
    ],
    exampleTitle: GuideText(en: 'Navigation', fr: 'Navigation'),
    example: GuideText(
      en: 'Open the mobile menu to move between Chat, Autonomous and Settings.',
      fr: 'Ouvrez le menu mobile pour passer de Discussion à Autonome ou Réglages.',
    ),
    remember: GuideText(
      en: 'Conversations are PC-authoritative even when you browse them from the phone.',
      fr: 'Les conversations restent gérées par le PC, même lorsqu’elles sont consultées sur le téléphone.',
    ),
    asset: 'assets/guide/mobile-navigation.png',
    caption: GuideText(
      en: 'Sanitized OSIA Mobile navigation with the real page names.',
      fr: 'Navigation OSIA Mobile assainie avec les véritables noms de pages.',
    ),
    altText: GuideText(
      en: 'OSIA Mobile menu showing Conversations, Autonomous and Settings.',
      fr: 'Menu OSIA Mobile affichant Conversations, Autonome et Réglages.',
    ),
  ),
  GuideLesson(
    id: 'essential.first-message',
    categoryId: guideEssentialCategoryId,
    order: 6,
    title: GuideText(
      en: 'Send the first message',
      fr: 'Envoyer le premier message',
    ),
    introduction: GuideText(
      en: 'Open or create a conversation, type a clear request, then send it.',
      fr: 'Ouvrez ou créez une conversation, saisissez une demande claire, puis envoyez-la.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Wait for OSIA’s response and continue in the same conversation. State your goal, add useful context and describe the result you want.',
        fr: 'Attendez la réponse d’OSIA puis continuez dans la même conversation. Indiquez votre objectif, ajoutez le contexte utile et décrivez le résultat souhaité.',
      ),
    ],
    exampleTitle: GuideText(en: 'Try this', fr: 'Essayez ceci'),
    example: GuideText(
      en: '“Help me plan tomorrow. Give me a short, prioritized checklist.”',
      fr: '« Aide-moi à organiser demain. Donne-moi une courte liste de priorités. »',
    ),
    remember: GuideText(
      en: 'Goal + context + desired result makes a stronger request.',
      fr: 'Objectif + contexte + résultat souhaité rend la demande plus efficace.',
    ),
  ),
  GuideLesson(
    id: 'essential.voice',
    categoryId: guideEssentialCategoryId,
    order: 7,
    title: GuideText(en: 'Use voice', fr: 'Utiliser la voix'),
    introduction: GuideText(
      en: 'The microphone records speech that the PC converts into message text.',
      fr: 'Le microphone enregistre la parole que le PC convertit en texte de message.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Allow microphone access when requested, speak, then review and send the result. TTS can read responses aloud when enabled. Availability depends on platform and PC configuration; there is no mobile wake word.',
        fr: 'Autorisez le microphone, parlez, puis vérifiez et envoyez le résultat. La synthèse vocale peut lire les réponses si elle est activée. La disponibilité dépend de la plateforme et du PC ; il n’existe pas de mot d’activation mobile.',
      ),
    ],
    exampleTitle: GuideText(en: 'Short procedure', fr: 'Procédure courte'),
    example: GuideText(
      en: 'Tap the microphone, speak one request, stop recording, then check the transcribed text.',
      fr: 'Touchez le microphone, dictez une demande, arrêtez l’enregistrement, puis vérifiez le texte transcrit.',
    ),
    remember: GuideText(
      en: 'Speech-to-text creates a message; it does not send one silently in the background.',
      fr: 'La reconnaissance vocale crée un message ; elle ne l’envoie pas discrètement en arrière-plan.',
    ),
  ),
  GuideLesson(
    id: 'essential.notifications-background',
    categoryId: guideEssentialCategoryId,
    order: 8,
    title: GuideText(en: 'Stay connected', fr: 'Rester connecté'),
    introduction: GuideText(
      en: 'OSIA Mobile prefers the paired PC on the local network and reconnects after interruptions.',
      fr: 'OSIA Mobile préfère le PC associé sur le réseau local et se reconnecte après une interruption.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Locking the phone or changing networks can briefly disconnect it. Android can optionally keep a visible foreground connection; iOS may suspend the app. Notifications are local socket events, not APNs push while fully suspended. The PC must remain available.',
        fr: 'Verrouiller le téléphone ou changer de réseau peut interrompre brièvement la connexion. Android peut conserver une connexion visible au premier plan ; iOS peut suspendre l’app. Les notifications sont des événements locaux du socket, pas des push APNs lorsque l’app est suspendue. Le PC doit rester disponible.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'After a network change',
      fr: 'Après un changement de réseau',
    ),
    example: GuideText(
      en: 'Reopen the app and allow reconnection before sending another message.',
      fr: 'Rouvrez l’application et laissez-la se reconnecter avant d’envoyer un autre message.',
    ),
    remember: GuideText(
      en: 'A short Connecting state after resume or network change can be normal.',
      fr: 'Un bref état Connexion après une reprise ou un changement de réseau peut être normal.',
    ),
    asset: 'assets/guide/mobile-settings.png',
    caption: GuideText(
      en: 'Sanitized Android Settings with notification and background controls.',
      fr: 'Réglages Android assainis avec les contrôles de notification et d’arrière-plan.',
    ),
    altText: GuideText(
      en: 'OSIA Mobile Settings showing notification and Android background connection controls.',
      fr: 'Réglages OSIA Mobile montrant les contrôles de notification et de connexion Android en arrière-plan.',
    ),
  ),
  GuideLesson(
    id: 'essential.ready',
    categoryId: guideEssentialCategoryId,
    order: 9,
    title: GuideText(en: 'You are ready', fr: 'Vous êtes prêt'),
    introduction: GuideText(
      en: 'The PC is running, the phone is paired and the connection state is visible.',
      fr: 'Le PC fonctionne, le téléphone est associé et l’état de connexion est visible.',
    ),
    bullets: <GuideText>[
      GuideText(
        en: 'Messages can now be sent.',
        fr: 'Les messages peuvent maintenant être envoyés.',
      ),
      GuideText(
        en: 'Voice remains optional.',
        fr: 'La voix reste facultative.',
      ),
      GuideText(
        en: 'Preferences can be changed later.',
        fr: 'Les préférences peuvent être modifiées plus tard.',
      ),
    ],
    exampleTitle: GuideText(en: 'Explore later', fr: 'Approfondir plus tard'),
    example: GuideText(
      en: 'The advanced guide explains connection modes, voice, models, notifications and troubleshooting.',
      fr: 'Le guide avancé explique les modes de connexion, la voix, les modèles, les notifications et le dépannage.',
    ),
    remember: GuideText(
      en: 'Finish closes this guide; Help keeps all three guide levels available.',
      fr: 'Terminer ferme ce guide ; Aide garde les trois niveaux de guide disponibles.',
    ),
  ),

  GuideLesson(
    id: 'advanced.pairing-trust',
    categoryId: guideAdvancedCategoryId,
    order: 1,
    title: GuideText(en: 'Pairing and trust', fr: 'Association et confiance'),
    introduction: GuideText(
      en: 'Pairing proves that this phone is allowed to communicate with this OSIA PC.',
      fr: 'L’association prouve que ce téléphone est autorisé à communiquer avec ce PC OSIA.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The temporary token starts authenticated trust; stored pairing information lets later sessions reconnect without retyping it. Reinstalling the app, clearing its storage, disconnecting, or resetting PC-side trust can require a new token. Keep every token private.',
        fr: 'Le jeton temporaire établit la confiance authentifiée ; les informations d’association enregistrées permettent ensuite de se reconnecter sans le ressaisir. Réinstaller l’app, effacer son stockage, se déconnecter ou réinitialiser la confiance sur le PC peut exiger un nouveau jeton. Gardez chaque jeton privé.',
      ),
    ],
    exampleTitle: GuideText(en: 'Pair again when', fr: 'Réassociez lorsque'),
    example: GuideText(
      en: 'The app was reinstalled or the PC deliberately revoked the phone’s trust.',
      fr: 'L’application a été réinstallée ou le PC a volontairement révoqué la confiance du téléphone.',
    ),
    remember: GuideText(
      en: 'Pairing is about trust, not merely discovering a PC on the network.',
      fr: 'L’association concerne la confiance, pas seulement la découverte d’un PC sur le réseau.',
    ),
  ),
  GuideLesson(
    id: 'advanced.connection-hierarchy',
    categoryId: guideAdvancedCategoryId,
    order: 2,
    title: GuideText(en: 'Connection hierarchy', fr: 'Hiérarchie de connexion'),
    introduction: GuideText(
      en: 'OSIA resolves the safest available route in a fixed order instead of switching unpredictably.',
      fr: 'OSIA détermine la route sûre disponible dans un ordre fixe, sans basculer de façon imprévisible.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'It prefers an existing or provisioned private-LAN WSS route, then tries direct WebRTC/P2P, then commits to the encrypted relay fallback. A reconnect performs fresh resolution with capped backoff. The active route is not changed in the middle of a request.',
        fr: 'Il préfère une route WSS sur LAN privé existante ou fournie, tente ensuite WebRTC/P2P direct, puis utilise le relais chiffré. Une reconnexion recherche à nouveau la meilleure route avec une attente plafonnée. La route active ne change pas au milieu d’une demande.',
      ),
    ],
    exampleTitle: GuideText(en: 'Plain-language order', fr: 'Ordre simplifié'),
    example: GuideText(
      en: 'Nearby direct connection first; internet-assisted direct path second; protected relay last.',
      fr: 'Connexion directe proche d’abord ; chemin direct aidé par Internet ensuite ; relais protégé en dernier.',
    ),
    remember: GuideText(
      en: 'The PC being offline prevents every normal route from completing.',
      fr: 'Un PC hors ligne empêche toute route normale d’aboutir.',
    ),
  ),
  GuideLesson(
    id: 'advanced.lan',
    categoryId: guideAdvancedCategoryId,
    order: 3,
    title: GuideText(
      en: 'LAN: the nearby route',
      fr: 'LAN : la route de proximité',
    ),
    introduction: GuideText(
      en: 'A private-LAN WSS connection is preferred when the phone can safely reach the paired PC nearby.',
      fr: 'Une connexion WSS sur LAN privé est préférée lorsque le téléphone peut joindre en sécurité le PC associé à proximité.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'It normally offers the lowest latency and keeps application traffic on the local network. Both devices need compatible local connectivity and permissions. Guest Wi-Fi isolation, blocked discovery or different networks can make this route unavailable without breaking remote fallbacks.',
        fr: 'Elle offre généralement la latence la plus faible et conserve le trafic applicatif sur le réseau local. Les deux appareils ont besoin d’une connectivité et d’autorisations compatibles. L’isolation Wi-Fi invité, une découverte bloquée ou des réseaux différents peuvent rendre cette route indisponible sans empêcher les solutions distantes.',
      ),
    ],
    exampleTitle: GuideText(en: 'Best case', fr: 'Meilleur cas'),
    example: GuideText(
      en: 'Phone and PC are on the same trusted home network with local access allowed.',
      fr: 'Le téléphone et le PC utilisent le même réseau domestique de confiance avec l’accès local autorisé.',
    ),
  ),
  GuideLesson(
    id: 'advanced.webrtc',
    categoryId: guideAdvancedCategoryId,
    order: 4,
    title: GuideText(en: 'WebRTC/P2P', fr: 'WebRTC/P2P'),
    introduction: GuideText(
      en: 'WebRTC/P2P tries to create an authenticated direct path when the LAN route is unavailable.',
      fr: 'WebRTC/P2P tente de créer un chemin direct authentifié lorsque la route LAN est indisponible.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Internet signaling helps the phone and PC exchange connection candidates; it does not make the PC optional. Firewalls, carrier networks and restrictive routers can prevent a direct path. When negotiation succeeds, traffic avoids the application relay and usually performs better.',
        fr: 'La signalisation Internet aide le téléphone et le PC à échanger des possibilités de connexion ; elle ne rend pas le PC facultatif. Pare-feu, réseaux mobiles et routeurs restrictifs peuvent bloquer le chemin direct. Lorsqu’il aboutit, le trafic évite le relais applicatif et offre souvent de meilleures performances.',
      ),
    ],
    exampleTitle: GuideText(en: 'Away from home', fr: 'Hors du domicile'),
    example: GuideText(
      en: 'A mobile-data phone can connect directly to the online PC if negotiation succeeds.',
      fr: 'Un téléphone en données mobiles peut joindre directement le PC en ligne si la négociation réussit.',
    ),
  ),
  GuideLesson(
    id: 'advanced.relay-reconnect',
    categoryId: guideAdvancedCategoryId,
    order: 5,
    title: GuideText(en: 'Relay and reconnect', fr: 'Relais et reconnexion'),
    introduction: GuideText(
      en: 'The encrypted relay is the committed fallback when direct LAN and WebRTC paths cannot complete.',
      fr: 'Le relais chiffré est la solution retenue lorsque les chemins directs LAN et WebRTC ne peuvent pas aboutir.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'It requires internet on both devices and usually adds latency compared with a direct route. After suspension or a network change, reconnect starts fresh route resolution with capped exponential delay beginning quickly. A request already in flight is never moved between routes.',
        fr: 'Il exige Internet sur les deux appareils et ajoute généralement de la latence par rapport à une route directe. Après une suspension ou un changement de réseau, la reconnexion relance la recherche avec un délai exponentiel plafonné. Une demande en cours n’est jamais déplacée entre deux routes.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'What Connecting means',
      fr: 'Signification de Connexion',
    ),
    example: GuideText(
      en: 'The app may be resolving a fresh route rather than remaining stuck on the old network.',
      fr: 'L’application peut rechercher une nouvelle route plutôt que rester bloquée sur l’ancien réseau.',
    ),
  ),
  GuideLesson(
    id: 'advanced.android-background',
    categoryId: guideAdvancedCategoryId,
    order: 6,
    title: GuideText(
      en: 'Android background connection',
      fr: 'Connexion Android en arrière-plan',
    ),
    introduction: GuideText(
      en: 'Android can optionally run OSIA’s connection as a foreground service with a visible private notification.',
      fr: 'Android peut facultativement exécuter la connexion OSIA comme service au premier plan avec une notification privée visible.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Enabling it requires notification permission and a reachable PC. Disabling the setting stops the service. Android can still restrict work through battery optimization, force-stop, connectivity loss or system policy; the service improves persistence but does not promise an unlimited connection.',
        fr: 'Son activation exige l’autorisation des notifications et un PC joignable. Désactiver le réglage arrête le service. Android peut encore limiter l’activité via l’optimisation de batterie, l’arrêt forcé, la perte de réseau ou ses règles système ; le service améliore la persistance sans garantir une connexion illimitée.',
      ),
    ],
    exampleTitle: GuideText(en: 'Practical check', fr: 'Vérification pratique'),
    example: GuideText(
      en: 'If the persistent notification disappears, reopen OSIA Mobile and check the background setting.',
      fr: 'Si la notification permanente disparaît, rouvrez OSIA Mobile et vérifiez le réglage d’arrière-plan.',
    ),
    remember: GuideText(
      en: 'The visible notification is an Android requirement for this optional service.',
      fr: 'La notification visible est une exigence Android pour ce service facultatif.',
    ),
    asset: 'assets/guide/mobile-settings.png',
    caption: GuideText(
      en: 'Sanitized Android Settings with the optional background connection control.',
      fr: 'Réglages Android assainis avec le contrôle facultatif de connexion en arrière-plan.',
    ),
    altText: GuideText(
      en: 'OSIA Mobile Android Settings showing the background connection switch.',
      fr: 'Réglages Android OSIA Mobile affichant l’interrupteur de connexion en arrière-plan.',
    ),
  ),
  GuideLesson(
    id: 'advanced.ios-background',
    categoryId: guideAdvancedCategoryId,
    order: 7,
    title: GuideText(
      en: 'iOS suspension and resume',
      fr: 'Suspension et reprise sur iOS',
    ),
    introduction: GuideText(
      en: 'iOS background execution can suspend OSIA Mobile, so a permanent socket is not guaranteed.',
      fr: 'L’exécution en arrière-plan sur iOS peut suspendre OSIA Mobile ; un socket permanent n’est donc pas garanti.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The app reconnects when it resumes. Current notifications are local and socket-delivered, not APNs push during full suspension. Local discovery intends to use Bonjour and multicast, subject to local-network permission and Apple multicast approval. This does not claim public TestFlight or App Store availability.',
        fr: 'L’application se reconnecte à la reprise. Les notifications actuelles sont locales et reçues par socket, pas des push APNs pendant une suspension complète. La découverte locale prévoit Bonjour et le multicast, sous réserve de l’autorisation réseau local et de l’approbation multicast d’Apple. Cela ne signifie pas une disponibilité publique sur TestFlight ou l’App Store.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'After unlocking',
      fr: 'Après le déverrouillage',
    ),
    example: GuideText(
      en: 'Wait for Connected before expecting a new socket event or sending a message.',
      fr: 'Attendez l’état Connecté avant d’attendre un nouvel événement socket ou d’envoyer un message.',
    ),
  ),
  GuideLesson(
    id: 'advanced.voice-tts-stt',
    categoryId: guideAdvancedCategoryId,
    order: 8,
    title: GuideText(en: 'STT: speech to text', fr: 'STT : parole vers texte'),
    introduction: GuideText(
      en: 'STT turns a phone microphone recording into text by sending the WAV audio to the paired PC.',
      fr: 'La STT transforme un enregistrement du microphone du téléphone en texte en envoyant l’audio WAV au PC associé.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Microphone permission is required. Recognition depends on the STT provider or local engine configured on the PC, its language support and network needs. Review the transcription before sending. Phone recording settings are separate from PC wake-word behavior; mobile has no wake word.',
        fr: 'L’autorisation du microphone est requise. La reconnaissance dépend du fournisseur STT ou du moteur local configuré sur le PC, de ses langues et de ses besoins réseau. Vérifiez la transcription avant l’envoi. L’enregistrement du téléphone est distinct du mot d’activation du PC ; le mobile n’en possède pas.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'When transcription fails',
      fr: 'Si la transcription échoue',
    ),
    example: GuideText(
      en: 'Check permission, PC connectivity, selected language and the PC’s configured STT engine.',
      fr: 'Vérifiez l’autorisation, la connexion au PC, la langue choisie et le moteur STT configuré sur le PC.',
    ),
  ),
  GuideLesson(
    id: 'advanced.tts',
    categoryId: guideAdvancedCategoryId,
    order: 9,
    title: GuideText(en: 'TTS: text to speech', fr: 'TTS : texte vers parole'),
    introduction: GuideText(
      en: 'TTS turns response text into audio that OSIA Mobile can play through the phone speaker.',
      fr: 'La TTS transforme le texte d’une réponse en audio qu’OSIA Mobile peut lire sur le haut-parleur du téléphone.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The PC selects and streams the configured voice output. You can play supported responses or enable optional automatic reading in mobile Settings. Voice, language, quality, cost and network use depend on the provider or local engine selected on the PC.',
        fr: 'Le PC sélectionne et diffuse la voix configurée. Vous pouvez lire les réponses compatibles ou activer la lecture automatique facultative dans les réglages mobiles. Voix, langue, qualité, coût et réseau dépendent du fournisseur ou moteur local choisi sur le PC.',
      ),
    ],
    exampleTitle: GuideText(en: 'No sound', fr: 'Aucun son'),
    example: GuideText(
      en: 'Check media volume, speaker output, PC connection and the configured TTS service.',
      fr: 'Vérifiez le volume multimédia, la sortie audio, la connexion au PC et le service TTS configuré.',
    ),
  ),
  GuideLesson(
    id: 'advanced.conversations-sync',
    categoryId: guideAdvancedCategoryId,
    order: 10,
    title: GuideText(
      en: 'Conversations and synchronization',
      fr: 'Conversations et synchronisation',
    ),
    introduction: GuideText(
      en: 'The conversation list and active conversation are authoritative on the paired PC.',
      fr: 'La liste et la conversation active font autorité sur le PC associé.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The phone stores pairing and preferences locally, then requests conversation data from the PC after connection. While disconnected, loading, creating, renaming or deleting PC conversations may be unavailable. Reconnection refreshes server state. Deletion is sent to the PC and should be treated as a real conversation action.',
        fr: 'Le téléphone stocke localement l’association et les préférences, puis demande les conversations au PC après connexion. Hors ligne, charger, créer, renommer ou supprimer des conversations PC peut être impossible. La reconnexion actualise l’état du serveur. La suppression est envoyée au PC et doit être considérée comme une action réelle.',
      ),
    ],
    exampleTitle: GuideText(en: 'After reconnecting', fr: 'Après reconnexion'),
    example: GuideText(
      en: 'Wait for the refreshed list before deciding that a recent PC conversation is missing.',
      fr: 'Attendez la liste actualisée avant de conclure qu’une conversation récente du PC manque.',
    ),
  ),
  GuideLesson(
    id: 'advanced.models',
    categoryId: guideAdvancedCategoryId,
    order: 11,
    title: GuideText(
      en: 'Models and AI selection',
      fr: 'Modèles et sélection de l’IA',
    ),
    introduction: GuideText(
      en: 'A provider operates the AI service; a model is the specific system selected within that provider.',
      fr: 'Un fournisseur exploite le service d’IA ; un modèle est le système précis choisi chez ce fournisseur.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Mobile requests the PC’s real provider/model list and sends the selected model and reasoning choice back to the PC. The PC remains authoritative and its hierarchy can override a request. Models differ in speed, quality, features and cost. An unavailable model produces an error; no invented provider fallback is promised.',
        fr: 'Le mobile demande au PC la liste réelle des fournisseurs et modèles, puis lui envoie le modèle et le niveau de raisonnement choisis. Le PC reste l’autorité et sa hiérarchie peut remplacer une demande. Les modèles diffèrent en vitesse, qualité, fonctions et coût. Un modèle indisponible provoque une erreur ; aucun basculement fournisseur inventé n’est promis.',
      ),
    ],
    exampleTitle: GuideText(en: 'Choosing well', fr: 'Bien choisir'),
    example: GuideText(
      en: 'Use a faster model for routine questions and a stronger one for difficult analysis, if configured.',
      fr: 'Utilisez un modèle rapide pour les demandes courantes et un modèle plus puissant pour une analyse difficile, s’ils sont configurés.',
    ),
  ),
  GuideLesson(
    id: 'advanced.notifications',
    categoryId: guideAdvancedCategoryId,
    order: 12,
    title: GuideText(
      en: 'Notification details',
      fr: 'Détails des notifications',
    ),
    introduction: GuideText(
      en: 'Current OSIA notifications begin as scheduled or reminder events delivered over the active PC socket.',
      fr: 'Les notifications OSIA actuelles commencent comme des événements planifiés ou des rappels reçus par le socket actif du PC.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The app can show an in-app message and, when enabled and permitted, a deduplicated local notification. Android background connection can keep the socket available more often. iOS suspension can stop socket delivery. APNs remote push is not currently supported, so a fully suspended app may receive nothing.',
        fr: 'L’app peut afficher un message interne et, si l’option et l’autorisation sont actives, une notification locale dédupliquée. La connexion Android en arrière-plan peut maintenir le socket plus souvent. La suspension iOS peut interrompre sa réception. Le push distant APNs n’est pas pris en charge ; une app entièrement suspendue peut ne rien recevoir.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'If one is missing',
      fr: 'Si une notification manque',
    ),
    example: GuideText(
      en: 'Check permission, OSIA’s notification setting, connection state and whether the PC actually emitted the event.',
      fr: 'Vérifiez l’autorisation, le réglage de notification OSIA, la connexion et si le PC a réellement émis l’événement.',
    ),
  ),
  GuideLesson(
    id: 'advanced.troubleshooting',
    categoryId: guideAdvancedCategoryId,
    order: 13,
    title: GuideText(
      en: 'Troubleshooting connection',
      fr: 'Dépanner la connexion',
    ),
    introduction: GuideText(
      en: 'Start with the visible state: token rejected, PC unavailable, or repeated Connecting.',
      fr: 'Commencez par l’état visible : jeton refusé, PC indisponible ou Connexion répétée.',
    ),
    bullets: <GuideText>[
      GuideText(
        en: 'Use a fresh token and check it for typing errors.',
        fr: 'Utilisez un jeton récent et vérifiez sa saisie.',
      ),
      GuideText(
        en: 'Confirm that the PC is running and both devices have network access.',
        fr: 'Vérifiez que le PC fonctionne et que les deux appareils ont un accès réseau.',
      ),
      GuideText(
        en: 'After a network change, reopen the app and let route resolution finish.',
        fr: 'Après un changement de réseau, rouvrez l’app et laissez la recherche de route aboutir.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'Local discovery absent',
      fr: 'Découverte locale absente',
    ),
    example: GuideText(
      en: 'Allow local-network access, avoid isolated guest Wi-Fi, then rely on WebRTC or relay if available.',
      fr: 'Autorisez le réseau local, évitez un Wi-Fi invité isolé, puis utilisez WebRTC ou le relais s’ils sont disponibles.',
    ),
    remember: GuideText(
      en: 'Do not repeatedly send while the app is still resolving a connection.',
      fr: 'N’envoyez pas plusieurs fois pendant que l’app recherche encore une connexion.',
    ),
  ),
  GuideLesson(
    id: 'advanced.troubleshooting-media',
    categoryId: guideAdvancedCategoryId,
    order: 14,
    title: GuideText(
      en: 'Troubleshooting voice and alerts',
      fr: 'Dépanner la voix et les alertes',
    ),
    introduction: GuideText(
      en: 'Audio and notification failures usually come from permission, device output, connection or PC configuration.',
      fr: 'Les problèmes audio et de notification proviennent généralement des autorisations, de la sortie, de la connexion ou de la configuration PC.',
    ),
    bullets: <GuideText>[
      GuideText(
        en: 'For STT, check microphone permission and the PC speech engine.',
        fr: 'Pour la STT, vérifiez le microphone et le moteur vocal du PC.',
      ),
      GuideText(
        en: 'For TTS, check media volume, speaker output and the PC voice service.',
        fr: 'Pour la TTS, vérifiez le volume, la sortie et le service vocal du PC.',
      ),
      GuideText(
        en: 'For alerts, check notification permission, OSIA settings and socket connection.',
        fr: 'Pour les alertes, vérifiez l’autorisation, les réglages OSIA et le socket.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'Stale or duplicated state',
      fr: 'État ancien ou dupliqué',
    ),
    example: GuideText(
      en: 'Return to the app, wait for one clean reconnect, then retry once instead of stacking repeated actions.',
      fr: 'Revenez dans l’app, attendez une reconnexion propre, puis réessayez une fois sans accumuler les actions.',
    ),
  ),
  GuideLesson(
    id: 'advanced.security-privacy',
    categoryId: guideAdvancedCategoryId,
    order: 15,
    title: GuideText(
      en: 'Security and privacy',
      fr: 'Sécurité et confidentialité',
    ),
    introduction: GuideText(
      en: 'Protect pairing tokens, connection details, real conversations, diagnostics and device identities.',
      fr: 'Protégez les jetons, détails de connexion, conversations réelles, diagnostics et identités d’appareil.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Phone and PC exchange content over authenticated paths, but external AI, STT, TTS or connector providers configured on the PC may process what they need. Prefer trusted networks. Before reporting a bug, use synthetic data, crop unrelated areas, mask identifiers and tokens, remove metadata and avoid attaching real logs.',
        fr: 'Le téléphone et le PC échangent du contenu par des chemins authentifiés, mais les fournisseurs externes d’IA, STT, TTS ou de connecteurs configurés sur le PC peuvent traiter les données nécessaires. Préférez les réseaux de confiance. Pour signaler un bug, utilisez des données fictives, recadrez, masquez identifiants et jetons, retirez les métadonnées et évitez les vrais journaux.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'Safe support package',
      fr: 'Dossier d’assistance sûr',
    ),
    example: GuideText(
      en: 'A synthetic conversation, cropped screenshot, masked fields, app version and plain reproduction steps.',
      fr: 'Une conversation fictive, une capture recadrée, des champs masqués, la version de l’app et des étapes simples.',
    ),
    remember: GuideText(
      en: 'Share only the minimum sanitized evidence needed to understand the problem.',
      fr: 'Partagez uniquement les éléments assainis indispensables à la compréhension du problème.',
    ),
  ),
];

final List<GuideLesson> guideLessons = <GuideLesson>[
  ..._legacyGuideLessons.take(9),
  ...generatedGuideCurriculum,
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

// GENERATED FROM THE AUDITED PC GUIDE MODEL.
// This is a checked-in runtime copy; the mobile app has no PC-repository dependency.
part of 'guide_content.dart';

final List<GuideLesson> generatedGuideCurriculum = <GuideLesson>[
  GuideLesson(
    id: 'mastery.mental-model',
    categoryId: guideMasteryCategoryId,
    order: 1,
    subjectId: 'mental-model',
    glossaryIds: <String>[],
    title: GuideText(en: 'OSIA\'s mental model', fr: 'Le modèle mental d’OSIA'),
    introduction: GuideText(
      en: 'OSIA executes work and keeps its main state on the PC; the phone is a secure second screen.',
      fr: 'OSIA exécute le travail et conserve son état principal sur le PC ; le téléphone est un second écran sécurisé.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Conversations, memory, providers, scheduled tasks and tool execution belong to the PC. Reinstalling the mobile app does not erase PC conversations, but most mobile actions require that PC to be awake, running and reachable.',
        fr: 'Les conversations, la mémoire, les fournisseurs, les tâches planifiées et les outils appartiennent au PC. Réinstaller l’app mobile n’efface pas les conversations du PC, mais la plupart des actions mobiles exigent un PC actif, démarré et joignable.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Start a plan on the PC, continue it from the phone, then return to the PC for a sensitive computer action.',
      fr: 'Commencez un plan sur le PC, poursuivez-le depuis le téléphone, puis revenez au PC pour une action sensible.',
    ),
    remember: GuideText(
      en: 'Back up and manage the PC profile as the source of truth.',
      fr: 'Sauvegardez et gérez le profil PC comme source de vérité.',
    ),
  ),
  GuideLesson(
    id: 'mastery.conversations-turns',
    categoryId: guideMasteryCategoryId,
    order: 2,
    subjectId: 'conversations-turns',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Conversations and turns',
      fr: 'Conversations et tours',
    ),
    introduction: GuideText(
      en: 'A conversation stores related messages; a turn is one request and its streamed result.',
      fr: 'Une conversation regroupe des messages liés ; un tour correspond à une demande et à son résultat diffusé progressivement.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Create or select a conversation before sending. PC and mobile synchronize history through the PC. While a turn is active, a second prompt can be blocked to prevent mixed tool results; Stop cancels the active work, and Retry should be used only after its terminal state is visible.',
        fr: 'Créez ou choisissez une conversation avant l’envoi. PC et mobile synchronisent l’historique via le PC. Pendant un tour actif, une seconde demande peut être bloquée pour éviter de mélanger les outils ; Arrêter annule le travail et Réessayer ne doit être utilisé qu’après l’état final.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'If a long reply is streaming, wait or stop it before asking a different question in that conversation.',
      fr: 'Si une longue réponse arrive progressivement, attendez ou arrêtez-la avant une autre demande dans cette conversation.',
    ),
    remember: GuideText(
      en: 'A blocked second prompt protects turn ordering; it is not a lost message.',
      fr: 'Le blocage d’une seconde demande protège l’ordre des tours ; ce n’est pas un message perdu.',
    ),
  ),
  GuideLesson(
    id: 'mastery.providers-accounts',
    categoryId: guideMasteryCategoryId,
    order: 3,
    subjectId: 'providers-accounts',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Providers and accounts',
      fr: 'Fournisseurs et comptes',
    ),
    introduction: GuideText(
      en: 'A provider operates the AI service; an account or API key authorizes OSIA to use it.',
      fr: 'Un fournisseur exploite le service d’IA ; un compte ou une clé API autorise OSIA à l’utiliser.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'ChatGPT Account uses its isolated managed sign-in. API providers exposed in Models use their own keys, quotas, availability and privacy terms; local Ollama remains a separate local option when installed. Status and errors belong to the selected route, not to OSIA as a promise of service.',
        fr: 'Compte ChatGPT utilise une connexion gérée et isolée. Les fournisseurs API affichés dans Modèles ont leurs propres clés, quotas, disponibilités et règles de confidentialité ; Ollama reste une option locale distincte s’il est installé. L’état et les erreurs dépendent de la route choisie.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Connect one route, select one compatible model, then send a harmless test prompt before adding fallbacks.',
      fr: 'Connectez une route, choisissez un modèle compatible, puis envoyez une demande sans risque avant d’ajouter des replis.',
    ),
    remember: GuideText(
      en: 'Provider availability, price and data handling can change outside OSIA.',
      fr: 'Disponibilité, prix et traitement des données peuvent changer hors d’OSIA.',
    ),
  ),
  GuideLesson(
    id: 'advanced.provider-api-hierarchy',
    categoryId: guideMasteryCategoryId,
    order: 4,
    subjectId: 'provider-hierarchy',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Provider and API hierarchy',
      fr: 'Hiérarchie des fournisseurs et API',
    ),
    introduction: GuideText(
      en: 'A provider operates an AI service; an API key is your private access code for that provider.',
      fr: 'Un fournisseur exploite un service d’IA ; une clé API est votre code d’accès privé à ce fournisseur.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'ChatGPT Account is a separate managed connection. It does not reuse an OpenAI API key and is never silently preferred. API providers are Anthropic, OpenAI, DeepSeek, Google, xAI, Groq and Mistral; Ollama is local and keyless.',
        fr: 'Le Compte ChatGPT est une connexion gérée séparée. Il ne réutilise pas une clé API OpenAI et n’est jamais privilégié silencieusement. Les fournisseurs API sont Anthropic, OpenAI, DeepSeek, Google, xAI, Groq et Mistral ; Ollama est local et sans clé.',
      ),
      GuideText(
        en: 'Within one API provider, OSIA uses the ordered saved key chain. The first configured key is primary. On the main chat path, 429/401/403 can advance to the next key before any model switch; shared provider call sites rotate only for technical failures, not ordinary content errors such as 400.',
        fr: 'Pour un fournisseur API, OSIA utilise la liste ordonnée des clés enregistrées. La première est principale. Dans la discussion, les erreurs 429/401/403 peuvent essayer la clé suivante avant tout changement de modèle ; les autres appels ne tournent les clés que pour des erreurs techniques, pas pour une erreur de contenu comme 400.',
      ),
      GuideText(
        en: 'A provider may also have a primary and fallback API endpoint. A connection or timeout failure can retry the same model and key on the fallback endpoint before key/model fallback. This is not a promise that every outage can be bypassed.',
        fr: 'Un fournisseur peut aussi avoir une adresse API principale et une adresse de secours. Une erreur de connexion ou un délai dépassé peut réessayer le même modèle et la même clé sur l’adresse de secours avant de changer de clé ou de modèle. Cela ne garantit pas de contourner toute panne.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'Failure order example',
      fr: 'Exemple d’ordre de secours',
    ),
    example: GuideText(
      en: 'Selected OpenAI model fails before output: try its endpoint fallback for a network failure → try the next OpenAI key for rate/auth failure → if automatic model routing is enabled, try the next configured model → finally retain the manual model as the chain’s last fallback.',
      fr: 'Le modèle OpenAI choisi échoue avant de répondre : essayer l’adresse de secours en cas de réseau → la clé OpenAI suivante en cas de limite/authentification → le modèle suivant si le routage automatique est actif → conserver le modèle manuel comme dernier secours.',
    ),
    remember: GuideText(
      en: 'Endpoint fallback keeps provider/model/key; key fallback keeps provider/model; model fallback may change both model and provider.',
      fr: 'Le secours d’adresse garde fournisseur/modèle/clé ; le secours de clé garde fournisseur/modèle ; le secours de modèle peut changer modèle et fournisseur.',
    ),
  ),
  GuideLesson(
    id: 'advanced.ai-model-hierarchy',
    categoryId: guideMasteryCategoryId,
    order: 5,
    subjectId: 'model-hierarchy',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Models and AI hierarchy',
      fr: 'Modèles et hiérarchie IA',
    ),
    introduction: GuideText(
      en: 'The provider is the service; the model is the particular AI inside that service. Different models trade quality, speed, price and local privacy.',
      fr: 'Le fournisseur est le service ; le modèle est l’IA particulière dans ce service. Les modèles offrent différents compromis de qualité, vitesse, prix et confidentialité locale.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'With automatic task routing disabled, OSIA always uses the provider/model you selected manually. This is the default and the easiest behavior to predict.',
        fr: 'Lorsque le routage automatique est désactivé, OSIA utilise toujours le fournisseur et le modèle choisis manuellement. C’est le comportement par défaut et le plus prévisible.',
      ),
      GuideText(
        en: 'When enabled, a local rule-based classifier labels each request Heavy (coding, debugging, architecture or deep research) or Medium (everything else). OSIA then follows that category’s ordered provider:model chain.',
        fr: 'Lorsqu’il est actif, un classificateur local à base de règles classe chaque demande en Lourde (code, débogage, architecture ou recherche approfondie) ou Moyenne (le reste). OSIA suit alors la chaîne fournisseur:modèle correspondante.',
      ),
      GuideText(
        en: 'The manually selected model is appended as the final fallback if it is not already in the chain. OSIA advances only on a technical failure before output starts; it does not silently switch for normal content/client errors or replay text that has begun streaming.',
        fr: 'Le modèle choisi manuellement est ajouté en dernier secours s’il n’est pas déjà dans la chaîne. OSIA avance seulement après une erreur technique avant le début de la réponse ; il ne change pas pour une erreur de contenu et ne rejoue pas un texte déjà commencé.',
      ),
      GuideText(
        en: 'If the selected main model cannot process images, a separately configured vision companion may describe the image first. Local Ollama models can avoid a remote chat request when installed, but capability, speed and memory use depend on the PC and model.',
        fr: 'Si le modèle principal ne comprend pas les images, un modèle visuel séparé peut d’abord les décrire. Les modèles Ollama locaux peuvent éviter un appel de discussion distant s’ils sont installés, mais leurs capacités, vitesse et mémoire dépendent du PC et du modèle.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'Worked routing example',
      fr: 'Exemple de routage',
    ),
    example: GuideText(
      en: '“Refactor this Python module” is classified Heavy. OSIA tries the first Heavy model, then the next only after an eligible technical failure, and ends with the manually selected model. “Summarize these notes” normally follows the Medium chain.',
      fr: '« Refactorise ce module Python » est classé Lourd. OSIA essaie le premier modèle Lourd, puis le suivant seulement après une erreur technique admissible, et termine avec le modèle manuel. « Résume ces notes » suit normalement la chaîne Moyenne.',
    ),
    remember: GuideText(
      en: 'Manual selection is the default. Heavy/Medium routing is optional, ordered and failure-driven—not a hidden provider preference.',
      fr: 'La sélection manuelle est la règle. Le routage Lourd/Moyen est facultatif, ordonné et déclenché par les erreurs, sans préférence cachée.',
    ),
  ),
  GuideLesson(
    id: 'mastery.reasoning',
    categoryId: guideMasteryCategoryId,
    order: 6,
    subjectId: 'reasoning',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Thinking and reasoning',
      fr: 'Réflexion et raisonnement',
    ),
    introduction: GuideText(
      en: 'Reasoning levels trade speed for deeper model work on models that support them.',
      fr: 'Les niveaux de raisonnement échangent de la vitesse contre un travail plus approfondi sur les modèles compatibles.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'OSIA exposes Auto, Off, Low, Medium and High where supported. Higher settings can take longer and consume more quota; unsupported models ignore the control. Use lower levels for simple formatting and higher levels for difficult planning or diagnosis.',
        fr: 'OSIA propose Auto, Désactivé, Faible, Moyen et Élevé lorsque le modèle le permet. Un niveau supérieur peut être plus lent et consommer davantage de quota ; les modèles incompatibles ignorent ce réglage. Préférez un niveau faible pour le formatage et élevé pour un diagnostic complexe.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Compare the same safe prompt at Low and High before choosing a default.',
      fr: 'Comparez la même demande sans risque en Faible puis Élevé avant de choisir.',
    ),
    remember: GuideText(
      en: 'A higher level does not guarantee a correct answer; review important results.',
      fr: 'Un niveau supérieur ne garantit pas une réponse exacte ; vérifiez les résultats importants.',
    ),
  ),
  GuideLesson(
    id: 'mastery.keys-quotas-security',
    categoryId: guideMasteryCategoryId,
    order: 7,
    subjectId: 'keys-quotas-security',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Keys, quotas and security',
      fr: 'Clés, quotas et sécurité',
    ),
    introduction: GuideText(
      en: 'Provider keys are PC-owned secrets and must never be pasted into a conversation.',
      fr: 'Les clés de fournisseur sont des secrets gérés par le PC et ne doivent jamais être collées dans une conversation.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Add, replace or remove keys in Models. OSIA can rotate through configured backup keys for technical failures such as authentication, rate limits, timeouts or server errors, but not for a content error such as an invalid request. The paired mobile editor masks keys and handles edits only over the authenticated encrypted connection.',
        fr: 'Ajoutez, remplacez ou supprimez les clés dans Modèles. OSIA peut essayer des clés de secours lors d’erreurs techniques d’authentification, de quota, de délai ou de serveur, mais pas pour une requête invalide. L’éditeur mobile associé masque les clés et les traite uniquement sur la connexion chiffrée authentifiée.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'For a 401 error, verify provider and key; for a 429, inspect quota before retrying or adding an authorized backup key.',
      fr: 'Pour une erreur 401, vérifiez fournisseur et clé ; pour une 429, contrôlez le quota avant de réessayer ou d’ajouter une clé autorisée.',
    ),
    remember: GuideText(
      en: 'Treat phone access, screenshots and diagnostics as part of the secret boundary.',
      fr: 'Considérez l’accès au téléphone, les captures et les diagnostics comme faisant partie de la frontière des secrets.',
    ),
  ),
  GuideLesson(
    id: 'mastery.files-images',
    categoryId: guideMasteryCategoryId,
    order: 8,
    subjectId: 'files-images',
    glossaryIds: <String>[],
    title: GuideText(en: 'Files and images', fr: 'Fichiers et images'),
    introduction: GuideText(
      en: 'PC drafts and mobile batches let one turn combine text with one or more files.',
      fr: 'Les brouillons PC et les lots mobiles permettent de combiner texte et fichiers dans un seul tour.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'On PC, files remain staged until Send and can be removed individually; attachment-only turns are allowed. Mobile accepts up to ten files and 20 MiB for each file and the whole batch, validates every chunk and commits atomically. Images require both a provider and model with vision support; unsupported combinations fail clearly before the provider call.',
        fr: 'Sur PC, les fichiers restent en brouillon jusqu’à Envoyer et peuvent être retirés séparément ; un tour sans texte est permis. Le mobile accepte jusqu’à dix fichiers et 20 Mio par fichier et par lot, valide chaque fragment puis valide le lot atomiquement. Les images exigent un fournisseur et un modèle compatibles avec la vision.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Attach a screenshot with the question “Explain this visible error,” then verify that a compatible vision model is selected.',
      fr: 'Joignez une capture avec « Explique cette erreur visible », puis vérifiez qu’un modèle de vision compatible est sélectionné.',
    ),
    remember: GuideText(
      en: 'PC limits follow measured resources and provider policy; mobile has the explicit ten-file, 20 MiB aggregate policy.',
      fr: 'Les limites PC suivent les ressources mesurées et le fournisseur ; le mobile applique explicitement dix fichiers et 20 Mio au total.',
    ),
  ),
  GuideLesson(
    id: 'mastery.autonomous',
    categoryId: guideMasteryCategoryId,
    order: 9,
    subjectId: 'autonomous',
    glossaryIds: <String>[],
    title: GuideText(en: 'Autonomous mode', fr: 'Mode autonome'),
    introduction: GuideText(
      en: 'Autonomous mode is for a bounded multi-step mission, not a routine follow-up question.',
      fr: 'Le mode autonome sert à une mission bornée en plusieurs étapes, pas à une question de suivi ordinaire.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Describe the objective, choose its provider/model and monitor phases, tasks and confirmations. One machine-wide runner is allowed. Interrupt pauses a resumable checkpoint; Abandon ends it and removes that checkpoint. Plans and retries are bounded, and external writes still follow confirmation policy.',
        fr: 'Décrivez l’objectif, choisissez son fournisseur/modèle et surveillez phases, tâches et confirmations. Une seule mission globale peut tourner. Interrompre met en pause un point de reprise ; Abandonner termine la mission et le retire. Plans et tentatives sont bornés, et les écritures externes gardent leurs confirmations.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Use it to inspect a project, propose a plan and apply approved fixes; use normal chat to rephrase one paragraph.',
      fr: 'Utilisez-le pour inspecter un projet, proposer un plan et appliquer des corrections approuvées ; utilisez le chat pour reformuler un paragraphe.',
    ),
    remember: GuideText(
      en: 'Keep consequential work supervised and preserve backups.',
      fr: 'Surveillez les actions importantes et conservez des sauvegardes.',
    ),
  ),
  GuideLesson(
    id: 'advanced.personality-skills-automation',
    categoryId: guideMasteryCategoryId,
    order: 10,
    subjectId: 'scheduled-tasks',
    glossaryIds: <String>[],
    title: GuideText(en: 'Scheduled tasks', fr: 'Tâches planifiées'),
    introduction: GuideText(
      en: 'Personality changes how OSIA communicates; skills add reusable instructions; tools perform supported work; automations schedule requests.',
      fr: 'La personnalité change la façon de communiquer d’OSIA ; les compétences ajoutent des instructions réutilisables ; les outils effectuent le travail pris en charge ; les automatisations planifient des demandes.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The OSIA page edits a local personality document that is added to the assistant instructions. Example: ask for concise explanations and a calm tone. Personality changes style, not permissions or factual capability.',
        fr: 'La page OSIA modifie un document local de personnalité ajouté aux instructions de l’assistant. Exemple : demander des explications concises et un ton calme. La personnalité change le style, pas les autorisations ni les capacités réelles.',
      ),
      GuideText(
        en: 'Skills are local Markdown instruction files that can be created, edited, enabled or disabled. Example: a meeting-notes skill can define your preferred headings. A skill guides the model; it does not create a missing integration or bypass safety checks.',
        fr: 'Les compétences sont des fichiers d’instructions Markdown locaux pouvant être créés, modifiés, activés ou désactivés. Exemple : une compétence de compte rendu peut définir vos titres préférés. Elle guide le modèle sans créer une intégration absente ni contourner la sécurité.',
      ),
      GuideText(
        en: 'Tools are the actual supported operations OSIA may call, including PC tools and configured MCP connectors. External write actions may require confirmation; unattended connector writes are a separate advanced safety choice and are off by default.',
        fr: 'Les outils sont les opérations réellement prises en charge, y compris les outils PC et les connecteurs MCP configurés. Les écritures externes peuvent demander confirmation ; les écritures sans surveillance sont un choix de sécurité avancé, désactivé par défaut.',
      ),
      GuideText(
        en: 'Settings → Advanced can schedule repeated or one-time tasks and optionally bind a conversation/model. The PC process must be running when a task is due. Heartbeat monitoring can report selected PC health thresholds; it is monitoring, not automatic repair.',
        fr: 'Réglages → Avancé peut planifier des tâches répétées ou ponctuelles et leur associer une conversation/un modèle. Le processus PC doit fonctionner à l’heure prévue. La surveillance peut signaler certains seuils du PC ; elle ne répare pas automatiquement.',
      ),
    ],
    exampleTitle: GuideText(en: 'Safe examples', fr: 'Exemples sûrs'),
    example: GuideText(
      en: 'Personality: “Explain unfamiliar terms before using them.”\nSkill: a reusable weekly-review format.\nTool: read a named local file and summarize it.\nAutomation: every weekday at 17:00, prepare a review in a chosen conversation—only while OSIA is running.',
      fr: 'Personnalité : « Explique les termes inconnus avant de les utiliser. »\nCompétence : un format réutilisable de bilan hebdomadaire.\nOutil : lire un fichier local nommé et le résumer.\nAutomatisation : chaque semaine à 17 h, préparer un bilan dans une conversation choisie—seulement si OSIA fonctionne.',
    ),
    remember: GuideText(
      en: 'Instructions shape behavior; tools provide capability; schedules trigger work. None should be treated as permission to ignore confirmations or review.',
      fr: 'Les instructions façonnent le comportement ; les outils donnent la capacité ; les horaires déclenchent le travail. Aucun ne remplace les confirmations ni la vérification.',
    ),
  ),
  GuideLesson(
    id: 'mastery.connectors',
    categoryId: guideMasteryCategoryId,
    order: 11,
    subjectId: 'connectors',
    glossaryIds: <String>[],
    title: GuideText(en: 'MCP and connectors', fr: 'MCP et connecteurs'),
    introduction: GuideText(
      en: 'A connector adds tools from another service; a catalog entry is not the same as a connected service.',
      fr: 'Un connecteur ajoute les outils d’un autre service ; une entrée de catalogue n’est pas un service connecté.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Connectors may use OAuth, a bearer token, local stdio or remote HTTP according to their catalog entry. Connected tools are namespaced and may request confirmation before writes; unattended connector writes are denied by default. Mobile mirrors status and confirmations, while unavailable catalog entries remain clearly unavailable.',
        fr: 'Selon le catalogue, un connecteur utilise OAuth, un jeton, stdio local ou HTTP distant. Les outils connectés sont nommés séparément et peuvent demander confirmation avant une écriture ; les écritures sans surveillance sont refusées par défaut. Le mobile reflète états et confirmations.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Connect one supported service, inspect the tools it adds, then begin with a read-only request.',
      fr: 'Connectez un service pris en charge, examinez les outils ajoutés, puis commencez par une lecture seule.',
    ),
    remember: GuideText(
      en: 'Never assume a visible catalog card is currently connectable.',
      fr: 'Ne supposez jamais qu’une carte visible du catalogue est actuellement connectable.',
    ),
  ),
  GuideLesson(
    id: 'advanced.memory-conversations',
    categoryId: guideMasteryCategoryId,
    order: 12,
    subjectId: 'memory-context',
    glossaryIds: <String>[],
    title: GuideText(en: 'Memory and context', fr: 'Mémoire et contexte'),
    introduction: GuideText(
      en: 'Conversation history and persistent memory are related, but they are not the same thing.',
      fr: 'L’historique des conversations et la mémoire persistante sont liés, mais différents.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The current conversation is the active sequence of messages. Saved conversations are local history files that you can reopen from Conversations so OSIA receives the relevant prior messages again.',
        fr: 'La conversation actuelle est la suite active de messages. Les conversations enregistrées sont des historiques locaux que vous pouvez rouvrir depuis Conversations afin qu’OSIA retrouve les messages précédents utiles.',
      ),
      GuideText(
        en: 'Persistent memory is a separate local store for verified facts, preferences, routes, contacts, shortcuts or workflows. Relevant entries may be added to a future request even when you open another conversation.',
        fr: 'La mémoire persistante est un stockage local séparé pour des faits, préférences, routes, contacts, raccourcis ou méthodes vérifiés. Les éléments pertinents peuvent être ajoutés à une demande future, même dans une autre conversation.',
      ),
      GuideText(
        en: 'Settings → Memory lets you review, edit, delete individual entries or clear all memory. Conversation controls manage saved chats separately. OSIA’s memory store rejects common secret/token patterns, but you should still never ask it to remember passwords, API keys or pairing tokens.',
        fr: 'Réglages → Mémoire permet de consulter, modifier, supprimer une entrée ou tout effacer. Les commandes Conversations gèrent les discussions séparément. La mémoire refuse des formes courantes de secrets, mais ne demandez jamais à OSIA de mémoriser mots de passe, clés API ou jetons d’association.',
      ),
      GuideText(
        en: 'Both stores are on the PC profile, so anyone with access to that profile may be able to read them. Delete sensitive history or memory you no longer need and protect the computer account.',
        fr: 'Les deux stockages se trouvent dans le profil PC ; une personne ayant accès à ce profil pourrait les lire. Supprimez les historiques ou souvenirs sensibles devenus inutiles et protégez le compte de l’ordinateur.',
      ),
    ],
    exampleTitle: GuideText(en: 'The difference', fr: 'La différence'),
    example: GuideText(
      en: 'Conversation: “Yesterday we compared two travel plans” stays with that saved chat.\nMemory: “I prefer morning appointments” may be relevant across future chats until you edit or delete it.',
      fr: 'Conversation : « Hier, nous avons comparé deux voyages » reste dans cette discussion enregistrée.\nMémoire : « Je préfère les rendez-vous le matin » peut servir dans de futures discussions jusqu’à modification ou suppression.',
    ),
    remember: GuideText(
      en: 'Conversations preserve chats; memory preserves selected reusable facts. Review and delete them through their separate controls.',
      fr: 'Les conversations conservent les discussions ; la mémoire conserve certains faits réutilisables. Gérez-les avec leurs commandes distinctes.',
    ),
  ),
  GuideLesson(
    id: 'mastery.computer-use',
    categoryId: guideMasteryCategoryId,
    order: 13,
    subjectId: 'tools-computer-control',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Tools and computer control',
      fr: 'Outils et contrôle de l’ordinateur',
    ),
    introduction: GuideText(
      en: 'OSIA prefers deterministic integrations before visual guesses when it operates the computer.',
      fr: 'OSIA préfère les intégrations déterministes aux suppositions visuelles lorsqu’il agit sur l’ordinateur.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'It can use deep links, command-line tools, browser structure, Windows UI Automation and keyboard input, then fall back to screenshots and vision. Coordinates can be uncertain when layouts move. Confirm sensitive actions, state the target precisely and verify the resulting window, file or page.',
        fr: 'Il peut utiliser liens profonds, ligne de commande, structure du navigateur, UI Automation Windows et clavier, puis se replier sur captures et vision. Les coordonnées deviennent incertaines si la mise en page bouge. Confirmez les actions sensibles et vérifiez fenêtre, fichier ou page obtenus.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Ask OSIA to open a named settings page and report what it sees before requesting a change.',
      fr: 'Demandez à OSIA d’ouvrir une page de réglages nommée et de décrire son état avant une modification.',
    ),
    remember: GuideText(
      en: 'Do not delegate irreversible actions without a review point.',
      fr: 'Ne déléguez pas d’action irréversible sans point de contrôle.',
    ),
  ),
  GuideLesson(
    id: 'advanced.voice-tts-stt',
    categoryId: guideMasteryCategoryId,
    order: 14,
    subjectId: 'voice',
    glossaryIds: <String>[],
    title: GuideText(en: 'Voice', fr: 'Voix'),
    introduction: GuideText(
      en: 'TTS means OSIA turns text into spoken audio. STT means OSIA turns your microphone audio into text.',
      fr: 'TTS signifie qu’OSIA transforme du texte en voix. STT signifie qu’OSIA transforme le son du microphone en texte.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'In Settings → Voice, TTS can use local Kokoro (offline by default), OpenAI, or Google. Cloud voices require the matching provider key and a network; if cloud synthesis fails, normal PC speech falls back to local Kokoro.',
        fr: 'Dans Réglages → Voix, le TTS peut utiliser Kokoro local (hors ligne par défaut), OpenAI ou Google. Les voix cloud demandent la clé correspondante et un réseau ; en cas d’échec, la parole normale du PC revient à Kokoro local.',
      ),
      GuideText(
        en: 'STT can use local faster-whisper or hosted Groq Whisper. Local offers installed Small/Medium models; Groq offers its hosted Whisper models and requires a Groq key. You can select local, Groq or no fallback when the primary transcription fails.',
        fr: 'Le STT peut utiliser faster-whisper local ou Whisper hébergé par Groq. Le mode local propose les modèles Small/Medium installés ; Groq propose ses modèles hébergés et demande une clé Groq. Le secours peut être local, Groq ou aucun.',
      ),
      GuideText(
        en: 'Allow microphone access in the operating system. If OSIA hears nothing, check the default input device and privacy permission. If words are wrong, reduce background noise, speak closer to the microphone, or try the other STT engine/model.',
        fr: 'Autorisez le microphone dans le système. Si OSIA n’entend rien, vérifiez le périphérique d’entrée et l’autorisation de confidentialité. Si la transcription est mauvaise, réduisez le bruit, rapprochez-vous du micro ou essayez l’autre moteur/modèle STT.',
      ),
      GuideText(
        en: 'Local TTS/STT keeps synthesis or transcription on the PC after models are installed. Cloud choices send the required text or audio to that provider under its service terms.',
        fr: 'Le TTS/STT local conserve la synthèse ou la transcription sur le PC une fois les modèles installés. Les choix cloud envoient le texte ou l’audio nécessaire au fournisseur selon ses conditions.',
      ),
    ],
    exampleTitle: GuideText(en: 'Troubleshooting path', fr: 'Dépannage simple'),
    example: GuideText(
      en: 'No transcription → check microphone permission → check the selected STT model is installed/keyed → try the configured fallback.\nNo spoken answer → check volume/output → test local Kokoro → verify the selected cloud key if applicable.',
      fr: 'Pas de transcription → vérifier l’autorisation du micro → vérifier le modèle STT ou la clé → essayer le secours configuré.\nPas de réponse parlée → vérifier le volume et la sortie → tester Kokoro local → vérifier la clé cloud choisie si nécessaire.',
    ),
    remember: GuideText(
      en: 'TTS speaks; STT listens. Local choices favor offline processing, while cloud choices need a key and network.',
      fr: 'Le TTS parle ; le STT écoute. Le local privilégie le traitement hors ligne ; le cloud demande une clé et un réseau.',
    ),
  ),
  GuideLesson(
    id: 'advanced.pc-mobile-connection',
    categoryId: guideMasteryCategoryId,
    order: 15,
    subjectId: 'pairing-connection',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Pairing and connection',
      fr: 'Association et connexion',
    ),
    introduction: GuideText(
      en: 'Pairing creates trust; transports are simply the different roads the phone can use to reach the same OSIA server on your PC.',
      fr: 'L’association crée la confiance ; les transports sont simplement les différentes routes permettant au téléphone d’atteindre le même serveur OSIA sur votre PC.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The token is the shared pairing secret. From it, PC and phone derive proofs and fresh encryption keys. The public relay routes encrypted data and does not receive the raw token.',
        fr: 'Le jeton est le secret d’association partagé. Le PC et le téléphone en dérivent des preuves et de nouvelles clés de chiffrement. Le relais public achemine des données chiffrées sans recevoir le jeton brut.',
      ),
      GuideText(
        en: 'Connection order is direct-first: (1) try an already provisioned private-LAN WSS connection; (2) open the end-to-end encrypted relay in standby; (3) retry newly provisioned LAN; (4) try data-only WebRTC/P2P with encrypted signaling through the relay; (5) explicitly commit the encrypted relay fallback.',
        fr: 'L’ordre privilégie le direct : (1) essayer une connexion WSS déjà configurée sur le réseau local privé ; (2) ouvrir le relais chiffré de bout en bout en attente ; (3) réessayer le réseau local nouvellement configuré ; (4) essayer WebRTC/P2P pour les données, avec signalisation chiffrée par le relais ; (5) activer explicitement le relais chiffré en secours.',
      ),
      GuideText(
        en: 'Only one road may carry application traffic at a time. After sleep or a network change, reconnect attempts are coalesced. OSIA does not switch roads during an active request because replaying part of a response could duplicate work.',
        fr: 'Une seule route transporte les données de l’application à la fois. Après une veille ou un changement de réseau, les reconnexions sont regroupées. OSIA ne change pas de route pendant une demande active afin d’éviter de dupliquer une partie du travail.',
      ),
      GuideText(
        en: 'The older direct host/rendezvous WebSocket route is a gated legacy fallback and is disabled by default. If the PC is off, asleep without a working server, disconnected, or unable to reach any usable transport, the phone cannot run OSIA tasks.',
        fr: 'L’ancienne route WebSocket directe par hôte/rendez-vous est un secours historique conditionnel, désactivé par défaut. Si le PC est éteint, en veille sans serveur actif, déconnecté ou sans transport utilisable, le téléphone ne peut pas exécuter de tâches OSIA.',
      ),
    ],
    exampleTitle: GuideText(en: 'Worked example', fr: 'Exemple concret'),
    example: GuideText(
      en: 'At home, the phone may connect over the authenticated private LAN. Away from home, WebRTC may establish a direct path; if it cannot, the end-to-end encrypted relay carries the conversation. The OSIA task still runs on the PC.',
      fr: 'À la maison, le téléphone peut utiliser le réseau local privé authentifié. À distance, WebRTC peut créer une route directe ; sinon, le relais chiffré de bout en bout transporte la conversation. La tâche OSIA s’exécute toujours sur le PC.',
    ),
    remember: GuideText(
      en: 'LAN → relay standby → provisioned LAN retry → WebRTC → committed relay. One authenticated application transport owns the bridge at a time.',
      fr: 'LAN → relais en attente → nouvel essai LAN → WebRTC → relais activé. Un seul transport authentifié contrôle la connexion à la fois.',
    ),
  ),
  GuideLesson(
    id: 'mastery.notifications-background',
    categoryId: guideMasteryCategoryId,
    order: 16,
    subjectId: 'notifications-background',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Notifications and background behavior',
      fr: 'Notifications et arrière-plan',
    ),
    introduction: GuideText(
      en: 'Notifications report results; they do not keep an unavailable PC executing work.',
      fr: 'Les notifications signalent des résultats ; elles ne font pas travailler un PC indisponible.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'PC notifications and Android local notifications are best effort and depend on system permissions. The Android foreground service can improve continuity but remains subject to Android power rules. Scheduled and autonomous work still needs OSIA running; after sleep or a network change, reopen the app and allow one clean reconnect.',
        fr: 'Les notifications PC et Android sont fournies au mieux et dépendent des autorisations système. Le service Android au premier plan améliore la continuité mais reste soumis aux règles d’énergie. Les tâches ont toujours besoin d’OSIA actif ; après veille ou changement réseau, rouvrez l’app et laissez une reconnexion propre.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'If a task completed without an alert, check its in-app result before changing the schedule.',
      fr: 'Si une tâche s’est terminée sans alerte, consultez son résultat dans l’app avant de modifier l’horaire.',
    ),
    remember: GuideText(
      en: 'Notification permission and execution availability are separate concerns.',
      fr: 'L’autorisation de notification et la disponibilité d’exécution sont deux sujets distincts.',
    ),
  ),
  GuideLesson(
    id: 'mastery.settings-tour',
    categoryId: guideMasteryCategoryId,
    order: 17,
    subjectId: 'settings-tour',
    glossaryIds: <String>[],
    title: GuideText(en: 'Settings tour', fr: 'Visite des réglages'),
    introduction: GuideText(
      en: 'Settings groups the controls that shape OSIA without changing conversation history.',
      fr: 'Les Réglages regroupent les contrôles qui configurent OSIA sans modifier l’historique des conversations.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'General covers language, appearance, capsule, startup and this guide. Models covers accounts, API keys, models, reasoning and hierarchies. Voice and Wake word configure audio. Memory reviews durable facts. MCP / Connectors manages integrations. Connection / Mobile manages pairing and server startup. Advanced contains schedules and PC health; Updates and Legal show release and policy information.',
        fr: 'Général couvre langue, apparence, capsule, démarrage et ce guide. Modèles couvre comptes, clés API, modèles, raisonnement et hiérarchies. Voix et Mot d’activation règlent l’audio. Mémoire examine les faits durables. MCP / Connecteurs gère les intégrations. Connexion / Mobile gère association et serveur. Avancé contient horaires et santé du PC ; Mises à jour et Légal affichent versions et règles.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'After changing a model or voice, run a short harmless test before starting important work.',
      fr: 'Après un changement de modèle ou de voix, lancez un essai court et sans risque.',
    ),
    remember: GuideText(
      en: 'Security-related toggles change permission boundaries; read their descriptions first.',
      fr: 'Les réglages de sécurité modifient les limites d’autorisation ; lisez leur description.',
    ),
  ),
  GuideLesson(
    id: 'advanced.updates-safety',
    categoryId: guideMasteryCategoryId,
    order: 18,
    subjectId: 'updates',
    glossaryIds: <String>[],
    title: GuideText(en: 'Updates', fr: 'Mises à jour'),
    introduction: GuideText(
      en: 'OSIA checks for available versions and presents changes in the dedicated Settings → Updates page.',
      fr: 'OSIA recherche les versions disponibles et présente les changements dans Réglages → Mises à jour.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Update detection runs automatically on its schedule and can also be requested from the page. When an update is available, OSIA shows the installed/available versions and embedded release notes before installation.',
        fr: 'La détection s’exécute automatiquement selon son calendrier et peut aussi être demandée depuis la page. Lorsqu’une version existe, OSIA affiche les versions installée/disponible et les notes intégrées avant installation.',
      ),
      GuideText(
        en: 'The Windows updater downloads the package, verifies the published metadata and package integrity, starts the installer, preserves the user profile, and uses a rollback path if replacing the application fails. Do not interrupt the installer or delete its working files.',
        fr: 'Sous Windows, le programme télécharge le paquet, vérifie les métadonnées publiées et son intégrité, lance l’installation, préserve le profil utilisateur et prévoit un retour arrière si le remplacement échoue. N’interrompez pas l’installation et ne supprimez pas ses fichiers temporaires.',
      ),
      GuideText(
        en: 'Unsigned internal or preview builds can trigger a Windows warning because the operating system cannot verify a trusted publisher signature. Only continue when you intentionally obtained that exact build from a trusted OSIA source.',
        fr: 'Les versions internes ou d’aperçu non signées peuvent déclencher un avertissement Windows, car l’éditeur n’est pas vérifiable. Continuez uniquement si vous avez obtenu volontairement cette version précise depuis une source OSIA fiable.',
      ),
      GuideText(
        en: 'Never share API keys, account codes, pairing tokens, OAuth data, diagnostic logs containing secrets, certificates or screenshots with private fields revealed. Regenerate a secret if it may have escaped.',
        fr: 'Ne partagez jamais clés API, codes de compte, jetons d’association, données OAuth, journaux contenant des secrets, certificats ou captures avec champs privés visibles. Régénérez tout secret potentiellement divulgué.',
      ),
    ],
    exampleTitle: GuideText(
      en: 'Before updating or asking for help',
      fr: 'Avant une mise à jour ou une demande d’aide',
    ),
    example: GuideText(
      en: 'Read the release notes → confirm the source/version → close important work → install → verify OSIA starts and your profile remains. For support, reproduce with sanitized details and mask every secret first.',
      fr: 'Lire les notes → confirmer source et version → fermer les travaux importants → installer → vérifier le démarrage et le profil. Pour l’assistance, reproduire avec des détails assainis et masquer d’abord chaque secret.',
    ),
    remember: GuideText(
      en: 'The updater protects package integrity and profile data, but you still control when to install and what private diagnostics to share.',
      fr: 'Le programme protège l’intégrité du paquet et le profil, mais vous contrôlez le moment de l’installation et les diagnostics privés partagés.',
    ),
  ),
  GuideLesson(
    id: 'mastery.troubleshooting',
    categoryId: guideMasteryCategoryId,
    order: 19,
    subjectId: 'troubleshooting',
    glossaryIds: <String>[],
    title: GuideText(en: 'Troubleshooting', fr: 'Dépannage'),
    introduction: GuideText(
      en: 'Diagnose the layer that failed before changing several settings at once.',
      fr: 'Identifiez la couche en échec avant de modifier plusieurs réglages à la fois.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'For keys or quota, inspect provider status and the selected model. For images, verify vision support and provider limits. For mobile, check the PC, pairing and one clean reconnect. For voice or notifications, check permissions and devices. For schedules, confirm the PC was running at the due time. For MCP or updates, verify connection status and availability.',
        fr: 'Pour clé ou quota, vérifiez le fournisseur et le modèle. Pour une image, contrôlez vision et limites. Pour le mobile, vérifiez PC, association et reconnexion. Pour voix ou notifications, contrôlez autorisations et appareils. Pour une tâche, confirmez que le PC tournait à l’heure prévue. Pour MCP ou mise à jour, vérifiez connexion et disponibilité.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Reproduce with one short request and record the sanitized error category, not secrets or full private logs.',
      fr: 'Reproduisez avec une demande courte et notez la catégorie d’erreur assainie, jamais les secrets ni des journaux privés complets.',
    ),
    remember: GuideText(
      en: 'One precise observation is more useful than repeated blind retries.',
      fr: 'Une observation précise vaut mieux que des tentatives répétées à l’aveugle.',
    ),
  ),
  GuideLesson(
    id: 'advanced.usage-examples',
    categoryId: guideMasteryCategoryId,
    order: 20,
    subjectId: 'practical-workflows',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Practical workflows',
      fr: 'Flux de travail pratiques',
    ),
    introduction: GuideText(
      en: 'Advanced use is mainly about giving OSIA a clear sequence, choosing the right connection/model, and checking results at the right moments.',
      fr: 'L’utilisation avancée consiste surtout à donner une séquence claire, choisir la bonne connexion ou le bon modèle et vérifier les résultats au bon moment.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Multi-step work: “Read these three notes, list disagreements, propose one plan, then stop before creating any external event.” This gives OSIA an order and a safety boundary.',
        fr: 'Travail en plusieurs étapes : « Lis ces trois notes, liste les désaccords, propose un plan, puis arrête-toi avant de créer un événement externe. » La séquence et la limite sont explicites.',
      ),
      GuideText(
        en: 'PC and mobile: start a document summary on the PC, reopen the same conversation on the phone, and ask for a shorter checklist. Voice: dictate the goal, then review names and dates in the written transcript before requesting an action.',
        fr: 'PC et mobile : commencez un résumé sur le PC, rouvrez la même conversation sur le téléphone et demandez une liste plus courte. Voix : dictez le but, puis vérifiez noms et dates dans la transcription avant une action.',
      ),
      GuideText(
        en: 'Models: use manual selection for predictable tests; enable Heavy/Medium chains only when you want automatic routing and have configured each entry. Compare quality, latency and provider usage with the same harmless prompt.',
        fr: 'Modèles : utilisez la sélection manuelle pour des tests prévisibles ; activez les chaînes Lourde/Moyenne seulement après avoir configuré chaque entrée. Comparez qualité, délai et utilisation avec la même demande sans risque.',
      ),
      GuideText(
        en: 'Troubleshooting: provider failure → verify selected provider/model, key and account limits; mobile failure → verify PC/server is running, token matches and network is available; memory surprise → review the Memory page and edit/delete the entry rather than correcting it repeatedly in chat.',
        fr: 'Dépannage : échec fournisseur → vérifier fournisseur/modèle, clé et limites du compte ; échec mobile → vérifier PC/serveur, jeton et réseau ; mémoire inattendue → consulter la page Mémoire et modifier/supprimer l’entrée plutôt que la corriger à chaque discussion.',
      ),
    ],
    exampleTitle: GuideText(en: 'One complete workflow', fr: 'Un flux complet'),
    example: GuideText(
      en: '1. On PC, ask OSIA to analyze a local error log without changing files.\n2. Review its diagnosis and choose one proposed fix.\n3. Continue from mobile and ask for a concise execution checklist.\n4. Return to PC for any tool action and verify the final diff/output.',
      fr: '1. Sur le PC, demander l’analyse d’un journal d’erreurs sans modifier de fichier.\n2. Vérifier le diagnostic et choisir une correction proposée.\n3. Continuer sur mobile et demander une liste d’exécution concise.\n4. Revenir au PC pour toute action d’outil et vérifier le résultat final.',
    ),
    remember: GuideText(
      en: 'Break work into stages, preserve context in the conversation, and place a review point before consequential actions.',
      fr: 'Découpez le travail, conservez le contexte dans la conversation et prévoyez une vérification avant les actions importantes.',
    ),
  ),
  GuideLesson(
    id: 'advanced.product-architecture',
    categoryId: guideAdvancedCategoryId,
    order: 1,
    subjectId: 'product-architecture',
    glossaryIds: <String>['provider', 'model', 'api'],
    title: GuideText(en: 'Product architecture', fr: 'Architecture du produit'),
    introduction: GuideText(
      en: 'OSIA is a PC-first assistant with a mobile control surface and pluggable AI providers.',
      fr: 'OSIA est un assistant centré sur le PC, avec une surface mobile et des fournisseurs d’IA interchangeables.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Execution, durable state and tools stay on the PC. The mobile is a second screen, networking prefers direct authenticated paths, provider adapters isolate external APIs, and the agent invokes only registered tools under confirmation policy.',
        fr: 'L’exécution, l’état durable et les outils restent sur le PC. Le mobile est un second écran, le réseau préfère les chemins directs authentifiés, les adaptateurs isolent les API externes et l’agent n’appelle que les outils enregistrés selon la politique de confirmation.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Trace any feature through UI, PC state owner, transport, agent/provider and terminal result.',
      fr: 'Suivez toute fonction à travers interface, propriétaire PC, transport, agent/fournisseur et résultat final.',
    ),
    remember: GuideText(
      en: 'Local-first describes ownership, not a promise that configured cloud providers receive no data.',
      fr: 'Local-first décrit la propriété, pas la promesse qu’aucun fournisseur cloud configuré ne reçoit de données.',
    ),
  ),
  GuideLesson(
    id: 'advanced.repository-topology',
    categoryId: guideAdvancedCategoryId,
    order: 2,
    subjectId: 'repository-topology',
    glossaryIds: <String>[],
    title: GuideText(en: 'Repository topology', fr: 'Topologie des dépôts'),
    introduction: GuideText(
      en: 'Four independently versioned repositories divide product responsibilities.',
      fr: 'Quatre dépôts versionnés indépendamment répartissent les responsabilités du produit.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'osia contains the cross-platform PC application; osia-mobile contains Flutter clients; osia-worker contains rendezvous and relay Workers; osia-site contains the public static site and release metadata presentation. Coordinated changes must audit each repository without assuming a shared release number.',
        fr: 'osia contient l’application PC multiplateforme ; osia-mobile les clients Flutter ; osia-worker les Workers de rendez-vous et relais ; osia-site le site statique public et la présentation des métadonnées. Une modification coordonnée audite chaque dépôt sans supposer un numéro commun.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'A transport change normally needs PC, mobile and Worker compatibility review, while a guide-only site explanation may remain read-only.',
      fr: 'Un changement de transport exige normalement une revue PC, mobile et Worker, tandis qu’une explication de guide peut laisser le site en lecture seule.',
    ),
    remember: GuideText(
      en: 'Record each repository HEAD and divergence separately.',
      fr: 'Consignez séparément le HEAD et la divergence de chaque dépôt.',
    ),
  ),
  GuideLesson(
    id: 'advanced.pc-architecture',
    categoryId: guideAdvancedCategoryId,
    order: 3,
    subjectId: 'pc-architecture',
    glossaryIds: <String>['api', 'provider', 'model'],
    title: GuideText(en: 'PC architecture', fr: 'Architecture PC'),
    introduction: GuideText(
      en: 'The PC application combines a Qt interface with local services and an agent runtime.',
      fr: 'L’application PC combine une interface Qt, des services locaux et un agent.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Key modules include osia/gui for Qt, main.py for startup, agent.py for turns, conversation storage, models.py and provider adapters, attachments.py and desktop_attachments.py, vision routing, mcp_client, cron.py, memory.py, LAN/relay/WebRTC modules, updater modules and packaging/windows. Protected parsing and transport contracts require targeted changes only.',
        fr: 'Les modules clés comprennent osia/gui pour Qt, main.py pour le démarrage, agent.py pour les tours, le stockage des conversations, models.py et les adaptateurs, attachments.py et desktop_attachments.py, la vision, mcp_client, cron.py, memory.py, LAN/relais/WebRTC, la mise à jour et packaging/windows. Les contrats protégés exigent des changements ciblés.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'When a GUI action changes state, find its signal, service call, persistence file and every caller before editing.',
      fr: 'Quand une action GUI change l’état, trouvez son signal, l’appel de service, le fichier persistant et tous les appelants avant modification.',
    ),
    remember: GuideText(
      en: 'Module names are navigation aids, not permission to refactor adjacent code.',
      fr: 'Les noms de modules aident à naviguer ; ils n’autorisent pas un refactoring voisin.',
    ),
  ),
  GuideLesson(
    id: 'advanced.mobile-architecture',
    categoryId: guideAdvancedCategoryId,
    order: 4,
    subjectId: 'mobile-architecture',
    glossaryIds: <String>['websocket'],
    title: GuideText(en: 'Mobile architecture', fr: 'Architecture mobile'),
    introduction: GuideText(
      en: 'The Flutter application renders screens while services mirror PC-owned state and select one transport.',
      fr: 'L’application Flutter affiche les écrans tandis que les services reflètent l’état du PC et choisissent un transport.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'lib/screens holds user surfaces; WebSocketService is the message facade; transport, LAN, WebRTC and relay services coordinate connectivity; storage keeps pairing and interface preferences; lifecycle, foreground service and notifications handle platform constraints. Android and iOS projects provide native shells, but the mobile is not the conversation source of truth.',
        fr: 'lib/screens contient les surfaces ; WebSocketService est la façade de messages ; les services transport, LAN, WebRTC et relais coordonnent la connexion ; le stockage garde association et préférences ; cycle de vie, service au premier plan et notifications gèrent les contraintes. Android et iOS sont des coques, pas la source des conversations.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Follow a mobile button from screen callback to service frame and PC acknowledgement.',
      fr: 'Suivez un bouton mobile depuis le rappel d’écran jusqu’à la trame de service et l’accusé PC.',
    ),
    remember: GuideText(
      en: 'A locally cached selection is not automatically authoritative PC configuration.',
      fr: 'Une sélection en cache local n’est pas automatiquement la configuration PC autoritaire.',
    ),
  ),
  GuideLesson(
    id: 'advanced.worker-architecture',
    categoryId: guideAdvancedCategoryId,
    order: 5,
    subjectId: 'worker-architecture',
    glossaryIds: <String>[
      'websocket',
      'e2e',
      'durable-object',
      'hibernation',
      'relay',
    ],
    title: GuideText(en: 'Worker architecture', fr: 'Architecture Worker'),
    introduction: GuideText(
      en: 'Cloudflare Workers provide rendezvous and an E2E-blind WebSocket relay.',
      fr: 'Les Cloudflare Workers fournissent le rendez-vous et un relais WebSocket aveugle au contenu E2E.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The rendezvous Worker maps a derived key to the PC route and relays OAuth callbacks. The relay uses one Durable Object per pair, role-authoritative URLs, WebSocket hibernation, sequence and size guards, priority-aware backpressure and generation replacement. It sees routing metadata and ciphertext, not decrypted conversations, tools, files or audio.',
        fr: 'Le Worker de rendez-vous associe une clé dérivée à la route PC et relaie les retours OAuth. Le relais utilise un Durable Object par paire, des URL autoritaires par rôle, l’hibernation WebSocket, des gardes de séquence/taille, une pression selon priorité et le remplacement de génération. Il voit métadonnées et chiffré, pas le contenu.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Inspect relay policy and endpoint crypto together before changing an envelope field.',
      fr: 'Examinez ensemble politique du relais et crypto des extrémités avant de changer une enveloppe.',
    ),
    remember: GuideText(
      en: 'Worker routing authority must never become decryption authority.',
      fr: 'L’autorité de routage du Worker ne doit jamais devenir une autorité de déchiffrement.',
    ),
  ),
  GuideLesson(
    id: 'advanced.message-flow',
    categoryId: guideAdvancedCategoryId,
    order: 6,
    subjectId: 'message-flow',
    glossaryIds: <String>['context', 'provider', 'model'],
    title: GuideText(
      en: 'End-to-end message flow',
      fr: 'Flux de message de bout en bout',
    ),
    introduction: GuideText(
      en: 'A user request is correlated from its conversation through one terminal result.',
      fr: 'Une demande utilisateur est corrélée depuis sa conversation jusqu’à un résultat final unique.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The UI assigns conversation and request identity, attachments prepare before commit, the PC locks the turn, selects provider/model, assembles context and runs the agent. Tool progress and streamed text carry correlation back to PC and mobile; completion, failure or cancellation seals the turn and releases the lock.',
        fr: 'L’interface attribue conversation et requête, les pièces jointes se préparent avant validation, le PC verrouille le tour, choisit fournisseur/modèle, assemble le contexte et lance l’agent. Progression et texte diffusé reviennent corrélés ; fin, échec ou annulation scellent le tour et libèrent le verrou.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Draw the flow as input → attachment commit → active turn → provider/tools → stream → terminal event.',
      fr: 'Dessinez le flux : entrée → validation des pièces jointes → tour actif → fournisseur/outils → flux → événement final.',
    ),
    remember: GuideText(
      en: 'Never replay a prior answer as success after an attachment or provider failure.',
      fr: 'Ne rejouez jamais une ancienne réponse comme succès après un échec de fichier ou de fournisseur.',
    ),
  ),
  GuideLesson(
    id: 'advanced.pairing-protocol',
    categoryId: guideAdvancedCategoryId,
    order: 7,
    subjectId: 'pairing-protocol',
    glossaryIds: <String>['token', 'hash', 'e2e'],
    title: GuideText(en: 'Pairing protocol', fr: 'Protocole d’association'),
    introduction: GuideText(
      en: 'Temporary pairing material establishes trust without publishing the raw secret.',
      fr: 'Le matériel temporaire d’association établit la confiance sans publier le secret brut.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'PC and mobile derive a pair identifier and proofs, assert authoritative roles and confirm fresh cryptographic context. Expired or mismatched material fails closed; regenerating the PC token replaces trust and requires pairing again. Reconnect creates a new session or generation rather than accepting stale identity.',
        fr: 'PC et mobile dérivent un identifiant de paire et des preuves, affirment leurs rôles et confirment un contexte cryptographique neuf. Un matériel expiré ou incohérent échoue fermé ; régénérer le jeton remplace la confiance. La reconnexion crée une session ou génération neuve.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Test correct, wrong, expired and replaced pairing paths without logging the secret.',
      fr: 'Testez les chemins correct, erroné, expiré et remplacé sans journaliser le secret.',
    ),
    remember: GuideText(
      en: 'A token is secret input; its derived identifiers are still sensitive metadata.',
      fr: 'Un jeton est une entrée secrète ; ses identifiants dérivés restent des métadonnées sensibles.',
    ),
  ),
  GuideLesson(
    id: 'advanced.transport-overview',
    categoryId: guideAdvancedCategoryId,
    order: 8,
    subjectId: 'transport-overview',
    glossaryIds: <String>['lan', 'websocket', 'webrtc', 'p2p', 'relay', 'e2e'],
    title: GuideText(
      en: 'Direct-first transport overview',
      fr: 'Vue d’ensemble des transports directs',
    ),
    introduction: GuideText(
      en: 'One authenticated application transport owns the PC bridge at a time.',
      fr: 'Un seul transport applicatif authentifié possède le pont PC à la fois.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Selection tries a provisioned private-LAN WSS path, opens the E2E relay in signaling standby, retries newly provisioned LAN, attempts data-only WebRTC/P2P, then explicitly commits the encrypted relay. The coordinator and OS-level lease prevent two bridges from delivering one turn.',
        fr: 'La sélection essaie le WSS du LAN privé, ouvre le relais E2E en attente de signalisation, retente le LAN nouvellement fourni, essaie WebRTC/P2P pour les données, puis valide explicitement le relais chiffré. Le coordinateur et le verrou système empêchent deux ponts de livrer un tour.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Log the chosen transport and attempt identity, not payload contents.',
      fr: 'Journalisez le transport et l’identité de tentative, pas le contenu.',
    ),
    remember: GuideText(
      en: 'Relay standby is signaling infrastructure until its application commit succeeds.',
      fr: 'Le relais en attente ne porte que la signalisation jusqu’à validation applicative.',
    ),
  ),
  GuideLesson(
    id: 'advanced.lan',
    categoryId: guideAdvancedCategoryId,
    order: 9,
    subjectId: 'lan',
    glossaryIds: <String>['lan', 'websocket', 'hash'],
    title: GuideText(en: 'LAN transport', fr: 'Transport LAN'),
    introduction: GuideText(
      en: 'The local path uses authenticated WSS on a private IPv4 network.',
      fr: 'Le chemin local utilise WSS authentifié sur un réseau IPv4 privé.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The PC advertises discovery data, binds the private address on port 8766 and presents a self-signed ECDSA certificate whose SHA-256 pin was provisioned inside the E2E channel. The phone accepts only private numeric addresses and the matching pin. Guest isolation, a public network profile or firewall policy can block discovery or connection.',
        fr: 'Le PC annonce la découverte, écoute l’adresse privée sur le port 8766 et présente un certificat ECDSA auto-signé dont l’empreinte SHA-256 a été fournie dans le canal E2E. Le téléphone n’accepte qu’une adresse numérique privée et l’empreinte correspondante. Isolation invité, profil public ou pare-feu peuvent bloquer.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Verify both devices share a trusted private LAN before inspecting fallback transports.',
      fr: 'Vérifiez que les deux appareils partagent un LAN privé de confiance avant les replis.',
    ),
    remember: GuideText(
      en: 'Do not forward the LAN port to the Internet.',
      fr: 'Ne redirigez pas le port LAN vers Internet.',
    ),
  ),
  GuideLesson(
    id: 'advanced.webrtc',
    categoryId: guideAdvancedCategoryId,
    order: 10,
    subjectId: 'webrtc',
    glossaryIds: <String>['webrtc', 'p2p', 'sdp', 'ice', 'signaling', 'e2e'],
    title: GuideText(en: 'WebRTC and P2P', fr: 'WebRTC et P2P'),
    introduction: GuideText(
      en: 'WebRTC seeks a direct, ordered and reliable data path across networks.',
      fr: 'WebRTC cherche un chemin de données direct, ordonné et fiable entre réseaux.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The PC creates a fresh offer; mobile answers; bounded SDP and ICE candidates travel only inside relay E2E frames. A single ordered DataChannel then performs another pairing-authenticated E2E handshake before application commit. Failed ICE, authentication, timeout or bridge availability closes that attempt and permits relay fallback.',
        fr: 'Le PC crée une offre neuve ; le mobile répond ; SDP et candidats ICE bornés voyagent uniquement dans les trames E2E du relais. Un DataChannel ordonné réalise un nouvel échange E2E authentifié avant validation. Échec ICE, authentification, délai ou pont ferme la tentative et permet le relais.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Record offer/answer state, candidate summary and failure category without SDP addresses in shared logs.',
      fr: 'Consignez état offre/réponse, résumé des candidats et catégorie d’échec sans adresses SDP dans les journaux partagés.',
    ),
    remember: GuideText(
      en: 'Every attempt uses fresh generation and cryptographic context.',
      fr: 'Chaque tentative utilise une génération et un contexte cryptographique neufs.',
    ),
  ),
  GuideLesson(
    id: 'advanced.ice-stun-turn',
    categoryId: guideAdvancedCategoryId,
    order: 11,
    subjectId: 'ice-stun-turn',
    glossaryIds: <String>['ice', 'stun', 'turn', 'webrtc', 'relay'],
    title: GuideText(en: 'ICE, STUN and TURN', fr: 'ICE, STUN et TURN'),
    introduction: GuideText(
      en: 'ICE selects connectivity candidates; STUN discovers mapped addresses; TURN relays WebRTC media or data when direct candidates fail.',
      fr: 'ICE sélectionne des candidats de connexion ; STUN découvre les adresses traduites ; TURN relaie les données WebRTC lorsque le direct échoue.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'OSIA persists only validated credential-free STUN URLs and currently defaults to Cloudflare STUN. Optional TURN records require credentials from protected runtime environment configuration and are never stored in ordinary settings. TURN is therefore supported as protected configuration, not configured by default; OSIA’s own E2E relay remains the normal fallback.',
        fr: 'OSIA ne persiste que des URL STUN validées sans identifiants et utilise par défaut le STUN Cloudflare. Les entrées TURN facultatives exigent des identifiants fournis par l’environnement protégé et ne sont jamais stockées dans les réglages. TURN est donc possible mais absent par défaut ; le relais E2E OSIA reste le repli normal.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Differentiate a STUN reachability failure from a relay failure before changing production configuration.',
      fr: 'Distinguez un échec STUN d’un échec du relais avant de changer la production.',
    ),
    remember: GuideText(
      en: 'Never place TURN credentials in tracked settings or guide examples.',
      fr: 'Ne placez jamais d’identifiants TURN dans des réglages suivis ou des exemples.',
    ),
  ),
  GuideLesson(
    id: 'advanced.relay',
    categoryId: guideAdvancedCategoryId,
    order: 12,
    subjectId: 'relay',
    glossaryIds: <String>[
      'relay',
      'durable-object',
      'hibernation',
      'websocket',
      'e2e',
      'chunking',
    ],
    title: GuideText(en: 'OSIA relay fallback', fr: 'Relais de secours OSIA'),
    introduction: GuideText(
      en: 'The public relay becomes the application transport only after direct paths fail and an encrypted commit succeeds.',
      fr: 'Le relais public devient le transport applicatif seulement après l’échec des chemins directs et une validation chiffrée.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'A Durable Object routes PC and mobile roles for one pair, enforces monotonic sequences, generations, frame and chunk limits, priorities and backpressure, and hibernates idle sockets. Application frames must be E2E envelopes; plaintext is rejected. Duplicate readiness and commits are idempotent, while stale sessions are superseded.',
        fr: 'Un Durable Object route les rôles PC/mobile d’une paire, impose séquences monotones, générations, limites de trames/fragments, priorités et pression, puis hiberne les sockets inactifs. Les trames applicatives doivent être E2E ; le clair est refusé. Les doublons sont idempotents et les sessions anciennes remplacées.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Exercise reconnect and duplicate messages in tests before changing relay ordering.',
      fr: 'Testez reconnexion et doublons avant de modifier l’ordre du relais.',
    ),
    remember: GuideText(
      en: 'The relay can route ciphertext and metadata but cannot decrypt application content.',
      fr: 'Le relais route chiffré et métadonnées sans pouvoir déchiffrer le contenu.',
    ),
  ),
  GuideLesson(
    id: 'advanced.e2e',
    categoryId: guideAdvancedCategoryId,
    order: 13,
    subjectId: 'e2e',
    glossaryIds: <String>['e2e', 'hash', 'chunking', 'token'],
    title: GuideText(
      en: 'End-to-end encryption',
      fr: 'Chiffrement de bout en bout',
    ),
    introduction: GuideText(
      en: 'Endpoint-only key establishment protects confidentiality, integrity and session identity.',
      fr: 'L’établissement de clés aux extrémités protège confidentialité, intégrité et identité de session.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'PC and mobile combine fresh X25519 agreement with pairing-derived material, derive direction-separated keys and nonces, confirm the transcript, then use authenticated ChaCha20-Poly1305 envelopes. Sequence guards reject replay; authenticated metadata binds role, pair, priority and finality. Oversized ciphertext is bounded, hashed and chunked; reconnect rotates context.',
        fr: 'PC et mobile combinent un accord X25519 neuf au matériel dérivé de l’association, dérivent clés et nonces par direction, confirment la transcription puis utilisent des enveloppes ChaCha20-Poly1305 authentifiées. Les séquences bloquent le rejeu ; les métadonnées lient rôle, paire, priorité et finalité. Le chiffré volumineux est borné, haché et fragmenté ; la reconnexion renouvelle le contexte.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Use deterministic cross-language vectors to verify both endpoints without exposing production secrets.',
      fr: 'Utilisez des vecteurs déterministes interlangages sans exposer de secrets de production.',
    ),
    remember: GuideText(
      en: 'Logs may name an error category or shortened key identifier, never key material or plaintext.',
      fr: 'Les journaux peuvent nommer une catégorie ou un identifiant raccourci, jamais une clé ni du clair.',
    ),
  ),
  GuideLesson(
    id: 'advanced.handshake',
    categoryId: guideAdvancedCategoryId,
    order: 14,
    subjectId: 'handshake',
    glossaryIds: <String>['e2e', 'signaling', 'websocket'],
    title: GuideText(
      en: 'Handshake state machine',
      fr: 'Machine d’état de négociation',
    ),
    introduction: GuideText(
      en: 'Confirmed E2E identity and transport readiness are separate states.',
      fr: 'L’identité E2E confirmée et la disponibilité du transport sont des états distincts.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Relay sessions exchange E2E_HELLO and E2E_READY, then MOBILE_READY and PC_READY describe routable readiness. Direct transports add their own hello, ready and commit sequence tied to attempt and generation. Exact fields, context identity, monotonically ordered messages and duplicate suppression make reconnect deterministic.',
        fr: 'Les sessions relais échangent E2E_HELLO et E2E_READY, puis MOBILE_READY et PC_READY décrivent la disponibilité. Les transports directs ajoutent hello, ready et commit liés à la tentative et génération. Champs exacts, identité de contexte, ordre monotone et suppression des doublons rendent la reconnexion déterministe.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Model each transition and reject a frame that arrives before its prerequisite state.',
      fr: 'Modélisez chaque transition et refusez une trame arrivée avant son état préalable.',
    ),
    remember: GuideText(
      en: 'Use only confirmed current message names in documentation and tests.',
      fr: 'N’utilisez dans documentation et tests que les noms de messages confirmés.',
    ),
  ),
  GuideLesson(
    id: 'advanced.correlation',
    categoryId: guideAdvancedCategoryId,
    order: 15,
    subjectId: 'correlation',
    glossaryIds: <String>['context'],
    title: GuideText(
      en: 'Conversation and turn correlation',
      fr: 'Corrélation conversation et tour',
    ),
    introduction: GuideText(
      en: 'Stable identities keep concurrent UI events attached to the correct request.',
      fr: 'Des identités stables rattachent les événements d’interface à la bonne requête.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Conversation ID selects history; request and turn IDs bind input, attachment batch, progress, tool calls, streamed deltas and terminal event. The active-turn lock blocks overlap. Replay guards and idempotent acknowledgements prevent duplicate delivery, while retry creates an intentional new attempt after the old terminal state.',
        fr: 'L’identifiant de conversation choisit l’historique ; requête et tour lient entrée, lot de fichiers, progression, outils, fragments de réponse et événement final. Le verrou bloque le chevauchement. Les gardes anti-rejeu et accusés idempotents évitent les doublons ; Réessayer crée une nouvelle tentative après la fin.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Assert exactly one terminal event and one committed user turn in correlation tests.',
      fr: 'Vérifiez exactement un événement final et un tour utilisateur validé dans les tests.',
    ),
    remember: GuideText(
      en: 'Never infer success from a stale buffered answer.',
      fr: 'Ne déduisez jamais un succès d’une ancienne réponse en tampon.',
    ),
  ),
  GuideLesson(
    id: 'advanced.attachments',
    categoryId: guideAdvancedCategoryId,
    order: 16,
    subjectId: 'attachments',
    glossaryIds: <String>['chunking', 'hash', 'mime'],
    title: GuideText(en: 'Attachments', fr: 'Pièces jointes'),
    introduction: GuideText(
      en: 'Attachments are validated and committed before the agent receives a turn.',
      fr: 'Les pièces jointes sont validées et engagées avant que l’agent reçoive le tour.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'PC picking creates an ordered draft and validates again at send time. Mobile copies private selections, enforces ten files and a 20 MiB aggregate, emits 20 KiB chunks with size and SHA-256, and commits only after PC reassembly. Shared checks cover MIME, magic bytes, order, cancellation, temporary cleanup and safe names that cannot traverse paths; a transport change aborts the batch.',
        fr: 'Sur PC, la sélection crée un brouillon ordonné puis revalide à l’envoi. Le mobile copie en privé, impose dix fichiers et 20 Mio au total, envoie des fragments de 20 Kio avec taille et SHA-256, puis engage après réassemblage PC. Les contrôles couvrent MIME, octets magiques, ordre, annulation, nettoyage et noms sans traversée ; changer de transport annule le lot.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Test a valid mixed batch, wrong hash, duplicate chunk, cancellation and reconnect before commit.',
      fr: 'Testez lot mixte valide, mauvais hash, fragment dupliqué, annulation et reconnexion avant validation.',
    ),
    remember: GuideText(
      en: 'A failed batch must not start the model or replay a previous answer.',
      fr: 'Un lot échoué ne doit ni lancer le modèle ni rejouer une réponse précédente.',
    ),
  ),
  GuideLesson(
    id: 'advanced.vision',
    categoryId: guideAdvancedCategoryId,
    order: 17,
    subjectId: 'vision',
    glossaryIds: <String>['provider', 'model', 'mime'],
    title: GuideText(en: 'Vision inputs', fr: 'Entrées de vision'),
    introduction: GuideText(
      en: 'Image delivery depends on both adapter format and model capability metadata.',
      fr: 'La livraison d’image dépend du format de l’adaptateur et des capacités du modèle.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'ChatGPT Account uses its localImage input path; Google and OpenAI-compatible adapters build their supported image content blocks. Provider and model preflight validates MIME and vision support before network work. Unknown capability fails closed, unsupported combinations return a clear error, no silent OCR substitute is invented, and image blocks remain current-turn only.',
        fr: 'Compte ChatGPT utilise son chemin localImage ; Google et les adaptateurs compatibles OpenAI construisent leurs blocs d’image pris en charge. Le préflight valide MIME et vision avant le réseau. Une capacité inconnue échoue fermée, une combinaison incompatible donne une erreur claire, aucun OCR silencieux n’est inventé et l’image reste limitée au tour courant.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Run adapter-structure tests with synthetic images and verify persisted history contains no image block.',
      fr: 'Testez la structure des adaptateurs avec des images fictives et vérifiez l’absence de bloc image dans l’historique persistant.',
    ),
    remember: GuideText(
      en: 'Model names alone are not proof of vision support.',
      fr: 'Le nom d’un modèle ne prouve pas sa compatibilité vision.',
    ),
  ),
  GuideLesson(
    id: 'advanced.provider-architecture',
    categoryId: guideAdvancedCategoryId,
    order: 18,
    subjectId: 'provider-architecture',
    glossaryIds: <String>['provider', 'api', 'model'],
    title: GuideText(
      en: 'Provider architecture',
      fr: 'Architecture des fournisseurs',
    ),
    introduction: GuideText(
      en: 'Adapters normalize different authentication, streaming, tool and image APIs behind one agent contract.',
      fr: 'Les adaptateurs normalisent authentification, streaming, outils et images derrière un contrat d’agent commun.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The registry covers ChatGPT Account/App Server, native Google behavior and API-key providers including Anthropic, OpenAI-compatible OpenAI/xAI/DeepSeek paths, Groq and Mistral where exposed. Each adapter owns request shape, streaming parsing, tool support, image encoding and error classification. Quota and retry behavior must preserve the provider’s real status.',
        fr: 'Le registre couvre Compte ChatGPT/App Server, Google natif et les fournisseurs à clé exposés, dont Anthropic, les chemins compatibles OpenAI pour OpenAI/xAI/DeepSeek, Groq et Mistral. Chaque adaptateur possède forme de requête, flux, outils, images et classification d’erreurs. Quotas et tentatives doivent préserver l’état réel.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Add adapter tests before advertising a model capability in the registry.',
      fr: 'Ajoutez des tests d’adaptateur avant d’annoncer une capacité dans le registre.',
    ),
    remember: GuideText(
      en: 'Do not generalize one OpenAI-compatible behavior to every provider without evidence.',
      fr: 'Ne généralisez pas un comportement compatible OpenAI à tous les fournisseurs sans preuve.',
    ),
  ),
  GuideLesson(
    id: 'advanced.provider-hierarchy',
    categoryId: guideAdvancedCategoryId,
    order: 19,
    subjectId: 'provider-hierarchy',
    glossaryIds: <String>['provider', 'model', 'api'],
    title: GuideText(
      en: 'Provider and API hierarchy',
      fr: 'Hiérarchie des fournisseurs et API',
    ),
    introduction: GuideText(
      en: 'Automatic hierarchy routes classified work through ordered provider:model entries.',
      fr: 'La hiérarchie automatique route le travail classé dans une liste ordonnée fournisseur:modèle.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'When enabled, Heavy and Medium chains are tried in user order and the manually selected model is the final fallback. Key rotation precedes model fallback for technical errors. Hierarchy switches only on authentication, quota, timeout, connection or server failures; content/client errors do not switch, and no fallback occurs after output streaming starts. Endpoint fallback is a single transport retry with the same key and model.',
        fr: 'Lorsqu’elle est active, les chaînes Lourde et Moyenne suivent l’ordre choisi et le modèle manuel reste le dernier repli. La rotation de clés précède le repli de modèle pour les erreurs techniques. La hiérarchie change seulement pour authentification, quota, délai, connexion ou serveur ; les erreurs de contenu ne changent pas, ni après le début du flux. Le repli d’endpoint est une unique tentative de transport avec même clé et modèle.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Configure two harmless entries, simulate a technical first failure, then verify the second receives no duplicate streamed turn.',
      fr: 'Configurez deux entrées sans risque, simulez un premier échec technique et vérifiez l’absence de tour dupliqué.',
    ),
    remember: GuideText(
      en: 'ChatGPT Account follows its configured position; it is not silently always first.',
      fr: 'Compte ChatGPT suit sa position configurée ; il n’est pas secrètement toujours prioritaire.',
    ),
  ),
  GuideLesson(
    id: 'advanced.model-capabilities',
    categoryId: guideAdvancedCategoryId,
    order: 20,
    subjectId: 'model-capabilities',
    glossaryIds: <String>['model', 'provider', 'thinking', 'context'],
    title: GuideText(
      en: 'Model hierarchy and capabilities',
      fr: 'Hiérarchie et capacités des modèles',
    ),
    introduction: GuideText(
      en: 'The model registry records capabilities used for safe routing and UI controls.',
      fr: 'Le registre des modèles décrit les capacités utilisées pour le routage sûr et les contrôles UI.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Metadata identifies provider, reasoning support, vision and tool compatibility. Manual selection is global unless a feature such as autonomous or voice exposes its own selector; conversations do not invent an independent model override. Heavy/Medium hierarchy handles classified tasks, while an unknown image capability fails closed instead of guessing.',
        fr: 'Les métadonnées indiquent fournisseur, raisonnement, vision et outils. La sélection manuelle est globale sauf lorsqu’une fonction comme Autonome ou Voix possède son propre sélecteur ; les conversations n’inventent pas de remplacement. La hiérarchie Lourde/Moyenne gère les tâches classées et une capacité image inconnue échoue fermée.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Validate registry metadata, UI availability and adapter behavior as one change.',
      fr: 'Validez ensemble métadonnées, disponibilité UI et comportement de l’adaptateur.',
    ),
    remember: GuideText(
      en: 'Never reintroduce an artificial global response-token ceiling.',
      fr: 'Ne réintroduisez jamais un plafond global artificiel de jetons de réponse.',
    ),
  ),
  GuideLesson(
    id: 'advanced.agent-runtime',
    categoryId: guideAdvancedCategoryId,
    order: 21,
    subjectId: 'agent-runtime',
    glossaryIds: <String>['context', 'provider', 'model'],
    title: GuideText(en: 'Agent runtime', fr: 'Exécution de l’agent'),
    introduction: GuideText(
      en: 'The agent assembles bounded context, calls one provider and executes registered tools until a terminal result.',
      fr: 'L’agent assemble un contexte borné, appelle un fournisseur et exécute des outils enregistrés jusqu’au résultat final.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Prompt assembly combines conversation, selected memory, personality/skills, system facts and current attachments. Provider output may stream text and tool calls; parsing occurs before raw tags are stripped, confirmations gate sensitive operations, and anti-loop detectors plus a per-turn time limit stop repeated or stalled behavior. The terminal contract must return useful text or an explicit ERROR state.',
        fr: 'L’assemblage combine conversation, mémoire sélectionnée, personnalité/compétences, faits système et pièces jointes courantes. Le fournisseur diffuse texte et appels d’outils ; l’analyse précède le retrait des balises brutes, les confirmations protègent les opérations sensibles, et anti-boucle plus limite de tour arrêtent les répétitions. Le contrat final renvoie un texte utile ou un état ERROR explicite.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Test plain text, native and XML tool calls, denial, loop detection and provider failure without changing protected parser code.',
      fr: 'Testez texte, appels natifs et XML, refus, boucle et échec fournisseur sans modifier l’analyseur protégé.',
    ),
    remember: GuideText(
      en: 'Parsing, execution and stripping order is an architectural contract.',
      fr: 'L’ordre analyse, exécution puis retrait est un contrat architectural.',
    ),
  ),
  GuideLesson(
    id: 'advanced.autonomous',
    categoryId: guideAdvancedCategoryId,
    order: 22,
    subjectId: 'autonomous',
    glossaryIds: <String>['provider', 'model'],
    title: GuideText(
      en: 'Autonomous mode internals',
      fr: 'Internes du mode autonome',
    ),
    introduction: GuideText(
      en: 'Autonomous mode orchestrates a persisted, bounded mission above normal agent turns.',
      fr: 'Le mode autonome orchestre une mission persistante et bornée au-dessus des tours normaux.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The planner creates at most five phases of five tasks, tasks have bounded attempts and the mission has bounded replans. One machine-wide runner writes a crash-safe checkpoint. Interrupt preserves an in-progress state for Resume; Abort marks it terminal and removes the checkpoint. Progress includes planning, task, salvage, failure and terminal events, while each underlying agent turn keeps loop/time protections.',
        fr: 'Le planificateur crée au plus cinq phases de cinq tâches, avec tentatives et replanifications bornées. Un exécuteur global écrit un point de reprise sûr. Interrompre conserve l’état pour Reprendre ; Abandonner le rend final et retire le point. La progression couvre plan, tâche, récupération, échec et fin, chaque tour gardant ses protections.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Crash after one task, resume, and verify completed work is rechecked rather than blindly repeated.',
      fr: 'Interrompez après une tâche, reprenez et vérifiez que le travail est contrôlé plutôt que répété aveuglément.',
    ),
    remember: GuideText(
      en: 'Unattended MCP writes remain denied unless the explicit advanced policy permits them.',
      fr: 'Les écritures MCP sans surveillance restent refusées sauf politique avancée explicite.',
    ),
  ),
  GuideLesson(
    id: 'advanced.computer-use',
    categoryId: guideAdvancedCategoryId,
    order: 23,
    subjectId: 'computer-use',
    glossaryIds: <String>[],
    title: GuideText(
      en: 'Computer use internals',
      fr: 'Internes du contrôle de l’ordinateur',
    ),
    introduction: GuideText(
      en: 'Computer use escalates from stable integrations to less certain visual interaction.',
      fr: 'Le contrôle de l’ordinateur progresse des intégrations stables vers l’interaction visuelle moins certaine.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Priority is API or command integration, URL/deep link, browser DOM and accessible names, native accessibility/UI Automation, keyboard navigation, then screenshot vision and coordinates. Browser sessions use isolated profiles and one managed launch path. Every action should observe resulting process, window, DOM or file state, and sensitive actions pass policy confirmation.',
        fr: 'La priorité est API ou commande, URL/lien profond, DOM du navigateur et noms accessibles, accessibilité/UI Automation native, clavier, puis vision et coordonnées. Les sessions navigateur utilisent des profils isolés et un lancement géré. Chaque action observe ensuite processus, fenêtre, DOM ou fichier, et les actions sensibles passent par confirmation.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Prefer a named button in the accessibility tree over a coordinate from an old screenshot.',
      fr: 'Préférez un bouton nommé dans l’arbre d’accessibilité à une coordonnée d’ancienne capture.',
    ),
    remember: GuideText(
      en: 'Coordinate confidence drops when scale, window position or content changes.',
      fr: 'La confiance des coordonnées baisse quand échelle, position ou contenu changent.',
    ),
  ),
  GuideLesson(
    id: 'advanced.cron',
    categoryId: guideAdvancedCategoryId,
    order: 24,
    subjectId: 'cron',
    glossaryIds: <String>['cron', 'model'],
    title: GuideText(
      en: 'Scheduled tasks and cron',
      fr: 'Tâches planifiées et cron',
    ),
    introduction: GuideText(
      en: 'The PC scheduler persists local-wall-clock jobs and polls for due work.',
      fr: 'Le planificateur PC persiste des tâches en heure locale et recherche les échéances.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Supported syntax covers every N minutes/hours/days, every N days at a time, daily at a time and an ISO one-shot. Weekly syntax is not supported. One-shots disable after firing; recurring jobs can be edited, toggled or deleted and may bind conversation/model. Startup schedules the next occurrence rather than catching up missed work, so sleep or downtime skips past slots; a busy execution remains retryable.',
        fr: 'La syntaxe couvre toutes les N minutes/heures/jours, tous les N jours à une heure, quotidien à une heure et un ISO ponctuel. L’hebdomadaire n’est pas pris en charge. Un ponctuel se désactive ; les récurrents sont modifiables et peuvent lier conversation/modèle. Au démarrage, la prochaine occurrence est calculée sans rattraper les créneaux manqués ; une exécution occupée reste retentable.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Test parsing at timezone and day boundaries with a fake clock, then verify notification and mobile mirror events.',
      fr: 'Testez l’analyse aux limites de fuseau et de jour avec une horloge simulée, puis notifications et miroir mobile.',
    ),
    remember: GuideText(
      en: 'The scheduler cannot wake a sleeping PC by itself.',
      fr: 'Le planificateur ne peut pas réveiller seul un PC endormi.',
    ),
  ),
  GuideLesson(
    id: 'advanced.mcp',
    categoryId: guideAdvancedCategoryId,
    order: 25,
    subjectId: 'mcp',
    glossaryIds: <String>['mcp', 'dcr', 'oauth', 'api'],
    title: GuideText(en: 'MCP architecture', fr: 'Architecture MCP'),
    introduction: GuideText(
      en: 'MCP connects external tool servers through catalog or custom configurations.',
      fr: 'MCP connecte des serveurs d’outils externes via le catalogue ou des configurations personnalisées.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Supported transports are stdio and streamable HTTP; legacy SSE is recognized but unsupported. Catalog entries define health and auth: OAuth may use Dynamic Client Registration or a static client, bearer tokens are validated, and custom connectors remain explicit. Connected tools are injected as namespaced agent tools. Lifecycle covers connect, cancel, disconnect, revoke and reconnect; mobile mirrors status and confirmation requests.',
        fr: 'Les transports pris en charge sont stdio et HTTP streamable ; SSE ancien est reconnu mais non pris en charge. Le catalogue définit santé et auth : OAuth peut utiliser l’enregistrement dynamique ou un client statique, les jetons sont validés et les connecteurs personnalisés explicites. Les outils sont injectés avec namespace. Le cycle couvre connexion, annulation, déconnexion, révocation et reconnexion ; le mobile reflète l’état.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Test a read tool, an annotated write, OAuth cancellation and restart reconnect with sanitized fixtures.',
      fr: 'Testez lecture, écriture annotée, annulation OAuth et reconnexion après redémarrage avec données fictives.',
    ),
    remember: GuideText(
      en: 'Catalog presence, suggestability and current connectability are different states.',
      fr: 'Présence au catalogue, proposition et connexion actuelle sont des états différents.',
    ),
  ),
  GuideLesson(
    id: 'advanced.memory-persistence',
    categoryId: guideAdvancedCategoryId,
    order: 26,
    subjectId: 'memory-persistence',
    glossaryIds: <String>['context', 'token'],
    title: GuideText(
      en: 'Memory and persistence',
      fr: 'Mémoire et persistance',
    ),
    introduction: GuideText(
      en: 'Conversation history, selected memory and runtime state have separate persistence contracts.',
      fr: 'Historique, mémoire sélectionnée et état d’exécution ont des contrats de persistance séparés.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The installed profile uses the resolved user data directory; source mode may use a project config only when its settings file exists. Conversations, memory JSON with atomic backup, settings, ignored API-key and OAuth stores, autonomous checkpoint, cron jobs, LAN identity and guide progress remain PC-owned. Mobile stores pairing plus interface preferences. Migration validates IDs and corruption falls back safely without reopening first-run UI.',
        fr: 'Le profil installé utilise le dossier utilisateur résolu ; le mode source peut utiliser config du projet si settings existe. Conversations, mémoire JSON atomique, réglages, magasins ignorés de clés/OAuth, point autonome, tâches, identité LAN et progression restent PC. Le mobile garde association et préférences. La migration valide les ID et la corruption retombe sûrement sans rouvrir le premier lancement.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Test source and installed path resolution with temporary generic directories, never a personal path.',
      fr: 'Testez la résolution source/installée avec des dossiers temporaires génériques, jamais un chemin personnel.',
    ),
    remember: GuideText(
      en: 'Deleting mobile data does not delete PC history or memory.',
      fr: 'Supprimer les données mobiles ne supprime pas l’historique ni la mémoire PC.',
    ),
  ),
  GuideLesson(
    id: 'advanced.configuration-secrets',
    categoryId: guideAdvancedCategoryId,
    order: 27,
    subjectId: 'configuration-secrets',
    glossaryIds: <String>['api', 'oauth', 'r2'],
    title: GuideText(
      en: 'Configuration and secrets',
      fr: 'Configuration et secrets',
    ),
    introduction: GuideText(
      en: 'Configuration is layered so shareable defaults never contain private credentials.',
      fr: 'La configuration est organisée en couches afin que les valeurs partageables ne contiennent jamais d’identifiants privés.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Tracked examples document shape and safe defaults; ignored profile files hold real settings, API keys and OAuth state. Android signing keys, Apple signing material, service accounts, R2 credentials and deployment tokens stay outside Git and enter only through approved local files, secret stores or environment variables. Logs, fixtures and screenshots must redact tokens and personal paths.',
        fr: 'Les exemples suivis documentent la forme et les valeurs sûres ; les fichiers de profil ignorés contiennent les vrais réglages, clés API et états OAuth. Les clés de signature Android, éléments Apple, comptes de service, identifiants R2 et jetons de déploiement restent hors de Git et passent uniquement par des fichiers locaux approuvés, magasins secrets ou variables d’environnement. Journaux, fixtures et captures doivent masquer jetons et chemins personnels.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Use a placeholder in an example file, inject a disposable test secret locally, then inspect the staged diff before committing.',
      fr: 'Placez un substitut dans le fichier d’exemple, injectez localement un secret de test jetable, puis inspectez le diff indexé avant validation.',
    ),
    remember: GuideText(
      en: 'A masked field is a display safeguard, not proof that no raw secret exists in authenticated runtime memory.',
      fr: 'Un champ masqué protège l’affichage ; il ne prouve pas qu’aucun secret brut n’existe dans la mémoire d’exécution authentifiée.',
    ),
  ),
  GuideLesson(
    id: 'advanced.development-environment',
    categoryId: guideAdvancedCategoryId,
    order: 28,
    subjectId: 'development-environment',
    glossaryIds: <String>['api'],
    title: GuideText(
      en: 'Development environment',
      fr: 'Environnement de développement',
    ),
    introduction: GuideText(
      en: 'Reproducible development starts with the repository’s documented toolchain and isolated dependencies.',
      fr: 'Un développement reproductible commence par la chaîne d’outils documentée du dépôt et des dépendances isolées.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'PC work uses PowerShell, a supported Python virtual environment and Qt dependencies; mobile uses the validated Flutter/Dart toolchain with Android SDK, Java and Gradle; Worker and site tooling use their declared Node packages and Wrangler where applicable. Resolve paths dynamically, keep generated caches out of source control, and record tool versions in release evidence rather than hard-coding them into timeless guidance.',
        fr: 'Le PC utilise PowerShell, un environnement virtuel Python pris en charge et les dépendances Qt ; le mobile utilise la chaîne Flutter/Dart validée avec SDK Android, Java et Gradle ; Worker et site suivent leurs paquets Node déclarés et Wrangler si nécessaire. Résolvez les chemins dynamiquement, excluez les caches générés du suivi et consignez les versions dans les preuves de livraison plutôt que dans un guide intemporel.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'From a fresh clone, create the prescribed environments, restore locked dependencies and run the smallest import or analysis check before editing.',
      fr: 'Depuis un clone neuf, créez les environnements prescrits, restaurez les dépendances verrouillées et lancez le plus petit test d’import ou d’analyse avant toute modification.',
    ),
    remember: GuideText(
      en: 'A tool installed globally can hide a missing repository dependency.',
      fr: 'Un outil installé globalement peut masquer une dépendance manquante du dépôt.',
    ),
  ),
  GuideLesson(
    id: 'advanced.takeover-workflow',
    categoryId: guideAdvancedCategoryId,
    order: 29,
    subjectId: 'takeover-workflow',
    glossaryIds: <String>['artifact', 'rollout'],
    title: GuideText(
      en: 'Twelve-step takeover workflow',
      fr: 'Reprise d’un travail en douze étapes',
    ),
    introduction: GuideText(
      en: 'A disciplined takeover makes repository state, running services and release evidence explicit before any edit.',
      fr: 'Une reprise disciplinée rend explicites l’état des dépôts, les services actifs et les preuves de livraison avant toute modification.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: '1. Read the request and repository rules. 2. Record every repository path and allowed scope. 3. Capture HEAD, branch, status, index and upstream divergence. 4. Classify existing changes as user-owned or task-owned. 5. Audit relevant processes and services. 6. Inspect architecture and all call sites. 7. Build a source-backed behavior matrix. 8. Define the smallest cross-platform change. 9. Implement without touching protected contracts. 10. Run syntax, import, focused and adjacent tests. 11. Perform an adversarial correctness, regression and policy review. 12. Stage explicitly, verify the exact diff, commit and build from the committed snapshot.',
        fr: '1. Lire la demande et les règles. 2. Noter chaque dépôt et le périmètre autorisé. 3. Relever HEAD, branche, état, index et divergence. 4. Classer les changements existants. 5. Auditer processus et services. 6. Étudier architecture et appelants. 7. Établir une matrice sourcée. 8. Définir le changement multiplateforme minimal. 9. Implémenter sans toucher aux contrats protégés. 10. Tester syntaxe, imports, cible et voisinage. 11. Mener une revue adversariale. 12. Indexer explicitement, vérifier le diff, valider et construire depuis le commit.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Practice on a disposable clone at C:\\path\\to\\osia and stop if a protected or user-owned change overlaps the task.',
      fr: 'Exercez-vous sur un clone jetable dans C:\\path\\to\\osia et arrêtez-vous si un changement protégé ou appartenant à l’utilisateur chevauche la tâche.',
    ),
    remember: GuideText(
      en: 'A clean-looking worktree does not replace recording the commit and upstream relationship.',
      fr: 'Un arbre apparemment propre ne remplace pas le relevé du commit et de sa relation avec l’amont.',
    ),
  ),
  GuideLesson(
    id: 'advanced.safe-modification',
    categoryId: guideAdvancedCategoryId,
    order: 30,
    subjectId: 'safe-modification',
    glossaryIds: <String>['hash', 'artifact'],
    title: GuideText(
      en: 'Safe modification workflow',
      fr: 'Flux de modification sûr',
    ),
    introduction: GuideText(
      en: 'Safe changes begin with evidence, preserve contracts and finish with an exact staged diff.',
      fr: 'Les changements sûrs commencent par des preuves, préservent les contrats et finissent par un diff indexé exact.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Reproduce or trace the behavior, identify root cause and every caller, then edit only necessary functions. Preserve parser order, anti-loop, key rotation, configuration resolution, WebSocket contracts and platform guards. Never clean a shared tree with destructive reset. Run targeted and adjacent checks, inspect generated artifacts physically, review from correctness, regression and instruction angles, then stage named paths and compare index against intent.',
        fr: 'Reproduisez ou tracez le comportement, trouvez la cause et tous les appelants, puis ne modifiez que les fonctions nécessaires. Préservez ordre d’analyse, anti-boucle, rotation de clés, résolution de configuration, contrats WebSocket et gardes de plateforme. Ne nettoyez jamais un arbre partagé par réinitialisation destructive. Testez cible et voisinage, inspectez physiquement les artefacts, menez la revue multi-angle, indexez les chemins nommés et comparez l’index à l’intention.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'For a two-file fix, stage those two paths explicitly and prove no third path appears in the cached diff.',
      fr: 'Pour un correctif à deux fichiers, indexez explicitement ces deux chemins et prouvez qu’aucun troisième n’apparaît dans le diff indexé.',
    ),
    remember: GuideText(
      en: 'Passing tests do not authorize unrelated cleanup or refactoring.',
      fr: 'Des tests réussis n’autorisent ni nettoyage ni refactoring hors périmètre.',
    ),
  ),
  GuideLesson(
    id: 'advanced.testing-strategy',
    categoryId: guideAdvancedCategoryId,
    order: 31,
    subjectId: 'testing-strategy',
    glossaryIds: <String>['e2e', 'artifact', 'hash'],
    title: GuideText(en: 'Testing strategy', fr: 'Stratégie de test'),
    introduction: GuideText(
      en: 'OSIA testing combines fast contract tests with physical checks at system boundaries.',
      fr: 'Les tests d’OSIA combinent contrats rapides et contrôles physiques aux frontières du système.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'PC changes need syntax/import checks plus focused and adjacent pytest suites; Flutter changes need formatting, static analysis, unit/widget tests and release builds. Worker and site changes use their declared checks. Transport and end-to-end tests cover authentication, sequencing, disconnects, replay, fallback and E2E opacity with deterministic fakes. Attachment tests cover limits, hashes, MIME, cancellation and atomic commit. Frozen-app, package and security checks validate the actual artifact, not merely source behavior.',
        fr: 'Les changements PC exigent syntaxe/imports puis tests pytest ciblés et voisins ; Flutter exige formatage, analyse statique, tests unitaires/widgets et builds release. Worker et site suivent leurs contrôles déclarés. Les tests transport et bout en bout couvrent authentification, séquences, déconnexions, rejeu, repli et opacité E2E avec des doublures déterministes. Les pièces jointes couvrent limites, hash, MIME, annulation et validation atomique. Les contrôles frozen, paquet et sécurité valident l’artefact réel.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Inject a fake clock and transport to prove one terminal event, then repeat the critical path on the packaged binary.',
      fr: 'Injectez une horloge et un transport fictifs pour prouver un seul événement final, puis rejouez le chemin critique sur le binaire empaqueté.',
    ),
    remember: GuideText(
      en: 'A mocked source test cannot prove signing, native libraries or installer contents.',
      fr: 'Un test source simulé ne prouve ni signature, ni bibliothèques natives, ni contenu de l’installateur.',
    ),
  ),
  GuideLesson(
    id: 'advanced.windows-packaging',
    categoryId: guideAdvancedCategoryId,
    order: 32,
    subjectId: 'windows-packaging',
    glossaryIds: <String>[
      'pyinstaller',
      'inno-setup',
      'manifest',
      'hash',
      'artifact',
    ],
    title: GuideText(en: 'Windows packaging', fr: 'Empaquetage Windows'),
    introduction: GuideText(
      en: 'A Windows release is produced from a clean committed snapshot and validated at every packaging layer.',
      fr: 'Une version Windows est produite depuis un instantané validé propre et contrôlée à chaque couche d’empaquetage.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'The repository build creates a PyInstaller onedir application, runs package smoke checks and validates GUI startup before an optional Inno Setup installer. Release metadata and SHA-256 must match immutable artifacts; code signing is a separate authenticity layer. The updater must consume the intended channel manifest and verify size/hash before replacement. Build directories are evidence until the new artifact is independently validated.',
        fr: 'Le build du dépôt crée une application PyInstaller onedir, exécute des tests du paquet et valide le démarrage GUI avant un éventuel installateur Inno Setup. Métadonnées et SHA-256 doivent correspondre aux artefacts immuables ; la signature de code est une couche d’authenticité distincte. Le programme de mise à jour doit lire le manifeste du canal prévu et vérifier taille/hash avant remplacement. Les dossiers de build restent des preuves jusqu’à validation indépendante du nouvel artefact.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Launch the packaged executable from outside the source tree, exercise a harmless chat/settings path and compare its digest with the manifest candidate.',
      fr: 'Lancez l’exécutable empaqueté hors de l’arbre source, testez un chemin conversation/réglages sans risque et comparez son empreinte au manifeste candidat.',
    ),
    remember: GuideText(
      en: 'Do not publish or delete the last known-good build before physical validation succeeds.',
      fr: 'Ne publiez ni ne supprimez le dernier build valide avant la réussite du contrôle physique.',
    ),
  ),
  GuideLesson(
    id: 'advanced.android-packaging',
    categoryId: guideAdvancedCategoryId,
    order: 33,
    subjectId: 'android-packaging',
    glossaryIds: <String>[
      'version-name',
      'version-code',
      'artifact',
      'hash',
      'rollout',
    ],
    title: GuideText(en: 'Android packaging', fr: 'Empaquetage Android'),
    introduction: GuideText(
      en: 'Android releases bind Flutter output, version metadata, signing and store artifacts into one auditable result.',
      fr: 'Les versions Android relient sortie Flutter, métadonnées de version, signature et artefacts de store en un résultat vérifiable.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Record the validated Flutter version with the build evidence. Increment versionName for the user release and versionCode for every uploaded build. Use release signing from ignored local configuration, build APK and AAB with production defines, inspect the bundle with bundletool, and verify application ID, minimum/target SDK and ABIs. R8 output includes a mapping to retain; keep native symbols when generated. Play App Signing protects the distribution key while the upload key signs submissions promoted deliberately through internal, closed, open and production tracks.',
        fr: 'Consignez la version Flutter validée avec les preuves du build. Incrémentez versionName pour la version utilisateur et versionCode pour chaque envoi. Utilisez la signature release depuis une configuration locale ignorée, construisez APK et AAB avec les paramètres production, inspectez le bundle avec bundletool, puis vérifiez identifiant, SDK minimal/cible et ABI. Conservez le mapping R8 et les symboles natifs générés. Play App Signing protège la clé de distribution tandis que la clé d’envoi signe les soumissions promues consciemment entre canaux interne, fermé, ouvert et production.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Install the signed release APK on a compatible device, validate pairing and reconnection, then inspect the AAB before any store upload.',
      fr: 'Installez l’APK release signé sur un appareil compatible, validez association et reconnexion, puis inspectez l’AAB avant tout envoi au store.',
    ),
    remember: GuideText(
      en: 'Never print or copy keystore passwords into logs, commands committed to Git or release notes.',
      fr: 'N’affichez ni ne copiez les mots de passe du keystore dans les journaux, commandes suivies ou notes de version.',
    ),
  ),
  GuideLesson(
    id: 'advanced.worker-site-deployment',
    categoryId: guideAdvancedCategoryId,
    order: 34,
    subjectId: 'worker-site-deployment',
    glossaryIds: <String>[
      'durable-object',
      'r2',
      'manifest',
      'rollout',
      'artifact',
    ],
    title: GuideText(
      en: 'Worker and site deployment',
      fr: 'Déploiement Worker et site',
    ),
    introduction: GuideText(
      en: 'Worker, object storage and public-site updates are separate deployments joined by channel metadata.',
      fr: 'Worker, stockage objet et site public sont des déploiements séparés reliés par les métadonnées de canal.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Validate Worker configuration, bindings, Durable Object migrations and compatibility before deployment. Upload immutable artifacts to R2 under versioned keys, then publish a small internal-preview or stable channel manifest with version, URL, size and SHA-256 only after verification. osia.space presents authoritative availability and release metadata without claiming platforms or channels that are not public. Rollback restores a known-good Worker or manifest pointer; it never overwrites an immutable version.',
        fr: 'Validez configuration Worker, bindings, migrations Durable Object et compatibilité avant déploiement. Envoyez les artefacts immuables dans R2 sous des clés versionnées, puis publiez le manifeste du canal aperçu interne ou stable avec version, URL, taille et SHA-256 seulement après vérification. osia.space présente disponibilité et métadonnées réelles sans annoncer de plateforme ou canal non public. Le retour arrière restaure un Worker connu ou un pointeur de manifeste ; il ne remplace jamais une version immuable.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Deploy to a non-production environment, verify rendezvous and blind relay behavior, then check the exact manifest URL from a clean client.',
      fr: 'Déployez dans un environnement hors production, vérifiez rendez-vous et relais aveugle, puis contrôlez l’URL exacte du manifeste depuis un client propre.',
    ),
    remember: GuideText(
      en: 'Repository access does not imply authorization to deploy or publish.',
      fr: 'L’accès au dépôt n’implique pas l’autorisation de déployer ou publier.',
    ),
  ),
  GuideLesson(
    id: 'advanced.release-process',
    categoryId: guideAdvancedCategoryId,
    order: 35,
    subjectId: 'release-process',
    glossaryIds: <String>['manifest', 'hash', 'artifact', 'rollout'],
    title: GuideText(en: 'Release process', fr: 'Processus de livraison'),
    introduction: GuideText(
      en: 'Release order prevents metadata from pointing at an artifact that is missing or unverified.',
      fr: 'L’ordre de livraison empêche les métadonnées de pointer vers un artefact absent ou non vérifié.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Audit and prepare versions, run all tests, then create targeted local commits and physical-review builds. After approval, fetch and recheck divergence, push normally, build final artifacts from the pushed commits, and perform a physical update test. Upload immutable files, update the channel manifest, then update osia.space metadata. Promote Android through Google Play testing separately; iOS/TestFlight follows its own signing and review process. Monitor rollout and prune only superseded completed evidence while keeping the known-good and ambiguous builds.',
        fr: 'Auditez et préparez les versions, lancez tous les tests, puis créez les commits locaux ciblés et les builds de revue physique. Après approbation, faites fetch et revérifiez la divergence, poussez normalement, construisez les artefacts finaux depuis les commits poussés et testez physiquement la mise à jour. Envoyez les fichiers immuables, actualisez le manifeste puis les métadonnées osia.space. Promouvez Android séparément via les tests Google Play ; iOS/TestFlight suit son propre processus de signature et revue. Surveillez le déploiement et ne supprimez que les preuves terminées remplacées.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Use a written checklist with one evidence path or digest beside every completed gate.',
      fr: 'Utilisez une liste écrite avec un chemin de preuve ou une empreinte pour chaque jalon terminé.',
    ),
    remember: GuideText(
      en: 'A successful local build is a candidate, not a published release.',
      fr: 'Un build local réussi est un candidat, pas une version publiée.',
    ),
  ),
  GuideLesson(
    id: 'advanced.security-model',
    categoryId: guideAdvancedCategoryId,
    order: 36,
    subjectId: 'security-model',
    glossaryIds: <String>['e2e', 'ciphertext', 'hkdf', 'nonce', 'oauth', 'mcp'],
    title: GuideText(en: 'Security model', fr: 'Modèle de sécurité'),
    introduction: GuideText(
      en: 'OSIA combines local ownership, authenticated transports, least privilege and explicit confirmation at sensitive boundaries.',
      fr: 'OSIA combine propriété locale, transports authentifiés, moindre privilège et confirmation explicite aux frontières sensibles.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Pairing establishes mobile trust, device identity and session keys; encrypted transports protect content, while a blind Worker relay routes ciphertext without plaintext. Secrets stay in ignored stores or approved bindings, logs are redacted, files are validated, and replay/sequence guards reject stale traffic. Tools are allowlisted and risky actions require confirmation; unattended connectors are stricter. Signed metadata, size and SHA-256 protect update integrity. External AI providers still receive content required for configured requests under their own policies.',
        fr: 'L’association établit confiance mobile, identité et clés de session ; les transports chiffrés protègent le contenu, tandis qu’un relais Worker aveugle route le chiffré sans texte clair. Les secrets restent dans des magasins ignorés ou bindings approuvés, les journaux sont masqués, les fichiers validés et les gardes de rejeu/séquence refusent l’ancien trafic. Les outils sont autorisés explicitement et les actions risquées demandent confirmation. Métadonnées signées, taille et SHA-256 protègent l’intégrité des mises à jour. Les fournisseurs IA externes reçoivent néanmoins le contenu nécessaire selon leurs règles.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Threat-model a stolen pairing token, replayed frame, malicious filename, compromised provider key and untrusted MCP write separately.',
      fr: 'Modélisez séparément vol de jeton d’association, trame rejouée, nom malveillant, clé fournisseur compromise et écriture MCP non fiable.',
    ),
    remember: GuideText(
      en: 'Encryption in transit does not replace endpoint security, backups or provider governance.',
      fr: 'Le chiffrement en transit ne remplace ni sécurité des terminaux, ni sauvegardes, ni gouvernance fournisseur.',
    ),
  ),
  GuideLesson(
    id: 'advanced.developer-troubleshooting',
    categoryId: guideAdvancedCategoryId,
    order: 37,
    subjectId: 'developer-troubleshooting',
    glossaryIds: <String>['request-id', 'sequence-number', 'hash', 'artifact'],
    title: GuideText(
      en: 'Developer troubleshooting',
      fr: 'Dépannage développeur',
    ),
    introduction: GuideText(
      en: 'Troubleshooting follows the failing boundary from observable symptom to the smallest reproducible contract.',
      fr: 'Le dépannage suit la frontière défaillante depuis le symptôme observable jusqu’au plus petit contrat reproductible.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'For startup, distinguish a port conflict, stale process, wrong profile, missing frozen import or missing PyInstaller asset. For mobile, separate pairing mismatch, WebSocket disconnect, ICE or STUN failure, expected relay fallback and a duplicate handshake. For Android, check app-signature mismatch and versionCode conflict. For tests, identify developer-profile dependence and any runtime file appearing unexpectedly in source. For providers, distinguish image rejection from authentication/quota; for schedules, verify syntax, due time and that the PC was running. Sanitize logs and preserve evidence before cleanup.',
        fr: 'Au démarrage, distinguez conflit de port, processus obsolète, mauvais profil, import frozen manquant ou asset PyInstaller absent. Pour le mobile, séparez association incohérente, déconnexion WebSocket, échec ICE ou STUN, repli normal vers le relais et handshake dupliqué. Pour Android, vérifiez signature d’app et conflit versionCode. Pour les tests, repérez la dépendance au profil développeur et tout fichier d’exécution apparu dans les sources. Pour les fournisseurs, distinguez rejet d’image et auth/quota ; pour les tâches, vérifiez syntaxe, échéance et PC actif. Masquez les journaux et conservez les preuves.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'Reduce a reconnect failure to one synthetic request ID and timeline before changing retry code.',
      fr: 'Réduisez un échec de reconnexion à un identifiant de requête et une chronologie fictifs avant de modifier les tentatives.',
    ),
    remember: GuideText(
      en: 'Do not treat a retry that hides duplication or data loss as a fix.',
      fr: 'Ne considérez pas comme correctif une nouvelle tentative qui masque duplication ou perte de données.',
    ),
  ),
  GuideLesson(
    id: 'advanced.glossary',
    categoryId: guideAdvancedCategoryId,
    order: 38,
    subjectId: 'glossary',
    glossaryIds: <String>[
      'provider',
      'model',
      'api',
      'token',
      'context',
      'thinking',
      'mcp',
      'dcr',
      'oauth',
      'cron',
      'websocket',
      'e2e',
      'lan',
      'p2p',
      'webrtc',
      'sdp',
      'ice',
      'stun',
      'turn',
      'signaling',
      'relay',
      'durable-object',
      'hibernation',
      'chunking',
      'hash',
      'mime',
      'abi',
      'apk',
      'aab',
      'r8',
      'pyinstaller',
      'inno-setup',
      'r2',
      'rollout',
      'version-name',
      'version-code',
    ],
    title: GuideText(en: 'Glossary', fr: 'Glossaire'),
    introduction: GuideText(
      en: 'Stable terms make the guide, UI, protocol tests and release evidence easier to compare.',
      fr: 'Des termes stables facilitent la comparaison entre guide, interface, tests de protocole et preuves de livraison.',
    ),
    paragraphs: <GuideText>[
      GuideText(
        en: 'Provider: service exposing models; model: selected AI implementation; API: programmatic service contract; token: bounded credential or model text unit, by context; context: input retained for a model turn; thinking: supported reasoning effort; MCP: Model Context Protocol; DCR: OAuth dynamic client registration; OAuth: delegated authorization; cron: schedule expression; WebSocket: persistent bidirectional connection.',
        fr: 'Fournisseur : service exposant des modèles ; modèle : implémentation IA choisie ; API : contrat programmable ; token : identifiant borné ou unité de texte selon le contexte ; contexte : entrée d’un tour ; thinking : effort de raisonnement pris en charge ; MCP : Model Context Protocol ; DCR : enregistrement dynamique OAuth ; OAuth : autorisation déléguée ; cron : expression de planification ; WebSocket : connexion bidirectionnelle persistante.',
      ),
      GuideText(
        en: 'E2E: endpoint-to-endpoint encryption; LAN: local area network; P2P: direct peer-to-peer path; WebRTC: real-time peer transport; SDP: WebRTC session description; ICE: WebRTC connectivity process; STUN: public-path discovery; TURN: WebRTC relay service; signaling: offer, answer and candidate exchange.',
        fr: 'E2E : chiffrement de bout en bout ; LAN : réseau local ; P2P : chemin direct entre pairs ; WebRTC : transport temps réel entre pairs ; SDP : description de session WebRTC ; ICE : recherche de connectivité ; STUN : découverte du chemin public ; TURN : relais WebRTC ; signalisation : échange offre, réponse et candidats.',
      ),
      GuideText(
        en: 'Relay: routed fallback path; Durable Object: stateful Worker coordination unit; hibernation: suspended object with resumable sockets; chunking: splitting a file for transport; hash: integrity digest; MIME: declared media type; ABI: native application binary interface; APK: installable Android package; AAB: Android App Bundle for stores; R8: Android shrinker and obfuscator.',
        fr: 'Relais : chemin de repli routé ; Durable Object : unité Worker à état ; hibernation : objet suspendu avec sockets reprenables ; chunking : découpage pour transport ; hash : empreinte d’intégrité ; MIME : type de média déclaré ; ABI : interface binaire native ; APK : paquet Android installable ; AAB : Android App Bundle pour les stores ; R8 : réduction et obfuscation Android.',
      ),
      GuideText(
        en: 'PyInstaller: Python application packager; Inno Setup: Windows installer builder; R2: object storage; rollout: staged release exposure; versionName: Android user version; versionCode: Android upload integer.',
        fr: 'PyInstaller : empaqueteur Python ; Inno Setup : créateur d’installateur Windows ; R2 : stockage objet ; rollout : exposition progressive ; versionName : version Android visible ; versionCode : entier Android d’envoi.',
      ),
    ],
    exampleTitle: GuideText(en: 'In practice', fr: 'En pratique'),
    example: GuideText(
      en: 'When a protocol field and UI label differ, document the mapping instead of silently using both words as synonyms.',
      fr: 'Si un champ protocolaire et un libellé UI diffèrent, documentez la correspondance au lieu d’en faire discrètement des synonymes.',
    ),
    remember: GuideText(
      en: 'Definitions describe OSIA’s usage; external standards remain authoritative for their specifications.',
      fr: 'Ces définitions décrivent l’usage d’OSIA ; les normes externes restent l’autorité pour leurs spécifications.',
    ),
  ),
];

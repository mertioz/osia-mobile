import 'guide_model.dart';

/// A short, Mobile-only introduction. The shared PC manual stays authoritative
/// for detailed help; these slides do not count as visits to manual lessons.
class OnboardingSlide {
  const OnboardingSlide(this.id, this.title, this.body);

  final String id;
  final GuideText title;
  final GuideText body;
}

const onboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    'welcome',
    GuideText(en: 'Welcome to OSIA', fr: 'Bienvenue sur OSIA'),
    GuideText(
      en: 'Your AI assistant,\non your phone and computer.',
      fr: 'Votre assistant IA,\nsur téléphone et ordinateur.',
    ),
  ),
  OnboardingSlide(
    'computer',
    GuideText(
      en: 'One assistant, two screens',
      fr: 'Un assistant, deux écrans',
    ),
    GuideText(
      en: 'Keep OSIA open on your PC\nto use it from your phone.',
      fr: 'Gardez OSIA ouvert sur le PC\npour l’utiliser sur votre téléphone.',
    ),
  ),
  OnboardingSlide(
    'install',
    GuideText(en: 'Start on your computer', fr: 'D’abord, sur votre PC'),
    GuideText(
      en: 'Install OSIA from osia.space,\nthen open it on your computer.',
      fr: 'Installez OSIA depuis osia.space,\npuis ouvrez-le sur votre PC.',
    ),
  ),
  OnboardingSlide(
    'pc-code',
    GuideText(
      en: 'Find your connection code',
      fr: 'Trouvez le code de connexion',
    ),
    GuideText(
      en: 'On PC: open Settings, then\nConnection / Mobile.',
      fr: 'Sur PC : Réglages, puis\nConnexion / Mobile.',
    ),
  ),
  OnboardingSlide(
    'connect',
    GuideText(en: 'Connect your phone', fr: 'Connectez votre téléphone'),
    GuideText(
      en: 'In the app, scan the QR code\nor paste the PC token.',
      fr: 'Dans l’app, scannez le QR code\nou collez le code de votre PC.',
    ),
  ),
  OnboardingSlide(
    'chat',
    GuideText(en: 'Chat naturally', fr: 'Parlez simplement'),
    GuideText(
      en: 'Ask a question or describe\nwhat you need help with.',
      fr: 'Posez une question ou dites\nce dont vous avez besoin.',
    ),
  ),
  OnboardingSlide(
    'actions',
    GuideText(en: 'More than chat', fr: 'Plus qu’une conversation'),
    GuideText(
      en: 'OSIA can also take action\nwith the tools you set up.',
      fr: 'OSIA peut aussi agir grâce\naux outils que vous configurez.',
    ),
  ),
  OnboardingSlide(
    'settings',
    GuideText(en: 'Make OSIA yours', fr: 'Réglez OSIA à votre goût'),
    GuideText(
      en: 'Open Settings for language,\nvoice and AI services.',
      fr: 'Dans Paramètres : langue,\nvoix et services d’IA.',
    ),
  ),
  OnboardingSlide(
    'support',
    GuideText(
      en: 'Support OSIA if you want',
      fr: 'Soutenez OSIA si vous voulez',
    ),
    GuideText(
      en: 'Donations are optional.\nThey help OSIA grow.',
      fr: 'Les dons sont facultatifs.\nIls aident OSIA à grandir.',
    ),
  ),
  OnboardingSlide(
    'ready',
    GuideText(en: 'You’re ready', fr: 'Tout est prêt pour commencer'),
    GuideText(
      en: 'Connect to your PC,\nthen send your first message.',
      fr: 'Connectez-vous à votre PC,\npuis envoyez un premier message.',
    ),
  ),
];

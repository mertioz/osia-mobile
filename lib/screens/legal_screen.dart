import 'package:flutter/material.dart';
import '../theme.dart';

/// Simple text screen for legal pages (ToS / Privacy Policy).
class LegalScreen extends StatelessWidget {
  final String title;
  final String body;
  const LegalScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: palette.textPrimary.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

const String osiaTermsOfService = '''
Conditions d'utilisation — OSIA Mobile

Bienvenue sur OSIA Mobile. En utilisant cette application, vous acceptez les conditions ci-dessous.

1. Service
OSIA Mobile est un client compagnon qui se connecte à votre propre serveur OSIA. L'application ne fournit pas de service distant : tous les traitements sont effectués par votre serveur, sous votre contrôle.

2. Connexion
Vous êtes responsable de la configuration de l'adresse de votre serveur et du jeton d'authentification. Conservez ce jeton en lieu sûr ; toute personne y ayant accès peut commander votre serveur.

3. Utilisation appropriée
N'utilisez pas l'application pour des activités illégales ou portant atteinte aux droits d'autrui. L'application est fournie « telle quelle », sans garantie d'aucune sorte.

4. Limitation de responsabilité
Les auteurs ne pourront être tenus responsables de tout dommage, direct ou indirect, résultant de l'utilisation de l'application.

5. Modifications
Ces conditions peuvent évoluer avec les versions futures de l'application. La poursuite de l'utilisation vaut acceptation des nouvelles conditions.

6. Contact
Pour toute question, contactez l'administrateur de votre serveur OSIA.
''';

const String osiaPrivacyPolicy = '''
Politique de confidentialité — OSIA Mobile

OSIA Mobile est conçu autour d'un principe simple : vos données restent chez vous.

1. Données traitées localement
L'adresse de votre serveur, votre jeton d'authentification, votre thème et le modèle sélectionné sont stockés exclusivement sur votre appareil, via le coffre-fort sécurisé du système d'exploitation (Keychain / Keystore).

2. Données envoyées au serveur
Les messages, transcriptions et fichiers audio que vous envoyez transitent directement de votre appareil à votre serveur OSIA. Aucun tiers ne reçoit ces données.

3. Aucune télémétrie
L'application n'envoie aucune donnée d'analyse, de mesure d'audience ou de plantage à un tiers.

4. Permissions
- Microphone : utilisé uniquement lorsque vous enregistrez un message vocal.
- Réseau : utilisé pour établir la connexion WebSocket avec votre serveur.

5. Conservation
Les conversations sont conservées par votre serveur, selon la configuration que vous y avez choisie. Vous pouvez supprimer une conversation depuis le menu latéral.

6. Suppression
Le bouton « Se déconnecter » de l'écran Paramètres efface immédiatement votre adresse de serveur, votre jeton et le modèle mémorisé de l'appareil.

7. Contact
Pour toute demande relative à vos données, adressez-vous à l'administrateur de votre serveur OSIA.
''';

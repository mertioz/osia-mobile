import 'package:flutter/material.dart';
import '../l10n.dart';
import '../theme.dart';

/// Which legal document to display.
enum LegalDocument { termsOfService, privacyPolicy }

/// Simple text screen for legal pages (ToS / Privacy Policy).
///
/// The title and body follow the app's active language.
class LegalScreen extends StatelessWidget {
  final LegalDocument document;
  const LegalScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);

    final title = document == LegalDocument.termsOfService
        ? strings.termsOfService
        : strings.privacyPolicy;
    final body = document == LegalDocument.termsOfService
        ? osiaTermsOfServiceFor(strings.languageCode)
        : osiaPrivacyPolicyFor(strings.languageCode);

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

// ── Localized bodies ──────────────────────────────────────────────────────

/// Terms of Service body for [languageCode], falling back to English.
String osiaTermsOfServiceFor(String languageCode) =>
    _termsOfService[languageCode] ?? _termsOfService['en']!;

/// Privacy Policy body for [languageCode], falling back to English.
String osiaPrivacyPolicyFor(String languageCode) =>
    _privacyPolicy[languageCode] ?? _privacyPolicy['en']!;

const Map<String, String> _termsOfService = {
  'en': '''
Terms of Service — OSIA Mobile

Welcome to OSIA Mobile. By using this application, you accept the terms below.

1. Service
OSIA Mobile is a companion client that connects to your own OSIA server. The application provides no remote service of its own: all processing happens on your server, under your control.

2. Connection
You are responsible for your authentication token. Keep it safe; anyone with access to it can control your server.

3. Appropriate use
Do not use the application for illegal activities or activities that infringe on the rights of others. The application is provided "as is", without warranty of any kind.

4. Limitation of liability
The authors cannot be held liable for any damage, direct or indirect, resulting from the use of the application.

5. Changes
These terms may evolve with future versions of the application. Continued use constitutes acceptance of the new terms.

6. Contact
For any questions, contact the administrator of your OSIA server.
''',
  'fr': '''
Conditions d'utilisation — OSIA Mobile

Bienvenue sur OSIA Mobile. En utilisant cette application, vous acceptez les conditions ci-dessous.

1. Service
OSIA Mobile est un client compagnon qui se connecte à votre propre serveur OSIA. L'application ne fournit pas de service distant : tous les traitements sont effectués par votre serveur, sous votre contrôle.

2. Connexion
Vous êtes responsable de votre jeton d'authentification. Conservez-le en lieu sûr ; toute personne y ayant accès peut commander votre serveur.

3. Utilisation appropriée
N'utilisez pas l'application pour des activités illégales ou portant atteinte aux droits d'autrui. L'application est fournie « telle quelle », sans garantie d'aucune sorte.

4. Limitation de responsabilité
Les auteurs ne pourront être tenus responsables de tout dommage, direct ou indirect, résultant de l'utilisation de l'application.

5. Modifications
Ces conditions peuvent évoluer avec les versions futures de l'application. La poursuite de l'utilisation vaut acceptation des nouvelles conditions.

6. Contact
Pour toute question, contactez l'administrateur de votre serveur OSIA.
''',
  'zh': '''
服务条款 — OSIA Mobile

欢迎使用 OSIA Mobile。使用本应用即表示您接受以下条款。

1. 服务
OSIA Mobile 是一个连接到您自己的 OSIA 服务器的配套客户端。本应用本身不提供任何远程服务：所有处理均在您的服务器上进行，由您掌控。

2. 连接
您对您的身份验证令牌负责。请妥善保管；任何持有该令牌的人都可以控制您的服务器。

3. 合理使用
请勿将本应用用于非法活动或侵犯他人权利的活动。本应用按"原样"提供，不附带任何形式的保证。

4. 责任限制
对于因使用本应用而导致的任何直接或间接损害，作者概不负责。

5. 变更
这些条款可能随应用的未来版本而变化。继续使用即表示接受新条款。

6. 联系方式
如有任何疑问，请联系您的 OSIA 服务器管理员。
''',
  'ja': '''
利用規約 — OSIA Mobile

OSIA Mobile へようこそ。本アプリケーションを使用することにより、以下の規約に同意したものとみなされます。

1. サービス
OSIA Mobile は、ご自身の OSIA サーバーに接続するコンパニオンクライアントです。本アプリ自体はリモートサービスを提供しません。すべての処理はお客様の管理下にあるサーバーで行われます。

2. 接続
認証トークンの管理はお客様の責任です。安全に保管してください。トークンにアクセスできる人は誰でもサーバーを操作できます。

3. 適切な使用
違法行為や他者の権利を侵害する行為に本アプリを使用しないでください。本アプリは「現状のまま」提供され、いかなる保証もありません。

4. 責任の制限
本アプリの使用に起因する直接的または間接的な損害について、作者は一切の責任を負いません。

5. 変更
これらの規約は、アプリの将来のバージョンで変更される場合があります。継続して使用することは、新しい規約への同意を意味します。

6. お問い合わせ
ご質問がある場合は、OSIA サーバーの管理者にお問い合わせください。
''',
  'de': '''
Nutzungsbedingungen — OSIA Mobile

Willkommen bei OSIA Mobile. Durch die Nutzung dieser Anwendung akzeptieren Sie die nachstehenden Bedingungen.

1. Dienst
OSIA Mobile ist ein Begleit-Client, der sich mit Ihrem eigenen OSIA-Server verbindet. Die Anwendung stellt selbst keinen Remote-Dienst bereit: Die gesamte Verarbeitung erfolgt auf Ihrem Server, unter Ihrer Kontrolle.

2. Verbindung
Sie sind für Ihr Authentifizierungs-Token verantwortlich. Bewahren Sie es sicher auf; jeder, der Zugriff darauf hat, kann Ihren Server steuern.

3. Angemessene Nutzung
Verwenden Sie die Anwendung nicht für illegale Aktivitäten oder Aktivitäten, die die Rechte anderer verletzen. Die Anwendung wird „wie besehen" bereitgestellt, ohne jegliche Gewährleistung.

4. Haftungsbeschränkung
Die Autoren haften nicht für direkte oder indirekte Schäden, die aus der Nutzung der Anwendung entstehen.

5. Änderungen
Diese Bedingungen können sich mit zukünftigen Versionen der Anwendung ändern. Die fortgesetzte Nutzung gilt als Annahme der neuen Bedingungen.

6. Kontakt
Bei Fragen wenden Sie sich an den Administrator Ihres OSIA-Servers.
''',
  'es': '''
Términos de servicio — OSIA Mobile

Bienvenido a OSIA Mobile. Al usar esta aplicación, aceptas los términos siguientes.

1. Servicio
OSIA Mobile es un cliente complementario que se conecta a tu propio servidor OSIA. La aplicación no proporciona ningún servicio remoto propio: todo el procesamiento se realiza en tu servidor, bajo tu control.

2. Conexión
Eres responsable de tu token de autenticación. Guárdalo en un lugar seguro; cualquier persona con acceso a él puede controlar tu servidor.

3. Uso apropiado
No utilices la aplicación para actividades ilegales o que infrinjan los derechos de terceros. La aplicación se proporciona «tal cual», sin garantía de ningún tipo.

4. Limitación de responsabilidad
Los autores no serán responsables de ningún daño, directo o indirecto, derivado del uso de la aplicación.

5. Modificaciones
Estos términos pueden evolucionar con futuras versiones de la aplicación. El uso continuado constituye la aceptación de los nuevos términos.

6. Contacto
Para cualquier pregunta, contacta con el administrador de tu servidor OSIA.
''',
};

const Map<String, String> _privacyPolicy = {
  'en': '''
Privacy Policy — OSIA Mobile

OSIA Mobile is built around a simple principle: your data stays with you.

1. Data processed locally
Your authentication token, theme, language and selected model are stored exclusively on your device, in the operating system's secure vault (Keychain / Keystore).

2. Data sent to the server
The messages, transcriptions and audio files you send travel directly from your device to your OSIA server. No third party receives this data.

3. No telemetry
The application sends no analytics, audience measurement or crash data to any third party.

4. Permissions
- Microphone: used only when you record a voice message.
- Network: used to establish the WebSocket connection to your server.

5. Retention
Conversations are kept by your server, according to the configuration you chose there. You can delete a conversation from the side menu.

6. Deletion
The "Disconnect" button in Settings immediately erases your token and remembered model from the device.

7. Contact
For any request regarding your data, contact the administrator of your OSIA server.
''',
  'fr': '''
Politique de confidentialité — OSIA Mobile

OSIA Mobile est conçu autour d'un principe simple : vos données restent chez vous.

1. Données traitées localement
Votre jeton d'authentification, votre thème, votre langue et le modèle sélectionné sont stockés exclusivement sur votre appareil, via le coffre-fort sécurisé du système d'exploitation (Keychain / Keystore).

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
Le bouton « Se déconnecter » de l'écran Paramètres efface immédiatement votre jeton et le modèle mémorisé de l'appareil.

7. Contact
Pour toute demande relative à vos données, adressez-vous à l'administrateur de votre serveur OSIA.
''',
  'zh': '''
隐私政策 — OSIA Mobile

OSIA Mobile 的设计基于一个简单的原则：您的数据属于您自己。

1. 本地处理的数据
您的身份验证令牌、主题、语言和所选模型仅存储在您的设备上，使用操作系统的安全保管库（Keychain / Keystore）。

2. 发送到服务器的数据
您发送的消息、转录和音频文件直接从您的设备传输到您的 OSIA 服务器。没有第三方会收到这些数据。

3. 无遥测
本应用不会向任何第三方发送分析数据、受众测量数据或崩溃数据。

4. 权限
- 麦克风：仅在您录制语音消息时使用。
- 网络：用于与您的服务器建立 WebSocket 连接。

5. 数据保留
对话由您的服务器根据您选择的配置保存。您可以从侧边菜单中删除对话。

6. 删除
设置中的"断开连接"按钮会立即从设备上清除您的令牌和记住的模型。

7. 联系方式
有关您数据的任何请求，请联系您的 OSIA 服务器管理员。
''',
  'ja': '''
プライバシーポリシー — OSIA Mobile

OSIA Mobile は、シンプルな原則に基づいて設計されています：あなたのデータはあなたのもとに残ります。

1. ローカルで処理されるデータ
認証トークン、テーマ、言語、選択したモデルは、お使いのデバイスのみに、オペレーティングシステムの安全な保管庫（Keychain / Keystore）を介して保存されます。

2. サーバーに送信されるデータ
送信するメッセージ、文字起こし、音声ファイルは、デバイスから OSIA サーバーへ直接転送されます。第三者がこれらのデータを受け取ることはありません。

3. テレメトリーなし
本アプリは、分析データ、利用状況測定データ、クラッシュデータを第三者に送信しません。

4. 権限
- マイク：音声メッセージを録音するときのみ使用されます。
- ネットワーク：サーバーとの WebSocket 接続を確立するために使用されます。

5. データの保持
会話は、サーバー側で選択した設定に従って保存されます。サイドメニューから会話を削除できます。

6. 削除
設定の「切断」ボタンを押すと、トークンと記憶されたモデルがデバイスから直ちに消去されます。

7. お問い合わせ
データに関するご要望は、OSIA サーバーの管理者にお問い合わせください。
''',
  'de': '''
Datenschutzerklärung — OSIA Mobile

OSIA Mobile basiert auf einem einfachen Prinzip: Ihre Daten bleiben bei Ihnen.

1. Lokal verarbeitete Daten
Ihr Authentifizierungs-Token, Ihr Thema, Ihre Sprache und das ausgewählte Modell werden ausschließlich auf Ihrem Gerät gespeichert, im sicheren Tresor des Betriebssystems (Keychain / Keystore).

2. An den Server gesendete Daten
Die Nachrichten, Transkriptionen und Audiodateien, die Sie senden, werden direkt von Ihrem Gerät an Ihren OSIA-Server übertragen. Kein Dritter erhält diese Daten.

3. Keine Telemetrie
Die Anwendung sendet keine Analyse-, Reichweitenmessungs- oder Absturzdaten an Dritte.

4. Berechtigungen
- Mikrofon: wird nur verwendet, wenn Sie eine Sprachnachricht aufnehmen.
- Netzwerk: wird verwendet, um die WebSocket-Verbindung zu Ihrem Server herzustellen.

5. Aufbewahrung
Unterhaltungen werden von Ihrem Server gemäß der dort gewählten Konfiguration aufbewahrt. Sie können eine Unterhaltung über das Seitenmenü löschen.

6. Löschung
Die Schaltfläche „Trennen" in den Einstellungen löscht Ihr Token und das gespeicherte Modell sofort vom Gerät.

7. Kontakt
Für Anfragen zu Ihren Daten wenden Sie sich an den Administrator Ihres OSIA-Servers.
''',
  'es': '''
Política de privacidad — OSIA Mobile

OSIA Mobile está diseñado en torno a un principio simple: tus datos se quedan contigo.

1. Datos procesados localmente
Tu token de autenticación, tu tema, tu idioma y el modelo seleccionado se almacenan exclusivamente en tu dispositivo, mediante el almacén seguro del sistema operativo (Keychain / Keystore).

2. Datos enviados al servidor
Los mensajes, transcripciones y archivos de audio que envías viajan directamente desde tu dispositivo a tu servidor OSIA. Ningún tercero recibe estos datos.

3. Sin telemetría
La aplicación no envía datos de análisis, de medición de audiencia ni de fallos a ningún tercero.

4. Permisos
- Micrófono: se usa solo cuando grabas un mensaje de voz.
- Red: se usa para establecer la conexión WebSocket con tu servidor.

5. Conservación
Las conversaciones las conserva tu servidor, según la configuración que hayas elegido allí. Puedes eliminar una conversación desde el menú lateral.

6. Eliminación
El botón «Desconectar» de Ajustes borra inmediatamente tu token y el modelo recordado del dispositivo.

7. Contacto
Para cualquier solicitud relacionada con tus datos, dirígete al administrador de tu servidor OSIA.
''',
};

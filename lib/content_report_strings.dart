import 'l10n.dart';

extension ContentReportStrings on OsiaStrings {
  String _text(
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

  String get reportContent => _text(
    'Report response',
    'Signaler la réponse',
    '举报回复',
    '回答を報告',
    'Antwort melden',
    'Denunciar respuesta',
  );
  String get reportDisclosure => _text(
    'Send only the text and note shown below to OSIA support. You can edit or remove private information first. Reports are stored for up to 30 days. Your conversation history, files and pairing credentials are not attached.',
    'Envoyez uniquement le texte et la note ci-dessous à l’assistance OSIA. Vous pouvez d’abord retirer les informations privées. Les signalements sont conservés jusqu’à 30 jours. L’historique, les fichiers et les identifiants d’association ne sont pas joints.',
    '仅将下方文字和备注发送给 OSIA 支持。请先编辑或删除私人信息。举报最多保存 30 天，不附加聊天记录、文件或配对凭据。',
    '以下の文章とメモのみを OSIA サポートに送信します。個人情報は先に編集・削除できます。報告は最大30日間保存され、会話履歴、ファイル、ペアリング情報は添付されません。',
    'Nur der folgende Text und die Notiz werden an den OSIA-Support gesendet. Entferne vorher private Informationen. Meldungen werden bis zu 30 Tage gespeichert. Verlauf, Dateien und Kopplungsdaten werden nicht angehängt.',
    'Envía solo el texto y la nota siguientes al soporte de OSIA. Puedes eliminar antes los datos privados. Los informes se guardan hasta 30 días. No se adjuntan el historial, los archivos ni las credenciales de vinculación.',
  );
  String get reportText => _text(
    'Text to send (editable)',
    'Texte à envoyer (modifiable)',
    '要发送的文字（可编辑）',
    '送信する文章（編集可能）',
    'Zu sendender Text (bearbeitbar)',
    'Texto que se enviará (editable)',
  );
  String get reportNote => _text(
    'Optional note',
    'Note facultative',
    '备注（可选）',
    'メモ（任意）',
    'Optionale Notiz',
    'Nota opcional',
  );
  String get reportReason =>
      _text('Reason', 'Motif', '原因', '理由', 'Grund', 'Motivo');
  String get reportConsent => _text(
    'I reviewed this text and want to send it to OSIA.',
    'J’ai relu ce texte et souhaite l’envoyer à OSIA.',
    '我已检查文字并希望将其发送给 OSIA。',
    '内容を確認し、OSIA に送信します。',
    'Ich habe den Text geprüft und möchte ihn an OSIA senden.',
    'He revisado el texto y quiero enviarlo a OSIA.',
  );
  String get reportSend => _text(
    'Send report',
    'Envoyer le signalement',
    '发送举报',
    '報告を送信',
    'Meldung senden',
    'Enviar denuncia',
  );
  String get reportReceived => _text(
    'Report received. Keep this reference if you contact support.',
    'Signalement reçu. Conservez cette référence pour contacter l’assistance.',
    '举报已收到。联系支持时请保留此编号。',
    '報告を受信しました。お問い合わせの際はこの番号をご利用ください。',
    'Meldung eingegangen. Bewahre diese Referenz für den Support auf.',
    'Denuncia recibida. Guarda esta referencia para contactar con soporte.',
  );
  String get reportUnconfirmed => _text(
    'We could not confirm receipt. Please try again later.',
    'La réception n’a pas pu être confirmée. Réessayez plus tard.',
    '无法确认是否收到。请稍后重试。',
    '受信を確認できませんでした。後でもう一度お試しください。',
    'Der Eingang konnte nicht bestätigt werden. Bitte später erneut versuchen.',
    'No se pudo confirmar la recepción. Inténtalo más tarde.',
  );
  String reportCategory(String category) => switch (category) {
    'harmful' => _text(
      'Harmful or abusive',
      'Nuisible ou abusif',
      '有害或辱骂',
      '有害・不適切',
      'Schädlich oder beleidigend',
      'Dañino o abusivo',
    ),
    'sexual' => _text(
      'Sexual content',
      'Contenu sexuel',
      '色情内容',
      '性的な内容',
      'Sexueller Inhalt',
      'Contenido sexual',
    ),
    'violence' => _text(
      'Violence',
      'Violence',
      '暴力',
      '暴力',
      'Gewalt',
      'Violencia',
    ),
    'deceptive' => _text(
      'Deceptive content',
      'Contenu trompeur',
      '欺骗性内容',
      '誤解を招く内容',
      'Irreführender Inhalt',
      'Contenido engañoso',
    ),
    _ => _text('Other', 'Autre', '其他', 'その他', 'Sonstiges', 'Otro'),
  };
}

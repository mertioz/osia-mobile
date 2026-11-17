/// Read-only projection of the PC's status snapshot. No usage/cost estimation
/// or account quota accounting is performed on Mobile.
class ChatStatusSnapshot {
  final String connection;
  final String modelLabel;
  final int? contextUsed;
  final int? contextMaximum;
  final bool contextEstimated;
  final bool quotaAvailable;
  final List<(String, double)> quotaWindows;
  final int? totalTokens;
  final double? costUsd;
  final List<ChatStatusModelUsage> models;
  final bool visibleTextEstimate;

  const ChatStatusSnapshot._({
    required this.connection,
    required this.modelLabel,
    this.contextUsed,
    this.contextMaximum,
    this.contextEstimated = false,
    this.quotaAvailable = false,
    this.quotaWindows = const [],
    this.totalTokens,
    this.costUsd,
    this.models = const [],
    this.visibleTextEstimate = false,
  });

  factory ChatStatusSnapshot.fromJson(Map<String, dynamic> value) {
    if (value['schema_version'] != 1 || value['command_id'] != 'status.info') {
      throw const FormatException('Unsupported chat status snapshot');
    }
    final connection = value['connection'];
    if (connection != 'account' &&
        connection != 'api' &&
        connection != 'local') {
      throw const FormatException('Invalid chat status connection');
    }
    final model = _map(value['model']);
    final context = _map(value['context']);
    final quota = _map(value['quota']);
    final usage = _map(value['usage']);
    final windows = <(String, double)>[];
    if (connection == 'account' && quota['state'] == 'available') {
      for (final raw in _list(quota['windows'])) {
        final item = _map(raw);
        final remaining = _number(item['remaining_percent']);
        if (remaining != null && remaining <= 100) {
          windows.add((_text(item['label']), remaining));
        }
      }
    }
    return ChatStatusSnapshot._(
      connection: connection as String,
      modelLabel: _text(model['label']).isNotEmpty
          ? _text(model['label'])
          : _text(model['id']),
      contextUsed: _integer(context['used']),
      contextMaximum: _positiveInteger(context['maximum']),
      contextEstimated: context['estimated'] != false,
      quotaAvailable: windows.isNotEmpty,
      quotaWindows: List.unmodifiable(windows),
      totalTokens: connection == 'account'
          ? null
          : _integer(usage['total_tokens']),
      costUsd: connection == 'api' && usage['currency'] == 'USD'
          ? _number(usage['cost_usd'])
          : null,
      models: connection == 'account'
          ? const []
          : List.unmodifiable([
              for (final raw in _list(usage['models']))
                ChatStatusModelUsage.fromJson(
                  _map(raw),
                  allowCost: connection == 'api' && usage['currency'] == 'USD',
                ),
            ]),
      visibleTextEstimate:
          connection == 'api' && usage['basis'] == 'visible_conversation',
    );
  }

  /// Only the requested model/context/quota or estimated usage/cost are shown.
  List<(String, String)> rows({required bool french}) {
    final unavailable = french ? 'Indisponible' : 'Unavailable';
    final context = contextUsed == null || contextMaximum == null
        ? unavailable
        : '${contextEstimated ? '≈ ' : ''}${_tokens(contextUsed!)} / ${_tokens(contextMaximum!)} tokens';
    return [
      (
        french ? 'Modèle' : 'Model',
        modelLabel.isEmpty ? unavailable : modelLabel,
      ),
      (french ? 'Contexte' : 'Context', context),
      if (connection == 'account') ...[
        if (!quotaAvailable)
          (french ? 'Quota restant' : 'Remaining quota', unavailable)
        else
          for (final (label, remaining) in quotaWindows)
            (
              label.isEmpty
                  ? (french ? 'Quota restant' : 'Remaining quota')
                  : '${french ? 'Quota restant' : 'Remaining quota'} · $label',
              '${_decimal(remaining)} %',
            ),
      ] else ...[
        (
          french ? 'Tokens utilisés (estimation)' : 'Tokens used (estimate)',
          totalTokens == null ? unavailable : '≈ ${_tokens(totalTokens!)}',
        ),
        (
          french ? 'Coût (estimation)' : 'Cost (estimate)',
          costUsd == null ? unavailable : '≈ ${_money(costUsd!)} USD',
        ),
        for (final item in models)
          (
            item.label.isEmpty ? (french ? 'Modèle' : 'Model') : item.label,
            '${item.totalTokens == null ? unavailable : '≈ ${_tokens(item.totalTokens!)} tokens'} · '
                '${item.costUsd == null ? (french ? 'tarif indisponible' : 'pricing unavailable') : '≈ ${_money(item.costUsd!)} USD'}',
          ),
      ],
    ];
  }

  String? estimateNotice({required bool french}) => !visibleTextEstimate
      ? null
      : french
      ? 'Estimation basée sur le texte visible. L’activité non enregistrée '
            '(outils et raisonnement) n’est pas incluse.'
      : 'Estimate based on visible text. Unrecorded activity '
            '(tools and reasoning) is not included.';
}

class ChatStatusModelUsage {
  final String label;
  final int? totalTokens;
  final double? costUsd;

  const ChatStatusModelUsage(this.label, this.totalTokens, this.costUsd);

  factory ChatStatusModelUsage.fromJson(
    Map<String, dynamic> value, {
    required bool allowCost,
  }) {
    final model = _map(value['model']);
    final label = _text(model['label']);
    return ChatStatusModelUsage(
      label.isEmpty ? _text(model['id']) : label,
      _integer(value['total_tokens']),
      allowCost ? _number(value['cost_usd']) : null,
    );
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _text(Object? value) => value is String ? value : '';

int? _integer(Object? value) => value is int && value >= 0 ? value : null;

int? _positiveInteger(Object? value) =>
    value is int && value > 0 ? value : null;

double? _number(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value.toDouble() : null;

String _tokens(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => '\u202f',
);

String _decimal(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _money(double value) =>
    value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');

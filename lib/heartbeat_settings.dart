const String heartbeatEnabledSettingKey = 'heartbeat_enabled';
const String heartbeatIntervalSettingKey = 'heartbeat_interval_seconds';
const String heartbeatChecksSettingKey = 'heartbeat_checks';

const List<String> heartbeatThresholdMetricIds = ['cpu', 'ram', 'disk'];
const List<String> heartbeatMetricIds = ['cpu', 'ram', 'disk', 'network'];

class HeartbeatCheckSetting {
  final bool enabled;
  final int? threshold;

  const HeartbeatCheckSetting({required this.enabled, this.threshold});

  HeartbeatCheckSetting copyWith({bool? enabled, int? threshold}) {
    return HeartbeatCheckSetting(
      enabled: enabled ?? this.enabled,
      threshold: threshold ?? this.threshold,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'enabled': enabled};
    final value = threshold;
    if (value != null) json['threshold'] = value;
    return json;
  }
}

class HeartbeatSettings {
  static const int minIntervalSeconds = 10;
  static const int maxIntervalSeconds = 300;
  static const int defaultIntervalSeconds = 30;
  static const int minThreshold = 0;
  static const int maxThreshold = 100;

  static const Map<String, int> defaultThresholds = {
    'cpu': 80,
    'ram': 90,
    'disk': 10,
  };

  static const Map<String, HeartbeatCheckSetting> defaultChecks = {
    'cpu': HeartbeatCheckSetting(enabled: true, threshold: 80),
    'ram': HeartbeatCheckSetting(enabled: true, threshold: 90),
    'disk': HeartbeatCheckSetting(enabled: true, threshold: 10),
    'network': HeartbeatCheckSetting(enabled: true),
  };

  final bool enabled;
  final int intervalSeconds;
  final Map<String, HeartbeatCheckSetting> checks;

  const HeartbeatSettings({
    required this.enabled,
    required this.intervalSeconds,
    required this.checks,
  });

  factory HeartbeatSettings.fromSettings(Map<String, dynamic> settings) {
    final hasChecks = settings.containsKey(heartbeatChecksSettingKey);
    final checks = readChecks(
      settings[heartbeatChecksSettingKey],
      useDefaults: !hasChecks,
    );
    return HeartbeatSettings(
      enabled: settings[heartbeatEnabledSettingKey] == true,
      intervalSeconds: sanitizeInterval(settings[heartbeatIntervalSettingKey]),
      checks: checks,
    );
  }

  static Map<String, HeartbeatCheckSetting> readChecks(
    Object? raw, {
    required bool useDefaults,
  }) {
    final rawMap = raw is Map ? raw : null;
    return {
      for (final metric in heartbeatMetricIds)
        metric: _readCheck(metric, rawMap?[metric], useDefault: useDefaults),
    };
  }

  static HeartbeatCheckSetting _readCheck(
    String metric,
    Object? raw, {
    required bool useDefault,
  }) {
    final fallback = defaultChecks[metric]!;
    if (useDefault) return fallback;
    if (raw is! Map) {
      return HeartbeatCheckSetting(
        enabled: false,
        threshold: fallback.threshold,
      );
    }

    final threshold = fallback.threshold == null
        ? null
        : sanitizeThreshold(metric, raw['threshold']);
    return HeartbeatCheckSetting(
      enabled: raw['enabled'] == true,
      threshold: threshold,
    );
  }

  static int sanitizeInterval(Object? value) {
    final parsed = _readNumber(value)?.toInt();
    return (parsed ?? defaultIntervalSeconds)
        .clamp(minIntervalSeconds, maxIntervalSeconds)
        .toInt();
  }

  static int sanitizeThreshold(String metric, Object? value) {
    final fallback = defaultThresholds[metric] ?? minThreshold;
    final parsed = _readNumber(value)?.toInt();
    return (parsed ?? fallback).clamp(minThreshold, maxThreshold).toInt();
  }

  static num? _readNumber(Object? value) {
    if (value is num) return value;
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return num.tryParse(text);
  }

  HeartbeatSettings copyWith({
    bool? enabled,
    int? intervalSeconds,
    Map<String, HeartbeatCheckSetting>? checks,
  }) {
    return HeartbeatSettings(
      enabled: enabled ?? this.enabled,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      checks: checks ?? this.checks,
    );
  }

  HeartbeatSettings withMetricEnabled(String metric, bool enabled) {
    final current = checks[metric] ?? defaultChecks[metric];
    if (current == null) return this;
    return copyWith(
      checks: {
        ...checks,
        metric: current.copyWith(enabled: enabled),
      },
    );
  }

  HeartbeatSettings withThreshold(String metric, Object? value) {
    final current = checks[metric] ?? defaultChecks[metric];
    if (current == null || current.threshold == null) return this;
    return copyWith(
      checks: {
        ...checks,
        metric: current.copyWith(threshold: sanitizeThreshold(metric, value)),
      },
    );
  }

  Map<String, dynamic> checksForSettings() {
    return {
      for (final metric in heartbeatMetricIds)
        metric: (checks[metric] ?? defaultChecks[metric]!).toJson(),
    };
  }
}

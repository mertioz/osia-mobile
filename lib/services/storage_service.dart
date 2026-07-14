import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LanPairingIdentity {
  const LanPairingIdentity({
    required this.instanceAlias,
    required this.certificateSha256,
  });

  final String instanceAlias;
  final String certificateSha256;
}

/// Service for persisting sensitive settings: server host and auth token.
///
/// Uses [FlutterSecureStorage] so keys are stored in the platform keychain
/// (Android Keystore / iOS Keychain).
///
/// Reads are resilient to keystore changes (app reinstall / Android Keystore
/// rotation), which can leave previously-encrypted values undecryptable and
/// make the plugin throw a [PlatformException] (BadPaddingException /
/// BAD_DECRYPT). Every read goes through [_safeRead], which drops the
/// corrupted entry and returns a default instead of crashing the caller.
class StorageService {
  static const _keyTailscaleIp = 'osia_tailscale_ip';
  static const _keyToken = 'osia_token';
  static const _keyThemeKey = 'osia_theme_key';
  static const _keySelectedModel = 'osia_selected_model';
  static const _keyLanguage = 'osia_language';
  static const _keyAutoTts = 'osia_auto_tts';
  static const _keyLiveApi = 'osia_liveapi_enabled';
  static const _keyRelayDeviceId = 'osia_relay_device_id';
  static const _keyNotificationsEnabled = 'osia_notifications_enabled';
  static const _keyBackgroundConnectionEnabled =
      'osia_background_connection_enabled';
  static const _keyShownNotificationIds = 'osia_shown_notification_ids';
  static const _keyLanPairings = 'osia_lan_pairings_v1';
  static const _keyAcceptedTermsVersion = 'osia_accepted_terms_version';
  static const _keyAcceptedTermsAt = 'osia_accepted_terms_at';
  static const _keySeenPrivacyVersion = 'osia_seen_privacy_version';

  /// Default/fallback server host. Normal connections resolve the current
  /// quick-tunnel host through rendezvous; only the token is asked for.
  static const String defaultHost = 'app.osia.space';
  static const String _legacyDefaultHost = 'osia.space';

  final FlutterSecureStorage _storage;

  StorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // resetOnError makes the Android plugin auto-drop entries it can
            // no longer decrypt (keystore change) instead of throwing — a
            // native backstop to the Dart-level [_safeRead] guard below.
            aOptions: AndroidOptions(resetOnError: true),
          );

  /// Read a value from secure storage, tolerating decryption failures.
  ///
  /// When the platform keystore changes (app reinstall, Android Keystore
  /// rotation) a previously-encrypted value can no longer be decrypted and the
  /// plugin throws a [PlatformException] (BadPaddingException / BAD_DECRYPT).
  /// Rather than letting that propagate — which froze the chat screen on a
  /// blank loading spinner — we swallow the error, delete the corrupted entry
  /// and fall back to [defaultValue].
  Future<String?> _safeRead(String key, {String? defaultValue}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint(
        '[OSIA Storage] read("$key") failed: $e — dropping corrupted entry',
      );
      try {
        await _storage.delete(key: key);
      } catch (_) {
        // Best-effort cleanup; ignore if the delete itself fails.
      }
      return defaultValue;
    }
  }

  // ── Tailscale IP ──────────────────────────────────────────────────────

  /// Save the PC's Tailscale IP address.
  Future<void> setTailscaleIp(String ip) async {
    await _storage.write(key: _keyTailscaleIp, value: ip.trim());
  }

  /// Read the saved Tailscale IP, or `null` if never set.
  Future<String?> getTailscaleIp() async {
    final saved = await _safeRead(_keyTailscaleIp);
    if (saved == _legacyDefaultHost) {
      try {
        await _storage.write(key: _keyTailscaleIp, value: defaultHost);
      } catch (e) {
        debugPrint('[OSIA Storage] legacy host migration write failed: $e');
      }
      return defaultHost;
    }
    return saved;
  }

  // ── Auth token ────────────────────────────────────────────────────────

  /// Save the authentication token.
  Future<void> setToken(String token) async {
    await _storage.write(key: _keyToken, value: token.trim());
  }

  /// Read the saved token, or `null` if never set.
  Future<String?> getToken() async {
    return _safeRead(_keyToken);
  }

  Future<String> getOrCreateRelayDeviceId() async {
    final saved = (await _safeRead(_keyRelayDeviceId))?.trim();
    if (saved != null && saved.isNotEmpty) return saved;

    final random = Random.secure();
    final suffix = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = 'mobile-$suffix';
    await _storage.write(key: _keyRelayDeviceId, value: id);
    return id;
  }

  Future<LanPairingIdentity?> getLanPairing(String pairId) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(pairId)) return null;
    final raw = await _safeRead(_keyLanPairings);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final entry = decoded[pairId];
      if (entry is! Map) return null;
      final alias = (entry['instance_alias'] ?? '').toString();
      final pin = (entry['certificate_sha256'] ?? '').toString().toLowerCase();
      if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(alias) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(pin)) {
        return null;
      }
      return LanPairingIdentity(instanceAlias: alias, certificateSha256: pin);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLanPairing(String pairId, LanPairingIdentity identity) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(pairId) ||
        !RegExp(r'^[0-9a-f]{16}$').hasMatch(identity.instanceAlias) ||
        !RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(identity.certificateSha256.toLowerCase())) {
      throw const FormatException('invalid LAN pairing identity');
    }
    final existing = await _safeRead(_keyLanPairings);
    Map<String, dynamic> pairings = <String, dynamic>{};
    if (existing != null && existing.isNotEmpty) {
      try {
        final decoded = jsonDecode(existing);
        if (decoded is Map) {
          pairings = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } catch (_) {
        pairings = <String, dynamic>{};
      }
    }
    pairings[pairId] = <String, String>{
      'instance_alias': identity.instanceAlias,
      'certificate_sha256': identity.certificateSha256.toLowerCase(),
    };
    await _storage.write(key: _keyLanPairings, value: jsonEncode(pairings));
  }

  // ── Theme ────────────────────────────────────────────────────────────

  Future<void> setThemeKey(String key) async {
    await _storage.write(key: _keyThemeKey, value: key);
  }

  Future<String?> getThemeKey() async {
    return _safeRead(_keyThemeKey);
  }

  // ── Language ─────────────────────────────────────────────────────────

  Future<void> setLanguageCode(String code) async {
    await _storage.write(key: _keyLanguage, value: code);
  }

  /// Read the saved language code, or `null` if the user never picked one
  /// (first launch — the device locale is used instead).
  Future<String?> getLanguageCode() async {
    return _safeRead(_keyLanguage);
  }

  // ── Auto-TTS ─────────────────────────────────────────────────────────

  /// Save whether OSIA reads responses aloud automatically.
  Future<void> setAutoTts(bool enabled) async {
    await _storage.write(key: _keyAutoTts, value: enabled ? 'true' : 'false');
  }

  /// Whether OSIA reads responses aloud automatically. WOR-78 Fix B: defaults
  /// to false (off) when the user never touched the toggle. An explicit enable
  /// persisted via [setAutoTts] (stored as 'true') is still honoured, so a user
  /// who already turned it on keeps their setting; only the unset default flips.
  Future<bool> getAutoTts() async {
    final raw = await _safeRead(_keyAutoTts);
    return raw == 'true';
  }

  // ── Live API ─────────────────────────────────────────────────────────

  /// Remember whether the voice-to-voice Live API is enabled. This only
  /// mirrors the user's last choice locally so the toggle restores its
  /// state on launch; the authoritative value lives in the PC's
  /// settings.json (pushed via `set_setting`).
  Future<void> setLiveApiEnabled(bool enabled) async {
    await _storage.write(key: _keyLiveApi, value: enabled ? 'true' : 'false');
  }

  /// Whether the Live API is enabled. Defaults to false (off) when the
  /// user never touched the toggle.
  Future<bool> getLiveApiEnabled() async {
    final raw = await _safeRead(_keyLiveApi);
    return raw == 'true';
  }

  /// Local-only mobile notification preference. Defaults to off until the user
  /// explicitly enables it from Settings and grants the platform permission.
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _storage.write(
      key: _keyNotificationsEnabled,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> getNotificationsEnabled() async {
    final raw = await _safeRead(_keyNotificationsEnabled);
    return raw == 'true';
  }

  /// Local-only preference for the Android foreground-service mode that keeps
  /// the mobile WebSocket alive while OSIA is backgrounded. Defaults off.
  Future<void> setBackgroundConnectionEnabled(bool enabled) async {
    await _storage.write(
      key: _keyBackgroundConnectionEnabled,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> getBackgroundConnectionEnabled() async {
    final raw = await _safeRead(_keyBackgroundConnectionEnabled);
    return raw == 'true';
  }

  Future<List<String>> getShownNotificationIds() async {
    final raw = await _safeRead(_keyShownNotificationIds);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint(
        '[OSIA Storage] notification id cache unreadable: $e - dropping it',
      );
      try {
        await _storage.delete(key: _keyShownNotificationIds);
      } catch (_) {
        // Best-effort cleanup; ignore if the delete itself fails.
      }
      return const [];
    }
  }

  Future<void> setShownNotificationIds(Iterable<String> ids) async {
    final clean = ids
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    await _storage.write(
      key: _keyShownNotificationIds,
      value: jsonEncode(clean),
    );
  }

  // ── Selected model ───────────────────────────────────────────────────

  Future<void> setSelectedModel(String model) async {
    await _storage.write(key: _keySelectedModel, value: model);
  }

  Future<String?> getSelectedModel() async {
    return _safeRead(_keySelectedModel);
  }

  Future<void> clearSelectedModel() async {
    await _storage.delete(key: _keySelectedModel);
  }

  Future<String?> getAcceptedTermsVersion() =>
      _safeRead(_keyAcceptedTermsVersion);

  Future<DateTime?> getAcceptedTermsAt() async {
    final value = await _safeRead(_keyAcceptedTermsAt);
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }

  Future<String?> getSeenPrivacyVersion() => _safeRead(_keySeenPrivacyVersion);

  Future<void> recordTermsAcceptance(
    String version,
    DateTime acceptedAt,
  ) async {
    await _storage.write(key: _keyAcceptedTermsVersion, value: version);
    await _storage.write(
      key: _keyAcceptedTermsAt,
      value: acceptedAt.toUtc().toIso8601String(),
    );
  }

  Future<void> recordPrivacySeen(String version) async {
    await _storage.write(key: _keySeenPrivacyVersion, value: version);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// True if a token is stored (i.e. ready to connect). WOR-64: the server host
  /// is no longer persisted — it is resolved fresh from the token on every
  /// connect — so only the token gates readiness.
  Future<bool> isConfigured() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear connection credentials (IP, token, selected model) while
  /// preserving non-connection preferences like the chosen theme.
  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyTailscaleIp);
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keySelectedModel);
    await _storage.delete(key: _keyLanPairings);
  }

  /// Clear all stored values.
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}

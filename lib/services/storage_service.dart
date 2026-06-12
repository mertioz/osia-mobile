import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  /// Default server host used by the connection screen — the app always
  /// connects to the public OSIA endpoint; only the token is asked for.
  static const String defaultHost = 'osia.space';

  final FlutterSecureStorage _storage;

  StorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
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
          '[OSIA Storage] read("$key") failed: $e — dropping corrupted entry');
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
    return _safeRead(_keyTailscaleIp);
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

  /// Whether OSIA reads responses aloud automatically. Defaults to true
  /// when the user never touched the toggle.
  Future<bool> getAutoTts() async {
    final raw = await _safeRead(_keyAutoTts);
    return raw != 'false';
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
  }

  /// Clear all stored values.
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for persisting sensitive settings: Tailscale IP and auth token.
///
/// Uses [FlutterSecureStorage] so keys are stored in the platform keychain
/// (Android Keystore / iOS Keychain).
class StorageService {
  static const _keyTailscaleIp = 'osia_tailscale_ip';
  static const _keyToken = 'osia_token';

  final FlutterSecureStorage _storage;

  StorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // ── Tailscale IP ──────────────────────────────────────────────────────

  /// Save the PC's Tailscale IP address.
  Future<void> setTailscaleIp(String ip) async {
    await _storage.write(key: _keyTailscaleIp, value: ip.trim());
  }

  /// Read the saved Tailscale IP, or `null` if never set.
  Future<String?> getTailscaleIp() async {
    return await _storage.read(key: _keyTailscaleIp);
  }

  // ── Auth token ────────────────────────────────────────────────────────

  /// Save the authentication token.
  Future<void> setToken(String token) async {
    await _storage.write(key: _keyToken, value: token.trim());
  }

  /// Read the saved token, or `null` if never set.
  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// True if both IP and token are stored (i.e. ready to connect).
  Future<bool> isConfigured() async {
    final ip = await getTailscaleIp();
    final token = await getToken();
    return ip != null && ip.isNotEmpty && token != null && token.isNotEmpty;
  }

  /// Clear all stored values.
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}

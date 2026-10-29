import '../native/native_call_bridge.dart';

/// Secure credential store contract (spec 10.1): native-backed shared store.
/// Android: Keystore + AES-GCM (fresh IV, standard primitive).
/// iOS: Keychain accessible after first unlock (AfterFirstUnlockThisDeviceOnly).
/// Nothing here ever writes to plaintext files or SharedPreferences/UserDefaults.
class SecureCredentialStore {
  final NativeCallBridge _bridge;
  SecureCredentialStore(this._bridge);

  static const _kDomain = 'smi.domain';
  static const _kExtension = 'smi.extension';
  static const _kPassword = 'smi.password';
  static const _kSipPassword = 'smi.sipPassword';
  static const _kInstallationId = 'smi.installationId';
  static const _kToken = 'smi.accessToken';

  Future<bool> hasAccount() async {
    final ext = await _bridge.secureRead(_kExtension);
    final pass = await _bridge.secureRead(_kPassword);
    return ext != null && pass != null;
  }

  Future<void> saveAccount({
    required String domain,
    required String extension,
    required String password,
    required String sipPassword,
    required String installationId,
    String? accessToken,
  }) async {
    await _bridge.secureWrite(_kDomain, domain);
    await _bridge.secureWrite(_kExtension, extension);
    await _bridge.secureWrite(_kPassword, password);
    await _bridge.secureWrite(_kSipPassword, sipPassword);
    await _bridge.secureWrite(_kInstallationId, installationId);
    if (accessToken != null) await _bridge.secureWrite(_kToken, accessToken);
  }

  Future<void> saveToken(String? token) async {
    if (token == null) {
      await _bridge.secureDelete(_kToken);
    } else {
      await _bridge.secureWrite(_kToken, token);
    }
  }

  Future<({String domain, String extension, String password, String? sipPassword, String installationId, String? token})?>
      load() async {
    final domain = await _bridge.secureRead(_kDomain);
    final ext = await _bridge.secureRead(_kExtension);
    final pass = await _bridge.secureRead(_kPassword);
    final sipPassword = await _bridge.secureRead(_kSipPassword);
    final inst = await _bridge.secureRead(_kInstallationId);
    final token = await _bridge.secureRead(_kToken);
    if (domain == null || ext == null || pass == null || inst == null) return null;
    return (
      domain: domain,
      extension: ext,
      password: pass,
      sipPassword: sipPassword,
      installationId: inst,
      token: token,
    );
  }

  /// Local wipe on logout. Server-side revoke failure is reported separately —
  /// wiping local state must never be claimed as a confirmed server logout (spec 7.4).
  Future<void> wipe() async {
    await _bridge.secureDelete(_kToken);
    await _bridge.secureDelete(_kPassword);
    await _bridge.secureDelete(_kSipPassword);
    await _bridge.secureDelete(_kExtension);
    await _bridge.secureDelete(_kInstallationId);
    await _bridge.secureDelete(_kDomain);
  }

  /// Detects a fresh install that lost its secure data (reinstall case, spec 10.1):
  /// the caller shows the login/reset flow instead of pretending to be signed in.
  Future<bool> looksFreshInstall() => hasAccount().then((v) => !v);
}

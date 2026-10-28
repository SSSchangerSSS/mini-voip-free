/// Build-time server configuration (spec 10.1 — single control-plane host).
///
/// The `android-build` GitHub Actions workflow bakes the server address into the
/// APK via `--dart-define=SMI_SERVER_HOST=... --dart-define=SMI_SERVER_PORT=...`
/// so the end user only enters extension + password. Without baked values
/// (local dev / CI tests) the login page keeps its manual domain field — the
/// previous behavior is preserved, nothing is guessed.
class AppConfig {
  static const String _host =
      String.fromEnvironment('SMI_SERVER_HOST', defaultValue: '');
  static const String _port =
      String.fromEnvironment('SMI_SERVER_PORT', defaultValue: '443');

  /// True when a server address was baked at build time.
  static bool get hasBakedHost => _host.trim().isNotEmpty;

  /// `host` or `host:port` for the https/wss base (443 stays implicit).
  /// TLS is NEVER bypassed: an IP or domain here must present a certificate
  /// the OS trusts (docs/USAGE.fa.md).
  static String get domain {
    final h = _host.trim().toLowerCase();
    final p = int.tryParse(_port) ?? 443;
    return p == 443 ? h : '$h:$p';
  }
}

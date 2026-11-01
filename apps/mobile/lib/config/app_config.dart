/// Build-time server configuration (spec 10.1 — single control-plane host).
///
/// The `android-build` GitHub Actions workflow bakes the server address into the
/// APK via `--dart-define=SMI_SERVER_HOST=... --dart-define=SMI_SERVER_PORT=...`
/// so the end user only enters extension + password. Without baked values
/// (local dev / CI tests) the login page keeps its manual domain field — the
/// previous behavior is preserved, nothing is guessed.
class AppConfig {
  static String? overrideDomain;
  static bool validAddress(String value) {
    if(value != value.trim() || value.length>253 || !RegExp(r'^[a-zA-Z0-9.-]+(?::[0-9]{1,5})?$').hasMatch(value)) return false;
    final parts=value.split(':'); final host=parts.first;
    if(host.startsWith('.') || host.endsWith('.') || host.contains('..') || !host.contains('.'))return false;
    if(parts.length==2 && ((int.tryParse(parts[1])??0)<1 || int.parse(parts[1])>65535))return false;
    if(RegExp(r'^[0-9.]+$').hasMatch(host)) {
      final octets=host.split('.'); if(octets.length!=4 || octets.any((o)=>(int.tryParse(o)??256)>255)) return false;
    }
    return true;
  }
  static const String _host =
      String.fromEnvironment('SMI_SERVER_HOST', defaultValue: '');
  static const String _port =
      String.fromEnvironment('SMI_SERVER_PORT', defaultValue: '443');

  /// True when a server address was baked at build time.
  static bool get hasBakedHost => overrideDomain != null || _host.trim().isNotEmpty;

  /// `host` or `host:port` for the https/wss base (443 stays implicit).
  /// TLS is NEVER bypassed: an IP or domain here must present a certificate
  /// the OS trusts (docs/USAGE.fa.md).
  static String get domain {
    if(overrideDomain != null) return overrideDomain!;
    final h = _host.trim().toLowerCase();
    final p = int.tryParse(_port) ?? 443;
    return p == 443 ? h : '$h:$p';
  }
}
